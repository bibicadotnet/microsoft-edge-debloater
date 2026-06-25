#!/usr/bin/env python3

import argparse
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path


def find_default_cab(root: Path, channel: str, major: str) -> Path:
    candidates = sorted((root / channel / major).glob("MicrosoftEdgePolicyTemplates_macOS-*.cab"))
    if not candidates:
        raise FileNotFoundError(f"No macOS policy template CAB found under {root / channel / major}")
    return candidates[0]


def require_bsdtar() -> str:
    path = shutil.which("bsdtar")
    if not path:
        raise RuntimeError("bsdtar is required to extract Microsoft CAB files")
    return path


def extract_cab(cab_path: Path, target_dir: Path) -> Path:
    subprocess.run([require_bsdtar(), "-xf", str(cab_path), "-C", str(target_dir)], check=True)
    zip_path = target_dir / "MicrosoftEdgePolicyTemplates.zip"
    if not zip_path.exists():
        raise FileNotFoundError(f"{cab_path} did not contain MicrosoftEdgePolicyTemplates.zip")
    return zip_path


def extract_manifest(zip_path: Path, output_path: Path) -> None:
    with zipfile.ZipFile(zip_path) as archive:
        with archive.open("mac/policy_manifest.json") as source:
            output_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_bytes(source.read())


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Extract Microsoft Edge macOS policy_manifest.json from a policy template CAB.")
    parser.add_argument("--cab", type=Path)
    parser.add_argument("--channel", default="Stable")
    parser.add_argument("--major", default="149")
    parser.add_argument("--templates-root", type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument("--output", type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    cab_path = args.cab or find_default_cab(args.templates_root, args.channel, args.major)
    output_path = args.output or args.templates_root / args.channel / args.major / "mac" / "policy_manifest.json"

    with tempfile.TemporaryDirectory() as directory:
        zip_path = extract_cab(cab_path.resolve(), Path(directory))
        extract_manifest(zip_path, output_path.resolve())

    print(output_path)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(error, file=sys.stderr)
        raise SystemExit(1)
