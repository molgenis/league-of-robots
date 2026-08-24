# sudoers role

This role can be used to manage (create and delete) files in ```/etc/sudoers.d/``` to extend the sudoers config.

The ```sudo``` permissions can be listed in a ```sudoers``` variable in ```group_vars/{{stack_name}}/vars.yml``` like this:

```yaml
sudoers:
  - who: ['%some-group']
    become: ['ALL']
    name: 'apptainer'
    command: '/bin/apptainer'
  - who: ['%some-group']
    become: ['some-group-dm']
```

* The ```who``` and ```become``` attributes are _required_.
* ```name``` is used as part of the filename for the file in in ```/etc/sudoers.d/```. This attribute is _optional_ and will default to the value of the ```become``` attribute when not specified.
* ```command``` is _optional_ and will default to ```ALL``` when not specified.
