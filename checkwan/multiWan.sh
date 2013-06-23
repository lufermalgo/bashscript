#!/bin/sh
#  
#  checkWand.sh
#  
#  Copyright (C) 2012 - Luis Fernando Maldonado Arango
#  Copyright (C) 2012 - Summan S.A.S.
#  
#  checkWand is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#  
#  checkWand is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with checkWand.  If not, see <http://www.gnu.org/licenses/>.
#

(
. /etc/checkWand/checkWand.conf

SLEEPTIME=2
TIMEOUT=1
PATH_NETWORKS="/etc/sysconfig/network-scripts"            
MAX_ERROR_COUNT=`echo "$TARGETHOSTS" | wc -w`

# redirect tty fds to /dev/null
function redirectStd() {
    [[ -t 0 ]] && exec </dev/null
    [[ -t 1 ]] && exec >/dev/null
    [[ -t 2 ]] && exec 2>/dev/null
}
 
# close all non-std* fds
function closeFds() {
    eval exec {3..255}\>\&-
}

function CheckConnection1() {
    ERROR_COUNT=0

    for target in $TARGETHOSTS ; do
        if dig +time=1 +tries=1 +short -b $CURRENT_IP $target > /dev/null 2>&1 ; then
            echo "$DATE Source: $CURRENT_IP Target: $target ---> The channel is UP"
            break
        else
            ERROR_COUNT=$(( $ERROR_COUNT + 1 ))
            echo "$DATE Source: $CURRENT_IP Target: $target ---> The channel is DOWN"	
	fi
    done
 
    if [[ $ERROR_COUNT == $MAX_ERROR_COUNT ]] ; then
	echo "ERROR_COUNT=$ERROR_COUNT"
        return 1
    fi
    
    return 0
}

function CheckConnection2() {
    ERROR_COUNT=0

    for target in $TARGETHOSTS ; do
        if dig +time=1 +tries=1 +short -b $WAN1_IP $target > /dev/null 2>&1 ; then
	echo "$DATE Source: $WAN1_IP Target: $target ---> The main channel is UP"
        break
        else
            ERROR_COUNT=$(( $ERROR_COUNT + 1 ))
            echo "$DATE Source: $WAN1_IP Target: $target ---> The main channel is DOWN"	
	fi
    done
 
    if [[ $ERROR_COUNT == $MAX_ERROR_COUNT ]] ; then
        return 1
    fi
    
    return 0
}

function SwitchNetworkSettings1() {
    if [[ $CURRENT_IP == $WAN1_IP ]]; then
       HWADDR=`ip addr show $INTERFACE |
               grep ether |
               awk '{print $2}'`
       echo "DEVICE="$INTERFACE"
HWADDR="$HWADDR"
ONBOOT="yes"
IPADDR="$WAN2_IP"
NETMASK="$WAN2_MASK"
GATEWAY="$WAN2_GW"" > "$PATH_NETWORKS/ifcfg-$INTERFACE"
    else
        echo "DEVICE="$INTERFACE"
HWADDR="$HWADDR"
ONBOOT="yes"
IPADDR="$WAN1_IP"
NETMASK="$WAN1_MASK"
GATEWAY="$WAN1_GW"" > "$PATH_NETWORKS/ifcfg-$INTERFACE"
    fi
}

function SwitchNetworkSettings2() {
        HWADDR=`ip addr show $INTERFACE |
                grep ether |
                awk '{print $2}'`
        echo "DEVICE="$INTERFACE"
HWADDR="$HWADDR"
ONBOOT="yes"
IPADDR="$WAN1_IP"
NETMASK="$WAN1_MASK"
GATEWAY="$WAN1_GW"" > "$PATH_NETWORKS/ifcfg-$INTERFACE"
}

function RestartNetwork() {
    ifdown $INTERFACE
    ifup $INTERFACE
}

function SendNotification1() {
	echo "$EMAILMESSAGE1" | mailx -s "$SUBJECT" "$EMAIL"
}

function SendNotification2() {
	echo "$EMAILMESSAGE2" | mailx -s "$SUBJECT" "$EMAIL"
}

function SetIPVirtual() {
    ifup $INTERFACE:1
    ip route add $WAN2_NW/$WAN2_MASK dev $INTERFACE src $WAN2_IP table route1
    ip route add default via $WAN2_GW table route1
    ip rule add from $WAN2_IP table route1
    ip route add $WAN1_NW/$WAN1_MASK dev $INTERFACE src $WAN1_IP table route2
    ip route add default via $WAN1_GW table route2
    ip rule add from $WAN1_IP table route2
    ip route del default scope global nexthop via $WAN1_GW dev $INTERFACE
    ip route add default scope global nexthop via $WAN1_GW dev $INTERFACE weight 1 nexthop via $WAN2_GW dev $INTERFACE weight 4

}

function DelIPVirtual() {
    ip route del default scope global nexthop via $WAN1_GW dev $INTERFACE weight 1 nexthop via $WAN2_GW dev $INTERFACE weight 4
    ip route add default scope global nexthop via $WAN2_GW dev $INTERFACE
    ip route del $WAN2_NW/$WAN2_MASK dev $INTERFACE src $WAN2_IP table route1
    ip route del default via $WAN2_GW table route1
    ip rule del from $WAN2_IP table route1
    ip route del $WAN1_NW/$WAN1_MASK dev $INTERFACE src $WAN1_IP table route2
    ip route del default via $WAN1_GW table route2
    ip rule del from $WAN1_IP table route2
    ifdown $INTERFACE:1
}

function CreateAliasInterface() {
    if -f "$PATH_NETWORKS/ifcfg-$INTERFACE:1" &&
        `grep $WAN1_IP $PATH_NETWORKS/ifcfg-$INTERFACE:1` ; then
        echo "alias for $INTERFACE interface exists."
        break
    else
        HWADDR=`ip addr show $INTERFACE |
                grep ether |
                awk '{print $2}'`
        echo "DEVICE="$INTERFACE:1"
HWADDR="$HWADDR"
ONBOOT="no"
IPADDR="$WAN1_IP"
NETMASK="$WAN1_MASK"
GATEWAY="$WAN1_GW"
ONPARENT="no"" > "$PATH_NETWORKS/ifcfg-$INTERFACE:1"
    fi
}

                # 1. fork
redirectStd     # 2.2.1. redirect stdin/stdout/stderr
trap '' 1 2     # 2.2.2. guard against HUP and INT (in child)
cd /            # 3. ensure cwd isn't a mounted fs
# umask 0       # 4. umask (leave this to caller)
closeFds        # 5. close unneeded fds

(
LOCK_FILE="/var/lock/checkWand"
ULIMIT_N=`ulimit -n`
let "FLOCK_FD = ULIMIT_N - 1"

CreateAliasInterface

while : ; do
    sleep 1200

    DATE=`date --rfc-3339=seconds`
    CURRENT_IP=`ip addr show dev $INTERFACE | 
                grep "inet " |
                head -1 | 
                awk '{ print $2 }' | 
                cut -d/ -f1`
    if [[ $CURRENT_IP != $WAN1_IP ]] ; then
        CURRENT_IP=$WAN1_IP
        SUBJECT="The configuration of the WAN interface changed."
        EMAILMESSAGE2="The main channel is up again, we proceeded to return the settings.
Current IP: $WAN1_IP
Date: $DATE
" 
        eval "exec $FLOCK_FD<> $LOCK_FILE"
        if flock -n $FLOCK_FD ; then
            echo "Set IP Virtual"
            SetIPVirtual
            echo "Checking Connection"
            if CheckConnection2 ; then
                echo "Del IP Virtual"
                DelIPVirtual
		echo "Swicht Setting Network"
                SwitchNetworkSettings2
                echo "Restarting Networks"
                RestartNetwork
                echo "Sending Notification"
                SendNotification2
            else
                echo "Principal channel is down again."
		echo "Del IP Virtual"
                DelIPVirtual
            fi
            flock -u $FLOCK_FD    # flock STOP
      else
          echo "Instance 1 is making changes."
      fi
    fi
done
) >> /var/log/checkWand/checkWand_1.log &

(
LOCK_FILE="/var/lock/checkWand"
ULIMIT_N=`ulimit -n`
let "FLOCK_FD = ULIMIT_N - 1"

while : ; do
    DATE=`date --rfc-3339=seconds`
    CURRENT_IP=`ip addr show dev $INTERFACE |
                grep "inet " |
                head -1 |
                awk '{ print $2 }' |
                cut -d/ -f1`
    SUBJECT="The configuration of the WAN interface changed."
    EMAILMESSAGE1="The WAN configuration has been changed to the secondary channel because the main channel lost connection.
Current IP: $WAN2_IP
Date: $DATE
"
    if ! CheckConnection1 ; then
        eval "exec $FLOCK_FD<> $LOCK_FILE"
        if flock -n $FLOCK_FD ; then
            echo "Swicht Setting Network"
            SwitchNetworkSettings1
            echo "Restarting Networks"
            RestartNetwork
            echo "Sending Notification"
            SendNotification1
            flock -u $FLOCK_FD    # flock STOP
         else
            echo "Instance 2 is making changes."
         fi
    fi
    sleep $SLEEPTIME
done
) >> /var/log/checkWand/checkWand_2.log
) &
disown -h $!
