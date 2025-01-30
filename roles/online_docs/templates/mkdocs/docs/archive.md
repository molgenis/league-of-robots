#jinja2: trim_blocks:False

{% if archive_groups is defined and archive_groups | length >= 1 %}

# Using remote archive storage

1. Overview

1.1. What is the archive

It is the storage that is provided on the external host. Currently we only have one archive provider - [SURF](https://www.surf.nl/en/services/data-archive).

1.2. How it works
    
Archive is automatically mounted when user navigates into /groups/GROUP/arcXX folder. At that moment storage from remote server gets mounted on this folder. The folder remains mounted while being used and gets unmounted after some idle time to save the resources.

Each group can access only own archive folder and the files in it. Data-manager account is the **only** account on the archive subfolder that can **read** or **write** the archive data. This is to prevent the potential problems of accidentally making files online when not needed, and to make sure all the files are stored in correct format (see 'Best practices' below).

2. Copying data

    2.1. cp or rsync between tmp/prm to arcXX

3. Validating data

    surf_archive --sha256sum

4. Managing data

    4.1. 

5. Best practices

    5.1. File sizes are extremely important on the archive. Tape storage performance and management is better when the files are larger size. Reccomended sizes (for SURF) are in between 1 and 100 GB. The average size is monitored and the groups with average size lower than this will have locked accounts.

6. Performance

7. Issues

{% endif %}
