#!/usr/bin/env python

import argparse
import json
import sys


def get_hosts(hosts_file='/etc/hosts'):
    '''
    Get the hostsnames from /etc/hosts.
    Returns: A set of hostnames.
    '''
    rv = []
    with open(hosts_file, 'r') as f:
        for line in f:
            if line == '\n':
                continue
            if line[0] == '#':
                continue
            rv.append(line.split()[1])
    rv = set(rv)
    ignore = {'localhost', 'ip6-allnodes', 'ip6-allrouters'}
    return rv.difference(ignore)


def get_args(args_list):
    """
    Parse the arguments and make sure only
    that --list or --host is given, not both.
    """
    parser = argparse.ArgumentParser(
        description='ansible inventory script parsing /etc/hosts')
    mutex_group = parser.add_mutually_exclusive_group(required=True)
    help_list = 'list all hosts from /etc/hosts'
    mutex_group.add_argument('--list', action='store_true', help=help_list)
    help_host = 'display variables for a host'
    mutex_group.add_argument('--host', help=help_host)
    return parser.parse_args(args_list)


def main(args_list):
    """
    Print a json list of the hosts if --list is given.
    Does not support host vars.
    Print an empty dictionary if --host is passed to remain valid.
    """
    args = get_args(args_list)
    if args.list:
        print(json.dumps({
            'all': {
                'hosts': list(get_hosts()),
            }
        }))
    if args.host:
        print(json.dumps({}))


if __name__ == '__main__':
    main(sys.argv[1:])
