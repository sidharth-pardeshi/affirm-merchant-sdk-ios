#!/usr/bin/env python3
from __future__ import annotations

import argparse
import pathlib
import plistlib
import shutil
import tempfile
import zipfile


def parse_env(values: list[str]) -> dict[str, str]:
    result: dict[str, str] = {}
    for value in values:
        if "=" not in value:
            raise SystemExit(f"Expected --env KEY=VALUE, got {value!r}")
        key, env_value = value.split("=", 1)
        if not key:
            raise SystemExit(f"Expected non-empty env key in {value!r}")
        result[key] = env_value
    return result


def patch_xctestrun(path: pathlib.Path, environment: dict[str, str], only_testing: str) -> None:
    data = plistlib.loads(path.read_bytes())
    if not isinstance(data, dict):
        raise RuntimeError(f"{path} did not contain an XCTest plist dictionary")

    patched_targets = 0
    for target_config in data.values():
        if not isinstance(target_config, dict):
            continue
        existing_environment = target_config.get("EnvironmentVariables")
        if not isinstance(existing_environment, dict):
            existing_environment = {}
        existing_environment.update(environment)
        target_config["EnvironmentVariables"] = existing_environment
        target_config["OnlyTestIdentifiers"] = [only_testing]
        patched_targets += 1

    if patched_targets == 0:
        raise RuntimeError(f"No XCTest target configurations found in {path}")
    path.write_bytes(plistlib.dumps(data))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Patch an XCTest zip with Thor runtime environment values.")
    parser.add_argument("--input", type=pathlib.Path, required=True)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    parser.add_argument("--only-testing", required=True)
    parser.add_argument("--env", action="append", default=[])
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    environment = parse_env(args.env)

    with tempfile.TemporaryDirectory() as tmp:
        extract_dir = pathlib.Path(tmp)
        with zipfile.ZipFile(args.input) as archive:
            archive.extractall(extract_dir)

        xctestrun_files = sorted(extract_dir.glob("*.xctestrun"))
        if len(xctestrun_files) != 1:
            raise RuntimeError(f"Expected exactly one .xctestrun file in {args.input}, found {len(xctestrun_files)}")

        patch_xctestrun(xctestrun_files[0], environment, args.only_testing)

        args.output.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(suffix=".zip", delete=False) as tmp_zip:
            tmp_zip_path = pathlib.Path(tmp_zip.name)
        try:
            with zipfile.ZipFile(tmp_zip_path, "w", zipfile.ZIP_DEFLATED) as archive:
                for path in sorted(extract_dir.rglob("*")):
                    if path.is_file():
                        archive.write(path, path.relative_to(extract_dir))
            shutil.move(tmp_zip_path, args.output)
        finally:
            if tmp_zip_path.exists():
                tmp_zip_path.unlink()

    print(f"Wrote patched XCTest zip to {args.output}", flush=True)


if __name__ == "__main__":
    main()
