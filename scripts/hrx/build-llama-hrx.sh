#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

. "${SCRIPT_DIR}/env.sh"

GGML_HRX_BUILD_HIP_BENCHES="${GGML_HRX_BUILD_HIP_BENCHES:-OFF}"
LLAMA_BUILD_TARGET="${LLAMA_BUILD_TARGET:-}"

if [[ -z "${ROCM_PATH:-}" ]]; then
    ROCM_PATH="${HRX_ROCM_ROOT}"
fi
export ROCM_PATH

if [[ -z "${GGML_HRX_AMDGPU_TARGETS:-}" ]]; then
    GGML_HRX_AMDGPU_TARGETS=""
    if [[ -x "${ROCM_PATH}/bin/rocminfo" ]]; then
        GGML_HRX_AMDGPU_TARGETS="$("${ROCM_PATH}/bin/rocminfo" 2>/dev/null | grep -oE 'gfx[0-9]+[a-zA-Z]*' | head -n 1 || true)"
    fi

    GGML_HRX_AMDGPU_TARGETS="${GGML_HRX_AMDGPU_TARGETS:-gfx1100}"
    export GGML_HRX_AMDGPU_TARGETS
fi

CMAKE_PREFIX_PATH="${HRX_INSTALL_PREFIX}${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}"
export CMAKE_PREFIX_PATH

CMAKE_COMPILER_LAUNCHER="${CMAKE_COMPILER_LAUNCHER:-}"
if [[ -z "${CMAKE_COMPILER_LAUNCHER}" ]] && command -v ccache >/dev/null 2>&1; then
    CMAKE_COMPILER_LAUNCHER="ccache"
fi

cmake_args=(
    -DCMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE}"
    -DGGML_HRX=ON
    -DGGML_NATIVE=OFF
    -DGGML_HRX_ROCM_PATH="${ROCM_PATH}"
    -DGGML_HRX_AMDGPU_TARGETS="${GGML_HRX_AMDGPU_TARGETS}"
    -DGGML_HRX_BUILD_HIP_BENCHES="${GGML_HRX_BUILD_HIP_BENCHES}"
    -DCMAKE_C_COMPILER="${ROCM_PATH}/lib/llvm/bin/amdclang"
    -DCMAKE_CXX_COMPILER="${ROCM_PATH}/lib/llvm/bin/amdclang++"
)

if [[ -n "${CMAKE_COMPILER_LAUNCHER}" ]]; then
    cmake_args+=(
        -DCMAKE_C_COMPILER_LAUNCHER="${CMAKE_COMPILER_LAUNCHER}"
        -DCMAKE_CXX_COMPILER_LAUNCHER="${CMAKE_COMPILER_LAUNCHER}"
    )
fi

configure_args=(-S "${LLAMA_SRC_DIR}" -B "${LLAMA_BUILD_DIR}" -G "${CMAKE_GENERATOR}")
cmake "${configure_args[@]}" "${cmake_args[@]}" "$@"

build_args=(--build "${LLAMA_BUILD_DIR}" --config "${CMAKE_BUILD_TYPE}" -j "${LLAMA_BUILD_JOBS:-$(nproc)}")
if [[ -n "${LLAMA_BUILD_TARGET}" ]]; then
    build_args+=(--target "${LLAMA_BUILD_TARGET}")
fi

cmake "${build_args[@]}"
