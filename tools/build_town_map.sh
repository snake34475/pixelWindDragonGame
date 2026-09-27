#!/usr/bin/env bash
# 由 resources/world/town_map.json 生成 town_tileset.tres 与 town_map.tscn。
#
# 三步：先跑一次写出打包图集 PNG（此时还没被 Godot 导入）→ --import 导入 → 再跑一次建资源。
# 幂等：重复执行结果一致。
set -euo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
# macOS 12 缺 MetalFX 框架，用 stub 兜底，否则无头模式起不来。
export DYLD_FALLBACK_FRAMEWORK_PATH="/tmp/mfx${DYLD_FALLBACK_FRAMEWORK_PATH:+:$DYLD_FALLBACK_FRAMEWORK_PATH}"

cd "$(dirname "$0")/.."

"$GODOT" --headless --path . --script res://tools/build_town_map.gd
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --script res://tools/build_town_map.gd