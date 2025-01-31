#jinja2: trim_blocks:False

{% if archive_groups is defined and archive_groups | length >= 1 %}

# Using remote archive storage

1. Overview

1.1. What is the archive

It is the storage that is provided on the external host. Currently we only have one archive provider - [SURF](https://www.surf.nl/en/services/data-archive).

1.2. How it works
    
Archive is automatically mounted when user navigates into /groups/GROUP/arcXX folder. At that moment storage from remote server gets mounted on this folder. The folder remains mounted while being used and gets unmounted after some idle time to save the resources.

Each group can access only own archive folder and the files in it. Data-manager account is the **only** account on the archive subfolder that can **read** or **write** the archive data. This is to prevent the potential problems of accidentally making files online when not needed, and to make sure all the files are stored in correct format (see 'Best practices' below).

2. Copying data

Run following commands

```
     [ regular-user@~ ] $ sudo -u [group]-dm bash
     [ group-dm@~ ] $ rsync /groups/`GROUP`/`prmXX`/subfolder/file /groups/`GROUP`/`arcXX`/subfolder/
```
or alternatively `cp` or another tool can work as well.

3. Validating data

If you copied your data recently and therefore it is still residing on regular disks on remote archive server, then you can simply calculate the `sha256sum value of the file, with

```
    surf_archive --sha256sum /groups/[GROUP]/arcXX/subfolder/file
```

4. Managing data

After some time, all the files on remote archive server get automatically migrated to the tape. When this happens, all the folders and files can be still normally seen in the structure. You can go into any (sub)directory and run `ls`. All the filenames and their permissions and metadata (age, size, ownerhip) can be seen.

The difference is that the file content is not directly available anymore - that is, not without calling it back first. If you happen to do anything with the file content (like `cat` or `grep` for instance), then the command will get stuck, because the file will be automatically recalled from the tapes - which take some time. During this time you have unusable shell.

Therefore the correct procedure is to **first stage (recall from the tape) the file, and when it is available again, then access the content**.

    4.1. Checking the data status



5. Best practices

    5.1. File sizes are extremely important on the archive. Tape storage performance and management is better when the files are larger size. Reccomended sizes (for SURF) are in between 1 and 100 GB. The average size is monitored and the groups with average size lower than this will have locked accounts.

6. Performance

7. Issues

{% endif %}
