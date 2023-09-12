#!/usr/bin/env bash
set -e # Exit with nonzero exit code if anything fails

BIN_DIR="${BIN_DIR:-/usr/local/bin}"
RUNNER_TEMP="${RUNNER_TEMP:-/tmp}"

# Check if we have an image name
if [ -z "${IMAGE_NAME}" ]; then
    echo "No image name found, exiting..."
    exit 1
fi

process_template() {
  while IFS= read -r line; do
    echo "${line//\"/\\\"}"
  done
}

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
DIVE_IMAGE_TOTAL_SIZE="$(jq -r '.image.sizeBytes' "${RUNNER_TEMP}/dive_output.json" | numfmt --to=iec-i --suffix=B --format="%.2f")"
DIVE_IMAGE_INEFFICIENT_BYTES="$(jq -r '.image.inefficientBytes' "${RUNNER_TEMP}/dive_output.json" | numfmt --to=iec-i --suffix=B --format="%.2f")" 
DIVE_IMAGE_EFFICIENCY_SCORE="$(jq -r '.image.efficiencyScore' "${RUNNER_TEMP}/dive_output.json")"
DIVE_IMAGE_EFFICIENCY_PERCENT=$(awk -v num="$DIVE_IMAGE_EFFICIENCY_SCORE" 'BEGIN { printf "%.2f%%\n", num * 100 }')
DIVE_IMAGE_TOTAL_LAYERS="$(jq -r '.layer | length' "${RUNNER_TEMP}/dive_output.json")"
DIVE_IMAGE_JSON="$(cat "${RUNNER_TEMP}/dive_output.json")"

# Export env vars
export DIVE_IMAGE_NAME
export DIVE_IMAGE_TOTAL_SIZE
export DIVE_IMAGE_INEFFICIENT_BYTES
export DIVE_IMAGE_EFFICIENCY_PERCENT
export DIVE_IMAGE_TOTAL_LAYERS
export DIVE_IMAGE_JSON

# envsubst template
TEMPLATE="### Dive image results for \`${DIVE_IMAGE_NAME}\`

| | |
| --- | --- |
| Image | \`${DIVE_IMAGE_NAME}\` |
| Total Size | \`${DIVE_IMAGE_TOTAL_SIZE}\` |
| Inefficient Bytes | \`${DIVE_IMAGE_INEFFICIENT_BYTES}\` |
| Efficiency Percentage | \`${DIVE_IMAGE_EFFICIENCY_PERCENT}\` |
| Total Layers | \`${DIVE_IMAGE_TOTAL_LAYERS}\` |

<details>
<summary>Show full output</summary>

\`\`\`json
${DIVE_IMAGE_JSON}
\`\`\`"

# Post results to GitHub if this is a pull request 
if [ "${GITHUB_EVENT_NAME}" == "pull_request" ]; then
  # Check if we have a GitHub token
    if [ -z "${GITHUB_TOKEN}" ]; then
        echo "No GitHub token found, exiting..."
        exit 1
    fi
  echo "Posting results to GitHub..."
  ESCAPED_TEMPLATE=$(process_template <<< "$TEMPLATE")
  PAYLOAD="{\"body\": \"${ESCAPED_TEMPLATE}\"}" > output.json
  ISSUE_NUMBER=$(jq --raw-output .pull_request.number "$GITHUB_EVENT_PATH")
  URL="https://api.github.com/repos/${GITHUB_REPOSITORY}/issues/${ISSUE_NUMBER}/comments"
  echo "${PAYLOAD}" | curl -s -S -H "Authorization: Bearer ${GITHUB_TOKEN}" --header "Content-Type: application/json" --data @- "${URL}" > /dev/null

else
    echo "Not a pull request, skipping posting results to GitHub."
    # Echo JSON to stdout
    echo "$DIVE_IMAGE_JSON"
fi