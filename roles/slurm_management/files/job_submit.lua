--[[

 This lua script:
 * assigns the right sub-QoS to each job, 
   based on a predefined table and assuming that each QoS will have a sub-QoS for short, medium and long jobs.
   The correct sub-QoS is chosen by comparing the time limit of the job to a given threshold.
 * Checks if the user submitting the job is associated to a Slurm account in the Slurm accounting database;
   If the relevant Slurm account or Slurm user or association does not yet exist in the DB,
   the missing pieces are automatically created.

 Note that this script should be 
  * named "job_submit.lua" and 
  * stored in the same directory as the SLURM configuration file, slurm.conf.
    the default location is /etc/slurm/slurm.conf
  * enabled in slurm.conf by adding:
    JobSubmitPlugins=lua
    
 When configured correctly the SLURM daemons will execute the following 2 functions automatically for each job:
  * slurm_job_submit on job submission.
  * slurm_job_modify when a job is modified.
  
 Documentation for the SLURM job submit Lua API is minimal. For available fields use the source @
    slurm-VERSION/src/plugins/job_submit/lua/

--]]

--
-- Only for debugging.
-- requires inspect.lua from https://github.com/kikito/inspect.lua
--
--local inspect = require 'inspect'

--
-- For a.o. converting UIDs and GIDs to user- and groupnames.
--
local posix = require "posix"

--
-- Production QoS levels are divided in sub-levels for short, medium and long jobs as indicated by a suffix.
-- It is currently not possible to get a list of QoS levels from the SLURM job submit Lua API,
-- so if something changes in our QoS setup, we must change the hard-coded list of sub-QoS levels here.
--
QOS_TIME_LIMITS = {
    {6*60,    'short'},
    {1*24*60, 'medium'},
    {7*24*60, 'long'},
}

--
-- Disabled default walltime limit to force users to specify a walltime.
--
--DEFAULT_WALLTIME = '1'

--
-- Check if the user submitting the job is associated to a Slurm account in the Slurm accounting database and
-- create the relevant Slurm account and/or Slurm user and/or association if it does not already exist.
--
function ensure_user_has_slurm_association(uid, user, group)
    --
    -- Skip root user.
    --
    if uid == 0 then
        return true
    end
    
    slurm.log_debug("Checking assoc for user %s (uid=%u) in account for group %s...", user, uid, group)
    if association_exists(user, group) then
        slurm.log_debug("Association of user %s to account %s already exists.", user, group)
        return true
    else
        if account_exists(group) then
            slurm.log_debug("Account %s already exists.", group)
        else
            slurm.log_info("Account %s does not exist; creating one...", group)
            if not create_account(group) then
                return false
            end
        end
        slurm.log_info("Association of user %s to account %s does not exist; creating one...", user, group)
        if not create_association(user,group) then
            return false
        end
    end
    return true
end

function account_exists(group)
    --
    -- Unfortunately, filehandles returned by io.popen() don't have a way to return their exitstatuses in <= lua 5.2.
    -- Should be reasonably safe here, since if we erroneously conclude the association doesn't exist,
    -- then we'll just try to add it.
    -- http://lua-users.org/lists/lua-l/2012-01/msg00364.html
    --
    local query = io.popen(string.format(
        "sacctmgr --parsable2 --noheader list accounts format=account account='%s'", group))
    for line in query:lines() do
        if line == group then
            return true
        end
    end
    return false
end

--
-- Use fairshare=parent only for (group) accounts to flatten the tree.
-- We use the groups only for reporting and not for differentiation in fair share factors.
-- See: https://bugs.schedmd.com/show_bug.cgi?id=3491
--
function create_account(group)
    local retval = os.execute(string.format(
        "sacctmgr -i create account '%s' descr=scientists org=various parent=users fairshare=parent", group))
    if retval ~= 0 then
        slurm.log_error("Failed to create account %s (exit status = %d).", group, retval)
        slurm.log_user("Failed to create account %s (exit status = %d). Contact an admin.", group, retval)
        return false
    else
        slurm.log_info("Created account for group %s.", group)
        return true
    end
end

function association_exists(user, group)
    --
    -- Unfortunately, filehandles returned by io.popen() don't have a way to return their exitstatuses in <= lua 5.2.
    -- Should be reasonably safe here, since if we erroneously conclude the association doesn't exist,
    -- then we'll just try to add it.
    -- http://lua-users.org/lists/lua-l/2012-01/msg00364.html
    --
    local query = io.popen(string.format(
        "sacctmgr --parsable2 --noheader list associations format=user,account user='%s' account='%s'", user, group))
    for line in query:lines() do
        if line == user .. '|' .. group then
            return true
        end
    end
    return false
end

--
-- Use fairshare=[integer] for (user) accounts.
-- Do not use fairshare=parent here, because that would give all users the same fair share,
-- which de facto disables fair share as all parents are groups with the same fair share.
-- See: https://bugs.schedmd.com/show_bug.cgi?id=3491
--
function create_association(user,group)
    local retval = os.execute(string.format(
        "sacctmgr -i create user name='%s' account='%s' fairshare=1", user, group))
    if retval ~= 0 then
        slurm.log_error("Failed to create association of user %s to account %s (exit status = %d).", user, group, retval)
        slurm.log_user("Failed to create association of user %s to account %s (exit status = %d). Contact an admin.", user, group, retval)
        return false
    else
        slurm.log_info("Created association of user %s to account %s.", user, group)
        return true
    end
end

function slurm_job_submit(job_desc, part_list, submit_uid)
    -- 
    -- Get details for the user who is trying to submit a job.
    --
    submit_user = posix.getpasswd(submit_uid)
    
    --
    -- Force jobs to share nodes when they don't consume all resources on a node.
    --
    if job_desc.shared == 0 then
        job_desc.shared = 1
    end
    
    --
    -- Check if the job does have a time limit specified.
    -- For some reason (bug?), the nil value is passed as 4294967294.
    --
    if job_desc.time_limit == nil or job_desc.time_limit == 4294967294 then
        slurm.log_error("Walltime missing for job named %s from user %s (uid=%u). You must specify a walltime!", tostring(job_desc.name), tostring(submit_user.name), job_desc.user_id)
        slurm.log_user("Walltime missing for job named %s from user %s (uid=%u). You must specify a walltime!", tostring(job_desc.name), tostring(submit_user.name), job_desc.user_id)
    end
    
    --
    -- Select all partitions by default. 
    -- Which nodes in which partitions can be used by a job is determined by QoS or constraints a.k.a. features.
    --
    job_desc.partition = '' -- This will reset the partition list if the user specified any.
    local part_names = { }
    for name, part in pairs(part_list) do
        part_names[#part_names+1] = tostring(name)
    end
    job_desc.partition = table.concat(part_names, ',')
    slurm.log_debug("Assigned partition(s) %s to job named %s from user %s (uid=%u).", tostring(job_desc.partition), tostring(job_desc.name), tostring(submit_user.name), job_desc.user_id)
    
    --
    -- Check if we need a specific file system based on path to job's working directory, *.err file or *.out file.
    -- and adjust features/constraints accordingly. Note: these features may conflict with features/constraints requested by the user.
    --
    --slurm.log_debug("Job script = %s.", tostring(job_desc.script))
    --slurm.log_debug("Path to job *.out  = %s.", tostring(job_desc.std_out))
    --slurm.log_debug("Path to job *.err  = %s.", tostring(job_desc.std_err))
    --slurm.log_debug("Job's working dir  = %s.", tostring(job_desc.work_dir))
    local job_metadata = {job_desc.std_out, job_desc.std_err, job_desc.work_dir}
    local group = nil
    local lfs = nil
    for inx,job_metadata_value in ipairs(job_metadata) do
        if string.match(tostring(job_metadata_value), '^/home/') then
            slurm.log_error(
                "Job's working dir, *.err file or *.out file is located in a home dir, which is only designed for user preferences and not for massive parallel data crunching.\n" .. 
                "Use a /groups/${group}/tmp*/ file system instead.\n" ..
                "Rejecting job named %s from user %s (uid=%u).", tostring(job_desc.name), tostring(submit_user.name), job_desc.user_id)
            slurm.log_user(
                "Job's working dir, *.err file or *.out file is located in a home dir, which is only designed for user preferences and not for massive parallel data crunching.\n" .. 
                "Use a /groups/${group}/tmp*/ file system instead.\n" ..
                "Rejecting job named %s from user %s (uid=%u).", tostring(job_desc.name), tostring(submit_user.name), job_desc.user_id)
            return slurm.ERROR
        end
        group, lfs = string.match(tostring(job_metadata_value), '^/groups/([^/]+)/(tmp%d%d)/?')
        if group ~= nil and lfs ~= nil then
            slurm.log_debug("Found group '%s' and LFS '%s' in job's metadata.", tostring(group), tostring(lfs))
            if job_desc.features == nil or job_desc.features == '' then
                job_desc.features = lfs
                slurm.log_debug("Job had no features yet; Assigned LFS as first feature: %s.", tostring(job_desc.features))
            else
                if not string.match(tostring(job_desc.features), lfs) then
                    job_desc.features = job_desc.features .. '&' .. lfs
                    slurm.log_debug("Appended LFS %s to job's features.", tostring(lfs))
                else
                    slurm.log_debug("Job's features already contained LFS %s.", tostring(lfs))
                end
            end
        else
            slurm.log_error(
                 "Job's working dir, *.err file or *.out file is not located in /groups/${group}/tmp*/...\n" ..
                 "Found %s instead.\n" ..
                 "You may have specified the wrong file system or you have a typo in your job script.\n" ..
                 "Rejecting job named %s from user %s (uid=%u).", tostring(job_metadata_value), tostring(job_desc.name), tostring(submit_user.name), job_desc.user_id)
            slurm.log_user(
                 "Job's working dir, *.err file or *.out file is not located in /groups/${group}/tmp*/...\n" ..
                 "Found %s instead.\n" ..
                 "You may have specified the wrong file system or you have a typo in your job script.\n" ..
                 "Rejecting job named %s from user %s (uid=%u).", tostring(job_metadata_value), tostring(job_desc.name), tostring(submit_user.name), job_desc.user_id)
            return slurm.ERROR
        end
    end
    slurm.log_debug("Job's features contains: %s.", tostring(job_desc.features))
    --
    -- Check if the user submitting the job is associated to a Slurm account in the Slurm accounting database and
    -- create the relevant Slurm account and/or Slurm user and/or association if it does not already exist.
    -- Note: as slurm account we use the group that was found last while parsing job_metadata above.
    --
    if not ensure_user_has_slurm_association(submit_uid, tostring(submit_user.name), tostring(group)) then
        slurm.log_error("Failed to create association in the Slurm accounting database for user %s in account/group %s", tostring(submit_user.name), tostring(group))
        slurm.log_error("Rejecting job named %s from user %s (uid=%u).", tostring(job_desc.name), tostring(submit_user.name), job_desc.user_id)
        slurm.log_user(
                 "Failed to create association in the Slurm accounting database. Contact an admin.\n" ..
                 "Rejecting job named %s from user %s (uid=%u).", tostring(job_desc.name), tostring(submit_user.name), job_desc.user_id)
        return slurm.ERROR
    end
    
    --
    -- Process final list of features:
    --  1. Check if features are specified in the correct format.
    --     A common mistake is to list multiple feature separated with a comma like in the node spec in slurm.conf,
    --     but when submitting jobs they must be separated with an & for logical AND (or with a | for logical OR).
    --  2. Check if we need a specific QoS based on features/constraints requested.
    --     Note: this may overrule the QoS requested by the user.
    --
    if job_desc.features ~= nil then
        local features = job_desc.features
        if string.match(features, ',') then
            slurm.log_error("Detected comma in list of requested features (%s) for job named %s from user %s (uid=%u). Multiple features must be joined with an ampersand (&) for logical AND.", tostring(features), tostring(job_desc.name), tostring(submit_user.name), job_desc.user_id)
            slurm.log_user("Detected comma in list of requested features (%s) for job named %s from user %s (uid=%u). Multiple features must be joined with an ampersand (&) for logical AND.", tostring(features), tostring(job_desc.name), tostring(submit_user.name), job_desc.user_id)
            return slurm.ERROR
        end
        slurm.log_info("features requested (%s) for job named %s from user %s (uid=%u). Will try to find suitable QoS...", tostring(features), tostring(job_desc.name), tostring(submit_user.name), job_desc.user_id)
        if string.match(features, 'dev') then
            job_desc.qos = 'dev'
        elseif string.match(features, 'ds') or string.match(features, 'prm') then
            job_desc.qos = 'ds'
        end
    end
    
    --
    -- Make sure we have a sanity checked base-QoS.
    --
    if job_desc.qos == nil then
        --
        -- Select default base-QoS if not set.
        --
        slurm.log_debug("No QoS level specified for job named %s from user %s (uid=%u). Will try to lookup default QoS...", tostring(job_desc.name), tostring(submit_user.name), job_desc.user_id)
        if job_desc.default_qos == nil then
            slurm.log_warn("Failed to fetch a default QoS for job named %s from user %s (uid=%u); will use QoS 'regular'.", tostring(job_desc.name), tostring(submit_user.name), job_desc.user_id)
            job_desc.qos = 'regular'
        else
            job_desc.qos = job_desc.default_qos
            slurm.log_debug("Found QoS %s for job named %s from user %s (uid=%u).", tostring(job_desc.qos), tostring(job_desc.name), tostring(submit_user.name), job_desc.user_id)
        end
    else
        --
        -- Sanity check: If the user accidentally specified a sub-QoS then reset the QoS by removing the sub-QoS suffix.
        --
        for index, sub_qos in ipairs(QOS_TIME_LIMITS) do
            local qos_suffix = sub_qos[2]
            slurm.log_debug("QoS %s before stripping sub-QoS suffix pattern %s.", tostring(job_desc.qos), tostring('-' .. qos_suffix .. '$'))
            job_desc.qos = string.gsub(job_desc.qos, '-' .. qos_suffix .. '$', '')
            slurm.log_debug("QoS %s after stripping sub-QoS suffix.", tostring(job_desc.qos), tostring(qos_suffix .. '$'))
        end
    end
    
    --
    -- Assign the right sub-QoS to the job.
    --
    local new_qos = false
    local qos_base = job_desc.qos
    for index, sub_qos in ipairs(QOS_TIME_LIMITS) do
        local qos_time_limit = sub_qos[1]
        local qos_suffix     = sub_qos[2]
        if job_desc.time_limit <= qos_time_limit then
            new_qos = qos_base .. '-' .. qos_suffix
            job_desc.qos = new_qos
            break
        end
    end
    
    --
    -- Sanity check if a valid sub-QOS has been found.
    --
    if not new_qos then
        slurm.log_error("Could not process job named %s from user %s (uid=%u) to assign a sub-QoS.", tostring(job_desc.name), tostring(submit_user.name), job_desc.user_id)
        slurm.log_user("Failed to assign a sub-QoS to the job named %s. Check the requested resources (cores, memory, walltime, etc.) as they do not fit any sub-QoS for QoS %s.", 
            tostring(job_desc.name), tostring(job_desc.qos)
        )
        return slurm.ERROR
    else
        slurm.log_info("Assigned QoS %s to job named %s from user %s (uid=%u).", new_qos, job_desc.name, tostring(submit_user.name), job_desc.user_id)
    end
    
    return slurm.SUCCESS
    
end

function slurm_job_modify(job_desc, job_rec, part_list, modify_uid)
--    if job_desc.comment == nil then
--        local comment = "***TEST_COMMENT***"
--        slurm.log_info("slurm_job_modify: for job %u from uid %u, setting default comment value: %s",
--                job_rec.job_id, modify_uid, comment)
--        job_desc.comment = comment
--    end
    return slurm.SUCCESS
end

function dump(o)
  if type(o) == 'table' then
    local s = '{ '
    for k,v in pairs(o) do
      if type(k) ~= 'number' then k = '"'..k..'"' end
      s = s .. '['..k..'] = ' .. dump(v) .. ','
    end
    return s .. '} '
  else
    return tostring(o)
  end
end

slurm.log_info("Initialized")
return slurm.SUCCESS
