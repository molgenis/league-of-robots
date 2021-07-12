#jinja2: trim_blocks:False
{% if 'hyperchicken' in slurm_cluster_name or 'fender' in slurm_cluster_name %}
# How to find and work with Solve-RD data on {{ slurm_cluster_name | capitalize }}

#### First: getting an account and starting a session on a User Interface (UI) server

In order to work with Slurm and manage jobs on the cluster you'll need a personal account and start a session on a User Interface (UI) server.
If you are completely new here, please:

 * [follow these instructions to request an account](../accounts/).
 * [follow these instructions to login using your account](../logins/).

## 1. Using the EGA FUSE client.

Solve-RD samples are read-only available on {{ slurm_cluster_name | capitalize }} via the
[EGA FUSE client](https://github.com/EGA-archive/ega-fuse-client).
This client uses the **F**ile system in **USE**rspace (FUSE) framework 
to make the Solve-RD data available as if it was located on just another disk.
Hence the client will handle both transfer and on the fly decryption of the data.
The data is located at the following mount point (path):
```
{% for mountpoint in ega_fuse_client_mounts | dict2items | map(attribute='value') | select('search', 'solve-rd') | list %}{{ mountpoint }}{% if not loop.last %}
{% endif %}{% endfor %}
```
From there samples can be staged to ```/groups/${group}/tmp*/...``` for analysis.

Staging means copying a batch of data from the original location on ```prm``` storage to ```tmp``` storage,
which is required as the ```prm``` storage is only available on the _User Interface (UI)_
whereas ```tmp``` is also mounted on the compute nodes. See
[Keep - What is stored where on {{ slurm_cluster_name | capitalize }}](../storage/)
for details on the differences between various storage systems.
The total Solve-RD data set is huge: Don't try to stage all data simultaneously on a ```tmp``` file system:

 * It won't fit on the storage system and
 * Is useless anyway as there is not a single cluster node that can possibly analyse all samples in a single job

Select a reasonable batch size instead, stage and process those samples, use rigorous QC and when the rsults are Ok, 
make a release / data freeze for the results, which can then be moved to a ```prm``` file system for longer term storage 
followed by cleanup from ```tmp``` to free up space for a next batch.

Unfortunately the _EGA FUSE client_ is not so fast,
so you may prefer to use the _EGA FUSE client_ client only to lookup which data is available from which paths
and then do the staging of large files using the _EGA Python API_ with _pyEGA3_ (see below).

## 2. Using the EGA Python API with pyEGA3.

To be able to use pyEGA3 you need a username and password provided by the [EGA](https://ega-archive.org).
These EGA credentials are not the same as your account for the {{ slurm_cluster_name | capitalize }} cluster 
and must be requested separately.

Add your credentials into a ```credentials.json ``` file, which is then used during data transfer.
An [example of the syntax for this credentials.json file](https://github.com/EGA-archive/ega-download-client/blob/master/pyega3/config/default_credential_file.json)
is located in the _PyEGA3_ repository at GitHub.
For more on PyEGA3 see the example code snippets below and
[the README.md in the root of the repo](https://github.com/EGA-archive/ega-download-client).

#### Example for downloading all files corresponding to specific sample from an EGA data set accession number.

```
echo 'Loading module pyEGA3 ...'
module load pyEGA3

output_dir='/groups/solve-rd/tmp10/username/yourdir'
ega_data_set_accession='EGAD00001005352'
sample_id='E577011'

mkdir -p -v "${outputdir}"

echo "Looking up all sampleIDs for data set ${ega_data_set_accession} and storing them into a ${ega_data_set_accession}.tmp file ..."
pyega3 -cf credentials.json files "${ega_data_set_accession}" > "${ega_data_set_accession}.tmp"
 
echo "Lookup all EGA file accession numbers corresponding to sample ID ${sample_id} ..."
grep "${sample_id}" "${ega_data_set_accession}.tmp" | awk '{print $1}' >> "${sample_id}.tmp"
 
echo "Staging all files for sample ${sample} to "${output_dir}" ..."
for ega_file_accession in $(cat "${sample_id}.tmp")
do
    pyega3 -cf credentials.json -c 10 fetch "${ega_file_accession}" --saveto "${output_dir}"
done
```

Or see more extended examples here: ```/groups/solve-rd/prm*/example_scripts```
{% endif %}