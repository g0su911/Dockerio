#!/bin/bash
set -euo pipefail

# Render timelapse videos from screenshots and upload to GCS
# Called by entrypoint.sh before map reset

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
    if command -v gsutil >/dev/null 2>&1; then
        gsutil -q cp "${output_file}" "gs://${GCS_BUCKET}/${TIMESTAMP}/${surface_name}.mp4"
        echo "[timelapse] ${surface_name}: uploaded to gs://${GCS_BUCKET}/${TIMESTAMP}/${surface_name}.mp4"
    else
        echo "[timelapse] gsutil not found, skipping upload."
    fi
done

# Cleanup
echo "[timelapse] Cleaning up screenshots and renders..."
rm -rf "${SCRIPT_OUTPUT}"
rm -rf "${RENDER_DIR}"
echo "[timelapse] Done."
