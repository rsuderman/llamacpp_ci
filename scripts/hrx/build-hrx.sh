#!/usr/bin/env bash
set -euo pipefail

HRX_SRC_DIR="${HRX_SRC_DIR:-${RUNNER_TEMP:-/tmp}/hrx-src}"
HRX_BUILD_DIR="${HRX_BUILD_DIR:-${RUNNER_TEMP:-/tmp}/hrx-build}"
HRX_INSTALL_PREFIX="${HRX_INSTALL_PREFIX:-${RUNNER_TEMP:-/tmp}/hrx-install}"
CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}"
CMAKE_GENERATOR="${CMAKE_GENERATOR:-Ninja}"

cmake -S "${HRX_SRC_DIR}" -B "${HRX_BUILD_DIR}" -G "${CMAKE_GENERATOR}" \
    -DCMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE}" \
    -DCMAKE_INSTALL_PREFIX="${HRX_INSTALL_PREFIX}" \
    "$@"

cmake --build "${HRX_BUILD_DIR}" --config "${CMAKE_BUILD_TYPE}" --target install -j "${HRX_BUILD_JOBS:-$(nproc)}"
