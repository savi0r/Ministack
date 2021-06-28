#!/bin/bash
#wait 3 min & 30 seconds until the vm runs that was the average time for me
sleep 210
vm=$1
#after @ comes your DNS ip addr
dig @10.47.100.5 $vm +short

