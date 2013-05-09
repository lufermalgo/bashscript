#!/bin/sh
#  
#  whitelist
#  
#  Copyright (C) 2012 - Luis Fernando Maldonado Arango
#  Copyright (C) 2012 - Summan S.A.S.
#  
#  whitelist is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#  
#  whitelist is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with checkWand.  If not, see <http://www.gnu.org/licenses/>.
#
#   Usage: whitelist [options]
#
#  Options:
#    <arg>            DOMINIO ó MAIL
#    --help           This help message

EXPECTED_MIN_ARGS=1
EXPECTED_MAX_ARGS=1
E_BADARGS=65
E_NOROOT=1
BASE_NAME=`basename $0`

if [[ $# -gt $EXPECTED_MAX_ARGS ]] || 
   [[ $# -lt $EXPECTED_MIN_ARGS ]] || 
   [[ $1 == "--help" ]] ; then
  echo "Usage: $BASE_NAME <arg>" 1>&2
  echo "Usage: $BASE_NAME --help" 1>&2
  exit $E_BADARGS
fi

if [ "$(id -u)" != "0" ]; then
   echo "$BASE_NAME: This script must be run as root." 1>&2
   exit $E_NOROOT
fi

LOCK_FILE="/var/lock/whitelist"
ULIMIT_N=`ulimit -n`
let "FLOCK_FD = ULIMIT_N - 1"
START_DATE=`date`
ERROR_EXIT="1"

(
  eval "exec $FLOCK_FD<> $LOCK_FILE"
  if flock -n $FLOCK_FD ; then
# flock START

Slog="/var/log/maillog"
PostPath="/opt/zimbra/conf"
DBSpammers="postfix_rbl_ip_spammers.db"
FSpammers="postfix_rbl_ip_spammers"
FWhitelist="postfix_rbl_ip_whitelist"
IP=`grep $1 $Slog | grep -m 1 -E 'rejected: Access denied' | awk '{print $10}' | cut -d[ -f2 | cut -d] -f1`
    
# 1. buscar bloqueado - recibe parametro "arg" (email ó dominio).
# Ejemplo de log:
# Mar  8 06:22:32 mail postfix/smtpd[12196]: NOQUEUE: reject: 
# RCPT from unknown[201.230.203.167]: 554 5.7.1 <unknown[201.230.203.167]>: 
# Client host rejected: Access denied; from=<diplomadosprogramas8@yahoo.es> 
# to=<info@summan.com> proto=SMTP helo=<192.168.1.20>
function SearchArgument(){
    if [[ $IP != "" ]]; then
        echo $IP
        return 0
    else
        echo "Argumento no encontrado!"
    fi
    return 1
}

# 2. busca la ip correspondiente al domino encontrado en la base de datos
# de spammers. "/opt/zimbra/conf/postfix_rbl_ip_spammers", y la borra.
function DeleteIPFSpammers() {
    sed '/^'$IP'/d' $PostPath/$FSpammers > $PostPath/fspam.tmp
    cat $PostPath/fspam.tmp > $PostPath/$FSpammers
    rm -f $PostPath/fspam.tmp
}

# 3. agrega la ip en la base de datos postfix_rbl_whitelist.
function AddIPWhitelist() {
    echo $IP >> $PostPath/$FWhitelist
}

# 4. regenera la base de datos de spammers
# "postmap /opt/zimbra/conf/postfix_rbl_ip_spammers".
function ReloadDBSpammers() {
    su - zimbra -c "rm -f $PostPath/$DBSpammers"
    su - zimbra -c "postmap $PostPath/$FSpammers"
}

# 5. recargar la base de datos "zmmtactl restart"
function RestartMta() {
    su - zimbra -c "zmmtactl restart"
}

function DeleteLock() {
    rm -f $LOCK_FILE
}


if SearchArgument ; then
   echo "Procesando dominio $1 con la IP: $IP"
   DeleteIPFSpammers
   AddIPWhitelist
   ReloadDBSpammers
   RestartMta
   DeleteLock
else 
   echo "Argumento $1 no encontrado!"    
fi

# flock END
  else
    echo "$BASE_NAME: Another instance is currently running."
  fi
)

