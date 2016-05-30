#!/bin/bash
. /opt/farm/scripts/functions.uid
. /opt/farm/scripts/functions.custom
# create local account with rsync access and ssh key, ready to connect Windows
# computer(s) with cwRsync and backup them inside local (eg. office) network:
# - first on local management server (to preserve UID)
# - then on specified storage server (sf-rsync-server and sf-rssh extensions required)
# - last on specified backup server (if not the same)
# Tomasz Klim, Aug 2014, Jan 2016


MINUID=1200
MAXUID=1299


if [ "$2" = "" ]; then
	echo "usage: $0 <user> <rsync-server[:port]> [backup-server[:port]]"
	exit 1
elif ! [[ $1 =~ ^[a-z0-9]+$ ]]; then
	echo "error: parameter 1 not conforming user name format"
	exit 1
elif ! [[ $2 =~ ^[a-z0-9.-]+[.][a-z0-9]+([:][0-9]+)?$ ]]; then
	echo "error: parameter 2 not conforming host name format"
	exit 1
elif [ -d /srv/rsync/$1 ]; then
	echo "error: user $1 exists"
	exit 1
elif [ "`getent hosts $2`" = "" ]; then
	echo "error: host $2 not found"
	exit 1
fi

uid=`get_free_uid $MINUID $MAXUID`

if [ $uid -lt 0 ]; then
	echo "error: no free UIDs"
	exit 1
fi

rserver=$2
if [ -z "${rserver##*:*}" ]; then
	rhost="${rserver%:*}"
	rport="${rserver##*:}"
else
	rhost=$rserver
	rport=22
fi

if [ "$3" != "" ] && [ "$3" != "$2" ]; then
	bserver=$3

	if ! [[ $bserver =~ ^[a-z0-9.-]+[.][a-z0-9]+([:][0-9]+)?$ ]]; then
		echo "error: parameter 3 not conforming host name format"
		exit 1
	fi

	if [ -z "${bserver##*:*}" ]; then
		bhost="${bserver%:*}"
		bport="${bserver##*:}"
	else
		bhost=$bserver
		bport=22
	fi

	if [ "`getent hosts $bhost`" = "" ]; then
		echo "error: host $bhost not found"
		exit 1
	fi
fi

groupadd -g $uid rsync-$1
useradd -u $uid -d /srv/rsync/$1 -s /bin/false -m -g rsync-$1 rsync-$1
chmod 0700 /srv/rsync/$1

path=/srv/rsync/$1/.ssh
sudo -u rsync-$1 ssh-keygen -f $path/id_rsa -P ""
cp -a $path/id_rsa.pub $path/authorized_keys

rkey=`ssh_management_key_storage_filename $rhost`
ssh -i $rkey -p $rport root@$rhost "groupadd -g $uid rsync-$1"
ssh -i $rkey -p $rport root@$rhost "useradd -u $uid -d /srv/rsync/$1 -s /usr/bin/rssh -M -g rsync-$1 rsync-$1"
rsync -e "ssh -i $rkey -p $rport" -av /srv/rsync/$1 root@$rhost:/srv/rsync

if [ "$3" != "" ] && [ "$3" != "$2" ]; then
	bkey=`ssh_management_key_storage_filename $bhost`
	ssh -i $bkey -p $bport root@$bhost "groupadd -g $uid rsync-$1"
	ssh -i $bkey -p $bport root@$bhost "useradd -u $uid -d /srv/rsync/$1 -s /bin/false -M -g rsync-$1 rsync-$1"
	rsync -e "ssh -i $bkey -p $bport" -av /srv/rsync/$1 root@$bhost:/srv/rsync
fi

echo "rsync/ssh target: rsync-$1@$rhost:/srv/rsync/$1"
cat $path/id_rsa
