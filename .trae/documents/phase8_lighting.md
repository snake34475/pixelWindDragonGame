# Phase 8：2D 光照实施复盘

> 日期：2026-09-27
> 基线：`3587c48`（`feat: add pond swimming state`）
> 引擎：Godot 4.7.2

## 目标

为城镇、玩家、传送圈和火焰加入基础 2D 光照，保持资源可复用、节点数量可控，
并完成原 Unity 原型迁移队列的收口。

## 交付物

| 文件 | 作用 |
| --- | --- |
| `resources/lighting/soft_light.tres` | 可复用的径向柔光纹理 |
| `resources/effects/fire_frames.tres` | 120 帧火焰 `SpriteFrames` |
| `tools/build_fire_frames.gd` | 从现有 PNG 序列生成火焰动画资源 |
| `scenes/effects/fire.tscn` | 火焰动画与红色点光源 |
| `scenes/characters/player.tscn` | 玩家暖色点光源 |
| `scenes/effects/teleport_ring.tscn` | 传送圈蓝色点光源 |
| `tests/test_lighting.gd` | 光照无头测试（16 项） |

## 关键决策

1. 用 Godot 原生 `GradientTexture2D` 生成柔光，不新增二进制贴图。
2. 火焰 120 帧通过工具脚本生成资源，保留可重复重建能力。
3. 城镇使用轻柔暖色 `CanvasModulate`，旱魃地图保留更暗的环境色调。
4. 玩家、传送圈和火焰各自只保留一个 `PointLight2D`，避免重复光照节点。

## 验证

| 测试 | 结果 |
| --- | --- |
| Phase 1 玩家动画 | 72/72 |
| Phase 2 瓦片世界 | 36/36 |
| Phase 3 石障破坏 | 15/15 |
| Phase 4 飞钩 / 钩爪 | 24/24 |
| Phase 5 传送圈 / 多场景 | 25/25 |
| Phase 6 NPC / 对话框 | 23/23 |
| Phase 7 水域表现 | 11/11 |
| Phase 8 2D 光照 | 16/16 |

## 已知限制

- 自动化测试验证光源配置和资源完整性，不测量真实显示器上的最终亮度。
- Godot 的 GL Compatibility 下 2D 光照表现可能与 Forward+ 有细微差异。
