#!/usr/bin/env python3
'''
Pushprox:  does not include the port number in its targets json
on the /clients endpoint. while Prometheus does seem to need it.

for more info see: https://github.com/RobustPerception/PushProx
'''

import json
from urllib import request

url = 'http://knyft.hpc.rug.nl:6060/clients'
outfile = 'targets.json'

data = json.loads(request.urlopen(url).read().decode('utf-8'))

targets = []

for node in data:
    for target in node['targets']:
        if target[-5:] != '9100':
            target = '{}:9100'.format(target)
            targets.append(target)

with open(outfile, 'w') as handle:
    handle.write(json.dumps(
        [{
        "targets" : targets,
        "labels": {
            "env": "peregrine",
            "job": "node"
            }
        }]
        ,indent=4 ))
