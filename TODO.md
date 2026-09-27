# TODO

> 本文件是 `main` 的唯一执行队列。状态以当前文件、提交和测试为准；完成项移入
> `README.md` 或阶段复盘，不保留在这里。

## 当前基线

- `main`：Phase 0～4 已完成；Phase 4 为当前工作基线
- 已验证：Godot 4.7.2 下 `test_player_animation.gd` 为 72/72 通过，
  `test_town_map.gd` 为 35/35 通过，`test_tile_destructor.gd` 为 15/15 通过，
  `test_hook.gd` 为 24/24 通过。
- 不修改 `unity-app`；仅通过 `git show unity-app:<路径>` 读取其历史实现。

## 下一阶段：Phase 5 — 传送圈与多场景

- [ ] **5.1 传送素材**：导出 Unity 的 25 帧传送圈 PNG，建立 `SpriteFrames` 和
  `scenes/effects/teleport_ring.tscn`。
- [ ] **5.2 触发逻辑**：建立 `Area2D` 传送圈，导出目标场景路径和目标出生点名，
  只检测玩家层，并防止一次进入重复请求切场景。
- [ ] **5.3 出生点**：增加 `SpawnPointManager`，消费 `GameManager.consume_spawn_point()`，
  按出生点名移动玩家；默认偏移目标传送圈上方 1 格。
- [ ] **5.4 第二场景**：先建立最小可运行的 `hanba_map.tscn` 打通双向传送，再决定是否
  扩展场景转换器还原完整旱魃地图；地图还原不得阻塞传送逻辑。
- [ ] **5.5 验证**：增加双向传送与出生点无头测试，并回归 Phase 1～4。

## 后续迁移顺序

- [ ] **Phase 6：NPC 与对话框**。实现交互检测、对话 UI 和最小 NPC 行为。
- [ ] **Phase 7：水域表现**。将现有池塘 `Area2D` 接入玩家入水视觉，不把水域设为实体障碍。
- [ ] **Phase 8：2D 光照与视觉打磨**。在玩法链路完成后再调。

## 不在当前迁移范围

以下内容在 `unity-app` 中未发现可迁移的游戏实现；如决定开发，应另立需求与设计，不把它们标为迁移任务：

- [ ] 战斗、敌人 AI、技能、装备、掉落、背包、存档

## 文档维护

- [ ] 每完成一个 Phase：更新 `README.md` 的进度、移除/拆分本文件对应待办，并在 `.trae/documents/` 写阶段复盘。
- [ ] 如 `MIGRATION_PLAN.md` 的「尚未开始」描述影响决策，更新其顶部状态与 Phase 0～2 的完成标记；不要重写其中保留的 Unity 侧调查证据。
