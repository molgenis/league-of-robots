#
# Centos7 Slurm Server
#

FROM centos:7

MAINTAINER Egon Rijpkema <e.m.a.rijpkema@rug.nl>

# Openldap client, installing from spacewalk leads to conflicts.
RUN yum install -y openldap-clients nss-pam-ldapd openssh-ldap

# add openldap config
ADD ldap.conf /etc/openldap/ldap.conf
ADD nslcd.conf /etc/nslcd.conf
ADD pam_ldap.conf /etc/pam_ldap.conf
ADD nsswitch.conf /etc/nsswitch.conf

RUN chmod 600 /etc/nslcd.conf

# Add spacewalk client
RUN rpm -Uvh http://yum.spacewalkproject.org/2.4-client/RHEL/7/x86_64/spacewalk-client-repo-2.4-3.el7.noarch.rpm

RUN yum install rhn-client-tools rhn-check rhn-setup rhnsd m2crypto yum-rhn-plugin -y

RUN rhnreg_ks --force --serverUrl=http://spacewalk.hpc.rug.nl/XMLRPC --activationkey=1-ce5e67697e0e3e699dd236564faa2fc4

# empty /etc/yum.repos.d/ for spacewalk
RUN sed -i 's/enabled=1/enabled=0/g' /etc/yum.repos.d/*
RUN sed -i '/name=/a enabled=0' /etc/yum.repos.d/*

# Disable gpgcheck
RUN sed -i 's/gpgcheck = 1/gpgcheck = 0/g' /etc/yum/pluginconf.d/rhnplugin.conf

RUN adduser -u 497 slurm
# Slurm and dependencies
RUN yum install -y slurm           \
                   slurm-plugins   \
                   slurm-lua       \
                   slurm-slurmdbd  \
                   slurm-sjobexit  \
                   slurm-munge     \
                   slurm-sql       \
                   slurm-perlapi   \
                   slurm-sjstat

# Slurm needs /sbin/mail to work in order to send mail
RUN yum install -y mailx ssmtp

# Add ssmtp config
ADD ssmtp.conf /etc/ssmtp/ssmtp.conf

RUN mkdir /var/log/slurm
RUN chown slurm: /var/log/slurm

RUN mkdir /var/spool/slurm
RUN chown slurm: /var/spool/slurm

ADD slurm.conf /etc/slurm/slurm.conf
ADD slurmdbd.conf /etc/slurm/slurmdbd.conf
ADD job_submit.lua /etc/slurm/job_submit.lua

ADD runslurmctld.sh /runslurmctld.sh
RUN chmod +x /runslurmctld.sh

# our users find UTC confusing
RUN rm /etc/localtime
RUN ln -s /usr/share/zoneinfo/Europe/Amsterdam /etc/localtime
