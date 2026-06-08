#!/usr/bin/env python3

from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
import re
import shutil
import tarfile
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from pathlib import Path, PurePosixPath


PLATFORM = "linux"

ARTIFACT_SETS = {
    "core": {
        "sysdeps": ["lib", "run", "dev"],
        "base": ["lib", "run", "dev"],
        "amd-llvm": ["lib", "run"],
        "core-runtime": ["lib", "run", "dev"],
        "core-amdsmi": ["lib", "run", "dev"],
        "aqlprofile": ["lib", "run", "dev"],
    },
    "core-with-llvm-dev": {
        "sysdeps": ["lib", "run", "dev"],
        "base": ["lib", "run", "dev"],
        "amd-llvm": ["lib", "run", "dev"],
        "core-runtime": ["lib", "run", "dev"],
        "core-amdsmi": ["lib", "run", "dev"],
        "aqlprofile": ["lib", "run", "dev"],
    },
    "core-with-upstream-hip": {
        "sysdeps": ["lib", "run", "dev"],
        "base": ["lib", "run", "dev"],
        "amd-llvm": ["lib", "run"],
        "core-runtime": ["lib", "run", "dev"],
        "core-amdsmi": ["lib", "run", "dev"],
        "aqlprofile": ["lib", "run", "dev"],
        "core-kpack": ["lib", "dev"],
        "core-hip": ["lib", "run", "dev"],
    },
}


@dataclass(frozen=True)
class S3Object:
    key: str
    size: int
    last_modified: str


def log(message: str = "") -> None:
    print(message, flush=True)


def env(name: str, default: str | None = None) -> str:
    value = os.environ.get(name, default)
    if value is None:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


def create_s3_client():
    try:
        from botocore import UNSIGNED
        from botocore.config import Config
        import boto3
    except ModuleNotFoundError as e:
        raise RuntimeError("Install boto3 and botocore to fetch ROCm artifacts") from e
    return boto3.client(
        "s3",
        region_name="us-east-2",
        config=Config(signature_version=UNSIGNED, max_pool_connections=64),
    )


def release_bucket(release_type: str) -> str:
    if release_type not in {"dev", "nightly", "prerelease"}:
        raise ValueError("HRX_RELEASE_TYPE must be dev, nightly, or prerelease")
    return f"therock-{release_type}-artifacts"


def list_prefix(s3, bucket: str, prefix: str) -> list[S3Object]:
    paginator = s3.get_paginator("list_objects_v2")
    objects: list[S3Object] = []
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        for obj in page.get("Contents", []):
            objects.append(
                S3Object(
                    key=obj["Key"],
                    size=obj["Size"],
                    last_modified=obj["LastModified"].isoformat(),
                )
            )
    return objects


def artifact_set_names(artifact_set: str) -> list[str]:
    try:
        mapping = ARTIFACT_SETS[artifact_set]
    except KeyError as e:
        raise ValueError(
            f"Unknown HRX_ARTIFACT_SET {artifact_set!r}; expected one of "
            f"{', '.join(sorted(ARTIFACT_SETS))}"
        ) from e
    return [
        f"{name}_{component}_generic"
        for name, components in mapping.items()
        for component in components
    ]


def wanted_artifacts() -> list[str]:
    explicit = os.environ.get("HRX_ROCM_ARTIFACTS", "").split()
    if explicit:
        return explicit
    base = artifact_set_names(env("HRX_ARTIFACT_SET", "core-with-upstream-hip"))
    extra = os.environ.get("HRX_EXTRA_ROCM_ARTIFACTS", "").split()
    return [*base, *extra]


def select_available(
    available: list[S3Object], prefix: str, wanted: list[str]
) -> tuple[list[S3Object], list[str]]:
    by_name: dict[str, S3Object] = {}
    for obj in available:
        filename = obj.key.removeprefix(prefix)
        if filename.endswith(".sha256sum"):
            continue
        if filename.endswith(".tar.zst"):
            by_name[filename.removesuffix(".tar.zst")] = obj
        elif filename.endswith(".tar.xz"):
            by_name.setdefault(filename.removesuffix(".tar.xz"), obj)
        elif filename.endswith(".tar.gz"):
            by_name.setdefault(filename.removesuffix(".tar.gz"), obj)
        elif filename.endswith(".tgz"):
            by_name.setdefault(filename.removesuffix(".tgz"), obj)
    selected = [by_name[name] for name in wanted if name in by_name]
    missing = [name for name in wanted if name not in by_name]
    return selected, missing


def discover_latest_run_id(s3, release_type: str, wanted: list[str]) -> str:
    bucket = release_bucket(release_type)
    paginator = s3.get_paginator("list_objects_v2")
    candidates: list[int] = []
    for page in paginator.paginate(Bucket=bucket, Delimiter="/"):
        for common_prefix in page.get("CommonPrefixes", []):
            match = re.match(r"^(\d+)-linux/$", common_prefix["Prefix"])
            if match:
                candidates.append(int(match.group(1)))
    for run_id in sorted(candidates, reverse=True):
        prefix = f"{run_id}-{PLATFORM}/"
        available = list_prefix(s3, bucket, prefix)
        _, missing = select_available(available, prefix, wanted)
        if not missing:
            return str(run_id)
    raise RuntimeError(
        f"Could not discover a complete {release_type} Linux ROCm artifact run"
    )


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def download_one(s3, bucket: str, obj: S3Object, cache_dir: Path) -> Path:
    dest = cache_dir / Path(obj.key).name
    if dest.exists() and dest.stat().st_size == obj.size:
        log(f"  == Cached {dest.name}")
        return dest
    log(f"  ++ Downloading {obj.key}")
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(dest.suffix + ".tmp")
    s3.download_file(bucket, obj.key, str(tmp))
    tmp.replace(dest)
    return dest


def download_checksum(s3, bucket: str, key: str, dest: Path) -> Path | None:
    checksum_key = f"{key}.sha256sum"
    checksum_dest = dest.with_name(dest.name + ".sha256sum")
    try:
        s3.download_file(bucket, checksum_key, str(checksum_dest))
    except Exception:
        return None
    return checksum_dest


def verify_checksum(archive_path: Path, checksum_path: Path | None) -> None:
    if checksum_path is None or not checksum_path.exists():
        log(f"  ?? No checksum for {archive_path.name}")
        return
    text = checksum_path.read_text().strip()
    if not text:
        log(f"  ?? Empty checksum for {archive_path.name}")
        return
    expected = text.split()[0]
    actual = sha256_file(archive_path)
    if actual != expected:
        raise RuntimeError(
            f"Checksum mismatch for {archive_path.name}: expected {expected}, got {actual}"
        )


def open_tar_archive(path: Path) -> tarfile.TarFile:
    if path.name.endswith(".tar.zst"):
        try:
            import zstandard
        except ModuleNotFoundError as e:
            raise RuntimeError("Install the zstandard Python package") from e
        backing_file = path.open("rb")
        stream = zstandard.ZstdDecompressor().stream_reader(backing_file)
        try:
            tf = tarfile.open(fileobj=stream, mode="r|")
        except Exception:
            stream.close()
            backing_file.close()
            raise
        tf._owned_streams = (stream, backing_file)  # type: ignore[attr-defined]
        return tf
    if path.name.endswith(".tar.xz"):
        return tarfile.open(path, mode="r:xz")
    if path.name.endswith(".tar.gz") or path.name.endswith(".tgz"):
        return tarfile.open(path, mode="r:gz")
    raise ValueError(f"Unsupported archive extension: {path}")


def close_tar_archive(tf: tarfile.TarFile) -> None:
    owned = getattr(tf, "_owned_streams", ())
    tf.close()
    for stream in owned:
        stream.close()


def checked_dest(base: Path, relpath: str) -> Path:
    rel = PurePosixPath(relpath)
    if rel.is_absolute() or ".." in rel.parts:
        raise RuntimeError(f"Unsafe archive path: {relpath}")
    dest = base / rel
    base_resolved = base.resolve()
    parent_resolved = dest.parent.resolve()
    if base_resolved != parent_resolved and base_resolved not in parent_resolved.parents:
        raise RuntimeError(f"Archive path escapes output directory: {relpath}")
    return dest


def strip_manifest_root(member_name: str, relroots: list[str]) -> str:
    for root in relroots:
        prefix = root.rstrip("/") + "/"
        if member_name.startswith(prefix):
            scoped = member_name[len(prefix) :]
            if scoped:
                return scoped
    raise RuntimeError(f"Archive member is outside manifest roots: {member_name}")


def remove_tree(path: Path) -> None:
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.exists():
        shutil.rmtree(path)


def flatten_therock_artifact(archive_path: Path, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    tf = open_tar_archive(archive_path)
    hardlinks: list[tuple[Path, str, list[str]]] = []
    try:
        manifest = tf.next()
        if manifest is None or manifest.name != "artifact_manifest.txt":
            raise RuntimeError(
                f"{archive_path.name} is not a TheRock artifact archive "
                "(artifact_manifest.txt was not the first member)"
            )
        manifest_file = tf.extractfile(manifest)
        if manifest_file is None:
            raise RuntimeError(f"Could not read manifest in {archive_path.name}")
        relroots = [line for line in manifest_file.read().decode().splitlines() if line]

        while member := tf.next():
            scoped_name = strip_manifest_root(member.name, relroots)
            dest_path = checked_dest(output_dir, scoped_name)
            if member.isdir():
                dest_path.mkdir(parents=True, exist_ok=True)
            elif member.isfile():
                dest_path.parent.mkdir(parents=True, exist_ok=True)
                if dest_path.exists() or dest_path.is_symlink():
                    dest_path.unlink()
                source = tf.extractfile(member)
                if source is None:
                    raise RuntimeError(f"Could not read {member.name}")
                with source, dest_path.open("wb") as out:
                    shutil.copyfileobj(source, out)
                mode = 0o666 | (member.mode & 0o111)
                os.chmod(dest_path, mode)
            elif member.issym():
                dest_path.parent.mkdir(parents=True, exist_ok=True)
                if dest_path.exists() or dest_path.is_symlink():
                    dest_path.unlink()
                dest_path.symlink_to(member.linkname)
            elif member.islnk():
                hardlinks.append((dest_path, member.linkname, relroots))
            else:
                raise RuntimeError(f"Unhandled tar member type: {member.name}")

        for dest_path, linkname, link_relroots in hardlinks:
            target_name = strip_manifest_root(linkname, link_relroots)
            target_path = checked_dest(output_dir, target_name)
            dest_path.parent.mkdir(parents=True, exist_ok=True)
            if dest_path.exists() or dest_path.is_symlink():
                dest_path.unlink()
            os.link(target_path, dest_path)
    finally:
        close_tar_archive(tf)


def write_manifest(
    path: Path,
    *,
    release_type: str,
    run_id: str,
    bucket: str,
    artifact_set: str,
    artifacts: list[S3Object],
) -> None:
    data = {
        "generated_at": dt.datetime.now(dt.UTC).isoformat(),
        "release_type": release_type,
        "run_id": run_id,
        "platform": PLATFORM,
        "bucket": bucket,
        "artifact_set": artifact_set,
        "artifacts": [obj.__dict__ for obj in artifacts],
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")


def main() -> None:
    release_type = env("HRX_RELEASE_TYPE", "nightly")
    artifact_set = env("HRX_ARTIFACT_SET", "core-with-upstream-hip")
    run_id = os.environ.get("HRX_RUN_ID", "")
    rocm_root = Path(env("HRX_ROCM_ROOT")).resolve()
    cache_dir = Path(env("HRX_DOWNLOAD_CACHE_DIR")).resolve()
    concurrency = int(env("HRX_DOWNLOAD_CONCURRENCY", "8"))
    wanted = wanted_artifacts()

    s3 = create_s3_client()
    if not run_id:
        run_id = discover_latest_run_id(s3, release_type, wanted)
        log(f"Resolved latest {release_type} Linux run id: {run_id}")

    bucket = release_bucket(release_type)
    prefix = f"{run_id}-{PLATFORM}/"
    available = list_prefix(s3, bucket, prefix)
    if not available:
        raise RuntimeError(f"No artifacts found at s3://{bucket}/{prefix}")

    selected, missing = select_available(available, prefix, wanted)
    if missing:
        raise RuntimeError("Missing required ROCm artifacts:\n  " + "\n  ".join(missing))

    log("ROCm artifacts selected:")
    for obj in selected:
        log(f"  {obj.key} ({obj.size / 1024 / 1024:.1f} MiB)")

    rocm_root.mkdir(parents=True, exist_ok=True)
    cache_dir.mkdir(parents=True, exist_ok=True)

    downloaded: list[tuple[S3Object, Path]] = []
    with ThreadPoolExecutor(max_workers=concurrency) as executor:
        futures = {
            executor.submit(download_one, s3, bucket, obj, cache_dir): obj
            for obj in selected
        }
        for future in as_completed(futures):
            obj = futures[future]
            downloaded.append((obj, future.result()))

    for obj, archive_path in sorted(downloaded, key=lambda item: item[1].name):
        checksum = download_checksum(s3, bucket, obj.key, archive_path)
        verify_checksum(archive_path, checksum)
        log(f"  ++ Flattening {archive_path.name}")
        flatten_therock_artifact(archive_path, rocm_root)

    write_manifest(
        rocm_root / ".hrx-rocm-artifacts.json",
        release_type=release_type,
        run_id=run_id,
        bucket=bucket,
        artifact_set=artifact_set,
        artifacts=selected,
    )
    log(f"ROCm build root ready: {rocm_root}")


if __name__ == "__main__":
    main()
