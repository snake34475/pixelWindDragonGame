# Phase 5：传送圈与多场景实施复盘

> 日期：2026-09-27
> 基线：`181a1c1`（`docs: plan phase 5 teleport`）
> 引擎：Godot 4.7.2

## 目标

玩家进入城镇或旱魃地图的传送圈后切换场景，并在目标场景的对应出生点出现；
往返过程不重复触发、不生成重复玩家。

## 交付物

| 文件 | 作用 |
| --- | --- |
| `resources/effects/teleport_frames.tres` | 25 帧传送圈 `SpriteFrames` |
| `scenes/effects/teleport_ring.tscn` | `Area2D` 传送圈、动画和触发碰撞体 |
| `scripts/world/teleport_ring.gd` | 检测玩家并请求场景切换 |
| `scripts/world/spawn_point_manager.gd` | 消费一次性出生点名并移动玩家 |
| `scenes/levels/hanba_map.tscn` | 最小可运行的旱魃地图与返回传送圈 |
| `tests/test_teleport.gd` | 双向传送无头测试（25 项） |

## 关键决策

1. Godot 场景路径替代 Unity 的场景名字符串；目标发现在 `TeleportRing` 上配置。
2. `GameManager.request_scene_change()` 返回是否接受请求，并拒绝切换期间或切到当前场景的重复请求。
3. 目标出生点用 `Marker2D` 名称表达；`SpawnPointManager` 调用
   `GameManager.consume_spawn_point()`，保证出生点名只消费一次。
4. 城镇与旱魃出生点都放在目标传送圈上方 1 格，避免落入触发区形成往返循环。
5. 旱魃地图先交付最小可运行场景，完整地形转换独立于传送与后续玩法。

## 验证

| 测试 | 结果 |
| --- | --- |
| Phase 1 玩家动画 | 72/72 |
| Phase 2 瓦片世界 | 35/35 |
| Phase 3 石障破坏 | 15/15 |
| Phase 4 飞钩 / 钩爪 | 24/24 |
| Phase 5 传送圈 / 多场景 | 25/25 |

Phase 5 覆盖：25 帧贴图加载、传送圈层位和玩家掩码、一次性切换保护、
城镇到旱魃、旱魃回城镇，以及两个目标出生点的位置。

## 已知限制

- `hanba_map.tscn` 目前只有背景、玩家、出生点和传送圈，尚未还原 Unity 的完整地形。
- 传送圈点亮光效留到 Phase 8；当前只迁移触发与动画链路。
