#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
configuration="${1:-release}"
app_dir="$project_dir/build/TempoTasks.app"
contents_dir="$app_dir/Contents"

cd "$project_dir"
swift build -c "$configuration"
binary_dir="$(swift build -c "$configuration" --show-bin-path)"

mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
cp "$binary_dir/TempoTasks" "$contents_dir/MacOS/TempoTasks"
cp "$project_dir/Resources/Info.plist" "$contents_dir/Info.plist"
chmod 755 "$contents_dir/MacOS/TempoTasks"

codesign --force --deep --sign - --timestamp=none "$app_dir"
echo "$app_dir"

