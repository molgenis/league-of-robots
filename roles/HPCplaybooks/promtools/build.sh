#!/bin/bash -ex

mkdir -p results
docker build . -t promtools
docker run -d --name promtools --rm promtools sleep 3
docker cp promtools:/results .
