#jinja2: trim_blocks:True

# Table of Contents
1. [Nextflow introduction](#nextflow-introduction)
2. [How to use and install Nextflow](#how-to-use-and-install-nextflow)
3. [How to run Nextflow in an interactive session](#how-to-run-nextflow-in-an-interactive-session)
4. [How to wrap Nextflow submission to a single Slurm job](#how-to-wrap-nextflow-submission-to-a-single-slurm-job)
5. [How to Paralize your work using Slurm](#how-to-paralize-your-work-using-slurm)
6. [Debugging, tracing and visualisation](#debugging-tracing-and-visualisation)

## Nextflow introduction

[Nextflow](https://www.nextflow.io) is a powerful tool for developing scientific workflows for use on HPC systems. It provides a simple 
solution to deploy parallelized workloads at scale using an elegant reactive/functional programming model in 
a portable manner.
It supports integration with multiple workload manager including Slurm that we use on {{ slurm_cluster_name 
| capitalize }}.


### How to use and install Nextflow  

This documentation only shows how to run Nextflow on {{ slurm_cluster_name | capitalize }}, and how you can 
make use of Slurm scheduling for running you Nextflow pipeline. 
For details about Nextflow itself see the official Nextflow documentation at 
[_Nextflow.io_](https://www.nextflow.io/docs/latest/index.html) or this 
page for common [implementation patterns](https://nextflow-io.github.io/patterns/index.html)

To load a pre-installed version of Nextflow you can load the existing module as follows:

```
module load nextflow
```

or you can install a local copy of the latest version using:
```
module load Java

curl -s https://get.nextflow.io | bash
```

Load help to make sure it runs: 
```
nextflow --help
```

For the most basic proof of work demonstration you can run a demo run. To do this navigate to a location on 
tmp to create a demo run directory, and run the command:

```
nextflow run hello
``` 

resulting in the following output:

```
N E X T F L O W  ~  version 23.04.1
Pulling nextflow-io/hello ...
 downloaded from https://github.com/nextflow-io/hello.git
Launching `https://github.com/nextflow-io/hello` [cheesy_agnesi] DSL2 - revision: 1d71f857bb [master]
executor >  local (4)
[d3/0d1b54] process > sayHello (4) [100%] 4 of 4 ✔
Ciao world!

Bonjour world!

Hello world!

Hola world!

```
### Changing the default writing location for $NXF_HOME
Nextflows default home directory is located in `$HOME/.nextflow`. This can cause your home directory to be 
flooded.To prevent this from happening you can set the ```${NXF_HOME}``` environment variable to a location 
somewhere in ```/groups/${group}/tmp*/...``` To do this you can add the following command line that looks 
something like this: `export NXF_HOME='/groups/${group}/tmp*/yourusername/'` for example, 
and add this to your ```${HOME}/.bashrc``` file.  

### Running local within an interactive session or single slurm job

Now that we see that Nextflow runs, we will describe how to run you own Nextflow pipeline using the Slurm 
scheduler as the job/process executor.
Note that the initial nextflow run command you will start ```nextflow run ...``` will act as a monitoring 
job that manages the individual subprocesses of your pipeline steps. It takes care of parallelization and 
job monitoring for you. 
These individual subprocesses can either be run in multiple paralel threads on a single machine, or can be 
submitted to a scheduler. In our case Slurm can be selected as the 'executor' where the subprocessed are 
being executed for you via the Slurm scheduler. 
The initial pilot job of your run command will monitor the run status for you.

---
> **Note:**
  Running Nextflow, particularly when running longer and more complex pipelines, can be 
  memory intensive if not computing intensive. 
  Please do not run your pipeline on login node as this will influence performance of the login node and 
  therefore all HPC users. 
  Please run Nextflow either with an interactive job for testing, requesting minimal amount of resources, or 
  within a job script for larger scale analyses via the Slurm scheduler.
---
### How to run Nextflow in an interactive session

One method is to run the ```nextflow run ...``` command into a interactive session you have started and run 
your pipeline there as 'local', which is the default executor. 
It runs the pipeline processes in the interactive session where Nextflow is launched. The processes are 
parallelized by spawning multiple threads, taking advantage of the available number of core you requested 
for your interactive session. The local executor within a interactive session 
is useful to develop and test your pipeline.

for example:

```
###Start a interactive session
srun --cpus-per-task=2 --mem=1gb --nodes=1 --qos=interactive --time=01:00:00 --pty bash -i

#run your pipeline
nextflow run /path/to/my_pipeline.nf

```

## How to wrap Nextflow submission to a single Slurm job

A second method is to run the ```nextflow run ...``` command into a batch script and submitting it to Slurm 
with ```sbatch```. The manager process will run on the allocated compute node, and all tasks are configured to use 
the local executor; 
it's even possible to use srun in your processes. An advantage of this method is that your process can run 
over multiple days, and is only the initial submission waits in a Slurm queue. And not subprocesses that are 
submitted later on your pipeline workflow. A downside it that you can not use the compute cluster to it;s 
full capacity since you process is bound to one job on one machine.
Note that workflow cannot run longer than the maximum wall time available to a single job in the Slurm QOS 
being used.

for example, create a ```launch_script.sh``` containing:

```
#!/bin/bash
#SBATCH --job-name=jobName
#SBATCH --output=jobName.out
#SBATCH --error=jobName.err
#SBATCH --time=00:59:00
#SBATCH --cpus-per-task=2
#SBATCH --mem=4gb
#SBATCH --nodes=1
#SBATCH --open-mode=append
#SBATCH --export=NONE
#SBATCH --get-user-env

PIPELINE=$1
CONFIG=$2

module load nextflow

nextflow -C ${CONFIG} run ${PIPELINE}
```

Next you can submit your ```launch_scipts.sh``` to Slurm on the _User Interface_ with the ```sbatch``` command:

```
sbatch launch_scipts.sh /path/to/mypipeline.nf /path/to/myconfig_file.conf
```

## How to paralize your work using Slurm

Nextflow configuration file (```nextflow.config```) is used to instruct the manager process to submit its 
tasks to Slurm instead of running them on the local host. Place the following file in your Nextflow working 
directory:

'nextflow.config' containing:

```
process {
  executor='slurm'
  queueSize = 10
  maxRetries = 1
}
```

Now your work that is devides in processes will be spitup in max 10 slurm jobs that are automatically 
submitted an monitored for you.  By default, Nextflow will submit up to 100 jobs at a time for execution. 
There are multiple parameters you could predefine in the nextflow.config. Such as runtime or queue, you can 
find more about that on [_Nextflow excutors_](https://www.nextflow.io/docs/latest/executor.html). The ```nextflow run ...``` 
command can either be submitted as a Slurm job itself, or started from a `screen` for example.

In order to be able to easily switch a local or slurm executed run it is useful to define profiles in you 
'nextflow.config'. 
To make use of this slurm profile select the slurm profile in your run command:

nextflow.config:

```
profiles {
  local {
    process.executor = 'local'
    process.cpus = 1
    queueSize = 1
  }

  slurm {
    process {
      executor = 'slurm'
      queueSize = 10
      maxRetries = 2
      time = '...'
      }
}

```

Now you can select a Slurm or local profile which makes is easier to use during testing fase of your 
pipeline. 

nextflow command:
```
nextflow run \
-profile local \ <slurm | local>
main.nf (path you main nf pipeline)    
```

## Debugging & Logging

Nextflow has some great functionality buildin to monitor your pipeline run logs, trace the status of indivual pipeline tasks,
and visualize this information in a runtime HTML report. This can help you to monitor your pipeline perforance and can be useful for optimalization. 

### Logging 
The `nextflow log` command shows information about executed pipelines in the current folder:

```
$ nextflow log
TIMESTAMP            RUN NAME         SESSION ID                            COMMAND
2016-08-01 11:44:51  grave_poincare   18cbe2d3-d1b7-4030-8df4-ae6c42abaa9c  nextflow run hello
2016-08-01 11:44:55  small_goldstine  18cbe2d3-d1b7-4030-8df4-ae6c42abaa9c  nextflow run hello -resume
2016-08-01 11:45:09  goofy_kilby      0a1f1589-bd0e-4cfc-b688-34a03810735e  nextflow run rnatoy -with-docker
```

Specifying a run name or session id prints tasks executed by that pipeline run:

```
$ nextflow log goofy_kilby
/Users/../work/0b/be0d1c4b6fd6c778d509caa3565b64
/Users/../work/ec/3100e79e21c28a12ec2204304c1081
/Users/../work/94/dfdfb63d5816c9c65889ae34511b32
```
This can help you to  find the `jobscripts`, `.err` and `.out` files find back for each executed process. 
This helps you to find out what actually goes on in the backgroup during execution of your pipeline, and helps you during debugging.

### Execution Report
Nextflow can create an HTML execution report: a single document which includes many useful metrics about a workflow execution.
It contains general information about Run date, output loction and the version of Nextflow that was used. Also plots are shown 
for CPU, memory, job duration and disk I/O which can be useful for pipeline optimization.
To create this report add the `-with-report` command line option when launching the pipeline for execution. 

```
nextflow run <pipeline name> -with-report [file name]
```

### Timeline Graph
Nextflow can render an HTML timeline for all processes executed in your pipeline. It genarates a bar graph showing information about 
runtime of each pipeline step. To enable the creation of the timeline report add the `-with-timeline` option to your run command:

```
nextflow run <pipeline name> -with-timeline [file name]
```

For more details about Nextflow debugging and tracing  see the official Nextflow documentation at
[Nextflow.tracing](https://www.nextflow.io/docs/latest/tracing.html) 

