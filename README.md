# V100 LeRobot Docker image

Docker configuration for a combined Ubuntu 22.04 development and LeRobot 0.6.1
environment targeting Tesla V100 GPUs.

The agreed package, security, persistence, and acceptance checklist is in
[`DESIGN.md`](DESIGN.md). This repository intentionally excludes OpenPI, JAX,
uv, VS Code Server, and `pi05_deployments`.

## Files

```text
.
|-- DESIGN.md
|-- Dockerfile
|-- condarc
|-- pip.conf
|-- requirements-lerobot.txt
|-- assets/vla-v100.pub
|-- config/sshd_config
`-- scripts/
    |-- check_environment.py
    |-- ensure-sshd.sh
    |-- enable-public-mirrors.sh
    |-- entrypoint.sh
    |-- nvidia-smi.sh
    `-- sshd.sh
```

## Build

The baseline 0.1 image was built successfully on 2026-10-18:

```text
tag:       vla-lerobot-v100:0.1
platform:  linux/amd64
image ID:  sha256:7ac9c1ccae6b8ef2911ad63600d24845f3d59d303d64275410a4ca4a3cee467e
```

To rebuild it from this directory:

```bash
docker build --progress=plain -t vla-lerobot-v100:0.1 .
```

The default build uses Chinese mirrors. Each mirror URL is an overridable build
argument; see the top of `Dockerfile`.

That baseline build passed `pip check`, the Dockerfile build check, and the
CPU-only import/version check. A local container also passed its SSH startup,
host-key generation, authorized-key permissions, default working directory,
and command-availability checks. GPU access cannot be tested on this build host
and remains part of the remote V100 acceptance.

Rebuild and repeat the acceptance checks after changing the image sources;
the baseline image ID above does not describe later unbuilt changes.

The entrypoint starts SSH even when a hosting platform replaces the image's
default command with `sleep infinity`. When the normal SSH foreground command
is retained, the entrypoint only prepares and validates SSH before executing
that command.

## Run

The external shared storage can be mounted at `/root/data1`:

```bash
docker run -d \
  --name vla-v100 \
  --gpus all \
  --ipc=host \
  -p 2222:22 \
  -v /host/path/to/data1:/root/data1 \
  vla-lerobot-v100:0.1
```

Then connect with the private key matching `assets/vla-v100.pub`:

```bash
ssh -p 2222 root@HOST
```

Login shells start in `/root`. `/root/data1` remains a shared data directory;
the image does not place caches, a workspace, or SSH keys there. Each tool keeps
its normal default paths unless you override them at runtime.

Run the non-downloading environment check after connecting:

```bash
python /usr/local/share/v100-image/check_environment.py --require-gpu
```

The check exercises FP32 matrix multiplication on every visible GPU. Model
download and PI0.5 inference remain separate acceptance steps.

The target platform currently injects a broken `/usr/bin/nvidia-smi` wrapper.
This image therefore puts a driver-matched fallback in `/opt/nvidia-fallback`
and exposes it as `/usr/local/bin/nvidia-smi`, which precedes `/usr/bin` on
`PATH`. The fallback is pinned to host driver `535.154.05`; revalidate or
update it before using the image on a different driver pool.

## Optional public mirrors

For public Hugging Face files only:

```bash
source /usr/local/share/v100-image/enable-public-mirrors.sh
```

The script also defines `github_public_url`, which prints a proxied URL for a
public GitHub archive or release. Do not use either third-party service for
tokens, gated models, or private repositories. Open a new shell or run
`unset HF_ENDPOINT` before accessing gated Hugging Face resources.

