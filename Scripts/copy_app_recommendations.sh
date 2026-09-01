#!/bin/sh
set -eu

script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
shared_dir="$(dirname "$script_dir")/Shared"
resources_dir="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"

mkdir -p "$resources_dir"
cp "$shared_dir/RecommendedApps.json" "$resources_dir/RecommendedApps.json"

for icon in "$shared_dir"/Icons/*.png; do
  [ -e "$icon" ] || continue
  cp "$icon" "$resources_dir/$(basename "$icon")"
done
