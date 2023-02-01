FROM debian:bullseye-slim

RUN apt-get update
RUN apt-get install nginx nginx-extras bash samba tzdata -y

RUN groupadd --gid 1000 smb
RUN useradd -rm -d /tmp -s /sbin/nologin --gid smb --uid 1000 smbuser

RUN mkdir -p /usr/local/samba/var/cores
RUN chmod -R 0700 /usr/local/samba/var/cores

COPY entrypoint.sh /usr/bin/entrypoint.sh
RUN chmod u+x /usr/bin/entrypoint.sh

EXPOSE 137/udp 138/udp 139 445 80

HEALTHCHECK --interval=60s --timeout=15s CMD smbclient -L \\localhost -U % -m SMB3

ENTRYPOINT ["/usr/bin/entrypoint.sh"]
