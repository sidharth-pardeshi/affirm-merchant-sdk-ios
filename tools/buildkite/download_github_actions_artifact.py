#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import pathlib
import shutil
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile


def env(name: str) -> str | None:
    value = os.environ.get(name)
    return value if value not in (None, "") else None


def github_request(token: str, path: str) -> dict[str, object]:
    request = urllib.request.Request(
        f"https://api.github.com{path}",
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            raw = response.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as error:
        details = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"GitHub API GET {path} failed: {error.code} {details}") from error


def download(token: str, url: str, destination: pathlib.Path) -> None:
    class NoRedirectHandler(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, newurl):
            return None

    opener = urllib.request.build_opener(NoRedirectHandler)
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )

    try:
        opener.open(request, timeout=30)
    except urllib.error.HTTPError as error:
        if error.code not in (301, 302, 303, 307, 308):
            details = error.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"GitHub artifact download failed: {error.code} {details}") from error
        redirect_url = error.headers.get("Location")
        if redirect_url is None:
            raise RuntimeError(f"GitHub artifact download redirect did not include Location header: {error.code}") from error
    else:
        raise RuntimeError("GitHub artifact download did not return the expected signed artifact redirect")

    signed_request = urllib.request.Request(urllib.parse.urljoin(url, redirect_url))
    try:
        with urllib.request.urlopen(signed_request, timeout=120) as response, destination.open("wb") as output:
            shutil.copyfileobj(response, output)
    except urllib.error.HTTPError as error:
        details = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Signed GitHub artifact download failed: {error.code} {details}") from error


def workflow_runs(
    token: str,
    repository: str,
    workflow_id: str,
    commit_sha: str,
) -> list[dict[str, object]]:
    query = urllib.parse.urlencode({"head_sha": commit_sha, "per_page": "20"})
    payload = github_request(token, f"/repos/{repository}/actions/workflows/{urllib.parse.quote(workflow_id)}/runs?{query}")
    runs = payload.get("workflow_runs", [])
    return runs if isinstance(runs, list) else []


def find_artifact(
    token: str,
    repository: str,
    runs: list[dict[str, object]],
    artifact_name: str,
) -> tuple[dict[str, object], dict[str, object]] | None:
    for run in runs:
        if run.get("status") != "completed":
            continue
        if run.get("conclusion") != "success":
            continue
        run_id = run.get("id")
        if not isinstance(run_id, int):
            continue
        artifacts_payload = github_request(token, f"/repos/{repository}/actions/runs/{run_id}/artifacts")
        artifacts = artifacts_payload.get("artifacts", [])
        if not isinstance(artifacts, list):
            continue
        for artifact in artifacts:
            if isinstance(artifact, dict) and artifact.get("name") == artifact_name and not artifact.get("expired"):
                return run, artifact
    return None


def extract_uploaded_zip(artifact_archive: pathlib.Path, output: pathlib.Path) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        extract_dir = pathlib.Path(tmp)
        with zipfile.ZipFile(artifact_archive) as archive:
            archive.extractall(extract_dir)

        candidates = sorted(extract_dir.rglob("*.zip"))
        if len(candidates) != 1:
            raise RuntimeError(
                f"Expected exactly one XCTest zip inside GitHub artifact, found {len(candidates)}: "
                f"{[str(candidate.relative_to(extract_dir)) for candidate in candidates]}"
            )

        output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(candidates[0], output)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Download the XCUITest bundle built by the iOS GitHub Actions UI workflow.")
    parser.add_argument("--repository", required=True)
    parser.add_argument("--workflow-id", required=True)
    parser.add_argument("--commit-sha", required=True)
    parser.add_argument("--artifact-name", required=True)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    parser.add_argument("--timeout-seconds", type=int, default=3600)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    token = env("GITHUB_API_KEY") or env("GITHUB_TOKEN") or env("GH_TOKEN")
    if token is None:
        raise SystemExit("GITHUB_API_KEY, GITHUB_TOKEN, or GH_TOKEN must be set")

    deadline = time.monotonic() + args.timeout_seconds
    last_runs: list[dict[str, object]] = []
    while time.monotonic() < deadline:
        last_runs = workflow_runs(token, args.repository, args.workflow_id, args.commit_sha)
        found = find_artifact(token, args.repository, last_runs, args.artifact_name)
        if found is not None:
            run, artifact = found
            run_url = run.get("html_url")
            archive_url = artifact.get("archive_download_url")
            if not isinstance(archive_url, str):
                raise RuntimeError(f"Artifact {args.artifact_name} did not include archive_download_url")
            with tempfile.NamedTemporaryFile(suffix=".zip") as archive:
                download(token, archive_url, pathlib.Path(archive.name))
                extract_uploaded_zip(pathlib.Path(archive.name), args.output)
            print(f"Downloaded {args.artifact_name} from {run_url} to {args.output}", flush=True)
            return

        states = [
            f"{run.get('html_url')} status={run.get('status')} conclusion={run.get('conclusion')}"
            for run in last_runs[:5]
        ]
        print(f"Waiting for successful {args.artifact_name} artifact on {args.commit_sha}. Recent runs: {states}", flush=True)
        time.sleep(30)

    print(json.dumps(last_runs[:5], indent=2, sort_keys=True), file=sys.stderr)
    raise TimeoutError(f"Timed out waiting for {args.artifact_name} artifact on {args.commit_sha}")


if __name__ == "__main__":
    main()
