#!/usr/bin/env bash
set -e # Exit with nonzero exit code if anything fails

BIN_DIR="${BIN_DIR:-/usr/local/bin}"
RUNNER_TEMP="${RUNNER_TEMP:-/tmp}"
IMAGE_NAME="${IMAGE_NAME:-nginx:latest}"

# Set version
DIVE_VERSION="${DIVE_VERSION:-0.11.0}"

# Download and install dive
rm -rf "${RUNNER_TEMP}/dive*"
rm -f "${BIN_DIR}/dive"
echo "Downloading dive ${DIVE_VERSION}..."
wget "https://github.com/wagoodman/dive/releases/download/v${DIVE_VERSION}/dive_${DIVE_VERSION}_linux_amd64.tar.gz" -O "${RUNNER_TEMP}/dive_${DIVE_VERSION}_linux_amd64.tar.gz"
wget "https://github.com/wagoodman/dive/releases/download/v${DIVE_VERSION}/dive_${DIVE_VERSION}_checksums.txt" -O "${RUNNER_TEMP}/dive_checksums.txt"
echo "$(grep "linux_amd64.tar.gz" "${RUNNER_TEMP}/dive_checksums.txt" | cut -d ' ' -f 1) ${RUNNER_TEMP}/dive_${DIVE_VERSION}_linux_amd64.tar.gz"  | sha256sum --check 
tar -xzf "${RUNNER_TEMP}/dive_${DIVE_VERSION}_linux_amd64.tar.gz" -C "${RUNNER_TEMP}"
chmod +x "${RUNNER_TEMP}/dive"
mv "${RUNNER_TEMP}/dive" "${BIN_DIR}"
rm "${RUNNER_TEMP}/dive_${DIVE_VERSION}_linux_amd64.tar.gz" "${RUNNER_TEMP}/dive_checksums.txt"
echo "dive ${DIVE_VERSION} installed to ${BIN_DIR}/dive"

# Run dive
echo "Running dive on ${IMAGE_NAME} ..."
dive "${IMAGE_NAME}" -j "${RUNNER_TEMP}/dive_output.json"

# Assign results to env vars
DIVE_IMAGE_NAME="${IMAGE_NAME}"
DIVE_IMAGE_TOTAL_SIZE="$(jq -r '.image.sizeBytes' "${RUNNER_TEMP}/dive_output.json")"
DIVE_IMAGE_INEFFICIENT_BYTES="$(jq -r '.image.inefficientBytes' "${RUNNER_TEMP}/dive_output.json")" 
DIVE_IMAGE_EFFICIENCY_SCORE="$(jq -r '.image.efficiencyScore' "${RUNNER_TEMP}/dive_output.json")"
DIVE_IMAGE_TOTAL_LAYERS="$(jq -r '.layer | length' "${RUNNER_TEMP}/dive_output.json")"
DIVE_IMAGE_JSON="$(cat "${RUNNER_TEMP}/dive_output.json")"

# Export env vars
export DIVE_IMAGE_NAME
export DIVE_IMAGE_TOTAL_SIZE
export DIVE_IMAGE_INEFFICIENT_BYTES
export DIVE_IMAGE_EFFICIENCY_SCORE
export DIVE_IMAGE_TOTAL_LAYERS
export DIVE_IMAGE_JSON

# envsubst template
TEMPLATE="$(envsubst < ./template.md)"

# Post results to GitHub if this is a pull request 
if [ "${GITHUB_EVENT_NAME}" == "pull_request" ]; then
  echo "Posting results to GitHub..."
  # PAYLOAD="$(echo "${TEMPLATE}" | jq -R --slurp '{body: .}')"
  PAYLOAD='{"body": "foo bar baz"}'
  URL="https://api.github.com/repos/${GITHUB_REPOSITORY}/issues/${GITHUB_REF}/comments"
  echo "${PAYLOAD}" | curl -L -X POST -d @- -H "Authorization: Bearer ${GITHUB_TOKEN}" -H "Content-Type: application/json" "${URL}"
else
    echo "Not a pull request, skipping posting results to GitHub."
    # Echo JSON to stdout
    echo "$DIVE_IMAGE_JSON"
fi
