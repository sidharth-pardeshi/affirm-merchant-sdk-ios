#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request


DEFAULT_REPOSITORY = "Affirm/affirm-merchant-sdk-ios"
DEFAULT_WORKFLOW_ID = "ui-tests.yml"


def env(name: str, default: str | None = None) -> str | None:
    value = os.environ.get(name)
    return value if value not in (None, "") else default


def require_env(name: str) -> str:
    value = env(name)
    if value is None:
        raise SystemExit(f"{name} must be set")
    return value


def repository_from_url(url: str | None) -> str | None:
    if url is None:
        return None

    parsed = urllib.parse.urlparse(url)
    path = parsed.path.lstrip("/")
    if path.endswith(".git"):
        path = path[:-4]
    parts = [part for part in path.split("/") if part]
    if len(parts) >= 2:
        return "/".join(parts[-2:])
    return None


def normalize_repository_and_ref(
    repository: str,
    ref: str,
    pull_request_repo: str | None,
) -> tuple[str, str]:
    if ":" not in ref:
        return repository, ref

    fork_owner, fork_ref = ref.split(":", 1)
    fork_repository = repository_from_url(pull_request_repo)
    if fork_repository is None:
        repo_name = repository.rsplit("/", 1)[-1]
        fork_repository = f"{fork_owner}/{repo_name}"

    return fork_repository, fork_ref


def github_request(
    token: str,
    method: str,
    path: str,
    body: dict[str, object] | None = None,
) -> tuple[int, dict[str, object] | None]:
    data = json.dumps(body).encode("utf-8") if body is not None else None
    request = urllib.request.Request(
        f"https://api.github.com{path}",
        data=data,
        method=method,
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        details = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"GitHub API {method} {path} failed: {error.code} {details}") from error


def dispatch_workflow(
    token: str,
    repository: str,
    workflow_id: str,
    ref: str,
    inputs: dict[str, str],
) -> None:
    path = f"/repos/{repository}/actions/workflows/{urllib.parse.quote(workflow_id)}/dispatches"
    status, _ = github_request(token, "POST", path, {"ref": ref, "inputs": inputs})
    if status != 204:
        raise RuntimeError(f"Expected workflow dispatch HTTP 204, got {status}")


def workflow_runs(
    token: str,
    repository: str,
    workflow_id: str,
    branch: str,
) -> list[dict[str, object]]:
    query = urllib.parse.urlencode(
        {
            "event": "workflow_dispatch",
            "branch": branch,
            "per_page": "20",
        },
    )
    path = f"/repos/{repository}/actions/workflows/{urllib.parse.quote(workflow_id)}/runs?{query}"
    _, payload = github_request(token, "GET", path)
    if payload is None:
        return []
    runs = payload.get("workflow_runs", [])
    return runs if isinstance(runs, list) else []


def parse_time(value: str) -> dt.datetime:
    return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))


def find_dispatched_run(
    runs: list[dict[str, object]],
    commit_sha: str | None,
    dispatched_after: dt.datetime,
) -> dict[str, object] | None:
    for run in runs:
        if commit_sha and run.get("head_sha") != commit_sha:
            continue
        created_at = run.get("created_at")
        if isinstance(created_at, str) and parse_time(created_at) >= dispatched_after:
            return run
    return None


def wait_for_run(
    token: str,
    repository: str,
    workflow_id: str,
    branch: str,
    commit_sha: str | None,
    dispatched_after: dt.datetime,
    timeout_seconds: int,
) -> dict[str, object]:
    deadline = time.monotonic() + timeout_seconds
    last_url = None
    while time.monotonic() < deadline:
        run = find_dispatched_run(
            workflow_runs(token, repository, workflow_id, branch),
            commit_sha,
            dispatched_after,
        )
        if run is not None:
            last_url = run.get("html_url", last_url)
            status = run.get("status")
            conclusion = run.get("conclusion")
            print(f"GitHub Actions run {last_url}: status={status} conclusion={conclusion}", flush=True)
            if status == "completed":
                return run
        else:
            print("Waiting for dispatched GitHub Actions run to appear...", flush=True)
        time.sleep(20)
    raise TimeoutError(f"Timed out waiting for GitHub Actions run. Last seen URL: {last_url}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Dispatch and wait for the iOS SDK Upfunnel promo Thor UI test GitHub Actions run.",
    )
    parser.add_argument("--repository", default=env("IOS_SDK_GITHUB_REPOSITORY", DEFAULT_REPOSITORY))
    parser.add_argument("--workflow-id", default=env("IOS_SDK_GITHUB_WORKFLOW_ID", DEFAULT_WORKFLOW_ID))
    parser.add_argument("--ref", default=env("IOS_SDK_GITHUB_REF", env("BUILDKITE_BRANCH")))
    parser.add_argument("--pull-request-repo", default=env("BUILDKITE_PULL_REQUEST_REPO"))
    parser.add_argument("--commit-sha", default=env("IOS_SDK_GITHUB_SHA", env("BUILDKITE_COMMIT")))
    parser.add_argument(
        "--timeout-seconds",
        type=int,
        default=int(env("IOS_SDK_GITHUB_WORKFLOW_TIMEOUT_SECONDS", "3600")),
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    token = env("GITHUB_API_KEY", env("GITHUB_TOKEN", env("GH_TOKEN")))
    if token is None:
        raise SystemExit("GITHUB_API_KEY, GITHUB_TOKEN, or GH_TOKEN must be set")
    if args.ref is None:
        raise SystemExit("IOS_SDK_GITHUB_REF or BUILDKITE_BRANCH must be set")
    repository, ref = normalize_repository_and_ref(args.repository, args.ref, args.pull_request_repo)

    inputs = {
        "run_upfunnel_promo_thor_test": "true",
        "affirm_promo_base_url": require_env("AFFIRM_PROMO_BASE_URL"),
        "affirm_public_key": require_env("AFFIRM_PUBLIC_KEY"),
        "affirm_promo_external_id": env("AFFIRM_PROMO_EXTERNAL_ID", "test_external_id") or "test_external_id",
        "affirm_expected_promo_text": env("AFFIRM_EXPECTED_PROMO_TEXT", "Affirm") or "Affirm",
        "affirm_country_code": env("AFFIRM_COUNTRY_CODE", "USA") or "USA",
        "affirm_locale": env("AFFIRM_LOCALE", "en_US") or "en_US",
        "affirm_currency": env("AFFIRM_CURRENCY", "USD") or "USD",
    }

    dispatched_after = dt.datetime.now(dt.timezone.utc) - dt.timedelta(seconds=5)
    dispatch_workflow(token, repository, args.workflow_id, ref, inputs)
    print(f"Dispatched {args.workflow_id} on {repository}@{ref}", flush=True)

    run = wait_for_run(
        token,
        repository,
        args.workflow_id,
        ref,
        args.commit_sha,
        dispatched_after,
        args.timeout_seconds,
    )
    if run.get("conclusion") != "success":
        print(json.dumps(run, indent=2, sort_keys=True), file=sys.stderr)
        raise SystemExit(f"GitHub Actions run failed with conclusion={run.get('conclusion')}")


if __name__ == "__main__":
    main()
