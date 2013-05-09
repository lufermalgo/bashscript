#!/bin/sh
#  
#  createLVM.sh
#  
#  Copyright (C) 2012 - Luis Fernando Maldonado Arango
#  Copyright (C) 2012 - Summan S.A.S.
#  
#  createLVM.sh is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#  
#  createLVM.sh is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with checkWand.  If not, see <http://www.gnu.org/licenses/>.
#
BOLD_RED_TEXT='\033[1;31m'
BOLD_GREEN_TEXT='\033[1;32m'
BOLD_PURPLE_TEXT='\033[1;35m'
RESET_TEXT='\033[0m'
function echoRed() {
    echo -e "$BOLD_RED_TEXT$1$RESET_TEXT"
}

function echoGreen() {
    echo -e "$BOLD_GREEN_TEXT$1$RESET_TEXT"
}

function echoPurple() {
    echo -e "$BOLD_PURPLE_TEXT$1$RESET_TEXT"
}

# Function to create the  logical volume in LVM
function createLV() {
    echoGreen "Creando Logical Volumes '$1' segun archivo insumo"
    lvcreate -n $1 -L $2G $3
    echoGreen "la siguiente linea confirma que el Logical Volumes fue creado:"
    lvs | grep $1
}

function formatLV() {
    echoGreen "Formateando Logical Volumes '$1'."
    if [[ -e /dev/$3/$1 ]]; then
        mke2fs -t ext3 /dev/$3/$1
        tune2fs -c 0 -i 0 /dev/$3/$1    
    else
        echoRed "Logical Volumes $1 no existe!"
        exit
    fi
    
}

function createMountPoint() {
    echoGreen "Creando punto de montage '/$1' para el Logical Volumes '$1'."
    if [[ ! -d /$1 ]]; then
    mkdir /$1
    else
        echoRed "Punto de montage '/$1' ya existe"
    fi
}

function createFStab() {
    echoGreen "Creando linea en fstab temporal para el filesystem '/$1'."
    if [[ ! `grep /dev/mapper/$3-$1 fstab.tmp` ]]; then
        echo "/dev/mapper/$3-$1 /$1 ext3    defaults    0 0" >> fstab.tmp
	echo "==========================================================="
    fi
}

while read LINE
do
  VGNAME=`echo $LINE | cut -d, -f1`
  LVMNAME=`echo $LINE | cut -d, -f2`
  SIZELV=`echo $LINE | cut -d, -f3`

  createLV $LVMNAME $SIZELV $VGNAME
  formatLV $LVMNAME $SIZELV $VGNAME
  createMountPoint $LVMNAME $SIZELV $VGNAME
  createFStab $LVMNAME $SIZELV $VGNAME
done < "$1"

