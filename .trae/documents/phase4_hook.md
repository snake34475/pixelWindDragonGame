# Phase 4：飞钩 / 钩爪实施复盘

> 日期：2026-09-27
> 基线：`014e6a3`（`feat: add stone tile destruction`）
> 引擎：Godot 4.7.2

## 目标

按住 E 后点击左键，飞钩朝鼠标世界坐标飞行；命中 `eaves` 物理层后发出信号，
由玩家状态机接管拉拽，抵达命中点或失败后恢复普通移动。

## 交付物

| 文件 | 作用 |
| --- | --- |
| `scripts/player/hook.gd` | 飞钩飞行、`RayCast2D` 命中、射程失败和信号通知 |
| `scenes/effects/hook.tscn` | 飞镖、锁链和 `eaves` 射线配置 |
| `scripts/player/states/hook_throw_state.gd` | 创建飞钩并等待命中/失败 |
| `scripts/player/states/hook_pull_state.gd` | 拉向命中点并管理飞钩生命周期 |
| `tests/test_hook.gd` | Phase 4 无头测试（24 项） |
| `tools/convert_unity_scene.py` | 修正屋檐物理层映射 |

## 关键决策

1. `eaves` 使用 Godot 第 4 层位掩码 `8`；屋檐同时保留 `world = 1`，最终 `collision_layer = 9`。
2. 飞钩根节点负责旋转和移动，`RayCast2D` 保持局部 `+X`，避免方向被旋转两次。
3. 飞钩只发 `hook_attached(point)` / `hook_failed`，不直接修改玩家位置、旋转或动画。
4. `HookThrowState` 和 `HookPullState` 属于玩家状态机；拉拽期间普通输入不参与位移。
5. 玩家只在速度非零时调用 `move_and_slide()`，让状态机的直接拉拽位移不被碰撞恢复拉回。

## 验证

| 测试 | 结果 |
| --- | --- |
| Phase 1 玩家动画 | 72/72 |
| Phase 2 瓦片世界 | 35/35 |
| Phase 3 石障破坏 | 15/15 |
| Phase 4 飞钩 / 钩爪 | 24/24 |

Phase 4 覆盖：输入动作、状态注册、`eaves` 层位、命中点、失败回收、信号通知、
重复发射拦截、状态切换、拉拽速度锁定、锚点到达和飞钩清理。

## 已知限制

- 玩家暂时复用 `idle` 动画，缺少独立的出钩、飞行和收钩帧动画。
- 锁链使用直线 `Line2D`，未还原 Unity 的摆动或重力表现。
- 屋檐与朱门碰撞区域存在重叠；当前按 Unity 逻辑由状态机直接拉拽玩家，不保证最终站位自动脱离所有重叠碰撞体。
