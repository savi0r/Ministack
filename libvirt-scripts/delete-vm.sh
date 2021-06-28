#!/bin/sh
# $1 = VM name
. /home/centos/libvirt-scripts/config.sh

usage() {
	echo "$0 <name>"
}

if [ $# -ne 1 ]; then
	usage
	exit 1
fi

if [ -z "$(virsh list --all --name | grep ^$1\$)" ]
then
	echo "Can't find VM $1!"
	exit 2
fi

virsh destroy $1
virsh undefine $1
rm -rf $VMDIR/$1.qcow2 $VMDIR/$1-cidata.iso 
