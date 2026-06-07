# llamacpp_ci

This repository contains GitHub Actions and local build scripts for validating the HRX runtime build and the pinned llama.cpp HRX backend integration.

The CI job builds HRX from a pinned ROCm/hrx revision on the default `ubuntu-latest` GitHub runner, validates the installed HRX runtime, then builds pinned ROCm/llama.cpp with `GGML_HRX=ON`. ROCm toolchain and runtime dependencies are fetched from HRX/TheRock ROCm assets instead of installing full ROCm packages from apt.

## What Gets Built

The active workflow builds HRX, validates the HRX install with `hrx-info --device=cpu:0`, then builds llama.cpp with the HRX backend enabled.

The HRX source revision and related repository pins live in:

```text
scripts/hrx/versions.sh
```

Current pinned inputs are:

- `ROCm/hrx` main checksum for the HRX build.
- `ROCm/llama.cpp` `hrx-integration` checksum for scripts that need a matching llama.cpp checkout.

## GitHub Actions

The workflow is defined in:

```text
.github/workflows/build-hrx.yml
```

It performs these steps:

1. Check out this CI repository.
2. Install base build dependencies.
3. Restore/configure ccache.
4. Check out the pinned HRX revision.
5. Fetch ROCm assets using HRX's asset-fetching support.
6. Configure, build, and install HRX with `amdclang` and `amdclang++` from those assets.
7. Validate the HRX install with `hrx-info --device=cpu:0`.
8. Check out pinned `ROCm/llama.cpp`.
9. Configure and build llama.cpp with `GGML_HRX=ON`.

Workflow dispatch inputs control the ROCm asset selection:

- `hrx_release_type`
- `hrx_run_id`
- `hrx_artifact_set`

The HRX repository and checkout revision are intentionally controlled by `scripts/hrx/versions.sh`, not workflow dispatch inputs.

## Local Build

Run the same HRX build flow locally with:

```sh
scripts/hrx/local-build-hrx.sh
```

Build the HRX+llama.cpp HRX flow locally with:

```sh
scripts/hrx/local-build-llama.sh
```

Prepare source checkouts and ROCm assets locally with:

```sh
scripts/hrx/local-build-setup.sh
```

By default, local generated files are placed under ignored paths:

```text
assets/hrx-src
assets/hrx-rocm-root
assets/hrx-rocm-downloads
build-hrx
build-hrx-install
assets/llama-src
assets/llama-src/build-hrx
```

For `local-build-hrx.sh` to run correctly, run `local-build-setup.sh` first (or otherwise ensure sources and assets are already prepared), then it runs:

```text
scripts/hrx/build-hrx.sh
scripts/hrx/validate-hrx.sh
```

`scripts/hrx/local-build-llama.sh` runs:

```text
scripts/hrx/build-llama-hrx.sh
```

`scripts/hrx/local-build-setup.sh` runs:

```text
scripts/hrx/checkout-hrx.sh
scripts/hrx/checkout-llama.sh
scripts/hrx/fetch-rocm-assets.sh
```

## Script Layout

- `scripts/hrx/versions.sh`: pinned upstream repository revisions.
- `scripts/hrx/env.sh`: shared default environment values.
- `scripts/hrx/checkout-repo.sh`: exact checkout helper used by HRX and llama.cpp checkout scripts.
- `scripts/hrx/checkout-hrx.sh`: checks out pinned HRX.
- `scripts/hrx/fetch-rocm-assets.sh`: fetches and exposes ROCm assets.
- `scripts/hrx/build-hrx.sh`: configures and builds HRX.
- `scripts/hrx/validate-hrx.sh`: validates the installed HRX runtime with a CPU smoke test.
- `scripts/hrx/checkout-llama.sh`: checks out pinned ROCm/llama.cpp.
- `scripts/hrx/build-llama-hrx.sh`: configures and builds llama.cpp with the HRX backend.
- `scripts/hrx/run-build.sh`: full HRX checkout, ROCm asset fetch, build, and validation flow.
- `scripts/hrx/local-build-hrx.sh`: local entrypoint using ignored repo-local output paths.
- `scripts/hrx/local-build-llama.sh`: local entrypoint for full HRX + llama.cpp HRX build flow.
- `scripts/hrx/local-build-setup.sh`: local setup entrypoint for repository checkouts and ROCm asset fetch.
- `scripts/hrx/ci-build-hrx.sh`: CI entrypoint.

## Notes

Generated build outputs and downloaded assets are ignored by `.gitignore`.

`AGENTS.md` is local branch guidance for Codex work and should not be committed.
