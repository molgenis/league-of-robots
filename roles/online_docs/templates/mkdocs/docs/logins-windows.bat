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

echo.- private key location [ like C:\Users\%USERNAME%\OneDrive - UMCG\Desktop ], note
echo.  that you can right click on file, select 'Copy as path' and paste it here.
echo.  If you don't have private key yet, simply press enter and script will create it
echo.  in the default location [ C:\Users\%USERNAME%\.ssh ]
set /p PRIVATEKEYRAW=  private key path: 
REM Remove all " from path
set PRIVATEKEY=%PRIVATEKEYRAW:"=%

if not exist "%PRIVATEKEY%" (
      echo.- error, incorrect path, no private key is found at "%PRIVATEKEY%" make sure
      echo.  you provided correct path [ and without quotes ]. Now you can either exit
      echo.  this script [press CTRL-C] and restart it again, or you can press enter to
      echo.  continue with creating a public/private keypair in the default location
      set /p CONTINUE= press [ CTRL-c ] to cancel or [ enter ] to continue
      if not exist "%SSH_DIR%\id_ed25519" (
         echo.- public/private keypair are missing, creating them now ...
         %OPENSSH%/ssh-keygen.exe -f "%SSH_DIR%\id_ed25519"
      )
      set "PRIVATEKEY=%SSH_DIR%\id_ed25519"
) else (
   echo.  private key file found
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
echo.Host {% for jumphost in groups['jumphost'] %}{{ jumphost }} {% endfor %}
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
echo.   HostName {{ userinterface }}
echo.   HostKeyAlias {{ userinterface }}
echo.   ServerAliveInterval 60
echo.   ServerAliveCountMax 5
echo.   IdentityFile "%PRIVATEKEY%"
echo.   User %USERNAME%
{% endfor -%}
{% endfor -%}
) > "%SSH_DIR%\conf.d\%CLUSTER%"

endlocal

echo.
echo.
echo. All done! ( Press enter to exit ... )
pause >nul
