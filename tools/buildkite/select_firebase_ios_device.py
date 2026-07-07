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
    "DEVICE_CAPACITY_LOW": 4,
    "DEVICE_CAPACITY_UNSPECIFIED": 5,
    "DEVICE_CAPACITY_NONE": 6,
}


def capacity_sort_key(capacity):
    if capacity in {"DEVICE_CAPACITY_HIGH", "DEVICE_CAPACITY_MEDIUM"}:
        return 0
    elif capacity == "DEVICE_CAPACITY_LOW":
        return 1
    elif capacity == "DEVICE_CAPACITY_UNSPECIFIED":
        return 2
    return 3


def version_sort_key(version):
    major = int(version.get("majorVersion", 0))
    minor = int(version.get("minorVersion", 0))

    # Prefer the newest non-deprecated iOS generation supported by the pinned
    # Firebase Xcode runner while still allowing older versions as fallbacks.
    if major == 18:
        major_rank = 0
    elif major == 17:
        major_rank = 1
    elif major == 16:
        major_rank = 2
    elif major == 15:
        major_rank = 3
    else:
        major_rank = 4

    return major_rank, -major, -minor


def has_reduced_stability(tags, version_id):
    for tag in tags:
        normalized = tag.lower()
        if "reduced_stability" in normalized and (
            version_id in tag or ("=" not in tag and ":" not in tag)
        ):
            return True
    return False


def has_model_deprecated_tag(tags):
    for tag in tags:
        normalized = tag.lower()
        if "deprecated" in normalized and "=" not in tag and ":" not in tag:
            return True
    return False


def has_deprecated_axis_tag(tags, version_id):
    for tag in tags:
        normalized = tag.lower()
        if "deprecated" in normalized and (
            version_id in tag or ("=" not in tag and ":" not in tag)
        ):
            return True
    return False


def device_kind_sort_key(model):
    model_id = model.get("id", "").lower()
    model_name = model.get("name", "").lower()
    form_factor = model.get("formFactor", "").lower()

    if "tablet" in form_factor or model_id.startswith("ipad") or "ipad" in model_name:
        return 1
    if "phone" in form_factor or model_id.startswith("iphone") or "iphone" in model_name:
        return 0

    # The iOS catalog does not always expose the same formFactor values as the
    # Android catalog. Treat unknown non-deprecated models as candidates and let
    # Firebase validate the final axis, but prefer explicit iPhone/iPad models.
    return 2


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
    parser.add_argument(
        "--limit",
        type=int,
        default=1,
        help="Maximum number of device specs to print.",
    )
    parser.add_argument(
        "--max-major-version",
        type=int,
        default=18,
        help="Maximum iOS major version to select.",
    )
    args = parser.parse_args()

    catalog = load_catalog(args.project)
    versions = {version["id"]: version for version in catalog.get("versions", [])}
    avoid_axes = set(args.avoid_axis)
    excluded_counts = {
        "deprecated_model": 0,
        "missing_version": 0,
        "avoided_axis": 0,
        "deprecated_axis": 0,
        "reduced_stability": 0,
        "unsupported_major_version": 0,
    }
    candidates = []

    for model in catalog.get("models", []):
        model_id = model.get("id", "")
        model_tags = model.get("tags", [])
        if has_model_deprecated_tag(model_tags):
            excluded_counts["deprecated_model"] += 1
            continue

        capacity_by_version = {
            item.get("versionId"): item.get("deviceCapacity", "DEVICE_CAPACITY_UNSPECIFIED")
            for item in model.get("perVersionInfo", [])
        }

        for version_id in model.get("supportedVersionIds", []):
            version = versions.get(version_id)
            if not version:
                excluded_counts["missing_version"] += 1
                continue
            if int(version.get("majorVersion", 0)) > args.max_major_version:
                excluded_counts["unsupported_major_version"] += 1
                continue
            if f"{model_id}:{version_id}" in avoid_axes:
                excluded_counts["avoided_axis"] += 1
                continue
            if has_deprecated_axis_tag(model_tags + version.get("tags", []), version_id):
                excluded_counts["deprecated_axis"] += 1
                continue
            if has_reduced_stability(model_tags + version.get("tags", []), version_id):
                excluded_counts["reduced_stability"] += 1
                continue

            capacity = capacity_by_version.get(version_id, "DEVICE_CAPACITY_UNSPECIFIED")
            candidates.append(
                (
                    capacity_sort_key(capacity),
                    device_kind_sort_key(model),
                    version_sort_key(version),
                    CAPACITY_RANK.get(capacity, 5),
                    model.get("name", ""),
                    model_id,
                    version_id,
                    capacity,
                )
            )

    if not candidates:
        print(
            "No suitable Firebase iOS device axis found. "
            f"models={len(catalog.get('models', []))} versions={len(versions)} "
            f"excluded={excluded_counts}",
            file=sys.stderr,
        )
        return 1

    for _, _, _, _, model_name, model_id, version_id, capacity in sorted(candidates)[
        : max(1, args.limit)
    ]:
        print(
            f"Selected Firebase iOS device candidate: {model_name} ({model_id}) "
            f"iOS {version_id} with {capacity}",
            file=sys.stderr,
        )
        print(f"model={model_id},version={version_id},locale=en,orientation=portrait")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
