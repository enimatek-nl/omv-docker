#!/bin/bash

# if [ ! -e /data/etc ]; then
#     echo "Initializing OpenMediaVault..."
#     mkdir -p /data/etc
#     mkdir /data/var
#     mv /etc/openmediavault /data/etc
#     mv /etc/default /data/etc
#     mv /var/log /data/var/log
# fi

# echo "Linking in configuration and data..."
# rm -Rf /etc/openmediavault
# rm -Rf /etc/default
# rm -Rf /var/log
# ln -s /data/etc/openmediavault /etc/openmediavault
# ln -s /data/etc/default /etc/default
# ln -s /data/var/log /var/log

start-stop-daemon --start --exec /usr/sbin/anacron
start-stop-daemon --start --quiet --pidfile /var/run/crond.pid --exec /usr/sbin/cron
start-stop-daemon --start --quiet --exec /usr/sbin/php-fpm7.4
start-stop-daemon --start --quiet --pidfile /run/nginx.pid --exec /usr/sbin/nginx
start-stop-daemon --start --quiet --oknodo --exec /usr/sbin/collectdmon -- -P "/var/run/collectd.pid" -- -C "/etc/collectd/collectd.conf"
start-stop-daemon --start --quiet --exec /usr/sbin/omv-engined
start-stop-daemon --start --quiet --oknodo --pidfile /run/monit.pid --exec /usr/bin/monit

while true; do
    sleep 1000 & wait $!
done