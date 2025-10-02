#jinja2: trim_blocks:False
# Apptainer (previously known as Singularity)

## Table of contents
- [About Apptainer](#about-apptainer)
    - [Containers and apptainer](#containers-and-apptainer)
- [List of commonly used commands](#list-of-commonly-used-commands)
- [Building Apptainer images](#building-apptainer-images)
    - [Building Without Elevated Permissions](#building-without-elevated-permissions)
- [Sandbox](#sandbox)
    - [Example with Ubuntu 18.04](#example-with-ubuntu-1804)
    - [Converting sandbox directory to sif file](#converting-sandbox-directory-to-sif-file)
- [Building image as a regular user](#building-image-as-a-regular-user)
- [Making an image from the definition file with elevated permissions](#making-an-image-from-the-definition-file-with-elevated-permissions)
- [Definition file](#definition-file)
    - [Header](#header)
    - [Sections](#sections)
- [Important](#important)
- [Caching redirect or disable](#caching-redirect-or-disable)
- [Running Apptainer on Windows or Mac](#running-apptainer-on-windows-or-mac)
- [Using images from the Docker repository](#using-images-from-the-docker-repository)
- [Isolated runs](#isolated-runs)
- [Mounting host folders inside containers](#mounting-host-folders-inside-containers)
- [Other considerations](#other-considerations)
    - [Architecture considerations](#architecture-considerations)
    - [Licence considerations](#licence-considerations)
- [Environment variables](#environment-variables)
- [Debug information](#debug-information)
- [Additional examples](#additional-examples)
    - [Alpine as regular user build static file via sandbox directory](#alpine-as-regular-user-build-static-file-via-sandbox-directory)
    - [Simple CentOS 7 example via sandbox](#simple-centos-7-example-via-sandbox)

## About Apptainer

### In short

> A container is an isolated environment that holds the software and its dependencies and configurations.
> Containers can be run on any machine with compatible container technology.
> Container instances can be run (deployed) from an existing image.
> Therefore, users must first either build (create) an image or fetch an existing image (f.e. pull from a public registry).
> You can also share your images with others to easily distribute software to different systems and can expect to always get the same results.
> _Apptainer_ and _Docker_ are different implementations of container technology.
> _Docker_ is the most popular one, but unfortunately not suited for multi-user environments.
> _Apptainer_ is suited for multi-user environments, was specifically designed for HPC clusters and can run both _Singularity_ as well as _Docker_ container images.
> Users can deploy containers, and inside those containers can access the same resources as they can access outside of those containers - nothing more.

The documentation below is only a _primer_ describing building, deploying and running containers on {{ slurm_cluster_name | capitalize }}.
For details see the official _Apptainer_ documentation available from the [Apptainer's documentation website](https://apptainer.org/docs/).

### Containers and apptainer

Linux containers

* are a method for running multiple isolated Linux systems (containers) on a control host using a single Linux kernel,
* provides the cgroups functionality that allows limitation and prioritization of resources (CPU, memory, block I/O, network, etc.) without the need for starting any virtual machines.

Apptainer is a container platform

* highly optimized to be run on a laptop or high-performance cluster,
* extremely fast and lightweight - as there is no virtualization, and images are simply executed just as any other program,
* enables a secure way of running containers - images can be easily verified,
* limits security risk, as it can only access user-accessible resources,
* can directly run images from the Docker repository (via path `docker://...`).

Apptainer container image

* is a file (e.g. `ubuntu_18.04.sif`) containing all programs and libraries needed to execute that environment,
* can contain a small subset of programs (with libraries), or entire Linux operating system (like Alpine, CentOS or Ubuntu),
* is highly portable between various Linux operating systems and environments - it only requires installed Apptainer,
* container filesystem environment is by default read-only when deployed (this can be partially changed by the user at the runtime - see section `Sandbox`),
* is usually in format`.sif` (Singularity Image Format), `.sqfs` (SquashFS) or `.img` (image) ext3
* can also be a directory instead of a single file, containing all the needed files, browsable by the user outside the container.


## List of commonly used commands

1. Pull container image from Docker repository

    `$ apptainer pull docker://alpine:latest`

2. Start an interactive shell within your container

    `$ apptainer shell alpine_latest.sif`

3. Run container (this executes its predefined runscript command)

    `$ apptainer run alpine_latest.sif`

4. Execute custom command inside the container

    `$ apptainer exec alpine_latest.sif cat /etc/os-release`

5. Execute a command directly from the Docker's repository container

    `$ apptainer exec docker://busybox:latest busybox | head -n1`

6. Build sandbox directory directly from the Docker image

    `$ apptainer build --sandbox alpine_sandbox docker://busybox:latest`

7. Shell into the sandbox, pretend to be a root user and permanently save all changes

    `$ apptainer shell --fakeroot --writable alpine_sandbox`

8. Convert sandbox to static image

    `$ apptainer build alpine.sif alpine_sandbox`

## Building Apptainer images

In order to create a new _Apptainer_ container, you will need to build an container image file.
Images can be built on top of other images, which can be local images or images pulled from a repository like [_Docker Hub_](https://hub.docker.com/).
When the commands used to build the image do not require elevated permissions, then you can build the image on {{ slurm_cluster_name | capitalize }}.
If on the other hand commands like `sudo dnf install ...` or `sudo apt-get install ...`, which require root permissions, are used in the recipe to build the image,
then elevated permissions are also needed to build the container image (e.g. `sudo apptainer build ...`).
Regular users don't have elevated permissions on a multi-user systems like {{ slurm_cluster_name | capitalize }}.
Section `Building without elevated permissions` describes workarounds how to build images without elevated permissions.

### Building without elevated permissions

_Apptainer_ has a `--fakeroot` argument to bypass some of these limitations.

Fortunately, there are at least two alternatives; you can
- Either build an image on another system where you do have elevated (sudo) permissions and then copy that `.sif` file to {{ slurm_cluster_name | capitalize }}
- Or build an image on {{ slurm_cluster_name | capitalize }} itself, but via intermediate _sandbox_ option and then convert the _sandbox_ into the `.sif` file.
  See sections `Sandbox` and `Building image as regular user` below for details.

## Sandbox

The _sandbox_ option builds a container image inside a directory, which allows users to:

* use the  `--fakeroot` option and become root inside container,
* change any files inside the container, and those changes *can be* saved (when combined with `--writable`),
* convert the _sandbox_ to a `*.sif` file.

The drawbacks are that

* the changes inside the _sandbox_ are not `recorded` in the image (in contrast to the build from `.def` files), and therefore,
* the `.sif` file is hard to maintain in the long run,
* running a _sandbox_ often decreases performance: due to the converting of the image, and the access of individual files inside the sandbox is usually slower than the use of `.sif` format.

Example: Rocky Linux 9 - from Docker repository to sandbox container

```
    $ apptainer build --sandbox --disable-cache rocky_9.0-minimal.sif docker://rockylinux:9.0-minimal
    $ apptainer shell --fakeroot --writable ./rocky_9.0-minimal/
```

where `--fakeroot` will emulate elevated (root) permissions inside container and `--writable` will allow files in the sandbox to be changed.

### Example with Ubuntu 18.04

Alternatively, you can use `.def` recipe file. Example file named `ubuntu_18.04.def`
```
    Bootstrap: docker
    From: ubuntu:18.04
    
    %post
       apt-get update
       apt install --assume-yes neofetch
    
    %runscript
       neofetch
```

which can be built as sandbox
```
    $ apptainer build --sandbox --disable-cache ubuntu_18.04.sandbox ubuntu_18.04.def
```

This created in the current working directory a subdirectory `ubuntu_18.04.sandbox`, which contains all the files of the operating filesystem and software that was defined in `.def` file. This directory **is a container**, and as such can be also executed
```
    $ apptainer run ubuntu_18.04.sandbox
```

### Converting sandbox directory to sif file

```
    $ apptainer build ubuntu_18.04.sif ubuntu_18.04.sandbox
```

Will create in a current working directory a file `ubuntu_18.04.sif`, which can be executed either directly as any other executable:

```
    $ ./ubuntu_18.04.sif
```
or it can be normally run via `apptainer` command, which gives the user more options (`run`, `exec`, `shell` ...)

```
    $ apptainer run ubuntu_18.04.sif
```

## Building image as a regular user

Regular users cannot build an image on the {{ slurm_cluster_name | capitalize }} by executing `sudo apptainer build ...`. Users can therefore either

- build an image on any apptainer Linux machine where they also have elevated permissions (f.e. their laptop, or dedicated apptainer build server), or
- they can build an image in a sandbox directory mode and then convert that directory to static `.sif` file

See the [Build a Container section in the Apptainer documentation](https://apptainer.org/docs/user/latest/build_a_container.html) for details.

**Example of building an image from the definition file**

1. first we need to make sure we are not using our home folder - we need to create a directory inside the appropriate tmpXX filesystem and execute our commands from within
   
   `$ mkdir /groups/umcg-MYGROUP/tmpXX/umcg-MYUSERNAME/mycontainers && cd $_ && pwd`
  
  change capitalized part of the path with appropriate values.

2. inside we can create new or copy pre-existent definition file, here is an example for the tiny definition file `busybox_min.def`
```
    Bootstrap: busybox
    MirrorURL: https://www.busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox
    %runscript
      /bin/busybox sh
```

3. now let's create a container image - first it will be just a sandbox directory made out of the definition file
   
   `$ apptainer build --sandbox --disable-cache /groups/umcg-group/tmpXX/umcg-myusername/busybox_sandbox ./busybox_min.def`
   
   where `./my_apptainer.def` is a container recipe file in local directory.

4. then we need to convert the sandbox into a static `.sif` file
   
   `$ apptainer build ./busybox.sif /groups/umcg-group/tmpXX/umcg-myusername/busybox_sandbox`
   
5. now we can execute the container, either (faster options) directly as any other executable file
   
   `$ ./my_apptainer.sif`
   
   or by calling the `apptainer` command first (this gives you more apptainer options)
   
   `$ apptainer run ./my_apptainer.sif`
   

## Making an image from the definition file with elevated permissions

Definition file `lolcow.def`:
```
    BootStrap: library
    From: centos:7.9
    
    %post
        apt-get -y update
        apt-get -y install fortune cowsay lolcat
    
    %environment
        export LC_ALL=C
        export PATH=/usr/games:$PATH
    
    %runscript
        fortune | cowsay | lolcat
    
    %labels
        Author GodloveD
```

Build from this file
```
    $ sudo singularity build lolcow.sif lolcow.def
```

## Definition file

Apptainer images can be created either from
- 'writable sandbox directory' environment,
- or (recommended) from a `.def` file, a definition file with instructions on how to build a custom container.

Definition file consists
- setting the initial operating system (or another container with already defined OS) as an underlying base image,
- set instructions on how to configure, unpackage or install the required software,
- configures the runtime environment and its variables,
- sets the container metadata.

More specifically, an Apptainer Definition file is divided into two parts: `Header` and `Sections`

### Header

At the top of the file is the Header with `Bootstrap` - and it defines base operating filesystem of the image, usually is set to either `docker`, `localimage`, `busybox` or `yum`, but [many others options](https://apptainer.org/docs/user/1.0/definition_files.html#other-bootstrap-agents) are also available.

### Sections

Contains some or all of the following sections:

- `%setup` commands in the %setup section are first executed on the host system outside of the container after the base OS has been installed,
- `%files` allows you to copy files into the container with greater safety than using the %setup section,
- `%app` it may be redundant to build different containers for each app with nearly equivalent dependencies, Apptainer supports installing apps within internal modules,
- `%post` download files from the internet with tools like git and wget, install new software and libraries, write configuration files, create new directories,
- `%test` runs at the very end of the build process to validate the container,
- `%environment` define environment variables that will be available at runtime,
- `%startscript` contents of this section are written to a file within the container at build time. This file is executed when the instance start command is issued,
- `%runscript` contents of this section are written to a file within the container that is executed when the container image is run,
- `%labels` are key-value pairs, and define the metadata of your container (f.e. `Author d@sylabs.io`),
- `%help` at build time is added to the metadata of the container, and can be displayed using the run-help command,
- `%post` section executes within the container at build time after the base OS has been installed. The `%post` section is therefore the place to perform installations of new applications.

You can read more about the definition file on the [Apptainer's documentation website](https://docs.sylabs.io/guides/3.7/user-guide/definition_files.html)

## Important

It depends on how the container was built, but the `/home` folder is shared between the container and the host machine.
**This means that the users home folder files can be changed or deleted just by running a container**.
Make sure you check first (either by running with `shell` option) and then run an isolated environment (check the section about `Isolated runs`).

The _docker_ and _apptainer_ repositories are developed and maintained by the community, and therefore **images can and do contain all sorts of software and configurations**.
While most of them are safe to use, users should be careful and avoid running containers from unknown sources; They might contain either buggy software or malicious code.
Only use trusted images and when not sure, first try running it inside an isolated environment (check the section about `Isolated runs`).

Containers can consume a lot of storage. Making a new container will quickly fill up the disk. Make sure you:
* Keep only containers that you need.
* Either disable cache or use the `${APPTAINER_CACHEDIR}` environment variable to use a folder on a tmp file system instead of the default.
* Use the `${APPTAINER_TMPDIR}` environment variable to use a folder on a tmp file system instead of the default.

## Cache and tmp folders

By default _Apptainer_ caches all the downloaded image layers in your home dir (`~/.apptainer/cache`).
In addition _Apptainer_ use a temporary working space where containers are constructed before being packaged into an _Apptainer_ `*.sif` image.
Temporary space is also used when running containers in unprivileged mode and when performing some operations on file systems that do not fully support `--fakeroot`.
The default temporary working space is `/tmp`, which is a small shared resource.
At best running out of disk space in your home dir will only make your own commands and processes fail.
At worst running out of disk space in `/tmp` will crash the machine and affect all users.

#### ${APPTAINER_CACHEDIR}

To prevent problems with running out of cache disk space, you can
 * Either run the `apptainer` command with  `--disable-cache` argument. E.g.
   ```
   $ apptainer pull --disable-cache alpine.sif docker://alpine
   ```
 * Or redirect the cache to an appropriate location on a tmp file system using `APPTAINER_CACHEDIR` environment variable before running `apptainer` commands. E.g.
   ```bash
    export APPTAINER_CACHEDIR=/groups/my_group/some_tmp/$(id -un)/apptainer/cache/
    mkdir -p ${APPTAINER_CACHEDIR}
    apptainer ......
    ```
    where *my_group* and *some_tmp* must be changed into appropriate values.

#### ${APPTAINER_TMPDIR}

To prevent problems with running out of working disk space, you can redirect this to an appropriate location on a tmp file system
using `APPTAINER_TMPDIR` environment variable before running `apptainer` commands. E.g.
```bash
export APPTAINER_TMPDIR=/groups/my_group/some_tmp/$(id -un)/apptainer/tmp/
mkdir -p ${APPTAINER_TMPDIR}
apptainer ......
```
where *my_group* and *some_tmp* must be changed into appropriate values.

#### Automatically configure ${APPTAINER_CACHEDIR} and ${APPTAINER_TMPDIR} for each login

Environment variables are set for the duration of your session and lost on logout.
You can add code to your `~/.bashrc` file to make sure the `${APPTAINER_CACHEDIR}` and `${APPTAINER_TMPDIR}` environment variables are configured each time you login.
E.g.:

```bash
apptainer_base_path="/groups/my_group/some_tmp/$(id -un)/apptainer/"
APPTAINER_TMPDIR="${apptainer_base_path}/tmp"
APPTAINER_CACHEDIR="${apptainer_base_path}/cache"
mkdir -p "${APPTAINER_TMPDIR}"
mkdir -p "${APPTAINER_CACHEDIR}"
export APPTAINER_TMPDIR
export APPTAINER_CACHEDIR
```
Replace *my_group* and *some_tmp* from the example for appropriate values.

## Running Apptainer on Windows or Mac

Apptainer cannot run natively on Windows or Mac, but it is possible to run apptainer on non-Linux machines. At the moment only by using full virtualization or [Windows Subsystem for Linux](https://learn.microsoft.com/en-us/windows/wsl/install) (WSL 2 or higher).

For more information please visit [Apptainer's installation documentation](https://apptainer.org/docs/admin/main/installation.html).

## Using images from the Docker repository

Users can shell, import, run, and exec Docker images directly from the Docker Registry:

* Run image directly from Docker repository

`$ apptainer run docker://alpine:latest`

* Download image from Docker reposiroty to local folder

`$ apptainer pull docker://centos:latest`

* Directly execute shell inside Docker repository image

`$ apptainer shell docker://alpine:latest`

* Execute command inside the image

`$ apptainer exec docker://alpine:latest echo "Hi from inside the container."`

* Build image from Docker repository - expects user to have elevated permissions:

`$ sudo apptainer build ubuntu.img docker://ubuntu:latest`

* Build sandbox image directly from Docker repository:

`$ apptainer build --sandbox --disable-cache ubuntu.img docker://ubuntu:latest`

* Convert sandbox to static .sif image

`$ apptainer build busybox.sif busybox_sandboxdir`

* Prevent caching downloaded files from online repositories

`$ apptainer pull --disable-cache centos.sif docker://centos:7.9`

## Using storage from the host system inside containers

**Be careful: by default some - but not all - folders from the host system are automatically shared between host and container.**
The exact list of folders shared between host and container depends on options used when the container image was built as well as on runtime parameters.
This means that buggy or malicious software inside the container can corrupt or delete the data from the host that is mounted in the container.
_Apptainer_ provides options to control this exposure, by controlling mount points.
You can use arguments both to limit/remove mount points as well as add additional mount points.

#### Default host folders mounted inside containers running on {{ slurm_cluster_name | capitalize }}

The pre-configured list of paths, that will be mounted inside _Apptainer_ containers,
is controlled by setting the ```${APPTAINER_BINDPATH}``` environment variable when you login using this code:

```bash
APPTAINER_BINDPATH='{{ hpc_env_prefix }}/:{{ hpc_env_prefix }}/:ro'
readarray -t my_groups < <(groups | tr ' ' '\n')
for my_group in "${my_groups[@]}"; do
  if [[ -e "/groups/${my_group}" ]]; then
    APPTAINER_BINDPATH="${APPTAINER_BINDPATH},/groups/${my_group}"
  fi
done
```

For batch jobs submitted to Slurm and running on a compute node the pre-configured list of paths,
that will be mounted inside _Apptainer_ containers, is supplemented in the Slurm job prologs using:

```bash
if [[ -z "${APPTAINER_BINDPATH:-}" ]]; then
  export APPTAINER_BINDPATH="{{ hostvars[groups['compute_node'][0]]['slurm_local_scratch_dir'] }}/${SLURM_JOB_ID}/"
else
  export APPTAINER_BINDPATH="${APPTAINER_BINDPATH},{{ hostvars[groups['compute_node'][0]]['slurm_local_scratch_dir'] }}/${SLURM_JOB_ID}/"
fi
```

These default lists should be sufficient for most use cases, but can be overruled with the commandline arguments described below.

#### Isolated containers

In order to remove/limit mounts you can use the arguments:

 * `-c` or `--contain` to use minimal `/dev` and empty other directories (e.g. `/tmp` and `${HOME}`) instead of sharing filesystems from your host.
 * `-C` or `--containall` to contain not only file systems, but also PID, IPC, and environment.
 * `--no-mount /some/path` to disable a mount, even if it was added to the global `/etc/apptainer.conf` configuration file by a system administrator.

E.g.: ```apptainer run -C mycontainer.sif```

#### Mounting host folders inside containers

You can add additional mounts using the arguments:

 * `-B /path/on/host:/path/inside/container` or `--bind /path/on/host:/path/inside/container`  
   For example `apptainer shell --bind /home/${USER}/mydata:/mnt busybox.sif` will expose the folder `mydata` from the host machine to `/mnt` inside container.
 * `--mount source=/path/on/host,destination=/path/inside/container,other_options`  
   This is similar to `--bind`, but allows specification of additional mount options.
   You can use for example the `ro` argument to expose a folder _read-only_ to a container using  
   `apptainer shell --mount type=bind,source=/home/SOMEUSER/mydata,destination=/mnt,ro mycontainer.sif`

For more information, check Apptainer's website [about mount points](https://apptainer.org/docs/user/main/bind_paths_and_mounts.html).

## Other considerations

### Architecture considerations

Software build for specific architecture, can be only executed on the systems of the same architecture. For example, an apptainer image build on Apple M1 (ARM) or PowerPC (RISC) architecture will not run on x86 systems and vice versa.

Software compiled within the _Apptainer_ image can also have issues when running on an older generation of the same type of architecture. This can happen when the compiled binary code contains instructions for a modern processor, that older ones cannot understand. The other way around, running software build for processors of a certain architecture should work on any newer generation processors of the same architecture.

### Licence considerations

A non-free software - a closed-source or proprietary software, can be used within the licence agreement of that software. Using a proprietary software from publicly available containers are not allowed. And conversly also creating and publicly share your own containers with closed-source software is usually prohibited.

Before using, and sharing containers, please check for software limitations, which can be (among many others) limited to

* group-wide, company-wide, enterprise-wide use,
* use on-premise only or geographically limited - for example to a region or country,
* limited to specific person (in some cases only when working at specific company and/or position),
* prohibited from running in the cloud,
* locked to a specific host or hardware (MAC address limited).

## Environment variables

If you have environment variables set outside of your container, on the host, then by default they will be available inside the container.
You can overwrite variable set inside container by defining it outside first. The variables that can overwrite the default set ones start with `APPTAINERENV_...`, f.e.

```
    $ export APPTAINERENV_PATH="/some/path"
    $ apptainer exec alpine_sandbox/ /bin/busybox sh -c 'echo $PATH'
    /some/path
```

or by providing argument `--env myvariable="myvalue1"` at container execution

```
    $ apptainer exec --env PATH=/some/path alpine_sandbox/ /bin/busybox sh -c 'echo $PATH'
    /some/path
```

## Debug information

In some cases you might need more information about how the container is behaving while running. Adding `-d` argument to `apptainer` call, will enable printing more information about the container environment and what system call is being executed. For example without debug:

```
    $ apptainer run -C ./busybox.sif 
    Apptainer> 
    (base) [user@hostname mycontainer]$
```

and the same container with debug option

```
    $ apptainer -d run -C ./busybox.sif 
      DEBUG   [U=50101501,P=19806]persistentPreRun()            Apptainer version: 1.1.3-1.el7
      DEBUG   [U=50101501,P=19806]persistentPreRun()            Parsing configuration file /etc/apptainer/apptainer.conf
      DEBUG   [U=50101501,P=19806]SetBinaryPath()               Setting binary path to /usr/libexec/apptainer/bin:/apps/software/Anaconda3/2022.05/bin:/apps/software/Anaconda3/2022.05/condabin:/apps/software/lmod/lmod/libexec:/apps/software/Lua/5.1.4.9/bin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
      DEBUG   [U=50101501,P=19806]SetBinaryPath()               Using that path for all binaries
    ... 185 other lines ...
      DEBUG   [U=50101501,P=1]   sylogBuiltin()                Sourcing /.singularity.d/env/94-appsbase.sh
      DEBUG   [U=50101501,P=1]   sylogBuiltin()                Sourcing /.singularity.d/env/95-apps.sh
      DEBUG   [U=50101501,P=1]   sylogBuiltin()                Sourcing /.singularity.d/env/99-base.sh
      DEBUG   [U=50101501,P=1]   sylogBuiltin()                Sourcing /.singularity.d/env/99-runtimevars.sh
      DEBUG   [U=50101501,P=1]   sylogBuiltin()                Running action command run
      DEBUG   [U=50101501,P=19806]PostStartProcess()            Post start process
    Apptainer>
```
## Additional examples

### Alpine - as regular user build static file via sandbox directory

Alpine has a known bug in that is still present in apptainer version `1.1.4`. It prevents users to build apptainer images from `.def` file, reporting:
```
    INFO:    Running post scriptlet
    /.singularity.d/libs/fakeroot: eval: line 140: /.singularity.d/libs/faked: not found
    fakeroot: error while starting the `faked' daemon.
    sh: you need to specify whom to kill
    FATAL:   While performing build: while running engine: exit status 1
```

Users can still use alpine linux, if the issue can be bypassed with:
1. first pulling image from repository, saving it in current working directory as sandbox,
2. then all the packages can be installed inside the sandbox with `apptainer exec --writable`, where changes are saved permanently,
4. lastly the sandbox is convert back to static file

But this involves manual run of the commands, and can needs extra work to be automatized. The example is:

```
    $ apptainer build --sandbox alpine_sandbox docker://alpine:latest
     INFO:    Starting build...
     Getting image source signatures
     Copying blob c158987b0551 done  
     Copying config 79c58fdfff done  
     Writing manifest to image destination
     Storing signatures
     2023/01/03 21:04:12  info unpack layer: sha256:c158987b05517b6f2c5913f3acef1f2182a32345a304fe357e3ace5fadcad715
     2023/01/03 21:04:13  warn xattr{etc/shadow} ignoring ENOTSUP on setxattr "user.rootlesscontainers"
     2023/01/03 21:04:13  warn xattr{/home/umcg-scimerman/build-temp-2831576097/rootfs/etc/shadow} destination filesystem does not support xattrs, further warnings will be suppressed
     WARNING: The sandbox contain files/dirs that cannot be removed with 'rm'.
     WARNING: Use 'chmod -R u+rwX' to set permissions that allow removal.
     WARNING: Use the '--fix-perms' option to 'apptainer build' to modify permissions at build time.
     INFO:    Creating sandbox directory...
     INFO:    Build complete: alpine_sandbox
    $ apptainer exec --writable alpine_sandbox apk add R
... long output shortened ...
    $ apptainer build ./alpine_R.sif ./alpine_sandbox
    INFO:    Starting build...
    INFO:    Creating SIF file...
    INFO:    Build complete: ./alpine_R.sif
```

### Simple CentOS 7 example via sandbox

This simple CentOS 7 example is created in two steps from a definition file `centos7.def`

```
    BootStrap: docker
    From: centos:7
    
    %post
       yum install -y wget
       wget -O /tmp/screenfetch https://raw.githubusercontent.com/KittyKatt/screenFetch/v3.9.1/screenfetch-dev
       chmod 0755 /tmp/screenfetch
    
    %runscript
       /tmp/screenfetch
```

Building sandbox directory first

```
    $ apptainer build --sandbox centos7.sandboxdir centos7.def
     INFO:    User not listed in /etc/subuid, trying root-mapped namespace
     INFO:    Could not start root-mapped namespace
     INFO:    The %post section will be run under fakeroot
    ... long output ...
    $ 
```

Then either run directly

```
    $ apptainer run centos7.sandboxdir
```

Or first converting sandbox directory into single static `centos7.sif` file

```
    $ apptainer build centos7.sif centos7.sandboxdir
```
and the run with

```
    $ apptainer run centos7.sif
                   ..                    user@hostname
                 .PLTJ.                  OS: CentOS 
                <><><><>                 Kernel: x86_64 Linux 3.10.0-1160.80.1.el7.x86_64
       KKSSV' 4KKK LJ KKKL.'VSSKK        Uptime: 42d 20h 33m
       KKV' 4KKKKK LJ KKKKAL 'VKK        Packages: 150
       V' ' 'VKKKK LJ KKKKV' ' 'V        Shell: sh
       .4MA.' 'VKK LJ KKV' '.4Mb.        Disk: 13G / 149G (9%)
     . KKKKKA.' 'V LJ V' '.4KKKKK .      CPU: Intel Core (Broadwell, IBRS) @ 24x 2.4GHz
   .4D KKKKKKKA.'' LJ ''.4KKKKKKK FA.    GPU: 
  <QDD ++++++++++++  ++++++++++++ GFD>   RAM: 109412MiB / 217778MiB
   'VD KKKKKKKK'.. LJ ..'KKKKKKKK FV    
     ' VKKKKK'. .4 LJ K. .'KKKKKV '     
        'VK'. .4KK LJ KKA. .'KV'        
       A. . .4KKKK LJ KKKKA. . .4       
       KKA. 'KKKKK LJ KKKKK' .4KK       
       KKSSA. VKKK LJ KKKV .4SSKK       
                <><><><>                
                 'MKKM'                 
                   ''                   

```
