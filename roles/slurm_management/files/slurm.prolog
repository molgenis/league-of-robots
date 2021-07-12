#!/bin/bash

if [[ -z "${SLURM_JOB_ID}" ]]; then
    logger -s "FATAL: SLURM_JOB_ID is empty or unset in SLURM prolog."
    exit 1
#else
#    logger -s "DEBUG: Found SLURM_JOB_ID ${SLURM_JOB_ID} and SLURM_JOB_QOS ${SLURM_JOB_QOS} in SLURM prolog."
fi

set -e
set -u

LOCAL_SCRATCH_DIR='/local'
#
# Check if local scratch dir is mountpoint and hence not a dir on the system disk.
#
if [[ $(stat -c '%d' "${LOCAL_SCRATCH_DIR}") -eq $(stat -c '%d' "${LOCAL_SCRATCH_DIR}/..") ]]; then
    logger -s "WARN: local scratch disk (${LOCAL_SCRATCH_DIR}) for Slurm jobs is not mounted/available."
else
    #
    # Create dedicated tmp dir for this job.
    #
    TMPDIR="${LOCAL_SCRATCH_DIR}/${SLURM_JOB_ID}/"
    #logger -s "DEBUG: local scratch disk (${LOCAL_SCRATCH_DIR}) is mounted. Trying to create ${TMPDIR} ..."
    mkdir -m 700 -p "${TMPDIR}" || logger -s "FATAL: failed to create ${TMPDIR}."
    chown "${SLURM_JOB_USER}" "${TMPDIR}" || logger -s "FATAL: failed to chown ${TMPDIR}."
fi
