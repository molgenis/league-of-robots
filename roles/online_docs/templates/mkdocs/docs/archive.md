#jinja2: trim_blocks:False

{% if archive_groups is defined and archive_groups | length >= 1 %}

# Using remote archive storage

## 1. Overview

### 1.1. What is archive

Briefly

- **Archive is not backup!**
- it is a storage location that you write once and read almost never
- it is a storage location with lower costs than a normal disk storage
- the permissions and metadata of the files are lost, if not properly handled/packaged before
- there is file size considerations - **no small files** (see 'Best practices' below)
- is built around the idea that performance must accomodate occasional (once a year or less) accessing the data

It is the storage that is provided on the external host. Currently we only have one archive provider - [SURF](https://www.surf.nl/en/services/data-archive).

### 1.2. How it works
    
Archive is automatically mounted when user navigates into /groups/GROUP/arcXX folder. At that moment storage from remote server gets mounted on this folder. The folder remains mounted while being used and gets unmounted after some idle time to save the resources.

Each group can access only own archive folder and the files in it. Data-manager account is the **only** account on the archive subfolder that can **read** or **write** the archive data. This is to prevent the potential problems of accidentally making files online when not needed, and to make sure all the files are stored in correct format (see 'Best practices' below).

## 2. Copying data

Run following commands

```
     [ regular-user@~ ] $ sudo -u [group]-dm bash
     [ group-dm@~ ] $ rsync /groups/`GROUP`/`prmXX`/subfolder/file /groups/`GROUP`/`arcXX`/subfolder/
```
or alternatively `cp` or another tool can work as well.

## 3. Validating data

If you copied your data recently and therefore it is still residing on regular disks on remote archive server, then you can simply calculate the `sha256sum value of the file, with

```
    surf_archive --sha256sum /groups/[GROUP]/arcXX/subfolder/file
```

## 4. Managing data

After some time, all the files on remote archive server get automatically migrated to the tape. When this happens, all the folders and files can be still normally seen in the structure. You can go into any (sub)directory and run `ls`. All the filenames and their permissions and metadata (age, size, ownerhip) can be seen.

The difference is that the file content is not directly available anymore - that is, not without calling it back first. If you happen to do anything with the file content (like `cat` or `grep` for instance), then the command will get stuck, because the file will be automatically recalled from the tapes - which take some time. During this time you have unusable shell.

Therefore the correct procedure is to **first stage (recall from the tape) the file, and when it is available again, then access the content**.

### 4.1. Data states

The data migrates on remote server from disk to tape and during this it has different states. **As long as the data is online (on disks), it is available to the user. It can be read or modified.**.

| State | Code | Online (data on disks) | Offline (data on tape) | Explanation |
| ----- | ---- |-------------- | ------------ | ----------- |
| Regular | `REG` | Yes | No | Files are only on disk. File content can be accessed and changed. |
| Migrating | `MIG` | Yes | **No**t yet | Files are being copied from disk to tape. Content is also still available on disks. |
| Dual-state | `DUL` | Yes | Yes | Content is both on disk and on tape. |
| Offline | `OFL` | No | Yes | Data is no longer online (on disks). It resides only on tape. It can be recalled - staged back to disks. |
| Unmigrating | `UNM` | **No**t yet | Yes | Files are being copied from tape to disk. Content is not avilable until copy is finised. |

Note that the folders are always online (in state `REG`) and as such you can always browse folders and check file permissions and their metadata information.

### 4.2. Normal workflow and changing the data states

1. Become the data manager
    ```
    user $ sudo -u [group]-dm bash
    user $ cp /groups/[group]/prm09/projects/x/yfile /groups/[group]/arc01/project/x/yfile
    dm-user $ surf_recall.sh --dmls /groups/[group]/arc01/project/x/yfile
    Submitted to remote host, waiting for reply ...
    ( You can press CTRL+C and check later for the output in /var/cache/arcq//output/tmp.ECc4X0dAEz )
    -rw-r-----  1 dm-user    dm-user    10485760000 2024-11-26 18:08 (OFL) yfile
    ```
1. File is offline, but we can get it online with
    ```
    dm-user $ surf_recall.sh --dmget /groups/[group]/arc01/project/x/yfile
    Submitted to remote host, waiting for reply ...
    ( You can press CTRL+C and check later for the output in /var/cache/arcq//output/tmp.EeHDV2kAPj )
    ```
1. Check the status again
    ```
    dm-user $ surf_recall.sh --dmls /groups/[group]/arc01/project/x/yfile
    Submitted to remote host, waiting for reply ...
    ( You can press CTRL+C and check later for the output in /var/cache/arcq//output/tmp.qo7tO9CtVB )
    -rw-r-----  1 dm-user    dm-user    10485760000 2024-11-26 18:08 (UNM) yfile
    dm-user $ # note that the file is unmigrating now
    ```

### Other command line options

Use `--help` argument to get more information

```
   dm-user $ $ surf_recall.sh --help
   Provide one of the following arguments
    --dmfind-reg <path>      print regular files / files that reside only on disk
    --dmfind-mig <path>      print files that are being copied from disk to tape
    --dmfind-dul <path>      print files that reside both online and offline
    --dmfind-ofl <path>      print data that is no longer on disk (is on tape)
    --dmfind-unm <path>      print files which are being copied from tape to disk
    --dmget      <path>      recall / stage online FROM TAPE
    --dmls       <path>      list state
    --dmput      <path>      send to offline / stage TO TAPE
    --sha256sum  <path>      compute the sha256sum of the file

```

## 5. Best practices

### 5.1. File sizes are extremely important on the archive. Tape storage performance and management is better when the files are larger size. Reccomended sizes (for SURF) are in between 1 and 100 GB.

The average size is monitored and the groups with average size lower than this will have **locked accounts**.

- there should be no files smaller than <100M
- files stored to archive should be in sizes between 1 and 100GB
- note that checksum files are also small files which reduce the average file size
- the archive filesystem was build around the idea of occasional (as in *once or twice a year at most*) accessing the data content

## 6. Performance

## 7. Issues

{% endif %}
