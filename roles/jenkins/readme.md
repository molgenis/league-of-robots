# Jenkins

This role installs a Jenkins webserver, which is used to run automated tests for our pipelines.

### Installing plugins manually when the webpage is unavailable

Find the current version of the plugin in plugins folder: 
```
cat /var/lib/jenkins/plugins/${plugin_id}/META-INF/maven/io.jenkins.plugins/${plugin_id}/pom.properties
```

Look at the available plugins and releases on https://plugins.jenkins.io/.
Go to the release of a specific version and copy the downloadlink.

Before installing a new version, create a backup of the current version:
```
cd /var/lib/jenkins/plugins
mv ${plugin_id}.jpi ${plugin_id}.jpi.bak
```

Install the plugin using wget and set correct owner and permissions:
```
wget https://updates.jenkins.io/download/plugins/${plugin_id}/${plugin_version}/${plugin_id}.hpi
cd ..
chown -R jenkins:jenkins plugins
chmod -R 750 plugins
```

NOTE: The plugins folder is created after a Jenkins restart and the downloaded .hpi file will be renamed to .jpi after that.

Restart Jenkins to apply the changes: 
```
systemctl restart jenkins
```
