# HPC playbooks

The `users.yml` playbook contains users and public keys.
The playbook uses `/etc/hosts` as a database for hosts to install the keys on.

## usage:

* Make changes to a local checkout of this repo.
* `git commit` the changes, `git push` and `git pull` on xcat.
* on xcat:

```bash
git pull
ansible-playbook users.yml # this will install the users on all hosts in /etc/hosts.
```
