#!/bin/sh

/opt/farm/scripts/setup/extension.sh sf-net-utils
/opt/farm/scripts/setup/extension.sh sf-farm-manager

ln -sf /opt/farm/ext/rsync-manager/add-rsync-user.sh /usr/local/bin/add-rsync-user
