# TODO

> 本文件是 `main` 的唯一执行队列。状态以当前文件、提交和测试为准；完成项移入
> `README.md` 或阶段复盘，不保留在这里。

## 当前基线

- `main`：Phase 0～5 已完成；Phase 5 为当前工作基线
- 已验证：Godot 4.7.2 下 `test_player_animation.gd` 为 72/72 通过，
  `test_town_map.gd` 为 35/35 通过，`test_tile_destructor.gd` 为 15/15 通过，
  `test_hook.gd` 为 24/24 通过，`test_teleport.gd` 为 25/25 通过。
- 不修改 `unity-app`；仅通过 `git show unity-app:<路径>` 读取其历史实现。

## 下一阶段：Phase 6 — NPC 与对话框

- [ ] **6.1 行为确认**：从 Unity 的 `npcMove.cs`、`npcdialog.cs` 和预制体确认游荡周期、
  交互距离、对话时长和输入锁定范围。
- [ ] **6.2 NPC 场景**：建立 NPC 场景与游荡状态，保留原逻辑的左右移动和定时换向。
- [ ] **6.3 对话链路**：建立交互检测、`InteractState`、最小对话 UI，并在对话期间停住 NPC 与玩家。
- [ ] **6.4 验证**：增加 NPC/对话无头测试，并回归 Phase 1～5。

## 后续迁移顺序

- [ ] **Phase 7：水域表现**。将现有池塘 `Area2D` 接入玩家入水视觉，不把水域设为实体障碍。
- [ ] **Phase 8：2D 光照与视觉打磨**。在玩法链路完成后再调。

## 已知非阻塞项

- [ ] 完整还原旱魃地图地形；当前 `hanba_map.tscn` 是最小可运行场景，不阻塞 Phase 6～8。

## 不在当前迁移范围

以下内容在 `unity-app` 中未发现可迁移的游戏实现；如决定开发，应另立需求与设计，不把它们标为迁移任务：

- [ ] 战斗、敌人 AI、技能、装备、掉落、背包、存档

## 文档维护

- [ ] 每完成一个 Phase：更新 `README.md` 的进度、移除/拆分本文件对应待办，并在 `.trae/documents/` 写阶段复盘。
- [ ] 如 `MIGRATION_PLAN.md` 的「尚未开始」描述影响决策，更新其顶部状态与 Phase 0～2 的完成标记；不要重写其中保留的 Unity 侧调查证据。
