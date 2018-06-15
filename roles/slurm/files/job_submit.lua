--[[

 This lua script assigns the right QoS to each job, based on a predefined table and
 assuming that each partition will have a QoS for short jobs and one for long jobs.
 The correct QoS is chosen by comparing the time limit of the job to a given threshold.

 The PARTITION_TO_QOS table contains these thresholds and QoS names for all partitions:
 for jobs having a time limit below the threshold, the given short QoS will be applied.
 Otherwise,  the specified long QoS will be applied.

 Note that this script should be named "job_submit.lua" and be stored
 in the same directory as the SLURM configuration file, slurm.conf.
 It will be automatically run by the SLURM daemon for each job submission.

--]]


--			PARTITION  TIME LIMIT	SHORT QOS	LONG QOS
--			NAME	   THRESHOLD	NAME		NAME
--				   (MINUTES!)
PARTITION_TO_QOS = {
			nodes 	  = {3*24*60,	"nodes",	"nodeslong"	},
                        regular   = {3*24*60,   "regular",      "regularlong"   },
			gpu	  = {1*24*60,	"gpu",		"gpulong"	},
			himem	  = {3*24*60, 	"himem",	"himemlong"	},
			short     = {30*60,	"short",	"short"		},
			nodestest = {3*24*60,	"nodestest",	"nodestestlong"	},
			target    = {3*24*60,   "target",       "target"        },
			euclid    = {3*24*60,   "target",       "target"        }
		   }

-- Jobs that do not have a partition, will be routed to the following default partition.
-- Can also be found dynamically using something like:
-- sinfo | awk '{print $1}' | grep "*" | sed 's/\*$//'
-- Or by finding the partition in part_list that has flag_default==1
DEFAULT_PARTITION = "regular"


function slurm_job_submit(job_desc, part_list, submit_uid)

	-- If partition is not set, set it to the default one
	if job_desc.partition == nil then
		job_desc.partition = DEFAULT_PARTITION
	end

	-- Find the partition in SLURM's partition list that matches the
	-- partition of the job description.
	local partition = false
	for name, part in pairs(part_list) do
		if name == job_desc.partition then
			partition = part
			break
		end
	end

	-- To be sure, check if a valid partition has been found.
	-- This should always be the case, otherwise the job would have been rejected.
	if not partition then
		return slurm.ERROR
	end

        -- If the job does not have a time limit, set it to
        -- the default time limit of the job's partition.
        -- For some reason (bug?), the nil value is passed as 4294967294.
        if job_desc.time_limit == nil or job_desc.time_limit == 4294967294 then
                job_desc.time_limit = partition.default_time
        end

	-- Now use the job's partition and the PARTITION_TO_QOS table
	-- to assign the right QOS to the job.
	local qos_map = PARTITION_TO_QOS[partition.name]
	if job_desc.time_limit <= qos_map[1] then
		job_desc.qos = qos_map[2]
	else
		job_desc.qos = qos_map[3]
	end
	--slurm.log_info("qos = %s", job_desc.qos)

	return slurm.SUCCESS
end

function slurm_job_modify(job_desc, job_rec, part_list, modify_uid)
--	if job_desc.comment == nil then
--		local comment = "***TEST_COMMENT***"
--		slurm.log_info("slurm_job_modify: for job %u from uid %u, setting default comment value: %s",
--				job_rec.job_id, modify_uid, comment)
--		job_desc.comment = comment
--	end

	return slurm.SUCCESS
end

slurm.log_info("initialized")
return slurm.SUCCESS
