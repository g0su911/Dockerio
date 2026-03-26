#!/bin/bash
set -euo pipefail

# Render timelapse videos from screenshots and upload to GCS
# Uses GCP metadata server for auth (no SDK needed)

SCRIPT_OUTPUT="/factorio/script-output/timelapse"
RENDER_DIR="/factorio/timelapse-render"
GCS_BUCKET="${GCS_TIMELAPSE_BUCKET:-dockerio-timelapse}"
TIMESTAMP=$(TZ=Asia/Seoul date '+%Y-%m-%d-%H%M')

if [ ! -d "${SCRIPT_OUTPUT}" ]; then
    echo "[timelapse] No screenshots found. Skipping."
    exit 0
fi

# Check if any surface has screenshots
has_screenshots=false
for surface_dir in "${SCRIPT_OUTPUT}"/*/; do
    if [ -d "${surface_dir}" ] && ls "${surface_dir}"*.png >/dev/null 2>&1; then
        has_screenshots=true
        break
    fi
done

if [ "${has_screenshots}" = false ]; then
    echo "[timelapse] No screenshots found. Skipping."
    exit 0
fi

# Get GCP access token from metadata server
gcs_upload() {
    local file="$1"
    local dest="$2"
    local token

    token=$(curl -sf -H "Metadata-Flavor: Google" \
        "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" \
        | jq -r '.access_token')

    if [ -z "${token}" ] || [ "${token}" = "null" ]; then
        echo "[timelapse] Failed to get GCP token. Skipping upload."
        return 1
    fi

    curl -sf -X POST \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: video/mp4" \
        --data-binary "@${file}" \
        "https://storage.googleapis.com/upload/storage/v1/b/${GCS_BUCKET}/o?uploadType=media&name=${dest}" \
        > /dev/null

    return $?
}

mkdir -p "${RENDER_DIR}"

for surface_dir in "${SCRIPT_OUTPUT}"/*/; do
    [ ! -d "${surface_dir}" ] && continue

    surface_name=$(basename "${surface_dir}")
    png_count=$(ls "${surface_dir}"*.png 2>/dev/null | wc -l)

    if [ "${png_count}" -eq 0 ]; then
        echo "[timelapse] ${surface_name}: no screenshots, skipping."
        continue
    fi

    echo "[timelapse] ${surface_name}: rendering ${png_count} screenshots..."

    output_file="${RENDER_DIR}/${TIMESTAMP}_${surface_name}.mp4"

    # ffmpeg: crossfade between images
    # Each image shows for 0.5s with 0.3s fade transition
    ffmpeg -y \
        -framerate 2 \
        -pattern_type glob -i "${surface_dir}*.png" \
        -vf "zoompan=z=1:d=30:s=1280x720,fade=t=in:st=0:d=0.3,fade=t=out:st=0.2:d=0.3" \
        -c:v libx264 \
        -pix_fmt yuv420p \
        -preset fast \
        -crf 23 \
        "${output_file}" \
        2>/dev/null

    echo "[timelapse] ${surface_name}: rendered -> ${output_file}"

    # Upload to GCS
    dest="${TIMESTAMP}/${surface_name}.mp4"
    if gcs_upload "${output_file}" "${dest}"; then
        echo "[timelapse] ${surface_name}: uploaded to gs://${GCS_BUCKET}/${dest}"
    else
        echo "[timelapse] ${surface_name}: upload failed, keeping local file."
    fi
done

# Cleanup
echo "[timelapse] Cleaning up screenshots and renders..."
rm -rf "${SCRIPT_OUTPUT}"
rm -rf "${RENDER_DIR}"
echo "[timelapse] Done."
