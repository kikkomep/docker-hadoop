#!/bin/bash

# default values
external_dns=false
background_mode=false
nfs_enabled=false
nfs_shared_paths=""

echo "$1 $2 $3"

# print usage
usage() {
    echo "Usage: $0 -d [--external-dns] [--nfs-mounts]"
    exit 1;
}

# parse arguments
OPTS=`getopt -o :d --long external-dns,nfs-mounts: -n 'parse-options' -- "$@"`

# check parsing result
if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; usage; exit 1 ; fi

# process arguments
eval set -- "${OPTS}"
while true; do
  case "$1" in
    -d ) background_mode="true"; shift ;;
    --external-dns ) external_dns=true; shift;;
    --nfs-mounts ) nfs_enabled="true"; nfs_shared_paths="${2}"; shift; shift ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done


#  update the DNS table if needed
if [[ ${external_dns} == true ]]; then
	echo "- Using external DNS ..."
else
	update-etc-hosts
fi


# initializes shared folders
init-shared-folders ${nfs_enabled} ${nfs_shared_paths}


# set the existing ssh keys 
shared_keys_path="/shared/keys"
if [[ -d "${shared_keys_path}" ]]; then
	mkdir -p /root/.ssh
	mkdir -p /home/aen/.ssh
	keys=($(ls ${shared_keys_path}/*.pub))
	for key in "${keys[@]}"
	do
		echo "Copying key ${key} ..."
		cat ${key} >> /root/.ssh/authorized_keys
		cat ${key} >> /home/aen/.ssh/authorized_keys
	done
fi

# start open SSH server
echo "OpenSSH service started"
/usr/sbin/sshd -D