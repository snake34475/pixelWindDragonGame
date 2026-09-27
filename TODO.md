# TODO

> 本文件是 `main` 的唯一执行队列。状态以当前文件、提交和测试为准；完成项移入
> `README.md` 或阶段复盘，不保留在这里。

## 自主执行规则

- 按阶段顺序连续执行，每个阶段固定走：实现 → 测试 → 文档 → 提交 → 推送。
- 不逐步请求确认；只有缺少必要外部素材、权限或出现无法自动修复的错误时暂停。
- 每个阶段完成后同步 `README.md`、本文件与 `.trae/documents/` 阶段复盘。

## 当前基线

- `main`：Phase 0～8 已完成；原 Unity 原型迁移队列已完成
- 已验证：Godot 4.7.2 下 `test_player_animation.gd` 为 72/72 通过，
  `test_town_map.gd` 为 36/36 通过，`test_tile_destructor.gd` 为 15/15 通过，
  `test_hook.gd` 为 24/24 通过，`test_teleport.gd` 为 25/25 通过，
  `test_npc.gd` 为 23/23 通过，`test_water.gd` 为 11/11 通过，
  `test_lighting.gd` 为 16/16 通过。
- 不修改 `unity-app`；仅通过 `git show unity-app:<路径>` 读取其历史实现。

## 当前状态

Phase 0～8 的迁移队列已经完成。后续战斗、敌人、技能、装备等属于新功能设计，
不再作为 Unity 原型迁移任务自动推进。

## 后续迁移顺序

## 已知非阻塞项

- [ ] 完整还原旱魃地图地形；当前 `hanba_map.tscn` 是最小可运行场景，不阻塞 Phase 8。

## 不在当前迁移范围

以下内容在 `unity-app` 中未发现可迁移的游戏实现；如决定开发，应另立需求与设计，不把它们标为迁移任务：

- [ ] 战斗、敌人 AI、技能、装备、掉落、背包、存档

## 文档维护

- [ ] 每完成一个 Phase：更新 `README.md` 的进度、移除/拆分本文件对应待办，并在 `.trae/documents/` 写阶段复盘。
- [ ] 如 `MIGRATION_PLAN.md` 的「尚未开始」描述影响决策，更新其顶部状态与 Phase 0～2 的完成标记；不要重写其中保留的 Unity 侧调查证据。
