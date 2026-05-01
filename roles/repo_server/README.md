# Repository servers role

## Intro

## Repository settings

The Repository Server role mirrors local repositories based on the `yum_repos` variable in `group_vars/all/repos.yml`.

Deployment Logic
 - Filtering: Only repositories with `repo_server_download: True` are processed.
 - Remote server file structure
   - All repositroy configuration files are stored inside top directory /mnt/repos/dnf/repos.d/
   - Master Config: A `[distribution].conf` file is created at the root of the `repos.d` folder to point to the specific distribution directory.
   - All the Repo Files for specific distrubution are stored inside `/mnt/repos/dnf/repos.d/[distribution]/` (e.g. `.../repos.d/centos7/`).


## Configurations scripts

 - the deployment and configuration scripts are added to `/mnt/repos/` folder
   - `1_xxx.sh` script syncronizes (download) the latest packages and creates
     a new version of this syncronization
   - `2_xxx.sh` script exposes this fresh download to the stack that will be
     using this version
   - `3_xxx.sh` script cleans all the versions that are not used by any stack
     deployments

## Server file storage

The total size of the individual repositories varies, but can be easily 100GB or
more. Therefore to save the space of the each version, the packages are downloaded
to the `0cache/[distribution]` directory. And all the future syncronization
update the entire structure every time - remove the packages which are not in
the original repository any more.

Versions are stored by making copy (on write - reflink) into `1version` folder at
the end of each syncronization. This enforces that the actually used disk space
is reduced to bare minimum.

## Debug

### Getting size and other information for all repositories of specific distribtuion

```
    ssh [admin-usernam]@hatch+repo-primary
    sudo -u repo bash
    cd /mnt/repos
    dnf repoinfo --conf /mnt/repos/dnf/repos.d/oracle8.conf
    ...
    Repo-id      : ol8_appstream
    Repo-name    : Oracle Linux 8 Application Stream (x86_64)
    Repo-size    : 312 G
    Available Packages: 10,842
```
