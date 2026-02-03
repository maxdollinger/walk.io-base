#!/walkio/busybox sh
set -eu

BB=/walkio/busybox

$BB echo "Starting init process ..."

# --- minimal dev/proc/sys so we can mount things ---
$BB echo "mounting proc ..."
$BB mount -t proc proc /proc

$BB echo "mounting sysfs ..."
$BB mount -t sysfs sysfs /sys

# devtmpfs gives you /dev/vda /dev/vdb etc.2
# If devtmpfs fails on your kernel, you can fall back to mdev, but devtmpfs is ideal

$BB echo "mounting devtmpfs ..."
$BB mount -t devtmpfs devtmpfs /dev || true

$BB echo "mounting dev/pts ..."
$BB mkdir -p /dev/pts
$BB mount -t devpts devpts /dev/pts || true

# --- mount the base root (vda) read-only at /mnt/lower ---
# IMPORTANT: even though the kernel booted from vda as /, we remount the *block device* at /mnt/lower
# so overlay has a clean lowerdir.
$BB mount -t ext4 -o ro /dev/vda /mnt/root
$BB mount -t ext4 -o ro /dev/vdb /mnt/app

# --- mount the state disk (vdb) read-write at /mnt/state ---
$BB mount -t ext4 -o rw /dev/vdc /mnt/state

# Prepare overlay upper/work dirs (must be on same fs: /mnt/state)
$BB mkdir -p /mnt/state/app_state /mnt/state/overlay_work

# Optional: provide persistent dirs on state (useful even with overlay)
$BB mkdir -p /mnt/state/persist

# --- mount overlay as the future root ---
$BB mount -t overlay overlay \
    -o lowerdir=/mnt/app:/mnt/root,upperdir=/mnt/state/app_state,workdir=/mnt/state/overlay_work \
    /mnt/newroot

# --- create standard mountpoints in the new root ---
$BB mkdir -p /mnt/newroot/proc /mnt/newroot/sys /mnt/newroot/dev /mnt/newroot/run /mnt/newroot/tmp /mnt/newroot/mnt

# A place to put the old root after pivot
$BB mkdir -p /mnt/newroot/.oldroot

# --- pivot_root into the overlay root ---
$BB pivot_root /mnt/newroot /mnt/newroot/.oldroot

# Now we're running with / = overlay merged root.

# Re-mount the standard virtual filesystems on the new root
$BB mount -t proc proc /proc
$BB mount -t sysfs sysfs /sys
$BB mount -t devtmpfs devtmpfs /dev || true
$BB mkdir -p /dev/pts
$BB mount -t devpts devpts /dev/pts || true

# Make Ctrl+Alt+Del send SIGINT to PID 1 instead of immediate reboot
$BB echo 0 >/proc/sys/kernel/ctrl-alt-del || true

# Runtime tmpfs (recommended)
$BB mount -t tmpfs -o mode=0755 tmpfs /run
$BB mount -t tmpfs -o mode=1777 tmpfs /tmp

# Clean up old root mounts (best effort)
$BB umount -l /.oldroot/proc 2>/dev/null || true
$BB umount -l /.oldroot/sys 2>/dev/null || true
$BB umount -l /.oldroot/dev 2>/dev/null || true

# Keep mounts to inspect later if you want; otherwise:
$BB umount -l /.oldroot/mnt/lower || true
$BB umount -l /.oldroot/mnt/state || true

# Networking (disabled for now)
# $BB ip link set lo up

# Bring up VM interface
# $BB ip link set eth0 up
# $BB ip addr add 10.0.0.2/24 dev eth0
# $BB ip route add default via 10.0.0.1

# DNS
# $BB echo "nameserver 1.1.1.1" >/etc/resolv.conf

# --- networking/basic /etc (optional, depends on your environment) ---
# If you want resolv.conf/hosts always present:
# if [ ! -e /etc/resolv.conf ]; then
#     $BB echo "nameserver 1.1.1.1" >/etc/resolv.conf || true
# fi
# if [ ! -e /etc/hosts ]; then
#     $BB echo "127.0.0.1 localhost" >/etc/hosts || true
# fi

shutdown() {
    $BB echo "[walkio] shutdown requested" >/dev/ttyS0

    $BB echo "[walkio] stopping app" >/dev/ttyS0
    $BB kill -TERM "$APP_PID" 2>/dev/null || true

    # grace period
    for i in 1 2 3 4 5; do
        $BB kill -0 "$APP_PID" 2>/dev/null || break
        $BB sleep 1
    done

    # hard kill if needed
    $BB kill -KILL "$APP_PID" 2>/dev/null || true

    $BB echo "[walkio] app stopped" >/dev/ttyS0

    $BB reboot -f
}

# --- pick what to run (injected from the app overlay) ---
# Read argv (newline-delimited) and exec
if [ -f /walkio/argv ]; then
    # Build "$@" from file lines
    set --
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        set -- "$@" "$line"
    done </walkio/argv

    # Load env (optional)
    if [ -f /walkio/env ]; then
        # export each KEY=VALUE line
        while IFS= read -r kv; do
            [ -n "$kv" ] || continue
            export "$kv"
        done </walkio/env
    fi

    cd $WORKDIR

    $BB echo "[walkio] starting app" >/dev/ttyS0

    trap shutdown INT TERM

    "$@" &
    APP_PID=$!
    $BB echo "[walkio] app started with PID: $APP_PID" >/dev/ttyS0

    wait "$APP_PID"
    STATUS=$?

    $BB echo "[walkio] app exited with status $STATUS" >/dev/ttyS0

    # Clean shutdown of VM
    $BB reboot

fi
