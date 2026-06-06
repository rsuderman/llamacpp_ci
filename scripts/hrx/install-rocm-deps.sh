#!/usr/bin/env bash
set -euo pipefail

ROCM_VERSION="${ROCM_VERSION:-7.2.1}"
ROCM_APT_CODENAME="${ROCM_APT_CODENAME:-}"
ROCM_PACKAGES="${ROCM_PACKAGES:-rocm-hip-sdk}"

if [[ -z "${ROCM_APT_CODENAME}" ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    ROCM_APT_CODENAME="${VERSION_CODENAME}"
fi

sudo apt-get update
sudo apt-get install -y \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    git \
    gnupg \
    libssl-dev \
    ninja-build \
    pkg-config \
    python3

sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://repo.radeon.com/rocm/rocm.gpg.key | \
    gpg --dearmor | \
    sudo tee /etc/apt/keyrings/rocm.gpg > /dev/null

cat <<EOF | sudo tee /etc/apt/sources.list.d/rocm.list > /dev/null
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/${ROCM_VERSION} ${ROCM_APT_CODENAME} main
EOF

cat <<EOF | sudo tee /etc/apt/preferences.d/rocm-pin-600 > /dev/null
Package: *
Pin: release o=repo.radeon.com
Pin-Priority: 600
EOF

sudo apt-get update
# shellcheck disable=SC2086
sudo apt-get install -y ${ROCM_PACKAGES}
