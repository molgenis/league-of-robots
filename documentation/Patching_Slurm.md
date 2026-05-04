# Creating patched Slurm & NHC RPMs for HPC clusters #

Table of Contents:

* [Summary](#-summary)
* [Configure rpmbuild](#-configure-rpmbuild)
* [Patch and Build Slurm RPMs](#-patch-and-build-slurm-rpms)
* [Build NHC RPM](#-build-nhc-rpm)

---

# <a name="Summary"/> Summary

We use a patched Slurm version in order to allow all users to retrieve job stats for all jobs with ```sstat```
and tools that depend on ```sstat``` (e.g. ```ctop``` from the ```cluster-utils``` module).
In a plain vanilla Slurm version only the root user can get the jobs stats for running of all jobs.
Regular users can only retrieve job stats for their own running jobs 
(and for all completed jobs using sacct and the Slurm accounting DB).
The rationale for the default behaviour is that fetching the stats for all jobs can cause quite some load on very large clusters
(thousands of nodes), but on the smaller clusters we use the load from ```sstat``` is negligible.

# <a name="Configure-rpmbuild"/> Configure rpmbuild

The ```rpmbuild``` command should have been deployed using the ```build_environment``` role on _Deploy Admin Interface (DAI)_ machines.
The only thing that needs to be created in order to use ```rpmbuild``` on a _DAI_ is a bunch of directories and a minimal ```~/.rpmmacros``` file:

```
mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
if [ -f ~/.rpmmacros ];then
    echo '~/.rpmmacros already exists.'
else
    echo '%_topdir %(echo $HOME)/rpmbuild' > ~/.rpmmacros
    echo 'Initialized ~/.rpmmacros'
fi
```

# <a name="Patch-and-Build-Slurm-RPMs"/> Patch and Build Slurm RPMs

This must be performed on a _DAI_ with configured ```rpmbuild```.

### 1. Resolve dependencies

The following packages should be already installed on the DAI, but run ```yum```/```dnf``` as root to make sure they are there and up to date:

##### On RHEL >= 8.x

Note: Slurm has support for both ```cgroups``` v1 and v2, but support for v2 is only compiled if the dbus development files are present.

The following packages are required to compile Slurm
 * These packages should be already present on Deploy Admin Interface (DAI) machines 
 * On Dragen machines they must be added manually

```
dnf install munge-devel munge-libs mysql-devel pam-devel pkgconfig readline-devel lua lua-devel lua-posix dbus-devel rpm-build autoconf automake
```

This installs on an Oracle 8.x Dragen machine:

```
[root@bb-dragen]# dnf install munge-devel munge-libs mysql-devel pam-devel pkgconfig readline-devel lua lua-devel lua-posix dbus-devel rpm-build autoconf automake
Package munge-libs-0.5.13-2.el8.x86_64 is already installed.
Package pkgconf-pkg-config-1.4.2-1.el8.x86_64 is already installed.
Package lua-5.3.4-12.el8.x86_64 is already installed.
======================================================================
 Package                        Architecture    Repository            
======================================================================
Installing:
 autoconf                       noarch          ol8_appstream         
 automake                       noarch          ol8_appstream         
 dbus-devel                     x86_64          ol8_appstream         
 lua-devel                      x86_64          ol8_codeready_builder 
 lua-posix                      x86_64          ol8_codeready_builder 
 munge-devel                    x86_64          ol8_codeready_builder 
 mysql-devel                    x86_64          ol8_appstream         
 pam-devel                      x86_64          ol8_baseos_latest     
 readline-devel                 x86_64          ol8_baseos_latest     
 rpm-build                      x86_64          ol8_appstream         
Upgrading:
 munge                          x86_64          ol8_appstream         
 munge-libs                     x86_64          ol8_appstream         
 mysql-common                   x86_64          ol8_appstream         
 mysql-libs                     x86_64          ol8_appstream         
 pam                            x86_64          ol8_baseos_latest     
Installing dependencies:
 cmake-filesystem               x86_64          ol8_appstream         
 elfutils                       x86_64          ol8_baseos_latest     
 ncurses-c++-libs               x86_64          ol8_baseos_latest     
 ncurses-devel                  x86_64          ol8_baseos_latest     
 zstd                           x86_64          ol8_appstream         
======================================================================
```

### 2. Download and unpack Slurm

```
wget https://download.schedmd.com/slurm/slurm-${SLURM_VERSION}.tar.bz2
tar -xvjf slurm-${SLURM_VERSION}.tar.bz2
```

### 3. Patching slurmd source

Disabled UID check in **_rpc_stat_jobacct** function of
```
slurm-${SLURM_VERSION}/src/slurmd/slurmd/req.c
```
to allow all users to retrieve job stats for all jobs with ```sstat```.

```
	/*
	 * check that requesting user ID is the Slurm UID or root
	 * DISABLED to allow sstat to retrieve job stats for all running jobs of all users.
	 * This may have a negative impact on highly parallellized apps or large clusters.
	 */
	/*if ((msg->auth_uid != uid) &&
	*    !_slurm_authorized_user(msg->auth_uid)) {
	*	error("stat_jobacct from uid %u for job %u owned by uid %u",
	*	      msg->auth_uid, req->job_id, uid);
	*
	*	if (msg->conn_fd >= 0) {
	*		slurm_send_rc_msg(msg, ESLURM_USER_ID_MISSING);
	*		close(fd);
	*		return;
	*	}
	}*/
```

### 4. Append umcg suffix to version/release number

Patch the SLURM ```slurm-${SLURM_VERSION}/slurm.spec``` file.

 * Append ```.umcg``` suffix to release in the SLURM ```slurm-${SLURM_VERSION}/slurm.spec``` file.
   Example for Slurm 18.08.8 where the patch level (last number) is ```8```:
   Change:
   ```
       Release:        %{rel}%{?extraver}%{?dist}
   ```
   into:
   ```
       Release:        %{rel}%{?extraver}%{?dist}.umcg
   ```
   The patch level number may be different for other releases.
 * Change:
   ```
       # when the rel number is one, the directory name does not include it
       %if "%{rel}" == "1"
       %global slurm_source_dir %{name}-%{version}
       %else
       %global slurm_source_dir %{name}-%{version}-%{rel}
       %endif
   ```
   into:
   ```
       %global slurm_source_dir %{name}-%{version}-%{rel}.umcg
   ```

Make sure to also add the ```%{rel}``` and ```.umcg``` suffix to the folder name.
E.g. when ```%{rel}``` is 1, then:

```
SLURM_REL=1
mv slurm-${SLURM_VERSION} slurm-${SLURM_VERSION}-${SLURM_REL}.umcg
```

### 5. Create new tar.bz2 source code archive with patched code

```
tar -cvjf ~/rpmbuild/SOURCES/slurm-${SLURM_VERSION}-${SLURM_REL}.umcg.tar.bz2  slurm-${SLURM_VERSION}-${SLURM_REL}.umcg
```

### 6. Build patched RPMs

```
rpmbuild -ta --with lua --with mysql ~/rpmbuild/SOURCES/slurm-${SLURM_VERSION}-${SLURM_REL}.umcg.tar.bz2
```
When successful, add the patched RPMs to our custom repo on the Pulp repo servers for the corresponding infra stacks.
Don't forget to create a new Pulp publication for the updated repo version and then update the Pulp distribution 
to serve the new Pulp publication. See [Configuring_Pulp](Configuring_Pulp.md) for details.

# <a name="Build-NHC-RPM"/> Build NHC RPM

This must be performed on a _DAI_ with configured ```rpmbuild```.

### 1. Download NHC

```
cd ~/rpmbuild/SOURCES/
wget https://github.com/mej/nhc/releases/download/${NHC_VERSION}/lbnl-nhc-${NHC_VERSION}.tar.gz
```

**IMPORTANT**: make sure to download the ```lbnl-nhc-${NHC_VERSION}.tar.gz``` artifacts attached to a release on Github
and **not** the ```${NHC_VERSION}.tar.gz``` files, which are automatically generated by GitHub and miss files required for the build system.

### 2. Build NHC RPM

```
rpmbuild -ta --define 'rel 1' ~/rpmbuild/SOURCES/lbnl-nhc-${NHC_VERSION}.tar.gz
```

When successful, add the patched RPMs
 * Either - for clusters that use repo servers - to our custom repo on the _Pulp repo server_ for the corresponding infra stack.  
   Don't forget to create a new Pulp _publication_ for the updated repo version
   and then update the Pulp _distribution_ to serve the new Pulp _publication_.  
   See [Configuring_Pulp](Configuring_Pulp.md) for details.
 * Or - for clusters that do not use repo servers - to the local _yum repo_ on all machines of the correspnding stack that need Slurm.  
   See `roles/yum_local/README.md` for details.
