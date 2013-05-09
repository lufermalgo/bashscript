#!/bin/bash
export LANG=C # Adds execution speed

#******************************************************************************************************
#* Author             : Riaan Pretorius riaan@satsoft.co.za
#* Date Written       : 2011 Mar 21
#* Application Name   : Zimbra/Postfix Connect From Filter ZPCFF
#* Current Version    : 0.02
#* Description        : This script will anyalize and extract all the connect from / unknown ip's
#*                      It will then do a host x.x.x.x and see if the ip resolves to a domain, if
#*                      the ip is not resolving it is considered a spam domain and printed to screen
#*
#* Modificación en Zimbra
#*
#* Para que esta base de datos se ponga en producción debemos agregar la siguiente configuración en
#* Zimbra:
#*
#* zmlocalconfig -e postfix_smtpd_client_restrictions="reject_unauth_pipelining, check_client_access hash:/opt/zimbra/conf/postfix_rbl_ip_spammers"
#*
#* Finalizamos reiniciando el servicio de zimbra
#*
#******************************************************************************************************

LOG="/var/log/maillog"
TMP_SPAMMERS="/opt/zimbra/conf/postfix_rbl_ip_spammers.tmp"
TMP_LOG1="/opt/zimbra/conf/postfix_rbl_ip_spammers.log1"
TMP_LOG2="/opt/zimbra/conf/postfix_rbl_ip_spammers.log2"
SPAMMERS="/opt/zimbra/conf/postfix_rbl_ip_spammers"
WHITELIST="/opt/zimbra/conf/postfix_rbl_ip_whitelist"

awk '/ connect from/ {print $8}' $LOG | \
grep unknown | \
awk '{print $1}' | \
cut -d[ -f2 | cut -d] -f1 | \
while read ip ; do
    host $ip > /dev/null 2>&1;\
    if [ $? -ne 0 ] ; echo "$ip         REJECT" >> $TMP_SPAMMERS; then
        echo "$ip"; 
    fi; 
done
cat $TMP_SPAMMERS | sort | uniq | grep -v -f $WHITELIST > $TMP_LOG1
cat $TMP_LOG1 $SPAMMERS > $TMP_LOG2
cat $TMP_LOG2 | sort | uniq | grep -v -f $WHITELIST > $SPAMMERS
rm -f $TMP_LOG1 $TMP_LOG2 $TMP_SPAMMERS 
su - -c "postmap $SPAMMERS" zimbra
su - -c "zmmtactl restart" zimbra

