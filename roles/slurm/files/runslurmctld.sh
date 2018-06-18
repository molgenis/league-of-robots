#!/bin/bash

# Start the nslcd daemon in the background and then start slurm.

nslcd

/usr/sbin/slurmctld -D
