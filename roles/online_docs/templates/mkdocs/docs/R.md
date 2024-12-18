#jinja2: trim_blocks:True, lstrip_blocks: True
{% set example_tmp_lfs = lfs_mounts | selectattr('lfs', 'search', 'tmp[0-9]+$') | map(attribute='lfs') | first %}
# Installing custom R packages

Installation of ```R``` packages for all cluster users can be requested via the helpdesk,
which will add them to a future ```RPlus``` module.
Making a new ```RPlus``` module is not something the helpdesk can do quickly though:
we maintain a list of more than 1500 R packages and compiling a new module can take a lot of time.

It is also possible to install custom```R``` packages in a ```tmp``` group folder yourself
and optionally share it with your colleagues as long as they have access to the same group folder.

## Create location for custom R packages and prepend that to the search path for R packages

First you will need to choose a location where you want to install your custom ```R``` packages.
This path needs to be added to the ```${R_LIBS}``` environment variable in your ```${HOME}/.Renviron``` config file.

#### 1. Create a ${HOME}/.Renviron file

```bash
touch ${HOME}/.Renviron
```

This will create a ```.Renviron``` file in your home dir if you did not already have one.
If the file already exists the touch command will only update the last modification time stamp of the file and leave the content unchanged.

#### 2. Add ${R_LIBS} to your ${HOME}/.Renviron file

If the path you chose for your custom R package is in the ```{{ example_tmp_lfs }}``` folder of the group named ```my-favorite-group```
and the R version for which you want to compile your extra R packages is 4.2.2,
then add something like this to your ```~/.Renviron``` file:

```bash
R_LIBS="/groups/my-favorite-group/{{ example_tmp_lfs }}/R-packages/x86_64-pc-linux-gnu-library/4.2:${R_LIBS}"
```

###### Note ${R_LIBS} versus ${R_LIBS_USER}

The R documentation instructs users to set ```${R_LIBS_USER}``` instead of ```${R_LIBS}```.
```${R_LIBS_USER}``` is used together with ```${R_LIBS_SITE}``` and hard-coded paths added at compile time to create ```${R_LIBS}```.
When you use ```${R_LIBS_USER}``` though, your custom folder for R packages will end up in the wrong order in ```${R_LIBS}```
when you mix custom R packages with R packages from other sources like for example the ```RPlus``` module.

###### Note % expansions do not work in ${R_LIBS}

The `%p` and `%v` expansions for _platform_ and _version_, which are available for ```${R_LIBS_USER}```
cannot be used with ```${R_LIBS}```, so something like this
```bash
R_LIBS="/groups/my-favorite-group/{{ example_tmp_lfs }}/R-packages/%p-library/%v:${R_LIBS}"
```
will __*not*__ work.

###### Note about version numbers in the path

When you upgrade to another patch level for the same major & minor version of R (e.g. 4.2.2 -> 4.2.3),
then you can use the same path.
But you will want to update the path in your ```${HOME}/.Renviron``` and recompile the R packages
when upgrading to another minor or another major version (e.g. 4.2.2 -> 4.3.1 or 4.2.2 -> 5.0.1).

#### 3. Make sure the custom path added to ${R_LIBS} exists

Create the folder if it does not already exist. E.g.:

```bash
mkdir -p -m 770 "/groups/my-favorite-group/{{ example_tmp_lfs }}/R-packages/x86_64-pc-linux-gnu-library/4.2"
```

Next, load either a _bare_ ```R``` or load ```RPlus```, which is a bundle of lots of ```R``` packages already pre-installed on {{ slurm_cluster_name | capitalize }}.

```bash
module load RPlus
R
```

Now, use the ```.libPaths()``` function in ```R``` to check the value(s) for the paths where ```R``` will search for extra packages.
By default new ```R``` packages will be installed in the first folder reported by ```.libPaths()```

```R
R> .libPaths()
[1] "/groups/my-favorite-group/{{ example_tmp_lfs }}/R-packages/x86_64-pc-linux-gnu-library/4.2"
[2] "/apps/software/R/4.2.2-foss-2022a-bare/lib64/R/library"
```

If the ```.libPaths()``` function does not list your folder for custom R packages (first),
but for example only the library folder for the loaded ```R``` version itself like this

```R
R> .libPaths()
[1] "/apps/software/R/4.2.2-foss-2022a-bare/lib64/R/library"
```

Then this most likely means that the path specified in ```${R_LIBS_USER}``` does not exist yet;
In that case quit ```R```, double check for typos and whether the folder was created correctly on the file system.

## Install custom R packages

With your custom folder for ```R``` packages present on the file system and listed as the first item by the ```.libPaths``` function,
you can now install packages. Below are examples of installing packages from different sources.

#### A. Install R package from the Comprehensive R Archive Network (CRAN) repository

Load and start R.

```bash
module load RPlus
R
```

Use the [```install.packages()``` function](https://cran.r-project.org/doc/manuals/r-release/R-admin.html#Installing-packages)
to install packages from [_CRAN_](https://cran.r-project.org/).  
E.g. to install a package named ```packageName```:

```R
R> install.packages('packageName')
```

#### B. Install R package from the BioConductor repository

Load and start R.

```bash
module load RPlus
R
```

_BioConductor_ has its own ```R``` package to manage package installations.
It is named _BiocManager_ and can be installed from _CRAN_.  
Install _BiocManager_ in ```R``` if it is not already installed: 

```R
R> if (!require("BiocManager", quietly = TRUE))
       install.packages("BiocManager")
```

Next, use _BiocManager_ to install _BioConductor_ packages. E.g.:

```R
R> BiocManager::install(c('myFavoritePackage', 'packageAlsoNeeded'))
```


#### C. Install R package from an archive file without (CRAN/BioConductor) repository

If the (version of the) ```R``` package you need is not available from _CRAN_ nor from _BioConductor_ nor from another ```R``` _repository_,
but you do have the source code of the package in a compressed archive file, then you can try to install that using the ```R CMD INSTALL``` command.
Note that this is sub optimal; when the code you need is available from a curated repo like _CRAN_ or _BioConductor_, use those repos instead.
In this example, we use _abctools_ version _1.1.4_ (and it was downloaded from CRAN, but it could have been fetched from another repo/source).

Since we know the URL, the command `wget` can be used to download the ```*.tar.gz``` archive.
You can also use for example ```rsync``` to copy the compressed archive to {{ slurm_cluster_name | capitalize }}
if you have the file on your local machine.

```wget https://cran.r-project.org/src/contrib/abctools_1.1.4.tar.gz```

Next, we need to load R (but do not start R yet)

```bash
module load RPlus
```

Run the command below to install the package from the compressed archive file.

```bash
R CMD INSTALL path/to/your/uploaded/abctools_1.1.4.tar.gz
```

#### D. Install R package from a GitHub repository

Note that this is sub optimal; when the code you need is available from a curated repo like _CRAN_ or _BioConductor_, use those repos instead.
Code that was not published in a curated repo for R packages usually lacks basic testing and documentation.
This may be OK if you are co-developing or beta testing, but not for reproducible science.

Load and start R.

```bash
module load RPlus
R
```

You can use the ```remotes::install_github``` command from the ```remotes``` package to install other packages from a GitHub repository.
If not already present the ```remotes``` package must be installed from _CRAN_ first.
In the example below we will install the package _devtools_ located in the corresponding GitHub repo from developer/organisation _r-lib_.

When no version is specified, the ```remotes::install_github``` command will install the latest commit from whatever the main branch is.
*WARNING*: this may be unstable, unreleased, untested code. In order to install the latest *released* version use ```ref = github_release()```.
You can also specify a specific version number; see the [documentation for ```remotes::install_github```](https://remotes.r-lib.org/)

```R
R> install.packages('remotes')
R> library('remotes')
R> remotes::install_github('r-lib/devtools', ref = github_release())
```

