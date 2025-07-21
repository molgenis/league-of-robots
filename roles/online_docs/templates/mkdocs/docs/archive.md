#jinja2: trim_blocks:False

{% if archive_groups is defined and archive_groups | length >= 1 %}

# Using remote archive storage

## 1. Overview

### 1.1. Basic overview

It is the storage that is hosted on the tapes on the remote location. Currently we only have one archive provider - [SURF](https://www.surf.nl/en/services/data-archive).

The following guidelines apply to this archive storage

- It is a remote storage to *write once* and *read rarely*.
- Performance accommodates occasional (once a year or less) access to the existing data on the remote tape storage.
- **Archive is not a backup**! It provides storage with lower costs than a normal disk storage.
- **Tape data does not have a backup**, so be extremely careful with the data deletion.
- If permissions and metadata of the files are needed to be kept, then they should be first packaged before uploading (use of `tar` or similar tool).
- File size must be considered - there should be **no small files** (see 'Best practices' below)
- Tape storage has the [ISO 27001 certification](https://www.surf.nl/en/services/data-archive)
- Data is stored in two physical locations in the Netherlands.


### 1.2. How it works

Archive is automatically mounted when user navigates to the `/groups/[GROUP]/arc[XX]` folder. At that moment storage from remote server gets mounted on the folder. It remains accessible until some specific idle time is reached.

Data-manager account of the specific group is the **only** account that has **read** and **write** access to the archive folder of the group. This is to prevent users accidentally recalling files online when not needed. Also to make sure that all the files are stored in correct format (see 'Best practices' below).

## 2. Managing data

After some time, all the files on remote archive server get automatically migrated to the tape. The **metadata** and **tree structure** remain on remote disks, while the **data content** exist only on tape. When this happens, the metadata (like file names, permissions, timestamps, size, ownership, etc.) can be normally accessed and the structure can be normally browsed. `cd`, `ls` and `find` commands work just like they do on a *regular* filesystem.

The difference is that the file content is not directly available anymore until it is recalled. Any command that attempts to read the file content (like `less`, `cat` or `grep`) or to edit the content (like `vim` or `nano`) may **appear stuck**. Actually the machine is waiting for data to be retrieved, which can take a very long time since the data needs to be copied back from tape to disk.

Therefore the correct procedure is to **first stage (recall from the tape) the file, and access the content when it is available again**.

### 2.1. Data states

The data migrates on remote server from disk to tape and during this it has different states. **As long as the data is online (on disks), it is available to the user. It can be read or modified.**.

| State | Code | Online (on disks) | Offline (on tape) | Explanation |
| ----- | ---- |-------------- | ------------ | ----------- |
| Regular | `REG` | Yes | No | Files are only on disk. File content can be accessed and changed. |
| Dual-state | `DUL` | Yes | Yes | Content is both on disk and on tape. |
| Offline | `OFL` | No | Yes | Content is no longer online/on disks, but only on tape. |
| Unmigrating | `QUE` | **No** | Yes | File queued for staging from tape. Not yet copied from tape. |
| Unmigrating | `STG` | **No**t yet / Partially | Yes | File being staged from tape to disk. Content is is unavailable until copy is finished. |

Note that the folders are always online (in state `REG`) and as such you can always
browse folders and check file permissions and their metadata information.

## 3. Workflow example

How to upload and modify states of the remote files.

### User

Become the data manager
```
   user $ sudo -u [group]-dm bash
```

### Bundling

Optional, but highly recommended:
Prepare the data by merging multiple files/folders
 into one compressed **tar** file.

Here are two options available

a) data is compressed

the data can be bundled and *compressed* at the same time
```
   dm-user $ tar -czvf /groups/[group]/[prm0X]/projects/project-x.tar.gz /groups/[group]/[prm0X]/projects/x/*
```
this will result (in comparison with the option b) in
 - taking longer to compress and decompress the files
 - smaller .tar.bz file - so less storage consumed on both prm and remote archive
 - taking less time to upload the file to the remote archive storage

b) or it can be simply bundled without compression
```
   dm-user $ tar -cvf /groups/[group]/[prm0X]/projects/project-x.tar /groups/[group]/[prm0X]/projects/x/*
```

this will result (in comparison to the option a)
 - in faster creation and possibly later extraction of the .tar file
 - but it will use more disk space both on prm and archive
 - and it will take longer to copy the entire file to the archive and back

### Local checksum

(highly recommended) Create a checksum of the file. This _fingerprint_ can
be checked later to verify that the file was successfully uploaded to the archive and that it was correctly restored when when downloading it back from the archive.
```
   dm-user $ sha256sum /groups/[group]/[prm0X]/projects/project-x.tar.gz > /groups/[group]/[prm0X]/projects/project-x.tar.gz.sha256sum
```

In order to speed up the checkup process when checking on the remote storage side, it is
recommended to use **`sha256sum`** for making a fingerprint.

### Uploading

Upload of the file(s) to the archive
```
   dm-user $ cp /groups/[group]/[pmp0X]/project-x.tar /groups/[group]/[arc0X]/projects/project-x.tar

```

### Remote checksum

(highly recommended) If file was copied recently, it _can be_ still on regular disks
on the remote archive server, so we can simply issue remote command to calculate the
`sha256sum` value of it
```
   arc_surf --sha256sum /groups/[GROUP]/arcXX/subfolder/file
```

If checkum was also made just after the .tar file was created, then both values can be checked if they are still identical.

### Migrating

(optionally) If file is still online, it can be moved to the tape (or simply wait for it to automatically move there)
```
   dm-user $ arc_surf --darelease /groups/[group]/[arc0X]/projects/project-x.tar
   Submitted to remote host, waiting for reply ...
   ( You can press CTRL+C and check later for the output in /var/cache/arcq//output/tmp.5eHsc2kAPj )
```

### Status

Check the file status
```
   dm-user $ arc_surf --dals /groups/[group]/[arc0X]/projects/project-x.tar
   Submitted to remote host, waiting for reply ...
   ( You can press CTRL+C and check later for the output in /var/cache/arcq//output/tmp.ECc4X0dAEz )
   -rw-r-----  1 dm-user    dm-user    10485760000 2024-11-26 18:08 (OFL) project-x.tar
```
### Unmigrating

If file is offline, we can call it back to disks - stage it `online` with
```
   dm-user $ arc_surf --daget /groups/[group]/[arc0X]/projects/project-x.tar
   Submitted to remote host, waiting for reply ...
   ( You can press CTRL+C and check later for the output in /var/cache/arcq//output/tmp.EeHDV2kAPj )
```

**Note**: when you request a file to be staged, for some time it will remain `OFL`, until it starts to be copied from tape to disks.

After some time we check the status again.

```
   dm-user $ arc_surf --dals /groups/[group]/[arc0X]/projects/project-x.tar
   Submitted to remote host, waiting for reply ...
   ( You can press CTRL+C and check later for the output in /var/cache/arcq//output/tmp.qo7tO9CtVB )
   -rw-r-----  1 dm-user    dm-user    10485760000 2024-11-26 18:08 (QUE) project-x.tar
```

In this example, the file has status `QUE` (queued), but it can also have `STG` (staged).
We must wait until it is changed to `DUL` (Dual-state).

## 4. Other command line options

Use `--help` argument to get more information

```
   dm-user $ $ arc_surf --help
   Provide one of the following arguments
    --dafind-reg <path>      print regular files / files that reside only on disk
    --dafind-que <path>      print files that are being copied from disk to tape
    --dafind-dul <path>      print files that reside both online and offline
    --dafind-ofl <path>      print data that is no longer on disk (is on tape)
    --dafind-stg <path>      print files which are being copied from tape to disk
    --daget      <path>      recall / stage online FROM TAPE
    --dals       <path>      list state
    --darelease  <path>      send to offline / stage TO TAPE
    --sha256sum  <path>      compute the sha256sum of the file

```

## 5. Best practices

File sizes are extremely important for archive. Tape storage performance and management is better when the files are larger size.

Therefore
 - files should be in range 1 and 100GB (checksums are exception)
 - average file size should not be lower than a **1GB**
 - the archive filesystem was build around the idea of occasional (as in *once or twice a year at most*) accessing the data content

The average size is monitored and the groups with average size lower than this will have **locked accounts**.

## 6. Performance

The speed of upload and download depends on the following conditions

 - the total bandwidth usage of the network by all the users on the Login node
 - (for restoring the data) the usage of the prm/tmp disk utilization by all users
 - load of the data and network on the remote tape archive system that hosts the data

So far the tests have shown the upload speeds in between of 30 and 50 MB/s.
Which means that archiving and restoring of the large datasets can take (depending on the size) anywhere from several hours to several days.

## 7. Issues

So far most of the bugs have been resolved, but it could happen that

 - the archive folder is not available - please inform the helpdesk unless maintenance was announced,
 - download/upload perfomance occasionally drops - this most probably depends on the Login node usage (and data copy by other users) - notify helpdesk if it persists for a longer period,

If you expirence any issues with the archive solution, please notify helpdesk.

```
Where is my data stored?

The Data Archive maintains two tape libraries for security and redundancy in two physically separate locations in the Amsterdam and Haarlemmermeer municipalities.  When data is uploaded to the Data Archive using SSH, (HPN)SCP, SFTP, rsync, GridFTP, iRODS, etc. it ends up on an online disk space managed by the Data Migration Facility (DMF). The DMF will then manage the careful migration of files from the disk space to two tape libraries until your data is available on both tape libraries. Once your data is safely stored in the two tape libraries it may be removed from the disk space (aka offline). Offline data can be interacted with in the same manner as online data though users may notice a delay in access time.
```

{% endif %}
