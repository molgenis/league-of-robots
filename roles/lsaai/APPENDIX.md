# Appendix

## Editing existing user

First print user's info

Create file

     [root@ladap ~]# cat add-user-externalVO.ldif 
     dn: cn=scimerman,ou=perun,ou=users,dc=donbot_azure,dc=local
     changetype: modify
     replace: givenName
     givenName: scimerman.umcg
     -
     add: objectClass
     objectClass: lsaaiPerson
     -
     replace: voPersonExternalAffiliation
     voPersonExternalAffiliation: yetAnotherValue@rug

Apply change

    [root@ladap ~]# ldapmodify -Y EXTERNAL -H 'ldapi://%2Fvar%2Frun%2Fslapd%2Fldapi' -f /root/add-user-externalVO.ldif

Check output

    [root@ladap ~]# ldapsearch -Y EXTERNAL -H "ldapi://%2Fvar%2Frun%2Fslapd%2Fldapi" -b "cn=scimerman,ou=perun,ou=users,dc=donbot_azure,dc=local"

# extended LDIF


## New user

Create file

    [root@ladap ~]# cat newuser_with_affiliation.ldif
    dn: uid=dschrute,cn=members,ou=perun,ou=groups,dc=donbot_azure,dc=local
    objectClass: inetOrgPerson
    objectClass: voPerson
    objectClass: lsaaiPerson
    cn: Dwight Schrute
    sn: Schrute
    uid: dschrute
    mail: dschrute@cern.ch
    userPassword: {SSHA}A123B123C123D123
    voPersonExternalAffiliation: director@cern.ch
    voPersonExternalAffiliation: student@umcg.nl

Add users

     ldapmodify -Y EXTERNAL -H 'ldapi://%2Fvar%2Frun%2Fslapd%2Fldapi' -f /root/newuser_with_affiliation.ldif

Check output


    [root@ladap ~]# ldapsearch -Y EXTERNAL -H "ldapi://%2Fvar%2Frun%2Fslapd%2Fldapi" -b "uid=dschrute,cn=members,ou=perun,ou=groups,dc=donbot_azure,dc=local"


