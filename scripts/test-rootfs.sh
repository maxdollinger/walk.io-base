#!/usr/bin/env bash
set -euo pipefail

# paths (override via env if you want)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FC_CONFIG="${FC_CONFIG:-$REPO_ROOT/test/firecracker-config.json}"

APP_EXT4="${APP_EXT4:-$REPO_ROOT/app.ext4}"
STATE_EXT4="${STATE_EXT4:-$REPO_ROOT/state.ext4}"

# sanity checks
for f in "$FC_CONFIG" "$APP_EXT4" "$STATE_EXT4"; do
    [[ -f "$f" ]] || {
        echo "missing file: $f" >&2
        exit 2
    }
done

ARCH="${ARCH:-x86_64}"

# download kernel
KERNEL_VER="v6.19-rc8"
KERNEL_URL="https://github.com/maxdollinger/walk.io-kernel/releases/download/${KERNEL_VER}/${ARCH}-vmlinux"

echo "downloading walk.io kernel from '$KERNEL_URL'"
curl -fsSL -o vmlinux "$KERNEL_URL"

# install firecracker
tmp="$(mktemp -d)"
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT

FC_VER="${FC_VER:-v1.14.0}"
FC_URL="https://github.com/firecracker-microvm/firecracker/releases/download/${FC_VER}/firecracker-${FC_VER}-${ARCH}.tgz"

curl -fsSL -o "$tmp/fc.tgz" "$FC_URL"
tar -xzf "$tmp/fc.tgz" -C "$tmp"
sudo install -m 0755 "$tmp/release-${FC_VER}-${ARCH}/firecracker-${FC_VER}-${ARCH}" /usr/local/bin/firecracker

# run firecracker
echo "[test] starting firecracker..."
set +e
(timeout "15s" sudo -E firecracker --no-api --config-file "$FC_CONFIG" --enable-pci)
FC_EXIT=?
set -e
echo "[test] firecracker exited with code: $FC_EXIT"

# validate result
mkdir statefs
echo "[test] mounting state.ext4..."
sudo mount -o loop "$STATE_EXT4" statefs

RESULT_FILE="statefs/app_state/var/app/result"
if [[ ! -f "$RESULT_FILE" ]]; then
    echo "[test] FAILED: result file not found: $RESULT_FILE"
    exit 2
fi

RESULT=$(cat "$RESULT_FILE")
echo "[test] result file says: '$RESULT'"
sudo umount statefs && rm -rf statefs

if [[ "$RESULT" == "PASSED" ]]; then
    echo "[test] ✅ PASSED"
    exit 0
else
    echo "[test] ❌ FAILED"
    exit 1
fi
