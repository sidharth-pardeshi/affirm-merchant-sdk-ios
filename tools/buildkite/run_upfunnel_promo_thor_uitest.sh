#!/usr/bin/env bash
set -euo pipefail

buildkite_metadata() {
  if command -v buildkite-agent >/dev/null 2>&1; then
    buildkite-agent meta-data get "$1" 2>/dev/null || true
  fi
}

annotate_firebase_result() {
  local attempt_log="$1"
  local style="$2"
  local context="$3"

  if ! command -v buildkite-agent >/dev/null 2>&1; then
    return 0
  fi

  local details_url
  details_url="$(
    awk '
      /More details are/ {
        for (i = 1; i <= NF; i++) {
          if ($i ~ /^https?:\/\//) {
            print $i
            exit
          }
        }
      }
    ' "$attempt_log" | sed 's/[),.]*$//'
  )"

  if [[ -n "$details_url" ]]; then
    printf 'Firebase iOS Test Lab results: %s\n' "$details_url" \
      | buildkite-agent annotate --style "$style" --context "$context"
  fi
}

if [[ -z "${AFFIRM_PROMO_BASE_URL:-}" ]]; then
  THOR_ID="$(buildkite_metadata "thor-id-us-live")"
  if [[ -n "$THOR_ID" ]]; then
    AFFIRM_PROMO_BASE_URL="https://${THOR_ID}.affirm-thor.com"
  fi
fi

AFFIRM_PUBLIC_KEY="${AFFIRM_PUBLIC_KEY:-$(buildkite_metadata "upfunnel-sdk-promo-messaging-public-key")}"

AFFIRM_PROMO_EXTERNAL_ID="${AFFIRM_PROMO_EXTERNAL_ID:-$(buildkite_metadata "upfunnel-sdk-promo-messaging-external-id")}"
AFFIRM_PROMO_EXTERNAL_ID="${AFFIRM_PROMO_EXTERNAL_ID:-test_external_id}"
AFFIRM_EXPECTED_PROMO_TEXT="${AFFIRM_EXPECTED_PROMO_TEXT:-$(buildkite_metadata "upfunnel-sdk-promo-messaging-expected-ala")}"
AFFIRM_EXPECTED_PROMO_TEXT="${AFFIRM_EXPECTED_PROMO_TEXT:-Affirm}"
AFFIRM_COUNTRY_CODE="${AFFIRM_COUNTRY_CODE:-USA}"
AFFIRM_LOCALE="${AFFIRM_LOCALE:-en_US}"
AFFIRM_CURRENCY="${AFFIRM_CURRENCY:-USD}"
FIREBASE_PROJECT="${FIREBASE_PROJECT:-firebase-affirm}"
FIREBASE_TEST_LOG="${FIREBASE_TEST_LOG:-firebase-ios-test-lab.log}"
IOS_XCTEST_ARTIFACT_NAME="${IOS_XCTEST_ARTIFACT_NAME:-UpfunnelPromoThorXCTest}"
IOS_XCTEST_GITHUB_REPOSITORY="${IOS_XCTEST_GITHUB_REPOSITORY:-Affirm/affirm-merchant-sdk-ios}"
IOS_XCTEST_GITHUB_SHA="${IOS_XCTEST_GITHUB_SHA:-${BUILDKITE_COMMIT:-}}"
IOS_XCTEST_GITHUB_WORKFLOW_ID="${IOS_XCTEST_GITHUB_WORKFLOW_ID:-ui-tests.yml}"
IOS_XCTEST_ZIP="${IOS_XCTEST_ZIP:-build/UpfunnelPromoThorXCTest.zip}"
IOS_XCTEST_PATCHED_ZIP="${IOS_XCTEST_PATCHED_ZIP:-build/UpfunnelPromoThorXCTest.patched.zip}"
IOS_ONLY_TESTING="${IOS_ONLY_TESTING:-ExamplesUITests/UpfunnelPromoMessagingThorUITests/testPromoButtonRendersAlaFromThorService}"
IOS_FIREBASE_RESULTS_BUCKET="${IOS_FIREBASE_RESULTS_BUCKET:-firebase-affirm-ios}"
IOS_FIREBASE_DEVICE="${IOS_FIREBASE_DEVICE:-}"
IOS_FIREBASE_DEVICE_ATTEMPTS="${IOS_FIREBASE_DEVICE_ATTEMPTS:-8}"
IOS_FIREBASE_NUM_FLAKY_TEST_ATTEMPTS="${IOS_FIREBASE_NUM_FLAKY_TEST_ATTEMPTS:-0}"
IOS_FIREBASE_XCODE_VERSION="${IOS_FIREBASE_XCODE_VERSION:-}"

: "${AFFIRM_PROMO_BASE_URL:?AFFIRM_PROMO_BASE_URL must be set, e.g. https://<thor-id>.affirm-thor.com}"
: "${AFFIRM_PUBLIC_KEY:?AFFIRM_PUBLIC_KEY must be set to the Thor merchant public key}"
: "${GITHUB_API_KEY:?GITHUB_API_KEY must be set so the Buildkite job can download the GitHub Actions XCTest artifact}"
: "${IOS_XCTEST_GITHUB_SHA:?IOS_XCTEST_GITHUB_SHA or BUILDKITE_COMMIT must be set}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

python3 tools/buildkite/download_github_actions_artifact.py \
  --repository "$IOS_XCTEST_GITHUB_REPOSITORY" \
  --workflow-id "$IOS_XCTEST_GITHUB_WORKFLOW_ID" \
  --commit-sha "$IOS_XCTEST_GITHUB_SHA" \
  --artifact-name "$IOS_XCTEST_ARTIFACT_NAME" \
  --output "$IOS_XCTEST_ZIP"

python3 tools/buildkite/patch_xctestrun_environment.py \
  --input "$IOS_XCTEST_ZIP" \
  --output "$IOS_XCTEST_PATCHED_ZIP" \
  --only-testing "$IOS_ONLY_TESTING" \
  --env "AFFIRM_PROMO_BASE_URL=$AFFIRM_PROMO_BASE_URL" \
  --env "AFFIRM_PUBLIC_KEY=$AFFIRM_PUBLIC_KEY" \
  --env "AFFIRM_PROMO_EXTERNAL_ID=$AFFIRM_PROMO_EXTERNAL_ID" \
  --env "AFFIRM_EXPECTED_PROMO_TEXT=$AFFIRM_EXPECTED_PROMO_TEXT" \
  --env "AFFIRM_COUNTRY_CODE=$AFFIRM_COUNTRY_CODE" \
  --env "AFFIRM_LOCALE=$AFFIRM_LOCALE" \
  --env "AFFIRM_CURRENCY=$AFFIRM_CURRENCY"

if ! command -v gcloud >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update
    apt-get install -y ca-certificates curl gnupg
    install -d -m 0755 /usr/share/keyrings
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
      | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
      > /etc/apt/sources.list.d/google-cloud-sdk.list
    apt-get update
    apt-get install -y google-cloud-cli
  else
    echo "gcloud is required for Firebase Test Lab, and this image does not support apt-get installation." >&2
    exit 2
  fi
fi

if [[ -n "${FIREBASE_SERVICE_ACCOUNT:-}" ]]; then
  firebase_credentials="$(mktemp)"
  firebase_credentials_decoded="${firebase_credentials}.decoded"
  printf "%s" "$FIREBASE_SERVICE_ACCOUNT" > "$firebase_credentials"
  if ! grep -q '"type"[[:space:]]*:[[:space:]]*"service_account"' "$firebase_credentials"; then
    if printf "%s" "$FIREBASE_SERVICE_ACCOUNT" | base64 -d > "$firebase_credentials_decoded" 2>/dev/null \
      && grep -q '"type"[[:space:]]*:[[:space:]]*"service_account"' "$firebase_credentials_decoded"; then
      mv "$firebase_credentials_decoded" "$firebase_credentials"
    else
      rm -f "$firebase_credentials_decoded"
      echo "FIREBASE_SERVICE_ACCOUNT must be a Google service-account JSON key, either raw JSON or base64-encoded JSON." >&2
      exit 2
    fi
  fi
  gcloud auth activate-service-account --key-file="$firebase_credentials"
fi

gcloud config set project "$FIREBASE_PROJECT"

gcloud firebase test ios versions list || true

if [[ -z "$IOS_FIREBASE_DEVICE" ]]; then
  mapfile -t IOS_FIREBASE_DEVICES < <(
    python3 tools/buildkite/select_firebase_ios_device.py \
      --project "$FIREBASE_PROJECT" \
      --limit "$IOS_FIREBASE_DEVICE_ATTEMPTS"
  )
else
  IOS_FIREBASE_DEVICES=("$IOS_FIREBASE_DEVICE")
fi

if [[ "${#IOS_FIREBASE_DEVICES[@]}" -eq 0 ]]; then
  echo "No Firebase iOS device axes were selected." >&2
  exit 1
fi

: > "$FIREBASE_TEST_LOG"
last_status=1
attempt=0
infrastructure_failures=0

for firebase_device in "${IOS_FIREBASE_DEVICES[@]}"; do
  attempt=$((attempt + 1))
  attempt_log="${FIREBASE_TEST_LOG%.log}-${attempt}.log"
  results_dir="upfunnel-promo-sdk-${BUILDKITE_BUILD_NUMBER:-local}-${BUILDKITE_JOB_ID:-manual}-${attempt}"

  echo "Running Firebase iOS test attempt ${attempt}/${#IOS_FIREBASE_DEVICES[@]} on ${firebase_device}" \
    | tee -a "$FIREBASE_TEST_LOG"

  firebase_test_args=(
    firebase test ios run
    --type xctest \
    --test "$IOS_XCTEST_PATCHED_ZIP" \
    --device "$firebase_device" \
    --results-bucket "$IOS_FIREBASE_RESULTS_BUCKET" \
    --results-dir "$results_dir" \
    --client-details "matrixLabel=Upfunnel iOS SDK promo Thor test,buildkiteBuild=${BUILDKITE_BUILD_NUMBER:-local},commit=${IOS_XCTEST_GITHUB_SHA}" \
    --record-video \
    --timeout 10m
  )

  if [[ "$IOS_FIREBASE_NUM_FLAKY_TEST_ATTEMPTS" =~ ^[1-9][0-9]*$ ]]; then
    firebase_test_args+=(--num-flaky-test-attempts "$IOS_FIREBASE_NUM_FLAKY_TEST_ATTEMPTS")
  fi

  if [[ -n "$IOS_FIREBASE_XCODE_VERSION" ]]; then
    firebase_test_args+=(--xcode-version "$IOS_FIREBASE_XCODE_VERSION")
  fi

  set +e
  gcloud "${firebase_test_args[@]}" 2>&1 | tee "$attempt_log"
  last_status=${PIPESTATUS[0]}
  set -e

  cat "$attempt_log" >> "$FIREBASE_TEST_LOG"

  if [[ "$last_status" -eq 0 ]]; then
    annotate_firebase_result "$attempt_log" success "firebase-ios-attempt-${attempt}"
    exit 0
  fi

  if grep -q "Infrastructure failure" "$attempt_log"; then
    annotate_firebase_result "$attempt_log" warning "firebase-ios-attempt-${attempt}"
    infrastructure_failures=$((infrastructure_failures + 1))
    echo "Firebase infrastructure failure on ${firebase_device}; trying the next selected axis." \
      | tee -a "$FIREBASE_TEST_LOG" >&2
    continue
  fi

  annotate_firebase_result "$attempt_log" error "firebase-ios-attempt-${attempt}"
  exit "$last_status"
done

if [[ "$infrastructure_failures" -eq "${#IOS_FIREBASE_DEVICES[@]}" ]]; then
  echo "All selected Firebase iOS device axes failed with infrastructure failures." \
    | tee -a "$FIREBASE_TEST_LOG" >&2
  exit 255
fi

exit "$last_status"
