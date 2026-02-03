#!/usr/bin/env bash
set -euo pipefail

# fetch tags without cloning full repo
git ls-remote --tags --refs https://github.com/torvalds/linux.git |
    awk '{print $2}' |
    sed 's#refs/tags/##' |
    sort -V |
    tail -n1
