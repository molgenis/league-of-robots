#jinja2: trim_blocks:True
# Software - How to use and install software on {{ slurm_cluster_name | capitalize }}
{% set example_tmp_lfs = lfs_mounts | selectattr('lfs', 'search', 'tmp[0-9]+$') | map(attribute='lfs') | first %}
## Introduction

Software can be installed using different methods; some are only available to admins and some you can use yourself.

1. Packages from the Linux distro / Operating System (OS)
2. Modules installed with EasyBuild by admins
3. Modules installed with EasyBuild by regular users in their own environment
4. Other package managers / deployment procedures
5. Language specific installation options for extra/custom packages

## 1. Packages from the Linux distro / Operating System (OS)

The Operating System (OS) a.k.a. Linux distro comes with a bunch of tools, which are available to all users and installed in _default_ locations.
These _default_ locations are part of _default search paths_ for binaries, libraries, etc.
Therefore you only need to type the name of a command and do not need to specify the complete path to that command,
because it can be found in the _search path_ for binaries. These _search paths_ are stored in environment variables,
which by convention have names in uppercase only.

E.g. the _search path_ for binaries is stored in the ```${PATH}``` environment variable and consists of one or more directories separated by a colon (```:```).
A pretty standard setting for ```${PATH}``` could look like this: ```/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:${HOME}/bin```.
This means the system will search those directories for a command, in the order given and use the first hit
or return ```command not found``` if it could not find an issued command in any of them.

E.g. the ```ls``` command to list the contents of a directory is located at ```/usr/bin/ls```,
but you can simply type ```ls``` in a terminal to run that command when ```/usr/bin/``` is part of ```${PATH}```.

The advantage of packages from the OS is that they are there by default and available to all users of the system.
The disadvantage of packages from the OS is that there can be only one version of a package in the _default_ location.
For some scientific analysis you may need a different version than for another analysis.
Hence, we often need multiple versions of software packages installed side by side and we have to be able to select a specific version for a specific analysis.
This is where all others options below come into play: the mechanisms vary, 
but they all - one way or another - modify the _search paths_ to make specific versions of software available in your environment.

## 2. Modules installed with EasyBuild by admins

We deploy software with [EasyBuild](https://easybuild.io/) in a central place on a Deploy Admin Interface (DAI) server. 
From there the software is synced to various storage devices that are mounted read-only on User Interface (UI) servers and compute nodes. 
Do not use hard-coded paths to software in your scripts: these will vary per cluster node and may change without notice in case we need to switch from one _tmp_ storage system to another due to (un)scheduled downtime. 
Instead use the [Lua based module system \(Lmod\)](https://github.com/TACC/Lmod) to transparently load software in your environment on any of the cluster components / servers.

* To get a list of available apps:

        module avail

* To load an app in your environment if you don't care about the version:

        module load ModuleName

* To load a specific version of an app:

        module load ModuleName/ModuleVersion

* To see which modules are currently active in your environment

        module list

    * Note that some modules may have dependencies on others.  
      In that case the dependencies are automatically loaded.  
      Hence ```module list``` may report more loaded modules than you loaded explicitly with ```module load```.
    * Suggested good practice: always use ```module list``` after ```module load``` in your scripts and write the output to a log file.
      This ensures you can always trace back which versions of which software and their dependencies were used.

* If you need multiple conflicting versions of apps for different parts of your analysis you can also remove a module and load another version:

        module load ModuleName/SomeVersion
        module list
        [analyse some data...]
        module unload ModuleName
        module load ModuleName/AnotherVersion
        module list
        [analyse more data...]

###### Example for the Genome Analysis Toolkit (GATK).

* List available [Genome Analysis Toolkit \(GATK\)](http://www.broadinstitute.org/gatk/) versions:

        module avail GATK
        ----------------------------------- /apps/modules/bio -----------------------------------
        GATK/3.3-0-Java-1.7.0_80    GATK/3.4-0-Java-1.7.0_80    GATK/3.4-46-Java-1.7.0_80 (D)

* To select version 3.4-46-Java-1.7.0_80 and check what got loaded:

        module load GATK/3.4-46-Java-1.7.0_80
        module list

   which returns:

        To execute GATK run: java -jar ${EBROOTGATK}/GenomeAnalysisTK.jar
        
        Currently Loaded Modules:
          1) GCC/4.8.4                                                  13) libpng/1.6.17-goolf-1.7.20
          2) numactl/2.0.10-GCC-4.8.4                                   14) NASM/2.11.06-goolf-1.7.20
          3) hwloc/1.10.1-GCC-4.8.4                                     15) libjpeg-turbo/1.4.0-goolf-1.7.20
          4) OpenMPI/1.8.4-GCC-4.8.4                                    16) bzip2/1.0.6-goolf-1.7.20
          5) OpenBLAS/0.2.13-GCC-4.8.4-LAPACK-3.5.0                     17) freetype/2.6-goolf-1.7.20
          6) gompi/1.7.20                                               18) pixman/0.32.6-goolf-1.7.20
          7) FFTW/3.3.4-gompi-1.7.20                                    19) fontconfig/2.11.94-goolf-1.7.20
          8) ScaLAPACK/2.0.2-gompi-1.7.20-OpenBLAS-0.2.13-LAPACK-3.5.0  20) expat/2.1.0-goolf-1.7.20
          9) goolf/1.7.20                                               21) cairo/1.14.2-goolf-1.7.20
         10) libreadline/6.3-goolf-1.7.20                               22) Java/1.8.0_45
         11) ncurses/5.9-goolf-1.7.20                                   23) R/3.2.1-goolf-1.7.20
         12) zlib/1.2.8-goolf-1.7.20                                    24) GATK/3.4-46-Java-1.7.0_80

  The _GATK_ was written in _Java_ and therefore the _Java_ dependency was loaded automatically. 
  _R_ was also loaded as some parts of the _GATK_ use _R_ for creating plots/graphs. 
  _R_ itself was compiled from scratch and has a large list of dependencies of its own ranging from compilers like _GCC_ to graphics libs like _libpng_.  
  _Java_ and _R_ have binaries, which can be executed without specifying the path to where they are locate on the system, 
  because the module system has added the directories, where they are located, to the ```${PATH}``` environment variable, which is used as search path for binaries.  
  
  If the _GATK_ was a binary too you could now simply call it without specifying the path to it, 
  but as the _GATK_ is a ```*.jar``` file we need to call the ```java``` binary and specify the path to the _GATK_ ```*.jar```.
  To make sure we don't need an absolute path to the _GATK_ ```*.jar``` hard-coded in our jobs/scripts, 
  the _GATK_ module created an environment variable named ```${EBROOTGATK}```, 
  so we can resolve the path to the _GATK_ transparently even if it varies per server.  
  
  The `EB` stands for [EasyBuild](https://easybuild.io/), which we use to deploy software. 
  _EasyBuild_ creates environment variables pointing to the root of where the software was installed for each module according to the scheme 
  EB + ROOT + [NAMEOFSOFTWAREPACKAGEINCAPITALS]. Hence for myFavoriteApp it would be ```${EBROOTMYFAVORITEAPP}```.  
  
* Let's see what's installed in ```${EBROOTGATK}```:  

        ls -hl "${EBROOTGATK}"
        
        drwxrwsr-x 2 deployadmin depad 4.0K Aug  5 15:59 easybuild
        -rw-rw-r-- 1 deployadmin depad  13M Jul  9 23:41 GenomeAnalysisTK.jar
        drwxrwsr-x 2 deployadmin depad 4.0K Aug  5 15:58 resources

* Hence we can now execute the _GATK_ and verify we loaded the correct version like this:

        java -jar "${EBROOTGATK}/GenomeAnalysisTK.jar" --version
        
        3.4-46-gbc02625

  Note that we did not have to specify a hard-coded path to java nor to the _GATK_ ```*.jar``` file. 

###### Missing software

If the software you need is not yet available, please use the following procedure:

  1. First try to install the software on a UI in a ```/groups/${group}/tmp*/...``` folder (without EasyBuild).
     Use whatever instructions came with the software...
  2. Test the software and evaluate if it is useful to do a proper reproducible deployment.  
     If yes, continue and otherwise cleanup.
  3. Choose a package manager
      * If you decide to go with EasyBuild, then depending on your time involved in a project:
         * If you work on the cluster for < 6 months (interns, master student projects, etc.) we don't expect you to learn how to use EasyBuild.  
           Ask your supervisor first; if he/she is not part of the deploy admins group, you can [send a request to the helpdesk via email](../contact/).
         * If you work on the cluster for > 6 months it's time to learn how to create an EasyConfig for EasyBuild.  
           See instructions below.
      * If you choose another deployment method / package manager, feel free to do so, but
         * Do realize you can only get minimal support from the helpdesk for other deployment methods.
         * Understand that mixing package managers is a bad idea.
           This will quickly create additional complexity when multiple package managers start fighting each other by modifying _search paths_ in conflicting ways.

###### Instructions for deploy admins

Login on the Deploy Admin Interface ```{{ groups['deploy_admin_interface'] | first }}```
via jumphost ```{{ groups['jumphost'] | first }}```
and deploy with EasyBuild in /apps/...

## 3. Modules installed with EasyBuild by regular users in their own environment

 * You can use these steps on a UI to 
   [create your own personal EasyBuild environment](https://gist.github.com/mmterpstra/d11ec81bf78c169ab6be5911df384496)
   and deploy software with EasyBuild in a ```/groups/${group}/tmp*/...``` folder.  
 * Use [the EasyBuild documentation](https://docs.easybuild.io/) to learn how to make an EasyConfig file.

Note: unless you really need a newer version of the full ```foss``` toolchain or its ```GCCcore``` sub toolchain,
we suggest you use the latest version that is already deployed on the cluster,
because a complete new toolchain takes up a lot of space and time to compile.

If you have your own EasyBuild environment and want to become a member of the deploy admins group in order to deploy software in ```/apps```,
then follow these steps:

 * Fork our [easybuild-easyconfigs repo on GitHub](https://github.com/molgenis/take-it-easyconfigs) and create a pull request with the EasyConfig(s) you created.
 * Request membership by [sending an email to the helpdesk](../contact/).  
   Include in your email:
     * a link to the pull request.
     * the path to the module file(s) created at the end of the deployment in your own EasyBuild environment.
 * If the EasyConfigs from your pull request are sane and the software was deployed properly,
   you have passed the test and will be added to the deploy admins group.

## 4. Other package managers / deployment procedures

There are many other ways to deploy software on a cluster, some of which are listed below.
Feel free to choose whatever suits your scientific project best, but

 * Do realize you can only get minimal support from our helpdesk for other deployment methods.
 * Understand that mixing package managers or methods is a bad idea.
   This will quickly create additional complexity when they start fighting each other by modifying _search paths_ in conflicting ways.
 * Make sure you have a good _recipe_ to make the software installation procedure [FAIR](https://doi.org/10.15497/RDA00068).
   Think ahead about how to write the _materials and methods_ section of the paper or internship report you will write in the near future:
   If the installation procedure was a horrible, hacky, band aid solution, then writing the _materials and methods_ section is going to be a challenge.
 * Watch out for package managers that want to install or cache lots of data in your home dir by default!
    * Your home dir is designed to be a small **private folder** for personal preferences.
    * Your home dir is **not** a suitable place for data sets nor for software.
    * If a software package manager cached a lot of data in your home dir,
      you will quickly run into _"quota exceeded"_ or _"no space left on device"_ errors.
      Consult the manual for the corresponding package manager how to relocate its cache to a different folder and cleanup your home dir.
      Do not forget to look for _hidden_ folders or files (the ones starting with a dot) in your home.
      E.g. ```${HOME}/.cache/```, ```${HOME}/.local/```, etc.

###### Conda, Miniconda and Bioconda

[Conda](https://docs.conda.io) is a package and environment manager originally written in and for the Python language,
but nowadays it can package and distribute software written in any language.

Anaconda is the name of both the [company developing Conda](https://www.anaconda.com) and the name of a large conda _channel/repository_ with curated conda packages.

Miniconda is a minimal, bootstrap version of Anaconda that includes only Conda, Python, their dependencies and a small number of utilities.

[Bioconda](https://bioconda.github.io/) is a conda _channel/repo_ with packaged bioinformatics software.

With _Conda_ you use pre-compiled binaries from a conda _channel/repo_ as opposed to compiling the code on {{ slurm_cluster_name | capitalize }}.
This has the advantage that it is faster and in many cases easier to deploy the software.
But the are also disadvantages:

 * The pre-compiled binaries cannot be optimized for different CPU/GPU architectures.
   * Either they will use a common denominator and only use instructions most generations of CPUs/GPUs understand, which may make the software slow.
   * Or if the software does use instructions for a specific generation of it will only work on that generation, which may be different than the one for {{ slurm_cluster_name | capitalize }}.
 * _Conda_ makes assumptions about locations of dependencies during compile time.
   The pre-compiled binaries will crash at run time if these dependencies are missing or located elsewhere on the machine where you install them.
   Depending on the error message it can be very hard to figure out if there is a problem with the pre-compiled software
   or whether there is a problem with your input data set.
   If you compile the software from source on the cluster instead,
   you will notice during compilation if there are issues due to missing dependencies.

Therefore we strongly suggest to *only try _Conda_ as last resort when all else has failed*.

When you do use _Conda_, then make sure to specify custom locations for both

 * The new _Conda_ environment
 * The cache dir where _Conda_ caches downloaded packages

Failure to do that means _Conda_ will use your small home dir and you will run into the storage quota limit for your home dir rather sooner than later.
You can change the defaults for these locations like this:

```
export CONDA_PKGS_DIRS=/groups/${choose_one_of_your_groups}/{{ example_tmp_lfs }}/some/example/folder/conda/packages/
conda info
conda create --prefix /groups/${choose_one_of_your_groups}/{{ example_tmp_lfs }}/some/example/folder/conda/environment/
```

###### Containers

Container technology is a lightweight form of virtualization, where a piece of software is packaged in a container image file together with all its dependencies.
The image file can then be used to start instances of the software.
On {{ slurm_cluster_name | capitalize }} you can use [_Apptainer_ containers](../apptainer/).

## 5. Language specific installation options for extra/custom packages

 * [R packages](../R/)
 * [Python virtual environment](../python/)
<!--
 * Perl packages
 * Python packages
-->

