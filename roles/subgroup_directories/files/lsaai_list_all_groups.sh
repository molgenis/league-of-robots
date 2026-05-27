#!/bin/bash
set -euo pipefail

./get_ggcc_token.sh
TOKEN_DIR="${HOME}/.cache/lsaai/"
TOKEN_FILE="${TOKEN_DIR}/token"
if test -r "${TOKEN_FILE}"; then
   TOKEN=$(cat "${TOKEN_FILE}")
else
   echo "ERROR, could not read token!"
   exit 1
fi

BASE_URL='https://perun-api.aai.lifescience-ri.eu/oauth/rpc/json'
VO_ID='3363'

DEBUG=false
DEBUG2=false
[[ ${2:-} == '-v' ]] && DEBUG=true
[[ ${2:-} == '-vv' ]] && { DEBUG2=true; DEBUG=true; }
 
curl_it() {
    local url="${1}"
    local json="${2:-}"
    local -a args=(-s -H "Authorization: Bearer ${TOKEN}")
 
    if [[ -n "${json}" ]]; then
        args+=(-X POST -H "Content-Type: application/json" -d "${json}")
    fi
 
    args+=("${url}")
    curl "${args[@]}"
}
 

USER_ALL_INFO="$(curl_it "${BASE_URL}/authzResolver/getPerunPrincipal")"
#echo "   user all info: >${USER_ALL_INFO}<"
USER_ID="$(echo "${USER_ALL_INFO}" | jq '.user.id')"
$DEBUG && echo "  >> USER_ID >$USER_ID< <<"
USER_ID="78969"

MEMBER_ID="$(curl_it "$BASE_URL/membersManager/getMemberByUser" \
    "$(jq -n --argjson user "$USER_ID" --argjson vo "$VO_ID" '{user: $user, vo: $vo}')" \
    | jq -r '.id')"
$DEBUG && echo "  >> MEMBER_ID >${MEMBER_ID}< <<"

my_admin_groups=$(curl_it "${BASE_URL}/usersManager/getGroupsWhereUserIsAdmin" "{\"user\": ${USER_ID}, \"vo\": ${VO_ID} }")

my_member_groups="$(curl_it "$BASE_URL/groupsManager/getMemberGroups" "{\"member\": ${MEMBER_ID} }")"
#echo "my_member_groups=>${my_member_groups}<"

$DEBUG && jq -r '.[]' <<< "$my_member_groups"

##parentId=46811  	# L:erdera:freeze1
##new_group_id=46815	# L:erdera:freeze1:v03







# $1 parentName
# $2 subgroupname
# $3 expirationdays
make_new_subgroup(){
   # ── Inputs ───────────────────────────────────────────────────────────
   # Expected variables: BASE_URL, VO_ID, USER_ID, parentName, subgroupname, expirationdays
   local parentName="${1}"
   local subgroupname="${2}"
   local expirationdays="${3}"
   parentNameClean=$(echo "$parentName" | tr ':' '-')
   subgroupname=$(echo "$subgroupname" | tr '-' '_')
   
   # ── Fetch all groups and resolve parentId by name ────────────────────
   all_groups=$(curl_it "$BASE_URL/groupsManager/getAllGroups" "{\"vo\":\"$VO_ID\"}")
   parentId=$(echo "$all_groups" | jq -r --arg name "$parentName" 'map(select(.name==$name)) | .[0].id')
   
   if [[ -z "$parentId" || "$parentId" == "null" ]]; then
       echo "Error: could not resolve parent group '$parentName'"
       exit 1
   fi
   
   echo "Resolved parent '$parentName' -> id: $parentId"
   
   # ── Find dms group by walking up from parentId ───────────────────────
   dms_group_id=""
   current_id="$parentId"
   while [[ -n "$current_id" && "$current_id" != "null" ]]; do
       dms_group_id=$(echo "$all_groups" | jq -r --argjson pid "$current_id" \
           'map(select(.shortName=="dms" and .parentGroupId==$pid)) | .[0].id // empty')
       [[ -n "$dms_group_id" ]] && break
       current_id=$(echo "$all_groups" | jq -r --argjson id "$current_id" \
           'map(select(.id==$id)) | .[0].parentGroupId // empty')
   done
   
   ${DEBUG} && echo "dms group id: $dms_group_id"
   
   # ── Create group ─────────────────────────────────────────────────────
   new_group=$(curl_it "$BASE_URL/groupsManager/createGroup" \
      "{\"parentGroup\": $parentId, \"group\": {\"name\": \"$subgroupname\"}}")
   ${DEBUG2} && echo "createGroup raw response: $new_group"
   new_group_id=$(echo "$new_group" | jq -r '.id')
   ${DEBUG} && echo "new_group_id: $new_group_id"

   # ── Add admggin user ───────────────────────────────────────────────────
   ${DEBUG} && echo "Adding admin user $USER_ID to group $new_group_id"
   curl_it "$BASE_URL/groupsManager/addAdmin" \
       "{\"group\": \"$new_group_id\", \"user\": \"$USER_ID\"}"
   
   # ── Set membership expiration attribute ──────────────────────────────
   ${DEBUG} && echo "Adding expiration attribute: +${expirationdays}d"
   curl_it "$BASE_URL/attributesManager/setAttributes" \
       "{\"attributes\":[{\"namespace\":\"urn:perun:group:attribute-def:def\",\"type\":\"java.util.LinkedHashMap\",\"id\":3375,\"friendlyName\":\"groupMembershipExpirationRules\",\"value\":{\"period\":\"+${expirationdays}d\"}}],\"group\":\"$new_group_id\"}"
   
   # ── Set unix group name attribute ─────────────────────────────────────
   ${DEBUG} && echo "Adding unix attribute: $parentNameClean-$subgroupname"
   curl_it "$BASE_URL/attributesManager/setAttribute" \
       "{\"attribute\":{\"id\":3691,\"friendlyName\":\"unixGroupName-namespace:ggcc\",\"namespace\":\"urn:perun:group:attribute-def:def\",\"type\":\"java.lang.String\",\"displayName\":\"Unix group name in ggcc\",\"value\":\"$parentNameClean-$subgroupname\"},\"group\":$new_group_id}"
   
   # ── Create application form and items ────────────────────────────────
   ${DEBUG} && echo "Creating application form for group $new_group_id"
   curl_it "$BASE_URL/registrarManager/createApplicationForm" "{\"group\":$new_group_id}"
   
   ${DEBUG} && echo "Updating form items for group $new_group_id"
   curl_it "$BASE_URL/registrarManager/updateFormItems" "$(jq -cn \
       --argjson gid "$new_group_id" '{
           group: $gid,
           items: [
               {
                   applicationTypes: ["INITIAL","EXTENSION"],
                   ordnum: 0, type: "HEADING", shortname: "title",
                   required: false, updatable: true, disabled: "NEVER", hidden: "NEVER",
                   i18n: { en: { label: "Join the group", help: "", errorMessage: "" } }
               },
               {
                   applicationTypes: ["INITIAL","EXTENSION"],
                   ordnum: 1, type: "AUTO_SUBMIT_BUTTON", shortname: "autosubmit",
                   required: false, updatable: true, disabled: "NEVER", hidden: "NEVER",
                   i18n: { en: { label: "", help: "", errorMessage: "" } }
               }
           ]
       }')"
   
   # ── Add application mail notification ────────────────────────────────
   ${DEBUG} && echo "Adding application mail for group $new_group_id"
   curl_it "$BASE_URL/registrarManager/addApplicationMail" "$(jq -cn \
       --argjson gid "$new_group_id" \
       --arg vo "$VO_ID" '{
           group: $gid,
           mail: {
               appType: "INITIAL", formId: 10475,
               mailType: "APP_CREATED_USER", send: true,
               message: {
                   en: {
                       locale: "en", htmlFormat: false,
                       subject: "There is a pending application for {groupName} membership",
                       text: "User {firstName} {lastName} (re)applied for membership.\nYou can approve or reject the request at the following URL\nhttps://perun.aai.lifescience-ri.eu/organizations/\($vo)/groups/\($gid)/applications\ndisplayName {displayName}\nmail {mail}\n\nappG {appGuiUrl}\nextSource {extSource}\nfromApp-itemName {fromApp-itemName}\n\nmailFooter {mailFooter}\n"
                   },
                   cs: { locale: "cs", htmlFormat: false, subject: "", text: "" }
               },
               htmlMessage: {
                   en: { locale: "en", htmlFormat: true, subject: "", text: "" },
                   cs: { locale: "cs", htmlFormat: true, subject: "", text: "" }
               }
           }
       }')"
   
#   # ── Assign roles to user ──────────────────────────────────────────────
#   for role in GROUPCREATOR GROUPMEMBERSHIPMANAGER; do
#       echo "Assigning $role to user $USER_ID on group $new_group_id"
#       curl_it "$BASE_URL/authzResolver/setRole" \
#           "{\"role\":\"$role\",\"user\":$USER_ID,\"complementaryObject\":{\"id\":$new_group_id,\"beanName\":\"Group\"}}"
#   done
#   
   
   # ── Assign dms group as GROUPCREATOR and GROUPMEMBERSHIPMANAGER ───────
   if [[ -n "$dms_group_id" ]]; then
       for role in GROUPCREATOR GROUPMEMBERSHIPMANAGER; do
           ${DEBUG} && echo "Assigning $role to dms group $dms_group_id on group $new_group_id"
           curl_it "$BASE_URL/authzResolver/setRole" "$(jq -cn \
               --arg role "$role" \
               --argjson ag "$dms_group_id" \
               --argjson gid "$new_group_id" \
               '{role:$role, authorizedGroup:$ag, complementaryObject:{id:$gid, beanName:"Group"}}')"
       done
   else
       ${DEBUG} && echo "Warning: dms group not found for this branch, skipping."
   fi
   # ── Remove GROUPADMIN ─────────────────────────────────────────────────
   ${DEBUG} && echo "Removing GROUPADMIN from user $USER_ID on group $new_group_id"
   curl_it "$BASE_URL/authzResolver/unsetRole" \
       "{\"role\":\"GROUPADMIN\",\"user\":$USER_ID,\"complementaryObject\":{\"id\":$new_group_id,\"beanName\":\"Group\"}}"
}


print_all_my_groups() {
   all_groups=$(curl_it "$BASE_URL/groupsManager/getAllGroups" "{\"vo\":\"$VO_ID\"}")
   member_id=$(curl_it "$BASE_URL/membersManager/getMemberByUser" "{\"user\":\"$USER_ID\", \"vo\":\"$VO_ID\"}" | jq -r 'if type=="array" then .[0].id else .id end')
   my_group_ids=$(curl_it "$BASE_URL/groupsManager/getMemberGroups" "{\"member\":\"$member_id\"}" | jq '[.[].id]')
   direct_ids=$(curl_it "$BASE_URL/usersManager/getGroupsWhereUserIsAdmin" "{\"user\":\"$USER_ID\", \"vo\":\"$VO_ID\"}" | jq '[.[].id]')
   
   # Find indirect groups via role check
   declare -A indirect_groups
   while IFS= read -r group; do
       gid=$(echo "$group" | jq -r '.id')
       echo "$direct_ids" | jq -e --argjson id "$gid" 'index($id) != null' > /dev/null && continue
   
       for role in GROUPCREATOR GROUPMEMBERSHIPMANAGER; do
           via=$(curl_it "$BASE_URL/authzResolver/getAdminGroups" \
               "$(jq -cn --arg r "$role" --argjson id "$gid" '{role:$r,complementaryObjectId:$id,complementaryObjectName:"Group"}')" \
               | jq -r --argjson ids "$my_group_ids" 'map(select(.id as $i | $ids|index($i))) | .[0].name // empty')
           if [[ -n "$via" ]]; then
               indirect_groups[$gid]=$(echo "$group" | jq -c --arg v "$via" '. + {_via:$v}')
               break
           fi
       done
   done < <(echo "$all_groups" | jq -c '.[]?')
   
   # Add all subgroups of indirect groups (walk up tree to check ancestry)
   while IFS= read -r group; do
       gid=$(echo "$group" | jq -r '.id')
       echo "$direct_ids" | jq -e --argjson id "$gid" 'index($id) != null' > /dev/null && continue
       [[ -n "${indirect_groups[$gid]:-}" ]] && continue
   
       current="$group"
       while true; do
           parent_id=$(echo "$current" | jq -r '.parentGroupId // empty')
           [[ -z "$parent_id" || "$parent_id" == "null" ]] && break
           if [[ -n "${indirect_groups[$parent_id]:-}" ]]; then
               via=$(echo "${indirect_groups[$parent_id]}" | jq -r '._via')
               indirect_groups[$gid]=$(echo "$group" | jq -c --arg v "$via" '. + {_via:$v, inherited:"inherited via"}')
               break
           fi
           current=$(echo "$all_groups" | jq -c --argjson pid "$parent_id" 'first(.[]?|select(.id==$pid))')
           [[ -z "$current" || "$current" == "null" ]] && break
       done
   done < <(echo "$all_groups" | jq -c '.[]?')
   
   echo "┌────────────────────────────────────────────────────────────────────────────┐"
   echo "│ You are manager or admin of following groups                               │"
   echo "$all_groups" | jq -c '.[]?' | while IFS= read -r g; do
      gid=$(echo "$g" | jq -r '.id')
      name=$(echo "$g" | jq -r '.name')
      shortName=$(echo "$g" | jq -r '.shortName')
      [[ "${shortName}" == "dms" ]] && continue
      if [[ -n "${indirect_groups[$gid]:-}" ]]; then
         via=$(echo "${indirect_groups[$gid]}" | jq -r '._via')
         inherited=$(echo "${indirect_groups[$gid]}" | jq -r '.inherited // ""')
         printf "│ %-35s %-17s %-20s │\n" "${name//\:/\-}" "$inherited" "$via"
      elif echo "$direct_ids" | jq -e --argjson id "$gid" 'index($id) != null' > /dev/null; then
         printf "│ %-35s direct manager                         │\n" "$name"
      fi
   done
   echo "└────────────────────────────────────────────────────────────────────────────┘"
}

print_all_my_groups

echo "Would you like to create a new group?"
read -rp '  Parent name: ' _parentname
read -rp '  Subgroup name: ' _subgroupname
while [[ ${#_subgroupname} -lt 2 ]] || \
      [[ ${#_subgroupname} -gt 8 ]] || \
      [[ ! "${_subgroupname}" =~ ^[0-9a-zA-Z_]+$ ]] || \
      [[ "${_subgroupname}" == "dms" ]]; do
   echo "  > Invalid: must be 2-8 characters, only letters, digits, and underscore, and group cannot be named 'dms', try again!"
   read -rp '  Subgroup name: ' _subgroupname
done
_defaultexpirationdays=365
read -p "(Default Membership Expiration: (set by default to ${_defaultexpirationdays} days)" _expirationdays
[[ -z "${_expirationdays}" ]] && _expirationdays="${_defaultexpirationdays}"
make_new_subgroup "${_parentname//\-/\:}" "${_subgroupname}" "${_expirationdays}"
