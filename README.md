# share-docker
Dockerfile for sharing drives over SAMBA and WebDAV easily with access control shared between the two.

## Tech
Uses smbd and nginx with the dav-extension and pam-extension.

## Commands
The entrypoint accepts the following input:
```
 -u  username:password:guid
     (eg -u foo:bar:1001)
 -s  name:path:rw:user1,2,3
     (eg -s foo_drive:/tmp:user)
     (or open for everyone -s foo_drive:/tmp)
```

An example `docker run` would be:
```
docker run --name samba -d -v "/mnt/Drive A":/drive_a -v "/mnt/Drive B":/drive_b -p 80:80 -p 445:445 -p 139:139 samba -u "foo:P4ssWrd:1001" -u "bar:p4SSwrD:1002" -s "Drive A:/drive_a:rw:foo" -s "Drive B:/drive_b:rw:bar"
```

This will give all Samba shares the names "Drive A" and "Drive B" and on WebDAV they are reachable on: `127.0.0.1/drive_a` and `127.0.0.1/drive_b` which are the docker mount paths.

If no user was mapped to a path Samba will accept guests (no passwords) and all users defined, but WebDAV only accept users defined (no guests).
