#!/bin/sh

/opt/farm/scripts/setup/role.sh sf-farm-manager

ln -sf /opt/farm/ext/rsync-manager/add-rsync-user.sh /usr/local/bin/add-rsync-user
