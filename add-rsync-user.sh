#!/bin/bash
. /opt/farm/scripts/functions.uid
. /opt/farm/scripts/functions.net
. /opt/farm/scripts/functions.custom
. /opt/farm/ext/keys/functions
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
	echo "error: parameter $1 not conforming user name format"
	exit 1
elif [ -d /srv/rsync/$1 ]; then
	echo "error: user $1 exists"
	exit 1
elif [ "`resolve_host $2`" = "" ]; then
	echo "error: parameter $2 not conforming hostname format, or given hostname is invalid"
	exit 1
fi

uid=`get_free_uid $MINUID $MAXUID`

if [ $uid -lt 0 ]; then
	echo "error: no free UIDs"
	exit 1
fi

rsyncserver=$2
backupserver=$3

if [ -z "${rsyncserver##*:*}" ]; then
	rsynchost="${rsyncserver%:*}"
	rsyncport="${rsyncserver##*:}"
else
	rsynchost=$rsyncserver
	rsyncport=22
fi

if [ "$backupserver" != "" ] && [ "$backupserver" != "$rsyncserver" ]; then
	if [ "`resolve_host $backupserver`" = "" ]; then
		echo "error: parameter $3 not conforming hostname format, or given hostname is invalid"
		exit 1
	fi

	if [ -z "${backupserver##*:*}" ]; then
		backuphost="${backupserver%:*}"
		backupport="${backupserver##*:}"
	else
		backuphost=$backupserver
		backupport=22
	fi
fi

groupadd -g $uid rsync-$1
useradd -u $uid -d /srv/rsync/$1 -s /bin/false -m -g rsync-$1 rsync-$1
chmod 0700 /srv/rsync/$1

path=/srv/rsync/$1/.ssh
sudo -u rsync-$1 ssh-keygen -f $path/id_rsa -P ""
cp -a $path/id_rsa.pub $path/authorized_keys

rsynckey=`ssh_management_key_storage_filename $rsynchost`
ssh -i $rsynckey -p $rsyncport root@$rsynchost "groupadd -g $uid rsync-$1"
ssh -i $rsynckey -p $rsyncport root@$rsynchost "useradd -u $uid -d /srv/rsync/$1 -s /usr/bin/rssh -M -g rsync-$1 rsync-$1"
rsync -e "ssh -i $rsynckey -p $rsyncport" -av /srv/rsync/$1 root@$rsynchost:/srv/rsync

if [ "$backupserver" != "" ] && [ "$backupserver" != "$rsyncserver" ]; then
	backupkey=`ssh_management_key_storage_filename $backuphost`
	ssh -i $backupkey -p $backupport root@$backuphost "groupadd -g $uid rsync-$1"
	ssh -i $backupkey -p $backupport root@$backuphost "useradd -u $uid -d /srv/rsync/$1 -s /bin/false -M -g rsync-$1 rsync-$1"
	rsync -e "ssh -i $backupkey -p $backupport" -av /srv/rsync/$1 root@$backuphost:/srv/rsync
fi

echo "rsync/ssh target: rsync-$1@$rsynchost:/srv/rsync/$1"
cat $path/id_rsa
