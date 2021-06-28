#!/bin/sh
vm=$1
sudo virsh migrate --live --verbose --undefinesource --persistent --p2p $vm qemu+ssh://10.47.100.4/system
# --direct - used for direct migration 
# --p2p - used for peer-to-peer migration 
# --persistent - leaves the domain in a persistent state on the destination host physical machine 
# --undefinesource - removes the guest virtual machine on the source host physical machine 
