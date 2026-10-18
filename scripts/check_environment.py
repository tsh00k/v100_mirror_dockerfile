#!/usr/bin/env python3
"""Check the baked Python stack and, optionally, every visible CUDA device."""

from __future__ import annotations

import argparse
import importlib
import importlib.metadata
import subprocess
import sys


EXPECTED_VERSIONS = {
    "lerobot": "0.6.1",
    "torch": "2.7.1+cu118",
    "torchvision": "0.22.1+cu118",
    "torchaudio": "2.7.1+cu118",
}

IMPORTS = (
    "accelerate",
    "av",
    "cv2",
    "datasets",
    "einops",
    "h5py",
    "huggingface_hub",
    "imageio",
    "lerobot",
    "matplotlib",
    "numpy",
    "pandas",
    "peft",
    "PIL",
    "pyarrow",
    "safetensors",
    "scipy",
    "seaborn",
    "sklearn",
    "tensorboard",
    "torch",
    "torchcodec",
    "torchaudio",
    "torchvision",
    "transformers",
    "wandb",
    "lerobot.policies.pi05.modeling_pi05",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--imports-only",
        action="store_true",
        help="check package imports and versions without probing NVIDIA tools",
    )
    parser.add_argument(
        "--require-gpu",
        action="store_true",
        help="fail unless CUDA is available and an FP32 operation succeeds on every GPU",
    )
    return parser.parse_args()


def check_imports() -> None:
    for module_name in IMPORTS:
        importlib.import_module(module_name)

    for distribution, expected in EXPECTED_VERSIONS.items():
        actual = importlib.metadata.version(distribution)
        if actual != expected:
            raise RuntimeError(f"{distribution}: expected {expected}, found {actual}")


def check_gpu(require_gpu: bool) -> None:
    import torch

    print(f"torch={torch.__version__} torch.version.cuda={torch.version.cuda}")
    print(f"cuda_available={torch.cuda.is_available()}")

    if not torch.cuda.is_available():
        if require_gpu:
            raise RuntimeError("CUDA is required but PyTorch cannot access a GPU")
        return

    device_count = torch.cuda.device_count()
    print(f"visible_cuda_devices={device_count}")
    for index in range(device_count):
        name = torch.cuda.get_device_name(index)
        capability = torch.cuda.get_device_capability(index)
        print(f"cuda:{index} name={name!r} capability={capability}")

        left = torch.ones((64, 64), device=index, dtype=torch.float32)
        right = torch.ones((64, 64), device=index, dtype=torch.float32)
        result = left @ right
        torch.cuda.synchronize(index)
        if result[0, 0].item() != 64.0:
            raise RuntimeError(f"cuda:{index} produced an invalid FP32 result")


def main() -> int:
    args = parse_args()
    check_imports()
    print("Python imports and pinned versions: OK")

    if not args.imports_only:
        try:
            completed = subprocess.run(
                ["nvidia-smi"],
                check=False,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
            )
        except FileNotFoundError:
            print("nvidia-smi: not found")
            if args.require_gpu:
                raise RuntimeError("nvidia-smi was not injected into the container")
        else:
            print(completed.stdout, end="")
            if args.require_gpu and completed.returncode != 0:
                raise RuntimeError(f"nvidia-smi exited with {completed.returncode}")

        check_gpu(args.require_gpu)

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)

