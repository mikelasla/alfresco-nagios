## Dockerfile
## 
##  for Icinga / Nagios Alfresco Demo
##
##   by Cesar Capillas
##
##  to run this Dockerfile:
##
##   git clone https://github.com/zylklab/alfresco-nagios
##   cd alfresco-nagios
##   sudo docker build . -t zylklab/icingalf
##   sudo docker run -i -t zylklab/icingalf
##

FROM ubuntu 
MAINTAINER zylk.net

RUN apt-get update

ENV ICINGA_CONFIG /etc/icinga/objects
ENV ICINGA_PLUGIN /usr/lib/nagios/plugins
ENV ALF_USER admin
ENV ALF_PASS s3cret
ENV ALF_HOST planetexpress.zylk.net
ENV ALF_PORT 8080 
ENV ALF_ADDR 127.0.0.1
ENV JMX_USER manager
ENV JMX_PASS s3cret

# Automate postfix basic installation
# Dummy postfix
RUN echo "postfix postfix/mailname string localhost" | debconf-set-selections
RUN echo "postfix postfix/main_mailer_type string 'Internet Site'" | debconf-set-selections
RUN apt-get install -y postfix 

# Automate icinga basic installation
# Setting admin as password for user icingaadmin
RUN echo "icinga-common icinga/check_external_commands select true" | debconf-set-selections
RUN echo "icinga-cgi icinga/adminpassword string admin" | debconf-set-selections
RUN echo "icinga-cgi icinga/adminpassword-repeat string admin" | debconf-set-selections
RUN apt-get install -y icinga

# Install some utils
RUN apt-get install -y vim tree mc zip unzip dstat nmap htop curl wget jshon 

# Icinga config
RUN sed -i "s/check_external_commands=0/check_external_commands=1/" /etc/icinga/icinga.cfg 

# Alfresco Icinga/Nagios configuration 
ADD objects/host.cfg $ICINGA_CONFIG/host-alfresco.cfg
RUN sed -i "s/alf5.melmac.net/$ALF_HOST/" $ICINGA_CONFIG/host-alfresco.cfg 

ADD objects/services_ootb.cfg $ICINGA_CONFIG/services_ootb.cfg
RUN sed -i "s/alf5.melmac.net!443/$ALF_HOST!$ALF_PORT/" $ICINGA_CONFIG/services_ootb.cfg 
RUN sed -i "s/monitor!secret/$ALF_USER!$ALF_PASS/" $ICINGA_CONFIG/services_ootb.cfg 
RUN sed -i "s/monitor2!secret2/$JMX_USER!$JMX_PASS/" $ICINGA_CONFIG/services_ootb.cfg 

ADD objects/ootb-commands.cfg $ICINGA_CONFIG/ootb-commands.cfg

ADD scripts/check_manager_jmxproxy.sh $ICINGA_PLUGIN 
ADD scripts/check_ootb_active_sessions.sh $ICINGA_PLUGIN
ADD scripts/check_ootb_performance_stats.sh $ICINGA_PLUGIN
ADD scripts/check_ootb_solr.sh $ICINGA_PLUGIN
RUN chmod +x $ICINGA_PLUGIN/check_ootb* $ICINGA_PLUGIN/check_manager_jmxproxy.sh

# Icinga fixes for external commands
RUN dpkg-statoverride --update --add nagios www-data 2710 /var/lib/icinga/rw/
RUN dpkg-statoverride --update --add nagios nagios 751 /var/lib/icinga/

WORKDIR $ICINGA_PLUGIN 

ENTRYPOINT service apache2 restart && service icinga restart && echo "$ALF_ADDR $ALF_HOST" >> /etc/hosts && bash
