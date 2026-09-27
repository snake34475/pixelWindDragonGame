# Phase 6：NPC 与对话框实施复盘

> 日期：2026-09-27
> 基线：`d7bf51d`（`chore: declare Godot 4.7 and document controls`）
> 引擎：Godot 4.7.2

## 目标

迁移佟湘玉的水平游荡与 `C` 键交互：弹出对话框，3 秒后关闭；
对话期间 NPC 停止移动，玩家输入锁定。

## 交付物

| 文件 | 作用 |
| --- | --- |
| `resources/characters/npc_sprite_frames.tres` | NPC idle 与水平行走 `SpriteFrames` |
| `scenes/characters/npc.tscn` | NPC 场景与碰撞体 |
| `scripts/npc/npc.gd` | 游荡、换向和对话停止逻辑 |
| `scripts/npc/npc_interactor.gd` | `C` 输入、射线检测和对话协调 |
| `scenes/ui/npc_dialog.tscn` | 最小故事对话框 UI |
| `scripts/ui/npc_dialog.gd` | 显示、计时和关闭信号 |
| `scripts/player/states/interact_state.gd` | 对话期间锁定玩家输入 |
| `tests/test_npc.gd` | NPC / 对话无头测试（23 项） |

## 关键决策

1. NPC 使用 `CharacterBody2D`，保留 Unity 的水平游荡和 5 秒换向。
2. 交互由独立 `NpcInteractor` 协调，NPC 不反向读取 UI 节点。
3. 玩家通过 `InteractState` 锁定输入；对话关闭后统一恢复到 `IdleState`。
4. 对话框用 `Control` + `TextureRect`，由自身计时并发出 `dialog_closed` 信号。
5. NPC 精灵表按 4×4、每帧 32×48 切分；游荡使用第二行四帧并左右翻转。

## 验证

| 测试 | 结果 |
| --- | --- |
| Phase 1 玩家动画 | 72/72 |
| Phase 2 瓦片世界 | 35/35 |
| Phase 3 石障破坏 | 15/15 |
| Phase 4 飞钩 / 钩爪 | 24/24 |
| Phase 5 传送圈 / 多场景 | 25/25 |
| Phase 6 NPC / 对话框 | 23/23 |

Phase 6 覆盖：NPC 游荡换向、层位、动画帧数、`C` 射线命中、玩家锁定、
对话框内容、自动关闭和双方状态恢复。

## 已知限制

- 对话框沿用 Godot 默认字体；尚未引入专用中文字体资源。
- 交互使用方向射线，多 NPC 遮挡时只命中最近的 NPC。
