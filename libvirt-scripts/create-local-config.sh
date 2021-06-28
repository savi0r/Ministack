#!/bin/sh
# Creates a configuration iso file for clount-init NoCloud
set -e
. /home/centos/libvirt-scripts/config.sh

# Temporary location to store files
TMPDIR=$(mktemp -d)
SSHDIR=/home/centos/libvirt-scripts/ssh-keys

usage() {
	echo "$0 <VM name> <network domain> <user>"
}

if [ $# -ne 3 ]; then
	usage
	exit 1
fi

if [ -z "$(ls -1 $SSHDIR)" ]; then
	echo "Put some public SSH keys in $SSHDIR!"
	exit 1
fi

cd $TMPDIR

for i in $SSHDIR/*; do echo "    - $(cat $i)"; done > ssh-file

cat > user-data <<EOF
#cloud-config
users:
  - name: $3
    ssh_authorized_keys:
$(cat ssh-file)
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
EOF

cat > meta-data <<EOF
instance-id: $1
local-hostname: $1.$2
EOF

genisoimage -output $VMDIR/$1-cidata.iso -volid cidata -joliet -rock user-data meta-data
virsh pool-refresh $VMPOOL
