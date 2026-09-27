# Phase 5：传送圈与多场景实施计划

> 日期：2026-09-27
> 基线：`3c5bb59`（`feat: add hook grappling`）
> 目标：完成城镇与旱魃地图之间的双向传送，并验证一次性出生点。

## 已确认事实

1. Unity 传送圈预制体使用 `BoxCollider2D(Trigger)` 检测玩家进入。
2. 城镇传送圈指向 `旱魃图`，旱魃地图传送圈指向 `SampleScene`。
3. 原实现进入目标场景后，把玩家放在目标传送圈位置上方 1 格。
4. 当前 `GameManager.request_scene_change(scene_path, spawn_point)` 和
   `consume_spawn_point()` 已经提供场景切换与一次性出生点接口。
5. 传送圈动画有 25 帧，源 PNG 已存在，可直接整理，不需要重建 PSB。

## 实施顺序

### 1. 传送圈场景与素材

- 从 `unity-app` 提取 `Assets/img/map/地面素材/传送圈/` 的 25 帧 PNG。
- 新建 `assets/effects/teleport/` 和 `SpriteFrames` 资源。
- 新建 `scenes/effects/teleport_ring.tscn`：根节点 `Area2D`，碰撞层为
  `teleport`，碰撞掩码只检测 `player`，子节点包含 `AnimatedSprite2D`。

### 2. `TeleportRing`

- 新增 `scripts/world/teleport_ring.gd`。
- 导出 `target_scene_path: String`、`target_spawn_point: StringName`、
  `spawn_point: StringName`。
- `body_entered` 确认是 `Player` 后调用：

```text
GameManager.request_scene_change(target_scene_path, target_spawn_point)
```

- 增加一次切换保护，避免同一帧重复触发或在场景切换前再次进入。

### 3. 出生点

- 新增 `scripts/world/spawn_point_manager.gd`。
- 每个场景放置 `Marker2D` 子节点，节点名即出生点名。
- 场景就绪时调用一次 `GameManager.consume_spawn_point()`：
  - 有名且找到节点：把玩家移动到该节点。
  - 无出生点名或节点不存在：保留场景默认玩家位置。
- 目标出生点默认放在目标传送圈上方 1 格，避免落在触发区内。

### 4. 场景接入

- `town.tscn` 接入传送圈和出生点管理器。
- 新建最小可运行的 `hanba_map.tscn`，先保证双向切换和出生点行为可验证。
- 随后单独评估是否扩展 `tools/convert_unity_scene.py` 来还原完整旱魃地图；
  地图内容量较大，不与传送逻辑绑定。

### 5. 测试与验收

- 场景存在、传送圈层位与掩码正确。
- 玩家进入城镇传送圈后请求切换到旱魃地图。
- 玩家在新场景出生到指定出生点，而不是传送圈内部。
- 从旱魃地图返回城镇同样生效。
- 连续触发不会产生重复场景或重复玩家。
- 回归 Phase 1～4，并更新 README、TODO 和阶段复盘。

## 风险

| 风险 | 影响 | 处理 |
| --- | --- | --- |
| 第二张地图地形转换工作量大 | 可能拖慢 Phase 5 | 先用最小场景打通逻辑，地图还原独立推进 |
| 出生点落在传送圈触发区内 | 来回循环切换 | 固定偏移 1 格，并消费一次性出生点名 |
| 场景切换期间重复触发 | 重复切场景或残留节点 | `TeleportRing` 增加切换锁 |
