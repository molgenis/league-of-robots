# NVidia GPU installation role

This role follows the latest instructions of the newest version of available
drivers, avaiable at [NVIDIA CUDA Installation Guide for
Linux](https://docs.nvidia.com/cuda/pdf/CUDA_Installation_Guide_Linux.pdf).

The driver can be installed via yum repository, but the version limiting and
driver version control is quite hard to implement. Therefore the driver is
installed by downloading and running the cuda .run file.

The driver features Dynamic Kernel Module Support (DKMS) and will be recompiled
automatically when a new kernel is installed.

## Role outline

- it expects the `gpu_count`, `gpu_type` and `gpu_driver_version` variables to be defined, and then
  - it attempts to gather the GPU device status by running `nvidia-smi` command
  - it detects the NVidia driver version
  - executes the GPU driver installation tasks
    - checks if machine needs to be rebooted and reboots it, if needed
    - installs packages that are required for installing and compiling the driver
    - installs a (after a reboot) a matching version of kernel
    - downloads the cuda .run driver file from nvidia website (version defined in `gpu_driver_version`)
    - installs and compile the Dynamic Kernel Module Support driver
    - by default it tries to install `gpu_kernel_module_type: open`, which is the only version available for newer NVidia GPUs.
      For older cards like the A40 you may need to set `gpu_kernel_module_type: proprietary`
  - execute configuration if `gpu_count` defined
    - creates a local nvidia (defaults GID 601) group
    - creates a local nvidia (defaults UID 601) user
    - blacklists nouveau
    - installs `nvidia-persistenced.service` file, that will be executed as nvidia user
    - reboots the machine
    - checks if number of GPU devices reported from `nvidia-smi` is same as in `gpu_count`

## Solved issues - described

`gpu_count` is needed to install the driver, since any other `automatic` detection is
failing sooner or later. To list few:

 - `lspci` found one nvidia device when there were 8,
 - `nvidia-smi` reported no device found, when it actually should found some,
 - and `nvidia-smi` had up-and-running 3 GPU's when it should be 8

This was just while testing, but I can expect more.

`gpu_count` instead defines the correct "truth", and can test aginst it - that is
if all the GPUs are actually working correctly.

Persistenced service script was modified based on trial and error, but is taken
mostly from the example files that come with the driver installation, and can be
found in the folder 

    /usr/share/doc/NVIDIA_GLX-1.0/samples/nvidia-persistenced-init.tar.bz2

## Other comments

 - The smaller Nvidia .run driver installation file is also avaialable, but then
   number of commands and options are missing on system (for example `nvidia-smi`)
 - The long term availablitiy of .run file on nvidia website is not of concern as
   the cuda archive website is in 2022 still containing the old versions from 2007
 - driver installation is possible via yum repository, but it is harder to implement
   for two reasons:
    - the version needs to be limitied for nvidia-driver rpm and 15 (!) other packages
    - it seems that not all old versions are available on repository, only 'recent' ones
 - nvidia advises against using the `persistenced mode` as it is slowly deprecated and
   instead reccomends the use of `persistenced daemon`

[cuda archive website](https://developer.nvidia.com/cuda-toolkit-archive)
