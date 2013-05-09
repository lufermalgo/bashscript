#!/bin/sh
#  
#  jboss_new_instance
#  
#  Copyright (C) 2013 - Luis Fernando Maldonado Arango
#  Copyright (C) 2013 - Summan S.A.S.
#  
#  jboss_new_instance is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#  
#  jboss_new_instance is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with checkWand.  If not, see <http://www.gnu.org/licenses/>.
#

# Source function library.
. /etc/init.d/functions

WHITE=$(tput bold ; tput setaf 7)
RED=$(tput bold ; tput setaf 1)
GREEN=$(tput bold ; tput setaf 2)
NORMAL=$(tput sgr0)

echoWhite() {
   echo -en "$WHITE$1$NORMAL"
}

echoRed() {
   echo -e "$RED$1$NORMAL"
}

BASE_NAME=`basename $0`
E_NOROOT=1

if [ "$(id -u)" != "0" ]; then
   echoRed "$BASE_NAME: This script must be run as root." 1>&2
   exit $E_NOROOT
fi

JBOSS_PATH=/etc/jbossas
JBOSS_CONF=/etc/sysconfig/jbossas
JBOSS_LOG=/var/log/jbossas
JBOSS_LIB=/var/lib/jbossas
JBOSS_HOME=/usr/share/jbossas
JBOSS_BIN=$JBOSS_HOME/bin
JBOSS_SCRIPT=/etc/init.d



askNonBlank() {
  while [ 1 ]; do
    echoWhite "name of the new instance? [] " 
    read response
        if [ ! -z $response ]; then
          break
        fi
        echoRed "A non-blank answer is required"
  done
}

# copy standalone to new-intance
copyInstance() {
   cp -a $JBOSS_PATH/standalone $JBOSS_PATH/$response 2>&1
}

# modify config file jbossas (/etc/sysconfig/jbossas)
modifyConfig() {
    sed -i 's/# JBOSSCONF=.*/JBOSSCONF="'$response'"/g ; s/JBOSSCONF=.*/JBOSSCONF="'$response'"/g' $JBOSS_CONF 2>&1
}

# copy dir log jboss
copyDir() {
    cp -a $JBOSS_LOG/standalone $JBOSS_LOG/$response 2>&1
}

# copy lib jboss
copyLib() {
    cp -a $JBOSS_LIB/standalone $JBOSS_LIB/$response 2>&1
}

# create simbolic-link $response
createSlink() {
CSL=0

    if [ $CSL -eq 0 ]; then
    ln -s $JBOSS_LIB/$response $JBOSS_HOME/$response 2>&1
        if [ $? -ne 0 ]; then
        CSL=1
        fi
    fi
    if [ $CSL -eq 0 ]; then
    rm -f $JBOSS_HOME/$response/configuration 2>&1
        if [ $? -ne 0 ]; then
        CSL=1
        fi
    fi   
    if [ $CSL -eq 0 ]; then
    ln -s $JBOSS_PATH/$response $JBOSS_HOME/$response/configuration 2>&1
        if [ $? -ne 0 ]; then
        CSL=1
        fi
    fi
    if [ $CSL -eq 0 ]; then
    rm -f $JBOSS_HOME/$response/log 2>&1
        if [ $? -ne 0 ]; then
        CSL=1
        fi
    fi
    if [ $CSL -eq 0 ]; then
    ln -s $JBOSS_LOG/$response $JBOSS_HOME/$response/log 2>&1
        if [ $? -ne 0 ]; then
        CSL=1
        fi
    fi
    if [ $CSL -eq 0 ]; then
    chown -R jboss.jboss $JBOSS_HOME/$response/ 2>&1
        if [ $? -ne 0 ]; then
        CSL=1
        fi
    fi
}

# copy script start jboss and config file
copyScript() {
    cp -a $JBOSS_BIN/standalone.sh $JBOSS_BIN/$response.sh 2>&1
    if [ $? -eq 0 ]; then
        cp -a $JBOSS_BIN/standalone.conf $JBOSS_BIN/$response.conf 2>&1
    fi     
}

# change value script start jboss
changeScriptStart() {
    sed -i 's/standalone.conf/'$response'.conf/g' $JBOSS_BIN/$response.sh 2>&1
    if [ $? -eq 0 ]; then
        sed -i 's/JBOSS_HOME\/standalone/JBOSS_HOME\/'$response'/g' $JBOSS_BIN/$response.sh 2>&1
    fi
}

# copy script create management user 
copySSJboss() {
    cp -a $JBOSS_BIN/add-user.sh $JBOSS_BIN/add-user-$response.sh 2>&1
}
# change value script start jboss
changeValueScript() {
    sed -i 's/#JAVA_OPTS="\$JAVA_OPTS -Djboss\.server\.config\.user\.dir=\.\.\/standalone\/configuration -Djboss\.domain\.config\.user\.dir=\.\.\/domain\/configuration"/JAVA_OPTS="\$JAVA_OPTS -Djboss\.server\.config\.user\.dir=\/usr\/share\/jbossas\/'$response'\/configuration"/g' $JBOSS_BIN/add-user-$response.sh 2>&1
}
# create management user jboss
createMUJboss() {
    $JBOSS_BIN/add-user-$response.sh 2>&1
}

rc=$?
askNonBlank
if [ -n $response ]; then
    service jbossas stop
    action $"Copy standalone to new-intance: " copyInstance
    if [ $? -ne 0 ]; then
        exit $rc       
    fi
    action $"Modify config file jbossas: " modifyConfig
    if [ $? -ne 0 ]; then
        exit $rc
    fi
    action $"Copy dir log jboss: " copyDir
    if [ $? -ne 0 ]; then
        exit $rc
    fi
    action $"Copy lib jboss: " copyLib
    if [ $? -ne 0 ]; then
        exit $rc
    fi
    action $"Create simbolic-link: " createSlink
    if [ $? -ne 0 ]; then
        exit $rc
    fi
    action $"Copy script start jboss and config file: " copyScript
    if [ $? -ne 0 ]; then
        exit $rc
    fi
    action $"Change value script start jboss: " changeScriptStart
    if [ $? -ne 0 ]; then
        exit $rc
    fi
    action $"Copy script create management user: " copySSJboss
    if [ $? -ne 0 ]; then
        exit $rc
    fi
    action $"Change value script start jboss: " changeValueScript
    if [ $? -ne 0 ]; then
        exit $rc
    fi
    action $"Management user jboss: " createMUJboss
    service jbossas restart
fi
