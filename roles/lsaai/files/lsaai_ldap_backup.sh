#!/bin/bash
set -ueo pipefail

TAG="slapd_backup"
LDAP_DATA_DIR="/usr/local/openldap"
LDAP_CONFIG_DIR="/etc/openldap"
BACKUP_DIR="/root/lsaai_ldap_backup"
DAY="$(date +%d)"
MONTH="$(date +%Y-%m)"
TARGZ="lsaai_ldap_backup.tar.gz"
SERVICE="slapd-ltb.service"

# Check the backup directory
if [ ! -d "${BACKUP_DIR}" ]; then
   logger -s -t "${TAG}" "info: Backup directory ${BACKUP_DIR} does not exist - making one ..."
   if ! mkdir -p "${BACKUP_DIR}" 2>/dev/null; then
      logger -s -t "${TAG}" "ERROR: backup directory ${BACKUP_DIR} could not be created - exiting"
      exit 1
   fi
fi

# Check ldap directories
if [ ! -d "${LDAP_DATA_DIR}" ]; then
   logger -s -t "${TAG}" "ERROR: OpenLDAP data directory ${LDAP_DATA_DIR} was not found - exiting"
   exit 1
fi
if [ ! -d "${LDAP_CONFIG_DIR}" ]; then
   logger -s -t "${TAG}" "ERROR: config dir ${LDAP_CONFIG_DIR} was not found - exiting"
   exit 1
fi

# Stopping service
logger -s -t "${TAG}" "info: Attempting to stop OpenLDAP service (${SERVICE}) ..."
systemctl stop ${SERVICE} || \
   logger -s -t "${TAG}" "ERROR: service (${SERVICE}) could not be stopped (return value ${SERVICE_STOP_STATUS}), still trying to do partial backup ..."

# Create daily backup
logger -s -t "${TAG}" "info: Creating daily tar.gz archive ..."
tar -czf "${BACKUP_DIR}/${TARGZ}" "${LDAP_DATA_DIR}" "${LDAP_CONFIG_DIR}"
TAR_STATUS="${?}"
if [ ${TAR_STATUS} -ne 0 ]; then
   logger -s -t "${TAG}" "ERROR: Tar command failed with status ${TAR_STATUS}."
else
   logger -s -t "${TAG}" "info: Daily backup created successfully: ${BACKUP_DIR}/${TARGZ}"
fi

# Start service
logger -s -t "${TAG}" "info: Attempting to start OpenLDAP service (${SERVICE}) ..."
systemctl start "${SERVICE}" || {
   logger -s -t "${TAG}" "ERROR: service (${SERVICE}) could not be started (return value ${?}"
   exit 1
}
logger -s -t "${TAG}" "info: Service started successfully"

# Store daily backups
logger -s -t "${TAG}" "info: Making version of daily backup into ${BACKUP_DIR}/${TARGZ}.${DAY}"
cp -f "${BACKUP_DIR}/${TARGZ}" "${BACKUP_DIR}/${TARGZ}.${DAY}"
logger -s -t "${TAG}" "info: daily LDAP backup process completed"

# Store monthly backup
if ! test -e "${BACKUP_DIR}/${TARGZ}.${MONTH}"; then
   logger -s -t "${TAG}" "info: Making monthly version of monthly backup into ${BACKUP_DIR}/${TARGZ}.${MONTH}"
   cp "${BACKUP_DIR}/${TARGZ}" "${BACKUP_DIR}/${TARGZ}.${MONTH}"
   logger -s -t "${TAG}" "info: monthly LDAP backup process completed"
fi

exit 0

