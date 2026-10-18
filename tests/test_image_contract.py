#!/usr/bin/env python3
"""Static regression tests for the V100 image's runtime contracts."""

from __future__ import annotations

import os
from pathlib import Path
import unittest


def find_project_root() -> Path:
    override = os.environ.get("V100_MIRROR_ROOT")
    if override:
        return Path(override)

    start = Path(__file__).resolve().parent
    for candidate in (start, *start.parents):
        if (candidate / "Dockerfile").is_file():
            return candidate
    raise RuntimeError("could not find the V100 mirror project root")


ROOT = find_project_root()


class ImageContractTests(unittest.TestCase):
    def read(self, relative_path: str) -> str:
        return (ROOT / relative_path).read_text(encoding="utf-8")

    def test_platform_cmd_override_still_starts_sshd(self) -> None:
        entrypoint = self.read("scripts/entrypoint.sh")
        self.assertIn('/usr/local/sbin/ensure-sshd', entrypoint)
        self.assertIn('exec "$@"', entrypoint)

    def test_ssh_helpers_are_baked_into_the_image(self) -> None:
        dockerfile = self.read("Dockerfile")
        ensure_sshd = self.read("scripts/ensure-sshd.sh")
        sshd_wrapper = self.read("scripts/sshd.sh")
        self.assertIn(
            "COPY scripts/ensure-sshd.sh /usr/local/sbin/ensure-sshd",
            dockerfile,
        )
        self.assertIn("COPY scripts/sshd.sh /usr/local/bin/sshd", dockerfile)
        self.assertIn("pgrep -x sshd", ensure_sshd)
        self.assertIn('/usr/sbin/sshd -f "${config}"', ensure_sshd)
        self.assertIn('exec /usr/sbin/sshd "$@"', sshd_wrapper)
        self.assertIn('CMD ["/usr/sbin/sshd", "-D", "-e"', dockerfile)

    def test_nvidia_smi_fallback_avoids_platform_mountpoint(self) -> None:
        dockerfile = self.read("Dockerfile")
        wrapper = self.read("scripts/nvidia-smi.sh")
        self.assertIn("ARG NVIDIA_DRIVER_VERSION=535.154.05", dockerfile)
        self.assertIn("apt-get download", dockerfile)
        self.assertIn("/opt/nvidia-${NVIDIA_DRIVER_VERSION}", dockerfile)
        self.assertIn("/opt/nvidia-fallback", wrapper)
        self.assertNotRegex(wrapper, r'exec\s+["\']?/usr/bin/nvidia-smi')

    def test_httpx_socks_dependency_is_explicit(self) -> None:
        requirements = self.read("requirements-lerobot.txt")
        environment_check = self.read("scripts/check_environment.py")
        self.assertRegex(requirements, r"(?m)^socksio(?:\s|$)")
        self.assertRegex(environment_check, r'(?m)^\s+"socksio",$')


if __name__ == "__main__":
    unittest.main()
