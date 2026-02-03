#!/usr/bin/env bash
set -euo pipefail

#build app and state device
>app.ext4
truncate -s 10M app.ext4
mkfs.ext4 -F -L APP app.ext4

>state.ext4
truncate -s 10M state.ext4
mkfs.ext4 -F -L STATE state.ext4

#setup app layout
mkdir appfs
sudo mount -o loop app.ext4 appfs
sudo chown -R $USER:$USER appfs

mkdir -p appfs/usr/bin
cp -v test/test-app.sh appfs/usr/bin/app
chmod +x appfs/usr/bin/app

mkdir appfs/walkio
mkdir appfs/app

cat >appfs/walkio/env <<EOF
PATH=/walkio:/usr/bin
WORKDIR=/app
WALKIO_TOKEN=ABC-123
EOF

cat >appfs/walkio/argv <<EOF
app
arg1
arg2
EOF

sudo umount appfs && rm -rf appfs
