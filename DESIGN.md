# V100 LeRobot development image design

Last updated: 2026-10-18

This document is the agreed design checklist for the image. It is deliberately
limited to LeRobot development and PI0.5 inference/smoke runs on Tesla V100
GPUs. OpenPI, JAX, uv, VS Code Server, and the obsolete `pi05_deployments`
scripts are outside this image.

## Target and constraints

- Host: Ubuntu/Linux with NVIDIA Container Toolkit.
- GPUs: 2 to 6 Tesla V100-SXM2-32GB-LS (`sm_70`). The image does not encode a
  fixed GPU count; visibility is selected with Docker's `--gpus` option.
- Known host driver: `535.154.05` (reports CUDA capability 12.2).
- Workload: LeRobot 0.6.1 PI0.5 FP32 inference and short smoke training. A full
  LoRA run is not a delivery requirement.
- External shared storage: `/root/data1`, supplied as a mount and shared by all
  users of the machine. The image treats it as shared data, not as a home or
  cache directory.
- GPU acceptance is performed on the remote V100 host, not on the build host.

## CUDA and NVIDIA boundary

- Base image: `nvcr.io/nvidia/cuda:11.8.0-devel-ubuntu22.04` from NVIDIA NGC.
  Its Linux/amd64 manifest digest matches the corresponding Docker Hub image;
  NGC avoids relying on Docker Hub's unreachable authentication endpoint.
- PyTorch stack: 2.7.1 cu118, torchvision 0.22.1 cu118, and torchaudio 2.7.1
  cu118.
- The host driver's reported CUDA 12.2 is its maximum supported CUDA driver API
  level. It does not require a CUDA 12.2 userspace in the container.
- The Dockerfile never installs an NVIDIA kernel driver, `nvidia-utils`, or a
  replacement `libnvidia-ml.so`. `nvidia-smi` and the driver libraries must be
  injected by NVIDIA Container Toolkit. This avoids the driver/library mismatch
  that damaged the old image.
- The runtime must use `--gpus all` (or an explicit subset). PyTorch/NCCL will
  discover 2 to 6 visible GPUs dynamically.

## System packages

APT uses the TUNA Ubuntu mirror and installs:

- Build: `build-essential`, `cmake`, `ninja-build`, `pkg-config`.
- Version control: `git`, `git-lfs`.
- Download/security: `curl`, `wget`, `ca-certificates`, `gnupg`.
- SSH: `openssh-client`, `openssh-server`.
- Archives/files: `rsync`, `zip`, `unzip`, `tar`, `xz-utils`, `bzip2`.
- CLI/editor: `jq`, `less`, `vim`, `nano`, `tmux`, `tree`, `ripgrep`,
  `fd-find`.
- Inspection/network: `htop`, `procps`, `psmisc`, `lsof`, `strace`, `pciutils`,
  `usbutils`, `iproute2`, `iputils-ping`, `net-tools`, `dnsutils`,
  `netcat-openbsd`.
- Media/runtime: `ffmpeg`, `libgl1`, `libglib2.0-0`, `libsndfile1`.
- Container basics: `bash-completion`, `locales`, `tzdata`, `sudo`, `tini`.

`systemd` is intentionally absent. A normal Docker container does not run
systemd as PID 1; `tini` is PID 1 and launches `sshd` directly.

## Conda and Python

- Miniconda is installed globally at `/opt/conda`.
- Conda base remains an environment-management layer only.
- The project environment is `/opt/conda/envs/lerobot`, using Python 3.12.
- `/opt/conda/envs/lerobot/bin` is first on `PATH`; interactive Bash also
  activates the environment.
- No project packages are installed into Ubuntu's system Python.
- The only Conda channel is `conda-forge` through TUNA (`nodefaults` plus an
  explicit `--override-channels`). PyPI uses TUNA by default.
- The three cu118 wheels are fetched directly from SJTUG and verified by their
  published SHA-256 fragments.

Core Python versions and extras:

```text
lerobot[peft,pi,training]==0.6.1
torch==2.7.1+cu118
torchvision==0.22.1+cu118
torchaudio==2.7.1+cu118
torchcodec>=0.5,<0.6
numpy>=2.0,<2.3
transformers>=5.4,<5.6
```

The `pi` extra provides the Transformers and SciPy dependencies used by PI0.5.
The `training` extra provides dataset/video, Accelerate, and W&B dependencies.
The `peft` extra supplies the constrained PEFT dependency used by LoRA tooling.
TorchCodec is constrained to the official release line paired with PyTorch 2.7
instead of allowing pip to choose a newer ABI-incompatible release.

Direct packages that overlap LeRobot extras repeat LeRobot's compatible version
bounds. This prevents pip from exhaustively backtracking through newer,
incompatible releases while retaining patch-level updates.

Common packages include SciPy, pandas, scikit-learn, h5py, PyArrow,
Matplotlib, Seaborn, Pillow, headless OpenCV, imageio, PyAV, einops,
safetensors, TensorBoard, W&B, tqdm, Rich, Datasets, Accelerate, Hugging Face
Hub, peft, IPython, JupyterLab, ipykernel, pytest, and Ruff.

TensorFlow, JAX, OpenPI, FlashAttention, and uv are not installed. A future
OpenPI checkout should own its own workspace-local uv environment because its
NumPy and Transformers requirements conflict with LeRobot 0.6.1.

## Filesystem and shared storage

- Login shells and the container default command start in `/root`.
- Hugging Face, Torch, pip, Conda, Matplotlib, and W&B retain their normal
  default locations. The image does not redirect caches into shared storage.
- `/root/data1` is only an externally mounted, shared data directory. The image
  does not create a workspace, caches, SSH material, or other private state in
  it.
- The Conda installation remains in the image at `/opt/conda`; installing new
  packages into it at runtime is not persistent across a new container.
- No Docker `VOLUME` instruction is used. The caller explicitly mounts the
  shared storage at `/root/data1`, preventing an accidental anonymous volume.

## SSH policy

- Root login is public-key only: `PermitRootLogin prohibit-password`.
- Password and keyboard-interactive authentication are disabled.
- `vla-v100.pub` is installed as `/root/.ssh/authorized_keys`.
- Expected key fingerprint:
  `SHA256:q/+K5ORLl6RPqFpsqY2NP6lnQkUQFRBqP4vJyI3AmAg`.
- RSA and ED25519 server host keys are generated at container start under
  `/etc/ssh`. They are deliberately not written to the shared `/root/data1`.
- The default command is `/usr/sbin/sshd -D -e`; port 22 is exposed.

Do not bake private keys, Hugging Face tokens, GitHub tokens, or W&B keys into
the image.

## Network policy

Build-time defaults:

- APT: TUNA Ubuntu.
- Conda: TUNA Anaconda/conda-forge.
- PyPI: TUNA PyPI.
- PyTorch cu118 wheels: SJTUG.

Runtime public-resource acceleration is opt-in via
`scripts/enable-public-mirrors.sh`:

- Hugging Face public resources: `https://hf-mirror.com`.
- Public GitHub archives/releases: URL helper for `https://ghfast.top/`.

Never route credentials, private repositories, or gated Hugging Face downloads
through a third-party mirror. PI0.5's gated dependencies must use the official
Hugging Face endpoint with a runtime-provided token.

## Verification boundary

The Dockerfile performs CPU-only import/version checks and `pip check` during
every build. The entrypoint validates the SSH configuration after creating host
keys. `scripts/check_environment.py` can inspect the GPU runtime without
downloading a model.

The remote acceptance owner should verify:

1. `nvidia-smi` reports all selected V100 devices without an NVML mismatch.
2. PyTorch reports CUDA 11.8, all expected devices, and capability `(7, 0)`.
3. A small FP32 CUDA matrix multiplication succeeds on every visible GPU.
4. LeRobot imports and the desired gated PI0.5 checkpoint downloads from the
   official Hugging Face service.
5. PI0.5 inference or a short smoke training run fits the intended device
   placement. The image does not promise that a full model replica fits on each
   32 GB card.

