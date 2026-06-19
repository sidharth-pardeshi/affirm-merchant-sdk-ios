#!/usr/bin/env bash
set -euo pipefail

buildkite_metadata() {
  if command -v buildkite-agent >/dev/null 2>&1; then
    buildkite-agent meta-data get "$1" 2>/dev/null || true
  fi
}

if [[ -z "${AFFIRM_PROMO_BASE_URL:-}" ]]; then
  THOR_ID="$(buildkite_metadata "thor-id-us-live")"
  if [[ -n "$THOR_ID" ]]; then
    AFFIRM_PROMO_BASE_URL="https://${THOR_ID}.affirm-thor.com"
  fi
fi

AFFIRM_PUBLIC_KEY="${AFFIRM_PUBLIC_KEY:-$(buildkite_metadata "upfunnel-sdk-promo-messaging-public-key")}"

AFFIRM_EXPECTED_PROMO_TEXT="${AFFIRM_EXPECTED_PROMO_TEXT:-$(buildkite_metadata "upfunnel-sdk-promo-messaging-expected-ala")}"
AFFIRM_EXPECTED_PROMO_TEXT="${AFFIRM_EXPECTED_PROMO_TEXT:-Affirm}"
AFFIRM_COUNTRY_CODE="${AFFIRM_COUNTRY_CODE:-USA}"
AFFIRM_LOCALE="${AFFIRM_LOCALE:-en_US}"
AFFIRM_CURRENCY="${AFFIRM_CURRENCY:-USD}"
IOS_DESTINATION="${IOS_DESTINATION:-platform=iOS Simulator,name=iPhone 15}"
RESULT_BUNDLE_PATH="${RESULT_BUNDLE_PATH:-build/UpfunnelPromoThorUITests.xcresult}"

: "${AFFIRM_PROMO_BASE_URL:?AFFIRM_PROMO_BASE_URL must be set, e.g. https://<thor-id>.affirm-thor.com}"
: "${AFFIRM_PUBLIC_KEY:?AFFIRM_PUBLIC_KEY must be set to the Thor merchant public key}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

cd Examples
pod install --verbose --repo-update
cd ..

rm -rf "$RESULT_BUNDLE_PATH"

AFFIRM_PROMO_BASE_URL="$AFFIRM_PROMO_BASE_URL" \
AFFIRM_PUBLIC_KEY="$AFFIRM_PUBLIC_KEY" \
AFFIRM_EXPECTED_PROMO_TEXT="$AFFIRM_EXPECTED_PROMO_TEXT" \
AFFIRM_COUNTRY_CODE="$AFFIRM_COUNTRY_CODE" \
AFFIRM_LOCALE="$AFFIRM_LOCALE" \
AFFIRM_CURRENCY="$AFFIRM_CURRENCY" \
xcodebuild \
  -workspace Examples/Examples.xcworkspace \
  -scheme ExamplesUITests \
  -destination "$IOS_DESTINATION" \
  -only-testing:ExamplesUITests/UpfunnelPromoMessagingThorUITests/testPromoButtonRendersAlaFromThorService \
  -resultBundlePath "$RESULT_BUNDLE_PATH" \
  test
