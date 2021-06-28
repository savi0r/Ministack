#!/bin/sh
# Creates a virtual machine from a base image, using CoW
# DO NOT DELETE YOUR BASE IMAGE AFTER YOU CREATE A VM, YOU WILL LOSE DATA
# If you don't want CoW copies of your base image, replace the `qemu-img` command below with:
# cp -v $6 $VMDIR/$1.qcow2
set -e
. /home/centos/libvirt-scripts/config.sh

usage() {
	echo "$0 <name> <domain> <cpus> <memory> <disksize> <baseimage> <user> <MAC address>"
}

if [ $# -ne 8 ]; then
	usage
	exit 1
fi

if [ ! -f /home/centos/libvirt-scripts/create-local-config.sh ]; then
	echo "This script needs ./create-local-config.sh to run!"
	exit 1
fi

if [ ! -f $6 ]; then
	echo "Can't find base image at $6!"
	usage
	exit 1
fi

if [ -f $VMDIR/$1 ]; then
	echo "Refusing to overwrite image at $VMDIR/$1!"
	exit 1
fi

qemu-img create -f qcow2 -F qcow2 -b $6 $VMDIR/$1.qcow2 $5
/home/centos/libvirt-scripts/create-local-config.sh $1 $2 $7

chown -v $VMUSER:$VMGROUP $VMDIR/$1.qcow2 $VMDIR/$1-cidata.iso
chmod -v 0600 $VMDIR/$1.qcow2 $VMDIR/$1-cidata.iso

# Manually copying images requies a pool refresh
virsh pool-refresh $VMPOOL

virt-install \
	-n $1 \
	--memory $4 \
	--vcpus $3 \
	--os-variant $OSVARIANT \
	--controller scsi,model=virtio-scsi \
	-w bridge=$VMBRIDGE,model=virtio,mac=$8 \
	--disk vol=$VMPOOL/$1.qcow2,bus=scsi,cache=directsync --import \
	--disk vol=$VMPOOL/$1-cidata.iso,device=cdrom,bus=scsi,cache=directsync \
	--autostart --noautoconsole
