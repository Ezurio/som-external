#!/bin/sh

# If the summit-rcm secret directory does not exist (in the event of an upgrade from WebLCM), create
# it and copy the default SSL certificates
if [ ! -d /data/secret/summit-rcm ]; then
    echo "Detected upgrade from WebLCM, restoring default configuration"
    cp -r /usr/share/factory/etc/secret/summit-rcm /data/secret
fi
