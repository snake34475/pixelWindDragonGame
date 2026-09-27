#!/usr/bin/env bash
# 顺序运行全部 SceneTree 无头测试，避免并行 Godot 进程争用项目缓存。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"

TESTS=(
	res://tests/test_player_animation.gd
	res://tests/test_town_map.gd
	res://tests/test_tile_destructor.gd
	res://tests/test_hook.gd
	res://tests/test_teleport.gd
	res://tests/test_npc.gd
	res://tests/test_water.gd
	res://tests/test_lighting.gd
)

for test in "${TESTS[@]}"; do
	echo "==> ${test}"
	"${GODOT}" --headless --path "${ROOT}" --script "${test}"
done
