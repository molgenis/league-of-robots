#jinja2: trim_blocks:False
# Python virtual environment

## Caution

Making a new Python virtual environment creates a new subfolder, inside which all the binaries, scripts and libraries are copied. After that those are available to be called, which initializes the environemnt. **The initialization of the environment needs to be done before every use and (even more important) before the installation of packages**. Failing to do so, will result in failed commands and (in case of package installation) full home directory, which prevents normal usage of the cluster.

## Introduction

Using Python `venv` module creates lightweight `virtual environment`, with own independent set of Python packages installed in the specified directory. A virtual environment is created on top of an existing Python installation, known as the virtual environment's `base` Python. Packages are isolated from the packages in the base environment, so only those explicitly installed in the virtual environment are available.

[More information about Python virtual environment](https://docs.python.org/3/library/venv.html)

Python has several different options on how to install and manage Python packages - here is described the recommended way for our clusters.
The steps are

- [first creating the Python virtual environment](#Creating new Python virtual environment)
- [then initialization of the environment](#To use the existing environment)
- [installing custom package(s) inside this environment](#To install packages inside the Python environment)
- [deactivation of the virtual environment](#Deactivation of the virtual environment)
- [and how to submit a slurm job that uses virtual Python environment](#Using Python virtual environemnt inside slurm job)


## Creating new Python virtual environment

To create a new Python virtual environment on the user interface machine (which can be later also used on compute nodes) use

- Load latest version of Python
  `module load Python`
- Check the Python's version
  `python3 --version`
- Build a Python Virtual Environment
  `python3 -m venv /groups/umcg-GROUP/TMPXX/MY_PYTHON_SUBDIR`
  and replace the `GROUP`, `TMPXX` and `MY_PYTHON_SUBDIR` with appropriate values. Remember `tmpXX` folders are also available on compute nodes and therefore the compute jobs can access this Python environment.


## To use the existing environment

- Source the environments 
  `source /groups/umcg-GROUP/TMPXX/MY_PYTHON_SUBDIR/bin/activate`


## To install packages inside the Python environment

- (Recommended) Upgrade `pip` and `wheel` packages, so that that you can install all the latest package versions
  `pip install --upgrade pip wheel`
- Install package
  `pip install pypackage`
  where `mypackage` is one or more packages from the `https://pypi.org/`.


# Deactivation of the virtual environment

- to deactivate the virtual environment, simply run command `deactivate`


## Using Python virtual environment inside slurm job

Create a slurm script with appropriate fields. For more information check also the documentation page about [batch jobs](analysis/#1-batch-jobs).

```
    #!/bin/bash
    #SBATCH --job-name=pyvenv
    #SBATCH --output=pyvenv-%N-%u-%j.out
    #SBATCH --error=pyvenv-%N-%u-%j.err
    #SBATCH --time=00:15:00
    #SBATCH --cpus-per-task=1
    #SBATCH --mem-per-cpu=1gb
    #SBATCH --nodes=1
    #SBATCH --open-mode=truncate
    #SBATCH --export=NONE
    #SBATCH --get-user-env
    
    # clear all loaded modules
    module purge
    # to load the latest version of Python
    module load Python
    # initialize the Python virtual environment
    source /groups/umcg-GROUP/TMPXX/MY_PYTHON_SUBDIR/bin/activate
    # check the Python version (useful for debugging)
    python3 --version
    # print the location of Python3 executable binary (also useful for debugging)
    which python3
    
    # run the Python command or in this case some custom Python script
    python3 ./my_python_script.py
```

Then submit this slurm SLURM job

- `sbatch pyvenv.sh`
