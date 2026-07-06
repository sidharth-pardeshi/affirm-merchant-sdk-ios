#!/usr/bin/env python3
"""Select a Firebase Test Lab iOS device axis with usable capacity."""

import argparse
import json
import subprocess
import sys
import urllib.parse
import urllib.request


CAPACITY_RANK = {
    "DEVICE_CAPACITY_HIGH": 0,
    "DEVICE_CAPACITY_MEDIUM": 1,
    "DEVICE_CAPACITY_LOW": 2,
    "DEVICE_CAPACITY_UNSPECIFIED": 3,
}


def version_sort_key(version):
    major = int(version.get("majorVersion", 0))
    minor = int(version.get("minorVersion", 0))

    # Prefer iOS 17 for an Xcode 15 / iOS 17.0 XCTest bundle. Avoid iOS 18+ until
    # Firebase video/result behavior and Xcode compatibility are intentionally updated.
    if major == 17:
        major_rank = 0
    elif major == 16:
        major_rank = 1
    elif major == 15:
        major_rank = 2
    else:
        major_rank = 3

    return major_rank, -major, -minor


def has_reduced_stability(tags, version_id):
    for tag in tags:
        normalized = tag.lower()
        if "reduced_stability" in normalized and (version_id in tag or ":" not in tag):
            return True
    return False


def load_catalog(project):
    token = subprocess.check_output(
        ["gcloud", "auth", "print-access-token"],
        text=True,
    ).strip()
    query = urllib.parse.urlencode({"projectId": project})
    request = urllib.request.Request(
        f"https://testing.googleapis.com/v1/testEnvironmentCatalog/IOS?{query}",
        headers={"Authorization": f"Bearer {token}"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)["iosDeviceCatalog"]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True)
    parser.add_argument(
        "--avoid-axis",
        action="append",
        default=["iphone14pro:16.6"],
        help="Axis to avoid, formatted as model:version.",
    )
    args = parser.parse_args()

    catalog = load_catalog(args.project)
    versions = {version["id"]: version for version in catalog.get("versions", [])}
    avoid_axes = set(args.avoid_axis)
    candidates = []

    for model in catalog.get("models", []):
        model_id = model.get("id", "")
        model_tags = model.get("tags", [])
        normalized_tags = [tag.lower() for tag in model_tags]
        if "deprecated" in normalized_tags:
            continue
        if "PHONE" not in model.get("formFactor", ""):
            continue

        capacity_by_version = {
            item.get("versionId"): item.get("deviceCapacity", "DEVICE_CAPACITY_UNSPECIFIED")
            for item in model.get("perVersionInfo", [])
        }

        for version_id in model.get("supportedVersionIds", []):
            version = versions.get(version_id)
            if not version:
                continue
            if f"{model_id}:{version_id}" in avoid_axes:
                continue
            if has_reduced_stability(model_tags + version.get("tags", []), version_id):
                continue

            capacity = capacity_by_version.get(version_id, "DEVICE_CAPACITY_UNSPECIFIED")
            capacity_rank = CAPACITY_RANK.get(capacity, 3)
            if capacity_rank > 1:
                continue

            candidates.append(
                (
                    capacity_rank,
                    version_sort_key(version),
                    model.get("name", ""),
                    model_id,
                    version_id,
                    capacity,
                )
            )

    if not candidates:
        print("No suitable Firebase iOS device axis found.", file=sys.stderr)
        return 1

    _, _, model_name, model_id, version_id, capacity = sorted(candidates)[0]
    print(
        f"Selected Firebase iOS device: {model_name} ({model_id}) iOS {version_id} "
        f"with {capacity}",
        file=sys.stderr,
    )
    print(f"model={model_id},version={version_id},locale=en,orientation=portrait")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
