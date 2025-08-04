#jinja2: trim_blocks:False

@echo off
setlocal

set /p USERNAME=- provide username (like umcg-xxxx): 
set "CLUSTER={{ slurm_cluster_name }}"
set "SSH_DIR=%USERPROFILE%\.ssh"
set "OPENSSH=C:\Windows\System32\OpenSSH\"
set "CERT_AUTH=@cert-authority {{ known_hosts_hostnames }} {{ lookup('file', ssh_host_signer_ca_private_key + '.pub') }} for {{ slurm_cluster_name }}"

if not exist "%SSH_DIR%" (
   echo.- making %SSH_DIR%
   mkdir "%SSH_DIR%"
)

echo.- private key location (like C:\Users\%USERNAME%\OneDrive - UMCG\Desktop, note
echo.  that you can right click on a file, select 'Copy as path' and paste it here)
echo.  If you don't have one yet, leave it empty and one will be created in the
echo.  default location (C:\Users\%USERNAME%\.ssh)
set /p PRIVATEKEY=  private key path: 
if not exist %PRIVATEKEY% (
   if not exist "%PRIVATEKEY%" (
      echo.- error, incorrect path, no private key is found at %PRIVATEKEY%
      echo.  you can exit and restart this script (press CTRL+C), or press enter to
      echo.  continue creating a public/private keypair in the default location
      if not exist "%SSH_DIR%\id_ed25519" (
         echo.- public/private keypair are missing, creating them now ...
         %OPENSSH%/ssh-keygen.exe -f "%SSH_DIR%\id_ed25519"
      )
      set "PRIVATEKEY=%SSH_DIR%\id_ed25519"
   ) else (
      echo.  private key file found
   )
)

if not exist "%SSH_DIR%\tmp" (
   echo.- making %SSH_DIR%\tmp
   mkdir "%SSH_DIR%\tmp"
)
if not exist "%SSH_DIR%\conf.d" (
   echo.- making %SSH_DIR%\conf.d
   mkdir "%SSH_DIR%\conf.d"
)

if exist "%SSH_DIR%\config" (
   echo.- %SSH_DIR%\config exists - make sure that contains line
   echo.  Include conf.d\*
) else (
   echo.- making %SSH_DIR%\config
   echo Include conf.d/* > "%SSH_DIR%\config"
)

echo %CERT_AUTH% >> "%SSH_DIR%\known_hosts"
echo.- cert. authority appended to %SSH_DIR%\known_hosts

echo. - configuring %SSH_DIR%\conf.d\%CLUSTER%
(
{% for jumphost in groups['jumphost'] %}
  {%- set network_id = ip_addresses[jumphost]
           | dict2items
           | json_query('[?value.fqdn].key')
           | first -%}
  {%- if ip_addresses[jumphost][network_id]['fqdn'] == 'NXDOMAIN' -%}
    {%- set ssh_hostname = ip_addresses[jumphost][network_id]['address'] -%}
  {%- else -%}
    {%- set ssh_hostname = ip_addresses[jumphost][network_id]['fqdn'] -%}
  {%- endif -%}
echo.Host {% for jumphost in groups['jumphost'] %}{{ jumphost }}* {% endfor %}{% raw %}{% endraw %}
echo.   HostName {{ ssh_hostname }}
echo.   User %USERNAME%
echo.   ServerAliveInterval 60
echo.   ServerAliveCountMax 5
echo.   IdentityFile "%PRIVATEKEY%"
echo.   PasswordAuthentication No
echo.   ControlMaster auto
echo.   # ControlPath "%SSH_DIR%\tmp" # not yet supported on Windows
echo.   ControlPersist 10m
{% for userinterface in groups['user_interface'] %}
echo.
echo.Host {{ jumphost }}+{{ userinterface }} {{ userinterface }}
echo.   ProxyJump {{ jumphost }}
echo.   HostKeyAlias {{ jumphost }}
{% endfor -%}
{% endfor -%}
) > "%SSH_DIR%\conf.d\%CLUSTER%"

endlocal

echo.
echo.
echo. All done! ( Press enter to exit ... )
pause >nul
