#!/usr/bin/env bash
set -euo pipefail

INIT_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
    --init-dir)
        INIT_DIR="$2"
        shift 2
        ;;
    *)
        echo "unknown arg: $1" >&2
        exit 2
        ;;
    esac
done

INIT_DIR="${INIT_DIR:-walkio}"

# build block device
>rootfs.ext4
truncate -s 6M rootfs.ext4
mkfs.ext4 -F -L ROOT rootfs.ext4

# mount
mkdir -p rootfs
sudo mount -o loop rootfs.ext4 rootfs
sudo chown -R $USER:$USER rootfs

# craete rootfs layout
mkdir rootfs/dev
mkdir rootfs/proc
mkdir rootfs/sys

mkdir -p rootfs/mnt/root
mkdir -p rootfs/mnt/state
mkdir -p rootfs/mnt/app
mkdir -p rootfs/mnt/newroot

INIT_PATH="rootfs/$INIT_DIR"
mkdir "$INIT_PATH"
cp -v init/init.sh "$INIT_PATH/init"
cp -v init/busybox "$INIT_PATH/busybox"

chmod +x "$INIT_PATH/init"

sudo umount rootfs && rm -rf rootfs
