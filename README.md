#Abstract
This project is a small scale cloud management solution which basically has three main parts:
1. Virtualization
2. Distributed storage
3. Monitoring
Through these building blocks you can create VMs seamlessly and manage them via a web API and by utilising distributed storage you are able to live migrate your VMs and provide a highly available service
![network diagram](img/Network-Diagram.jpg)


Because we want to run our vms on a bridge mode network so we can access them from other nodes which reside in the same network and based on research and what articles over internet suggest you can't get ip address of vms in bridge mode easily through commands like ` virsh domifaddr [vm_name] ` so we need a dhcp server in place I went with dnsmasq because it provides the functionality of both a DHCP and a DNS server and it is lightweight nature.
I prepared a single cpu and 2 GB ram Centos8 ready system for running dnsmasq

```
yum install dnsmasq
systemctl start dnsmasq
systemctl enable dnsmasq
systemctl status dnsmasq
```

Configuring dnsmasq Server in CentOS and RHEL Linux

```
cp /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
vi /etc/dnsmasq.conf 
```
change listen-address which is used to set the IP address, where dnsmasq will listen on

```
listen-address=::1,127.0.0.1,10.47.100.5 #change the second address with your dns server IP
interface=eth1 #you can restrict the interface dnsmasq listens on using the interface option
expand-hosts #If you want to have a domain (which you can set as shown next) automatically added to simple names in a hosts-file, uncomment the expand-hosts option.
domain=arvan.lan # set the domain name
# Google's nameservers ,upstream DNS server for non-local domains 
server=8.8.8.8
server=8.8.4.4
#force your local domain to an IP address(es) using the address option as shown
address=/arvan.lan/127.0.0.1 
address=/arvan.lan/10.47.100.5

#enable the DHCP server
dhcp-range=10.47.200.1,10.47.200.50,12h #set your ip range
dhcp-leasefile=/var/lib/dnsmasq/dnsmasq.leases # where DHCP server will keep its lease database
dhcp-authoritative

```

check the configuration file syntax for errors as shown

```
dnsmasq --test
```



Configuring dnsmasq with /etc/resolv.conf File

```
vi /etc/resolv.conf
nameserver 127.0.0.1
```

The /etc/resolv.conf file is maintained by a local daemon especially the NetworkManager, therefore any user-made changes will be overwritten. To prevent this

```
chattr +i /etc/resolv.conf
lsattr /etc/resolv.conf
```

 The Dnsmasq reads all the DNS hosts and names from the /etc/hosts file, so add your DNS hosts IP addresses and name pairs as shown.
 
```
compute01 10.47.100.3
compute02 10.47.100.4
```

To apply the above changes, restart the dnsmasq service as shown.

```
systemctl restart dnsmasq
```

Testing Local DNS

To test if the local DNS server or forwarding is working fine, you need to use tools such as dig or nslookup for performing DNS queries. 

```
yum install bind-utils # remember to install it on every compute node as well because we need it later on
dig arvan.lan
```

The VMs will not have any internet access because the default route in them is set to the ip address of our local DNS which is `10.47.100.5` in our case so in order to make sure DNS server act as a router we need to install iptables on it - centos8 does not have it by default - so follow along.

Enable ip forwarding

```
sysctl -w net.ipv4.ip_forward=1
```

Installing iptables 

```
sudo yum install iptables-services -y
sudo systemctl start iptables
sudo systemctl enable iptables
```

Set iptables rules accordingly

```
iptables -F # flush the default rules
iptables --table nat --append POSTROUTING --out-interface eth0 -j MASQUERADE
```


Virtual Machine Host Configuration
Each virtual machine should be setup identically, with only the hostname and local IP addresses being different. First, since we are putting the VMs on the same network segment as the host machine, we need to setup a network bridge. 

Bridged mode operates on Layer 2 of the OSI model. When used, all of the guest virtual machines will appear on the same subnet as the host physical machine. The most common use cases for bridged mode include:
Deploying guest virtual machines in an existing network alongside host physical machines making the difference between virtual and physical machines transparent to the end user.
Deploying guest virtual machines without making any changes to existing physical network configuration settings.
Deploying guest virtual machines which must be easily accessible to an existing physical network. Placing guest virtual machines on a physical network where they must access services within an existing broadcast domain, such as DHCP.
Connecting guest virtual machines to an exsting network where VLANs are used.


CentOS 8 uses NetworkManager as it's default networking daemon, so we will be configuring that.

```
sudo nmcli con add type bridge ifname br0
sudo nmcli con add type bridge-slave ifname eth1 master br0

#I will also disable Spanning Tree Protocol (STP) on the bridge to speed up network startup significantly. Make sure there are no loops in your network! If you can't remove the loops in your network, then you need to leave STP enabled.
sudo nmcli con modify bridge-br0 bridge.stp no
```

Now setup the IP configuration like your primary networking device, along with your DNS settings. If you don't know what to put in for ipv4.dns-search, then you don't need to set it. You would want it only if your home network uses a domain (my network is set to use arvan.lan).

```
sudo nmcli con modify bridge-br0 ipv4.addresses 10.47.100.3/16
sudo nmcli con modify bridge-br0 ipv4.gateway 10.47.0.1
sudo nmcli con modify bridge-br0 ipv4.dns 10.47.0.7
sudo nmcli con modify bridge-br0 ipv4.dns-search arvan.lan
```

If your network bridge slave device is being used already, then the bridge will not start. Simply activate the network slave device to bring up your bridge. If your network is misconfigured, this is where you may lose your SSH session!

```
sudo nmcli con up bridge-slave-eth1
```

Check to make sure everything is configured correctly.You might need to wait ~10 seconds for any input to be returned:

```
watch ip a show br1
```

Now we need to install and configure libvirt. 
```
dnf update
sudo yum install -y libvirt-daemon libvirt-admin libvirt-client \
  libvirt-daemon-kvm libvirt-daemon-driver-qemu \
  libvirt-daemon-driver-network libvirt-daemon-driver-storage \
  libvirt-daemon-driver-storage-core virt-install nfs-utils
sudo systemctl enable libvirtd
sudo systemctl start libvirtd
```

You need to disable selinux as default security driver because it gets in our way and we are testing it in a lab environment we can simply disable selinux completely or change the security driver settings as described below:

```
vi /etc/libvirt/qemu.conf 
#change 
security_driver = "none"
systemctl restart libvirtd
```

Now we need to setup the storage backend, with the local directory being at /data/vms:
https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/virtualization_administration_guide/chap-virtualization_administration_guide-storage_pools-storage_pools

> Suppose a storage administrator responsible for an NFS server creates a share to store guest virtual machines' data. The system administrator defines a pool on the host physical machine with the details of the share (nfs.example.com:/path/to/share should be mounted on /vm_data). When the pool is started, libvirt mounts the share on the specified directory, just as if the system administrator logged in and executed mount nfs.example.com:/path/to/share /vmdata. If the pool is configured to autostart, libvirt ensures that the NFS share is mounted on the directory specified when libvirt is started.
Once the pool starts, the files that the NFS share, are reported as volumes, and the storage volumes' paths are then queried using the libvirt APIs. The volumes' paths can then be copied into the section of a guest virtual machine's XML definition file describing the source storage for the guest virtual machine's block devices. With NFS, applications using the libvirt APIs can create and delete volumes in the pool (files within the NFS share) up to the limit of the size of the pool (the maximum storage capacity of the share). Not all pool types support creating and deleting volumes. Stopping the pool negates the start operation, in this case, unmounts the NFS share. The data on the share is not modified by the destroy operation, despite the name. See man virsh for more details. 

```
sudo mkdir -p /data/vms
sudo virsh pool-define-as \
  --name vmstorage --type netfs \
  --source-host 192.168.99.100 --source-path /sharedvol \
  --source-format auto --target /data/vms
sudo virsh pool-autostart vmstorage
sudo virsh pool-start vmstorage
```

At this point you can create working virtual machines manually, but that takes too long! I want to spin up virtual machines fast. To do that, we need to use cloud-init enabled images. I will be using the ubuntu Focal cloud-init image here as an example.


```
sudo curl -L \
http://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img -o /data/vms/focal-server-cloudimg-amd64.qcow2
sudo virsh pool-refresh vmstorage
```

Don't use the base image directly! You want to create copies of that file for each VM, which can either be done with cp for normal copies, or qemu-img if you want to create a copy-on-write copy which reduces disk space significantly by only storing the difference between the base image and the VM.

```
sudo su -
git clone !
cd libvirt-scripts
```

for the sake of test run the script using the following command 

```
./create-vm.sh test arvan.lan 1 $((2*1024)) 10G \
  /data/vms/focal-server-cloudimg-amd64.qcow2 debian $(./gen-mac-address.sh)

virsh list # you must see your vm name in the ouput
```

