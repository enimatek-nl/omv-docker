#!/bin/bash
#set -eo pipefail

echo -n "Nginx check: "
if nginx -V 2>&1 | grep -qE "http_dav_module|http-dav-ext"; then echo "good to go!"; else echo "missing dav modules!"; fi

CONFIG_FILE="/etc/samba/smb.conf"
hostname=`hostname`
set -e

cat > /etc/nginx/sites-enabled/default << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    root /tmp;
    index index.html index.htm;
    server_name _;

EOF

# housekeeping nginx (eg. run as root)
sed -i '1s/user www-data/user root/g' /etc/nginx/nginx.conf
echo "OK" > /tmp/index.html

cat >$CONFIG_FILE <<EOT
[global]
    workgroup = WORKGROUP
    netbios name = $hostname
    server string = $hostname
    security = user
    create mask = 0664
    directory mask = 2777
    force create mode = 0664
    force directory mode = 0775
    follow symlinks = yes
    force user = smbuser
    force group = smb
    load printers = no
    printing = bsd
    printcap name = /dev/null
    disable spoolss = yes
    guest account = smbuser
    usershare allow guests = yes
    max log size = 50
    log file = /dev/stdout
    map to guest = bad user
    socket options = TCP_NODELAY SO_RCVBUF=8192 SO_SNDBUF=8192
    local master = no
    dns proxy = no
EOT

while getopts "u:s:" opt; do
    case $opt in
        u)
            IFS=: read username password guid <<<"$OPTARG"
            addgroup --gid "$guid" "$username"
            adduser --system --shell /sbin/nologin --gid "$guid" --uid "$guid" "$username"
            echo "$username:$password" | chpasswd
            printf "$password\n$password\n" | smbpasswd -a -s "$username"
            ;;
        s)
            IFS=: read sharename sharepath readwrite users <<<"$OPTARG"
            echo -n "Adding share '$sharename': "
            echo "[$sharename]" >>"$CONFIG_FILE"
            echo -n "path '$sharepath' "
            echo "path = \"$sharepath\"" >>"$CONFIG_FILE"
            echo -n "read"
            if [[ "rw" = "$readwrite" ]] ; then
                echo -n "+write "
                echo "read only = no" >>"$CONFIG_FILE"
                echo "writable = yes" >>"$CONFIG_FILE"
            else
                echo -n "-only "
                echo "read only = yes" >>"$CONFIG_FILE"
                echo "writable = no" >>"$CONFIG_FILE"
            fi
            if [[ -z "$users" ]] ; then
                echo -n "for guests: "
                echo "browseable = yes" >>"$CONFIG_FILE"
                echo "guest ok = yes" >>"$CONFIG_FILE"
                echo "public = yes" >>"$CONFIG_FILE"
                cat >> "/etc/nginx/sites-enabled/default" <<EOT

                location $sharepath {
                    root /;
                    dav_methods PUT DELETE MKCOL COPY MOVE;
                    dav_ext_methods PROPFIND OPTIONS;
                    dav_access user:rw group:rw all:rw;

                    client_max_body_size 0;
                    create_full_put_path on;
                    client_body_temp_path /tmp/;

                    auth_pam "Restricted";
                    auth_pam_service_name "common-auth";
                }
EOT

            else
                echo -n "for users: "
                users=$(echo "$users" |tr "," " ")
                echo -n "$users "
                echo "valid users = $users" >>"$CONFIG_FILE"
                echo "write list = $users" >>"$CONFIG_FILE"
                # build ngnix restriction
                restricted=$(echo "$sharepath" |tr "/" "-")-auth
                users=$(echo "$users" |tr " " "\n")
                echo "$users" > "/etc/nginx/$restricted"
                arch=$(arch)
                cat > "/etc/pam.d/$restricted" <<EOT
auth    required                        /lib/$arch-linux-gnu/security/pam_listfile.so onerr=fail item=user sense=allow file=/etc/nginx/$restricted
auth    [success=1 default=ignore]      pam_unix.so nullok
auth    requisite                       pam_deny.so
auth    required                        pam_permit.so
auth    optional                        pam_cap.so
EOT

                chmod 644 "/etc/pam.d/$restricted"
                cat >> "/etc/nginx/sites-enabled/default" <<EOT

                location $sharepath {
                    root /;
                    dav_methods PUT DELETE MKCOL COPY MOVE;
                    dav_ext_methods PROPFIND OPTIONS;
                    dav_access user:rw group:rw all:rw;

                    client_max_body_size 0;
                    create_full_put_path on;
                    client_body_temp_path /tmp/;

                    auth_pam "Restricted";
                    auth_pam_service_name "$restricted";
                }
EOT

            fi
            echo "DONE"
            ;;
    esac
done

echo "}" >> "/etc/nginx/sites-enabled/default"

#ionice -c 3 nginx -g "daemon off;"
ionice -c 3 nginx
ionice -c 3 nmbd -D
ionice -c 3 smbd -F -S --no-process-group
