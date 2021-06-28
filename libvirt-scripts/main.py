#!/usr/bin/env python3
import os
import uvicorn
import subprocess
from typing import Optional
from fastapi import FastAPI, Path
from pydantic import BaseModel

#Tags and descriptions used for items in API
tags_metadata = [
    {
        "name": "Create",
        "description": "You can create your VMs by providing resources and a name right here. Take note that Ram and Storage expect a 'G' at the end of the value",
    },
    {
        "name": "Delete",
        "description": "You can delete a VM by providing it's name",
    },
    {
        "name": "Migrate",
        "description": "You can live migrate your VM , please take note that if you migrate it you can't delete it on this node",
    },
]


app = FastAPI(
    title="Mini stack",
    description="This is a small scale bare bone openstack reinvention.",
    version="0.0.1",
    openapi_tags=tags_metadata)

#A base class for input variables
class Item(BaseModel):
    name: str
    ram: str 
    cpu: int
    storage: str

#A base class for removable VM
class Item2(BaseModel):
    name: str

#A base class for output variable
class Response(BaseModel):
    ip: str



@app.post("/create/", tags=["Create"])
async def create_item(item: Item):
    #set environment variables on linux
    os.environ["name"] = item.name
    os.environ["ram"] = item.ram[:-1]
    os.environ["cpu"] = str(item.cpu)
    os.environ["storage"] = item.storage
    
    #subprocess.run Run the command described by args and env variable. Wait for command to complete, then return a CompletedProcess instance. then pipe the output for final result
    #generate a mac addr
    mac=result=subprocess.run(["/home/centos/libvirt-scripts/gen-mac-address.sh"],stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    #run the script which create VM and return its output for the sake of debug
    result=subprocess.run(["/home/centos/libvirt-scripts/create-vm.sh",os.environ["name"],"domain",os.environ["cpu"],str(int(os.environ["ram"]) * 1024),os.environ["storage"],"/data/vms/focal-server-cloudimg-amd64.qcow2","ubuntu",mac.stdout]
    ,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)

    #if anything goes wrong from executing the above command show the output for the sake of debug
    if result.returncode !=0:
        return result.stdout.replace(b"\n", b" ").strip()

    
    #run the script which catch the ip addr of VM
    ip=subprocess.run(["/home/centos/libvirt-scripts/find-ip.sh",os.environ["name"]],stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    
    #return the ip addr of VM 
    return Response(ip=ip.stdout.replace(b"\n", b" ").strip())
    

@app.post("/delete/", tags=["Delete"])
async def create_item(item: Item2):
    #set the environment variable to VM name
    os.environ["name"] = item.name
    #run the script that remove VM
    result=subprocess.run(["/home/centos/libvirt-scripts/delete-vm.sh",os.environ["name"]],stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    #return the results and remove \n in the output
    return result.stdout.replace(b"\n", b" ").strip()

@app.post("/migrate/", tags=["Migrate"])
async def create_item(item: Item2):
    os.environ["name"] = item.name
    #run the script which do the migration
    result = subprocess.run(["/home/centos/libvirt-scripts/migrate.sh",os.environ["name"]],stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    #check the exit code if it is successful or equal 0 or if it's failed or not equal to 0
    if result.returncode == 0 :
        return "Done! The migration was successful"
    else:
        return result.stdout.replace(b"\n", b" ").strip()

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)

