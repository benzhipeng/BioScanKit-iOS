#!/bin/sh
set -eu

script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
shared_dir="$(dirname "$script_dir")/Shared"
resources_dir="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"

mkdir -p "$resources_dir"

for recommendations in "$shared_dir"/RecommendedApps*.json; do
  [ -e "$recommendations" ] || continue
  cp "$recommendations" "$resources_dir/$(basename "$recommendations")"
done

for icon in "$shared_dir"/Icons/*.png; do
  [ -e "$icon" ] || continue
  cp "$icon" "$resources_dir/$(basename "$icon")"
done
