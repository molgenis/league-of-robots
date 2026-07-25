# Setting up the lvm with

# cf-storage lvm

## overview

```
logical volume           .> 87 TB/hdd cached with nvme 'data' <-.          <-.  lvconvert
                         |                                      |            ^ lvcreate 
                   'nvme' raid1 (cache volume)       'hdd' (logical volume)  | 
                         /          \                 |                      ^ vgcreate
pvdevices          /dev/nvme1    /dev/nvme2       /dev/sda                   | 
                                                                             ^ pvcreate
disks              /dev/nvme1    /dev/nvme2       /dev/sda                   | 
volume group       ^---------- volume group 87TB ---------^
```

Cachevol = raw caching storage  
Cachepool = complete caching mechanism (cachevol + metadata).

## 1. Make LVM

```
      [root@cf-storage ~]# dnf install -y lvm2
      
      [root@cf-storage mnt]# lsblk 
      NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
      sda           8:0    0  87.3T  0 disk 
      nvme1n1     259:1    0   1.5T  0 disk 
      nvme2n1     259:3    0   1.5T  0 disk 
      nvme0n1     259:5    0 894.2G  0 disk 
      ├─nvme0n1p1 259:6    0   550M  0 part /boot/efi
      ├─nvme0n1p2 259:7    0     8M  0 part 
      ├─nvme0n1p3 259:8    0 893.6G  0 part /
      └─nvme0n1p4 259:9    0    65M  0 part 

      [root@cf-storage mnt]# vgcreate data /dev/sda /dev/nvme1n1 /dev/nvme2n1
      Physical volume "/dev/sda" successfully created.
      Physical volume "/dev/nvme1n1" successfully created.
      Physical volume "/dev/nvme2n1" successfully created.
      Volume group "data" successfully created

  > -l|--extents Number[PERCENT]
  >        Specifies  the  size  of  the new LV in logical extents.  The --size and --extents options are alternate methods of specifying size.
  >        The total number of physical extents used will be greater when redundant data is needed for RAID levels.  An alternate syntax allows
  >        the  size to be determined indirectly as a percentage of the size of a related VG, LV, or set of PVs. The suffix %VG denotes the to‐
  >        tal size of the VG, the suffix %FREE the remaining free space in the VG, and the suffix **%PVS** the free space in  the  specified  PVs.
  >        For  a  snapshot,  the  size can be expressed as a percentage of the total size of the origin LV with the suffix %ORIGIN (100%ORIGIN
  >        provides space for the whole origin).  When expressed as a percentage, the size defines an upper limit for the number of logical ex‐
  >        tents in the new LV. The precise number of logical extents in the new LV is not determined until the command has completed

      [root@cf-storage mnt]# lvcreate --type raid1 -m 1 -n nvme -l 100%PVS data /dev/nvme1n1 /dev/nvme2n1 
        Logical volume "nvme" created.
      [root@cf-storage mnt]# lvcreate -n hdd -l 100%PVS data /dev/sda
        Logical volume "hdd" created.

  > --cachevol LV
  >        Pass this option a standard LV.  With a cachevol, cache data and metadata are contained within the single
  >        LV.  This is used with dm-writecache or dm-cache.
  > --cachepool CachePoolLV|LV
  >        Pass this option a cache pool object.  With a cache pool, lvm places cache data  and  cache  metadata  on
  >        different  LVs.   The  two LVs together are called a cache pool.  This permits specific placement of data
  >        and metadata.  A cache pool is represented as a special type of LV that cannot be used directly.   (If  a
  >        standard  LV  is  passed  to  this option, lvm will first convert it to a cache pool by combining it with
  >        another LV to use for metadata.)  This can be used with dm-cache.
  > -c|--chunksize Size[k|UNIT]
  >        The  size of chunks in a snapshot, cache pool or thin pool.  For snapshots, the value must be a power of 2 between 4 KiB and 512 KiB and the de‐
  >        fault value is 4.  For a cache pool the value must be between 32 KiB and 1 GiB and the default value is 64.  For a thin pool the value  must  be
  >        between  64 KiB  and 1 GiB and the default value starts with 64 and scales up to fit the pool metadata size within 128 MiB, if the pool metadata
  >        size is not specified.  The value must be a multiple of 64 KiB.  See lvmthin(7) and lvmcache(7) for more information.

      [root@cf-storage mnt]# lvconvert --type cache --cachemode writethrough --chunksize 2M --cachevol nvme data/hdd
      Erase all existing data on data/nvme? [y/n]: y
        Logical volume data/hdd is now cached.
````
## 2. Making a filesystem on top of LVM storage

```
      # mkdir /mnt/umcgst16
      # mkfs.ext4 /dev/87TB/hdd
      # sudo vi /etc/fstab
      /dev/data/hdd    /mnt/umcgst16    ext4    defaults    0 0
      # systemctl daemon-reload
      # mount /mnt/umcgst16
```
switch cache

```
      [root@cf-storage umcgst16]# lvconvert --splitcache 87TB/hdd
      Logical volume 87TB/hdd is not cached and 87TB/nvme is unused.

      [root@cf-storage umcgst16]# lvconvert --type cache --chunksize 2M --cachemode writethrough --cachevol 87TB/nvme 87TB/hdd
      Erase all existing data on 87TB/nvme? [y/n]: y
      Logical volume 87TB/hdd is now cached.
```
autocommit

```
      lvchange --cachesettings 'autocommit_time = 60000' data/hdd
```
## 3. Storage testing

install sysstat to get `iostat` which shows 
```
      iostat -dx 5
      Device            r/s     rkB/s   rrqm/s  %rrqm r_await rareq-sz     w/s     wkB/s   wrqm/s  %wrqm w_await wareq-sz     d/s     dkB/s   drqm/s  %drqm d_await dareq-sz     f/s f_await  aqu-sz  %util
      dm-5             0.00      0.00     0.00   0.00    0.00     0.00 8846.67  41313.33     0.00   0.00  126.64     4.67    0.00      0.00     0.00   0.00    0.00     0.00    0.00    0.00 1120.34  95.83
      ... nvme devices ...
      sda              0.00      0.00     0.00   0.00    0.00     0.00 5276.67  41313.33  4011.67  43.19    1.09     7.83    0.00      0.00     0.00   0.00    0.00     0.00    0.00    0.00    5.75  95.73
```

that `sda` and `dm-5` are being used.

about dm-5

```
      [root@cf-storage umcgst16]# dmsetup info /dev/dm-5
      Name:              data-nvme_cvol-cmeta
      State:             ACTIVE
      Read Ahead:        256
      Tables present:    LIVE
      Open count:        1
      Event number:      0
      Major, minor:      253, 7
      Number of targets: 1
      UUID: LVM-3ZoXXPYA2mYbtKi48kmK8xW7VmgqptZMvilrmeylSiuLXLAF5OYMkDC2RtuBnWj0-cmeta
```

## Extra

pvs
```
      [root@cf-storage ~]# pvs
      PV           VG       Fmt  Attr PSize  PFree
      /dev/nvme1n1 vg_raid1 lvm2 a--  <1.46t    0 
      /dev/nvme2n1 vg_raid1 lvm2 a--  <1.46t    0 
      /dev/sda     vg_data  lvm2 a--  87.31t    0
```
vgs
```
      [root@cf-storage ~]# vgs
      VG       #PV #LV #SN Attr   VSize  VFree
      vg_data    1   1   0 wz--n- 87.31t    0 
      vg_raid1   2   1   0 wz--n-  2.91t    0 
```
lvs
```
      LV       VG       Attr       LSize  Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
      lv_data  vg_data  -wi-a----- 87.31t                                                    
      lv_cache vg_raid1 -wi-a-----  2.91t                                                    
```
lvdisplay
```
      [root@cf-storage ~]# lvdisplay -m
      --- Logical volume ---
      LV Path                /dev/87TB/hdd
      LV Name                hdd
      VG Name                87TB
      LV UUID                L2dk97-jesY-cXRr-d7ia-Bg1c-QXs2-ifkvDU
      LV Write Access        read/write
      LV Creation host, time cf-storage, 2025-02-06 09:56:33 +0000
      LV Cache pool name     nvme_cvol
      LV Cache origin name   hdd_corig
      LV Status              available
      # open                 1
      LV Size                87.31 TiB
      Cache used blocks      34.92%
      Cache metadata blocks  15.07%
      Cache dirty blocks     0.00%
      Cache read hits/misses 533346 / 1023253
      Cache wrt hits/misses  313882 / 1050585
      Cache demotions        0
      Cache promotions       266423
      Current LE             22888703
      Segments               1
      Allocation             inherit
      Read ahead sectors     auto
      - currently set to     8192
      Block device           253:0
         
      --- Segments ---
      Logical extents 0 to 22888702:
         Type		cache
         Chunk size		2.00 MiB
         Metadata format	2
         Mode		writethrough
         Policy		smq
```

## Benchmark 10TB
```
      [root@cf-storage umcgst16]# sync; taskset -c 2-7 ~sandi/disk $((1024*1024*1024)) 1000 output 1 1 10 $(cat /dev/urandom | tr -dc '[[:alnum:]]' | head -c 1); sync
      block              : 1073741824
      loops              : 1000
      file_name          : output
      parallel process   : 10
      syncing            : 1
      ascii character    : x
      total written      : 10737418240000b, 10240000 MB, 10000.000 GB
      There will be written #10000 chunks of data.
      checking for old files ...
      each dot represents a block of data vritten
      Starting of the test
      process with PID 374070, created file output.0, and starting to writing data 
      process with PID 374071, created file output.1, and starting to writing data 
      process with PID 374072, created file output.2, and starting to writing data 
      process with PID 374073, created file output.3, and starting to writing data 
      process with PID 374074, created file output.4, and starting to writing data 
      process with PID 374079, created file output.9, and starting to writing data 
      process with PID 374078, created file output.8, and starting to writing data 
      process with PID 374076, created file output.6, and starting to writing data 
      process with PID 374077, created file output.7, and starting to writing data 
      process with PID 374075, created file output.5, and starting to writing data 
      ........................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................
.....
      It took 6906.323615 seconds to write 10240000 MB bytes of data - throughput 1482.699128 MB/s 
      [root@cf-storage umcgst16]#
```

