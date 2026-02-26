#!/bin/bash
set -ueo pipefail

TAG="slapd_backup"
LDAP_DATA_DIR="/usr/local/openldap"
LDAP_CONFIG_DIR="/etc/openldap"
BACKUP_DIR="/root/lsaai_ldap_backup"
SUFFIX="$(date +%d)"
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

# Create backup
logger -s -t "${TAG}" "info: Creating tar.gz archive ..."
tar -czf "${BACKUP_DIR}/${TARGZ}" "${LDAP_DATA_DIR}" "${LDAP_CONFIG_DIR}"
TAR_STATUS="${?}"
if [ ${TAR_STATUS} -ne 0 ]; then
    logger -s -t "${TAG}" "ERROR: Tar command failed with status ${TAR_STATUS}."
else
     logger -s -t "${TAG}" "info: Backup created successfully: ${BACKUP_DIR}/${TARGZ}"
fi

# Start service
logger -s -t "${TAG}" "info: Attempting to start OpenLDAP service (${SERVICE}) ..."
systemctl start "${SERVICE}" || SERVICE_START_STATUS="${?}"

if [ ${SERVICE_START_STATUS} -ne 0 ]; then
    logger -s -t "${TAG}" "ERROR: service (${SERVICE}) could not be starter (return value ${SERVICE_START_STATUS})"
    exit 1
else
    logger -s -t "${TAG}" "info: Service started successfully"
fi

logger -s -t "${TAG}" "info: Making version of dail backup into ${BACKUP_DIR}/${TARGZ}.${SUFFIX}"
cp -f "${BACKUP_DIR}/${TARGZ}" "${BACKUP_DIR}/${TARGZ}.${SUFFIX}"
logger -s -t "${TAG}" "info: LDAP backup process completed"

exit 0

