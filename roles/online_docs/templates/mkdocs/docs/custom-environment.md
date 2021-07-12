#jinja2: trim_blocks:False
# Customize your environment

Once logged in you can customize your environment by editing your ```${HOME}/.bashrc``` file on the cluster.
The first few lines that are already present should not be changed unless you want to break your environment,
so please append your custom stuff at the bottom of this file. In case you did corrupt your ```${HOME}/.bashrc```, 
you can get a fresh copy from the template located in ```/etc/skel/.bashrc```.

## Time Zone

The cluster runs in the Coordinated Universal Time (or UTC) time zone, which is not adjusted for daylight saving time. 
The latter could confuse software when switching from winter to summer time or back resulting in newer files having older time stamps.
If you prefer to see time stamps in your local time zone, you can set your preferred time zone by configuring the TZ environment variable. 
E.g. for the Netherlands:
```
export TZ=Europe/Amsterdam
```
If you add this command to your ```${HOME}/.bashrc``` file you can make it the default when you login.
See the [list of time zones on WikiPedia](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones) for other countries.

