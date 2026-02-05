# Repository servers role

## Intro

## Repository settings

Repository servers role take existing repository settings defined inside
`yum_repos` variable in the `group_vars/all/repos.yml`.

It deployes all the settings and scripts
 - and places them under `/mnt/repos` (default) on the repository server
 - under a folder `dnf/repos.d/[distribution]`, where `distribution` are the
   first level sub-items of the `yum_repos` variable
 - all the repositories that have variable `repo_server_download` set to `True` in the `yum_repos` are placed into
 - `/mnt/repos/dnf/repos.d/[distribution].conf` file defines the path where the
   `.repo` files of that distribution exist - this is set to
   `/mnt/repos/dnf/repos.d/[distribution]/` folder

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
