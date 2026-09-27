# Phase 2 实施计划：瓦片世界 + 碰撞

## 一、Summary

把 Unity 主场景 `SampleScene.unity` 里的地形与道具**用脚本忠实还原**到 Godot 4：

- 两层地形：`Ground`（地面，1547 格）+ `Obstacles`（障碍，118 格，带碰撞）
- 全部环境道具：树木（4 类预制体共 11 个实例）、朱门、屋檐、池塘、樱树 ×2
- Y-sort 遮挡生效，玩家被树木/建筑/水阻挡

产出物：解析脚本 `tools/convert_unity_scene.py` → 中间数据 `resources/world/town_map.json` → 生成器 `tools/build_town_map.gd` → 场景 `scenes/levels/town_map.tscn`，由 `scenes/levels/town.tscn` 实例化。

**不做**：Hook、敌人、装备、Tilemap 自动地形（Terrain）、动画瓦片、传送圈、NPC。

---

## 二、Current State Analysis

### 2.1 Unity 侧（已实测确认）

来源：`unity-app:Assets/Scenes/SampleScene.unity`（未 checkout，用 `git show` 读）

| 项 | 实测值 |
| --- | --- |
| Tilemap 层数 | 2 |
| `Tilemap`（地面） | 格子 x=-29..-1, y=-10..-1；1547 格；`m_SortingOrder=0`；无碰撞 |
| `障碍` | 格子 x=-29..-1, y=-10..-7；118 格；`m_SortingOrder=1`；**有 `TilemapCollider2D`（非 Trigger）** |
| `Grid.m_CellSize` | `{x:1, y:1}` |
| 图集 | `初始32格子素材.png`，512×480，`spritePixelsToUnits=64`，切片 32×32，pivot (0.5,0.5) |
| 图集 guid | `3acb934ef9c805941a1db7e0fa879af1` |
| 特殊瓦片 | 无 AnimatedTile、无 RuleTile、无自定义碰撞形状（`m_ColliderType: 1` = Sprite） |

**每个格子的数据链路**（两段都实测过，取短的那段）：

```
m_Tiles[i].first  = {x, y, z}          # 格子坐标
m_Tiles[i].second.m_TileIndex          # → 瓦片资源数组下标
瓦片资源数组[idx] = {fileID:11400000, guid:<.asset 的 guid>, type:2}
.asset 的 m_Sprite = {fileID:<图集内 sprite>, guid:3acb934e…, type:3}
```

等价短链路：`m_TileSpriteIndex` 直接 → 图集 sprite（`{fileID, guid:3acb934e…, type:3}`），跳过 `.asset`。**实现时优先用短链路**，`.asset` 的语义名（青砖正面/草坪/石障…）只用于人工核对。

瓦片资源实测（`Assets/img/map/2d地面调色板/`）语义名：`青砖正面`、`青砖`、`草坪`、`草坪背面`、`石障`，其余为 `中国风rpg游戏地图元件…_NNN` 自动命名。

**道具对象**（`SampleScene.unity` 内的 SpriteRenderer / PrefabInstance）：

| 对象 | 类型 | 备注 |
| --- | --- | --- |
| `屋檐` | SpriteRenderer | 537×42 |
| `池塘` | SpriteRenderer | 443×60 |
| `朱门` | SpriteRenderer | 537×464 |
| `“樱”“桃”树 (1)` | SpriteRenderer | 256×256 |
| `“樱”“桃”树` | SpriteRenderer | 同上 |
| `场景障碍` | 容器，11 个 PrefabInstance | 树木预制体 |

树木预制体在 `Assets/img/map/树木预制体/`，已解析到 4 个：`桃花直树`、`灌木丛`、`枯树`、`枫树夏天`。

### 2.2 Godot 侧现状

| 项 | 现状 |
| --- | --- |
| `scenes/levels/town.tscn` | 占位场景：`Town` → `World`(Node2D) → `Ground`(Node2D, 含 ColorRect + 6 个石障 Sprite2D 标记点) / `Entities`(含 Player 实例)；另有 `Lighting`(CanvasModulate)、`UI`(CanvasLayer) |
| `project.godot` | 2D 物理层已定义：1 `world` / 2 `player` / 3 `npc` / 4 `eaves` / 5 `town` / 6 `teleport` / 7 `pond` / 8 `interactable`；viewport 640×360，stretch `canvas_items` + `integer`；`default_texture_filter=0`(nearest) |
| `scenes/characters/player.tscn` | `Player`(CharacterBody2D, `collision_layer=2`, `collision_mask=1`) + `AnimatedSprite2D`(SpriteFrames, autoplay `idle_down`, **无 offset**) + `CollisionShape2D`(RectangleShape2D `24×32`, **position 0**) + `Camera2D` + `StateMachine` |
| `assets/environment/tiles/` | 10 个 PNG，含 `初始32格子素材.png`(512×480) 与 `32地图素材 2.png`(512×480) |
| `assets/environment/props/` | `“樱”“桃”树.png`(256×256)、`屋檐.png`(537×42)、`朱门.png`(537×464)、`池塘.png`(443×60)、`灌木丛_16种参考图.png`(744×504) |
| 动画帧 | Phase 1 已补齐为统一画布 94×81，靴底锚点 y=75、头部中心 x=47 |

### 2.3 计划文档既定设计（`MIGRATION_PLAN.md`）

- §5 第 301 行：Tilemap 布局数据「⚠️ 需写脚本解析 Unity YAML ｜ 或人工重画」→ **本次选脚本解析**
- §6 目标场景结构：`World(y_sort_enabled=true)` → `Ground` / `Obstacles` / `Props` / `Zones` / `Entities`
- §7：树木 6 个可合并为 `prop.tscn` + 不同贴图
- §12.1：物理层映射（上表）
- §12.2：树木/朱门/障碍 → `StaticBody2D`；屋檐 → `StaticBody2D` 层 `eaves`；池塘 → `Area2D` 层 `pond`
- §12.4：`World.y_sort_enabled = true`，树木/玩家/NPC 必须同处一个 Y-sort 父节点

---

## 三、Proposed Changes

### 3.1 新增 `tools/convert_unity_scene.py`（Python，一次性开发工具）

**Why**：Unity 数据无法手工可靠还原；且要可复现（以后能重跑）。

**How**：
1. 用 `git show unity-app:Assets/Scenes/SampleScene.unity` 读场景 YAML
2. 解析两个 Tilemap 的 `m_Tiles` + `m_TileSpriteArray`，得到 `(layer, x, y, fileID)`
3. 解析图集 `初始32格子素材.png.meta`：建立 `fileID → rect{x,y,w,h}` 映射
   - Unity 的 `fileID` 由 `spriteID`（32 位 hex）推导：取**前 16 个 hex 字符**当有符号 int64 大端解析
   - **实现第一步必须先验证这个换算**：用 `青砖正面.asset` 的 `m_Sprite.fileID = -8910997435833179003` 反查 meta，确认能对上唯一 rect；对不上就改用「按 spriteID 前 16 hex 转 unsigned 再判符号」等变体，直到对上
4. 解析道具：遍历场景里目标 GameObject 的 `SpriteRenderer.m_Sprite` → 同样走 `guid → PNG → fileID → rect`；`场景障碍` 的 11 个子对象按 `PrefabInstance.m_Modification` 取 `m_LocalPosition`，并读对应 `.prefab` 拿贴图
5. 输出 `resources/world/town_map.json`：
   ```json
   {
     "atlas": "res://assets/environment/tiles/初始32格子素材.png",
     "atlas_size": [512, 480],
     "tile_size": [32, 32],
     "ground":    [[x, y, ax, ay], ...],
     "obstacles": [[x, y, ax, ay], ...],
     "props": [
       {"name": "桃花直树", "kind": "tree", "pos": [px, py], "texture": "res://...", "rect": [x,y,w,h], "size": [w,h]}
     ]
   }
   ```
6. 坐标换算（**关键，写死为规则**）：
   - Unity y 轴向上、Godot y 轴向下 → `godot_y = -unity_y`
   - Unity 图集 rect 的 y 是**自下而上** → `godot_atlas_y = (atlas_h - rect.y - rect.h) / 32`
   - `godot_atlas_x = rect.x / 32`
   - 世界坐标：Unity 1 格 = `m_CellSize` = 1 单位 = `spritePixelsToUnits`(64) px → Godot px = unity_unit × 64
   - 若实测发现 PPU 与格子尺寸不匹配（64 vs 32px 切片），**以 32px 为格子尺寸**，把 Unity 世界坐标整体 ×(32/64)=0.5 换算，并在脚本里留一行注释说明依据

### 3.2 新增 `tools/build_town_map.gd`（Godot SceneTree 脚本，一次性开发工具）

**Why**：Godot 的 `TileMapLayer.tile_map_data` 是二进制格式，手工/外部生成易随版本失效；让 Godot 自己写最稳。

**How**：
1. 读 `res://resources/world/town_map.json`
2. 建 `TileSet`：`TileSetAtlasSource` 指向 `初始32格子素材.png`，`texture_region_size = Vector2i(32,32)`；对 JSON 里出现的每个 `(ax,ay)` 调 `create_tile()`
3. 建根节点 `TownMap`(Node2D) 及子节点：
   - `Ground` (TileMapLayer)：`tile_set` 同上，`y_sort_enabled=false`，`collision_enabled=false`
   - `Obstacles` (TileMapLayer)：`tile_set` 同上，`collision_enabled=true`，**每个用到的 tile 加一个 32×32 矩形物理层**，`physics_layer 0` = 层 1 `world`
   - `Props` (Node2D, `y_sort_enabled=true`)：每个道具一个 `StaticBody2D`（`collision_layer = 5 town`）+ `Sprite2D`(用 `region_enabled=true` + `region_rect` 从图集取切片) + `CollisionShape2D`(按贴图宽高建矩形，可留 4px 底部容差)
     - 屋檐单独放层 `4 eaves`
   - `Zones` (Node2D)：池塘一个 `Area2D`（`collision_layer = 7 pond`）+ `CollisionShape2D`
4. 对每个 tile 调 `set_cell(Vector2i(gx, gy), 0, Vector2i(ax, ay))`
5. `PackedScene.pack()` → `ResourceSaver.save(..., "res://scenes/levels/town_map.tscn")`；`TileSet` 存为 `res://resources/world/town_tileset.tres`
6. 无头运行方式（与现有测试同款）：
   ```
   HOME=/tmp/godot_home <godot> --headless --path . --script res://tools/build_town_map.gd
   ```

### 3.3 修改 `scenes/levels/town.tscn`

- `World` 设 `y_sort_enabled = true`
- 删除占位的 `World/Ground`（ColorRect + 6 个石障标记 Sprite2D）
- 新增 `World/TownMap` = 实例 `res://scenes/levels/town_map.tscn`
- `World/Entities` 保留（内含 Player 实例）
- `Lighting` / `UI` 保留不动
- 背景色保留在 `TownMap/Ground` 之下或改为 `Town` 根下的 ColorRect，避免删掉后画面全黑

### 3.4 修改 `scenes/characters/player.tscn`（仅为 Y-sort 基准点）

**Why**：Y-sort 按节点 origin 的 Y 排序，俯视游戏必须按**脚底**排序。当前 Player origin 在身体中心，会和树木的遮挡关系错乱。

**How**（数值来自 Phase 1 已定的帧锚点：画布 94×81、靴底 y=75）：
- `AnimatedSprite2D.offset = Vector2(0, -34.5)`（= 75 − 81/2），把脚底移到 origin
- `CollisionShape2D.position = Vector2(0, -16)`，让 24×32 的碰撞体位于脚底之上
- **不改** `player.gd`、`state_machine.gd`、`IdleState`、`MoveState`

### 3.5 新增 `tests/test_town_map.gd`（无头测试）

沿用 `tests/test_player_animation.gd` 的写法（`extends SceneTree`、退出码 0/1）：

- `town_map.tscn` 能加载；`Ground` / `Obstacles` / `Props` / `Zones` 节点存在
- `Ground.used_cells` 数量 == JSON 里 ground 格数（1547）
- `Obstacles.used_cells` 数量 == JSON 里 obstacles 格数（118）
- `Obstacles.collision_enabled == true`，且至少有一个 tile 定义了 physics layer
- 抽 3 个已知格子核对 `get_cell_atlas_coords()` 与 JSON 一致
- 玩家从初始位置向障碍方向移动若干帧后，位移被阻挡（`velocity` 被 `move_and_slide` 抵消 / 位置未穿过）
- `Props` 子节点数量 == JSON 里 props 数量；每个子节点有 `Sprite2D` + `CollisionShape2D`
- `World.y_sort_enabled == true`

---

## 四、Assumptions & Decisions

| # | 决策 | 依据 |
| --- | --- | --- |
| D1 | 地形用脚本解析还原，不人工重画 | 用户选择；`MIGRATION_PLAN.md` §5 也标注了此选项 |
| D2 | 道具全部解析生成 | 用户选择 |
| D3 | 地图持久化为 `town_map.tscn`，`town.tscn` 实例化 | 用户选择；可在编辑器查看/微调 |
| D4 | 走 `m_TileSpriteIndex` 短链路，`.asset` 语义名仅用于人工核对 | 少一层间接，减少出错点 |
| D5 | 格子尺寸按 32×32 px | 图集是「32格子素材」，切片实测 32×32 |
| D6 | Y-sort 基准点 = 脚底，通过 `AnimatedSprite2D.offset` + `CollisionShape2D.position` 调整 | `MIGRATION_PLAN.md` §12.4；帧锚点已知 |
| D7 | `Ground` 不做碰撞，`Obstacles` 做碰撞 | 对应 Unity 只有「障碍」层挂 `TilemapCollider2D` |
| D8 | 道具碰撞统一给层 1 `world`，屋檐额外给层 4 `eaves`，池塘给层 7 `pond` | §12.1 映射表 |
| D9 | 不生成 RuleTile/Terrain 自动地形 | Unity 侧实测无 RuleTile，§5 也标注第三方 Tilemap Extras 整体废弃 |
| D10 | 若 Unity `fileID ↔ spriteID` 换算对不上，改为按 `rect` 顺序 / `internalID` 兜底匹配 | 该换算未 100% 验证，留兜底路径 |

---

## 五、Verification

1. **脚本自检**：`convert_unity_scene.py` 跑完打印「ground 格数 / obstacles 格数 / props 数 / 图集切片命中数」，人工核对与本文档 2.1 节的 1547 / 118 / 13 一致
2. **无头测试**：`godot --headless --path . --script res://tests/test_town_map.gd` 退出码 0
3. **回归**：`godot --headless --path . --script res://tests/test_player_animation.gd` 仍 72/72 通过（改了 player.tscn 的 offset，需确认不影响 Phase 1 的动画断言）
4. **目视验收**（跑一次带窗口的 Godot，人工看）：
   - 地图完整显示、格子无缝、无错位
   - 玩家走到树后 → 被树遮挡；走到树前 → 遮住树
   - 玩家撞树/朱门/屋檐 → 被挡住；踩进池塘 → 不阻挡（Area2D）
   - 玩家脚底与地面格子对齐
5. **Git**：`git status` 确认只含预期文件，提交 `feat: add tilemap world`，推送 `main`

---

## 六、实施顺序

```
1. 写 convert_unity_scene.py，先只验证 fileID↔spriteID 换算（用青砖正面反查）
2. 跑通解析，产出 town_map.json，人工核对格数
3. 写 build_town_map.gd，生成 town_tileset.tres + town_map.tscn
4. 改 town.tscn（World y_sort + 实例化 TownMap）
5. 改 player.tscn（offset / 碰撞体位置）
6. 写 test_town_map.gd，无头跑通
7. 回归 test_player_animation.gd
8. 带窗口目视验收，修错位/遮挡问题
9. 更新 README，git commit + push
```