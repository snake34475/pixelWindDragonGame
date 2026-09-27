# Godot 4 迁移进度汇报

> 报告日期：2026-09-27
> 分支 / 提交：`main` @ `7e20afe`（与 `origin/main` 完全同步，工作区干净）
> 引擎：Godot 4.7.2 stable
> 完整路线见 `MIGRATION_PLAN.md`；本文件是**某一时刻的进度快照**，稳定结论以 `README.md` 为准。

---

## 一、总体状态

| 阶段 | 内容 | 状态 |
| --- | --- | --- |
| Phase 0 | Godot 基础骨架（项目配置 / Input Map / 物理层 / 目录结构 / GameManager / town 空场景 / Player 骨架 + Idle·Move 状态机 / 素材整理） | ✅ 已完成 |
| Phase 1 | 玩家移动与动画（四向 facing、`AnimatedSprite2D` + 5 组真实动画、walk / run、双击加速、`Camera2D` 平滑跟随 + limit、左右 `flip_h`） | ✅ 已完成 |
| Phase 2 | 瓦片世界 + 碰撞（Unity 地形/道具脚本还原 → `town_map.tscn`、TileSet + TileMapLayer、Y-sort 遮挡、障碍与道具碰撞、池塘 Area2D） | ✅ 已完成 |
| Phase 3 | 石头破坏（Q） | ⛔ **阻塞：缺素材** |
| Phase 4+ | 钩爪 / 敌人 / 装备 / NPC / UI 等 | ⏸ 未开始 |

当前**没有任何未提交的改动**，Phase 0～2 的成果全部已提交并推送到远端。

---

## 二、提交历史（main）

| 提交 | 说明 |
| --- | --- |
| `881b877` | feat: initialize Godot 4 project |
| `4360767` | feat: add Godot 4 Phase 0 skeleton |
| `1338df8` | feat: implement player animation and movement |
| `1727dc8` | feat: add player animation |
| `01f2795` | docs: add agent convergence rules and Phase 2 plan |
| `7e20afe` | feat: add tilemap world ← **当前 HEAD / origin/main** |

---

## 三、Phase 2 交付物

地形与道具**由脚本从 Unity 场景还原**，不是手工重画，可重复生成（幂等）：

```
unity-app:Assets/Scenes/SampleScene.unity
        │  tools/convert_unity_scene.py      （解析 Unity YAML）
        ▼
resources/world/town_map.json               （中间数据，9007 行，可人工核对）
        │  tools/build_town_map.gd           （生成 Godot 资源）
        ▼
resources/world/town_tileset.tres  +  scenes/levels/town_map.tscn
        │
        ▼  scenes/levels/town.tscn 实例化 TownMap
```

`7e20afe` 共改动 **15 个文件（+10688 / -45）**：

| 文件 | 作用 |
| --- | --- |
| `tools/convert_unity_scene.py` | Unity 场景 YAML 解析器（538 行） |
| `resources/world/town_map.json` | 中间数据（9007 行） |
| `tools/build_town_map.gd` | 由 JSON 生成 TileSet 与场景（262 行） |
| `tools/build_town_map.sh` | 三步跑法（写打包图集 → `--import` → 建资源） |
| `tools/render_town_preview.gd` | 无头渲染预览 PNG，供目视验收（141 行） |
| `assets/environment/tiles/town_tiles.png` | 重新打包后的规整瓦片图集 |
| `resources/world/town_tileset.tres` | TileSet（18 个切片） |
| `scenes/levels/town_map.tscn` | 生成的地形 + 道具场景（291 行） |
| `scenes/levels/town.tscn` | 改为实例化 `town_map.tscn`，`World.y_sort_enabled = true` |
| `scenes/characters/player.tscn` | 动画 / 碰撞体原点移到脚底，配合 Y-sort |
| `tests/test_town_map.gd` | Phase 2 无头测试（240 行） |
| `README.md` | 补齐 Phase 2 章节 |

### 实测数据（`resources/world/town_map.json` 核对结果）

| 项 | 值 |
| --- | --- |
| 打包切片数 | 18 |
| 地面格数 | **1546** |
| 障碍格数 | 118 |
| 道具数 | 14 |
| 池塘区域 | 1 |
| 格范围 | `gx ∈ [-29, 32]`、`gy ∈ [-20, 9]`（62 × 30） |
| 格尺寸 / 图集列数 | 64 px / 8 列 |
| 解析跳过项 | 0（无坏索引、无空精灵） |

---

## 四、验证证据

两条 SceneTree 无头测试，**本次重新跑过，退出码均为 0**：

| 测试 | 结果 | 命令 |
| --- | --- | --- |
| Phase 1 — 玩家动画 | **72 项检查，0 项失败** | `godot --headless --path . --script res://tests/test_player_animation.gd` |
| Phase 2 — 瓦片世界 | **35 项检查，0 项失败** | `godot --headless --path . --script res://tests/test_town_map.gd` |

Phase 2 测试覆盖：场景结构、各节点 `y_sort_enabled`、地面/障碍格数与 atlas 坐标、障碍碰撞层与物理多边形、**空间点查询**（验证障碍格有碰撞、纯地面格无碰撞）、道具与池塘区域、**玩家向上顶到障碍后停在表面未穿透**。

目视验收未开窗口，而是用 Godot 的 CPU 侧 `Image` 直接渲染了一张 4032 × 1984 的预览图（`tools/render_town_preview.gd`），已确认：地形无缝、树木 / 朱门 / 樱树 / 灌木丛 / 池塘位置正确、透明区正常。

---

## 五、Phase 2 过程中修掉的真实缺陷

| # | 现象 | 根因 | 修复 |
| --- | --- | --- | --- |
| 1 | 打包出来的瓦片图集是空白的 | `blit_rect()` 要求源与目标格式一致，源图不是 `RGBA8` | 先 `convert(FORMAT_RGBA8)` 再 `blit_rect` |
| 2 | 生成的 `town_map.tscn` 只有根节点（99 字节） | `PackedScene.pack()` 会**忽略 `owner` 未指向根节点的子节点** | 生成器最后递归指派 `owner` |
| 3 | TileSet 被整份内嵌进场景文件 | 未设 `resource_path`，无法转成引用 | 显式设 `resource_path`，改为 `ext_resource` |
| 4 | 预览图里道具全是黑块 | 预览器用 `blit_rect` 原样拷贝，丢弃了 alpha | 改用 `blend_rect`（**仅预览器问题，游戏内不受影响**） |

---

## 六、本次新增发现

### 6.1 PSB 素材审计（`unity-app` 全仓库）

全仓库只有 **6 个 PSB，没有 PSD**。帧数取自 Unity `.psb.meta` 的 `rigSpriteImportData`（权威值）：

| PSB 文件 | PPU | meta 帧数 | 已导出 | 状态 |
| --- | --- | --- | --- | --- |
| `Assets/img/role/dragin/龙人站立.psb` | 16 | 2 | `idle` 2 帧 | ✅ 完整 |
| `Assets/img/role/dragin/正身走路.psb` | 16 | 4 | `walk_down` 4 帧 | ✅ 完整 |
| `Assets/img/role/dragin/背身走路.psb` | 16 | **4** | `walk_up` **3 帧** | ⚠️ **少 1 帧，待核对** |
| `Assets/img/role/dragin/走路.psb` | 16 | 4 | `walk_side` 4 帧 | ✅ 完整 |
| `Assets/img/role/dragin/跑路6帧.psb` | 16 | 6 | `run` 6 帧 | ✅ 完整 |
| `Assets/img/map/地面素材/碎石动画.psb` | **32** | **8** | 无 | ⛔ **待导出（Phase 3 阻塞）** |

**`碎石动画.psb` 为什么无法自动导出**：

- 8 帧的 rect 排布在 2 列 × 6 行网格上（`x = 4 / 68`，`y = 4 / 44 / 84 / 124 / 164 / 204`），尺寸**递减**：56×32（帧 8/7/6/5）→ 35×32（帧 4）→ 31×32（帧 3/2/1），即石头从完整到碎没
- 但该 PSB 的**实际画布只有 64 × 32**（`sips` 实测 + 文件头一致），帧 rect 延伸到 (99, 236) —— **帧全在画布之外**。Photoshop 允许图层超出画布，Unity 的 PSD Importer 靠图层 rect 读取所以能拿到 8 帧，但扁平化导出的图只剩画布内的重叠部分，切不出帧
- `qlmanage`（Quick Look）**不支持 PSB**，本机无其他可用渲染器

> 另外注意 PPU 差异：碎石是 **32**，龙人系是 **16**，地形是 **64**。所以碎石特效在 Godot 里需要按 ×2 缩放才能对上世界比例。

### 6.2 `unity-app` 分支会出现"一大堆未提交代码"——那不是代码

切到 `unity-app` 后 `git status` 冒出的东西，**不是源码，是 Godot 的编辑器缓存 `.godot/`**。

原因（实测）：

- `main` 与 `unity-app` **无共同祖先**（两条不相关历史）：main 426 个文件、unity-app 878 个，**同名文件只有 2 个**（`.gitignore`、`README.md`）
- 切过去时，main 的 **424 个文件被整体从工作区删除**，同时写入 unity-app 的 878 个 Unity 文件
- **被 gitignore 的文件不受分支切换影响，会原地留下**。main 的 `.gitignore` 忽略了 `.godot/`，而 unity-app 的 `.gitignore` 是 Unity 官方模板，**完全没有 `.godot/` 这条规则** → `.godot/` 在 unity-app 上不再被忽略，**394 个缓存文件**全部变成未跟踪

⚠️ **严禁在 `unity-app` 上执行 `git add -A` 或提交** —— 会把 394 个 Godot 缓存文件提交进 Unity 分支，直接违反「禁止修改 `unity-app`」的硬约定。

浏览 Unity 工程的正确方式：

```bash
git show unity-app:<路径>                                        # 读单个文件
git -c core.quotepath=false ls-tree -r --name-only unity-app     # 列文件
git worktree add /tmp/ua-readonly unity-app                      # 需要能翻目录时（不改动分支）
```

---

## 七、与计划文档的偏差（已按实测修正）

| 项 | 计划文档 | 实测 | 处理 |
| --- | --- | --- | --- |
| 地面格数 | 1547 | **1546** | 以实测为准 |
| 格范围 | 描述不准确 | `gx ∈ [-29, 32]`、`gy ∈ [-20, 9]` | 以实测为准，并据此把 `Camera2D` limit 从占位的 ±960/±540 改为真实地图边界 `-1856 / -1280 / 2112 / 640` |
| `背身走路.psb` 帧数 | 3 帧 | meta 记录 **4 帧** | 标记为待核对（见 6.1） |

---

## 八、阻塞项与下一步

### 唯一阻塞：导出 `碎石动画.psb` 的 8 帧

需**人工**用 Photoshop 打开并导出（自动方案已证伪，见 6.1）：

- 输出到 `assets/effects/stone_break/`，建议命名 `stone_break_00.png` … `stone_break_07.png`
- 沿用既有导出约定：帧宽一致、背景透明 RGBA、保持原始像素尺寸不缩放
- 顺序按图层 name `8` → `1`
- **需确认播放方向**（完整 → 碎，还是反向）

### 下一步：Phase 3 — 石头破坏（Q）

| 项 | 内容 |
| --- | --- |
| 产出 | `scripts/world/tile_destructor.gd`、`scenes/effects/stone_break.tscn` |
| 逻辑 | 读玩家朝向 → 算目标格 → 若是石障 tile → 清除该格 + 生成破碎特效（1.5s 后自毁） |
| 验收 | ① 朝石障按 Q，石障消失 ② 破碎动画播放正确 ③ 特效播完自动销毁 ④ 非石障格按 Q 无反应 |

素材到位后即可开工；`tile_destructor.gd` 的骨架（读取目标格、判定石障、清除）不依赖素材，可先行实现，只把特效实例化部分留到素材到位。

---

## 九、不确定项

| 不确定项 | 影响 | 处理 |
| --- | --- | --- |
| `碎石动画.psb` 的播放方向 | 影响 `stone_break.tscn` 的帧序 | 导出时确认 |
| `背身走路.psb` 第 4 帧是否真实存在 | 若存在则 `walk_up` 缺一帧，动画会有跳变 | Photoshop 打开核对 |
| 碎石特效在 Godot 中的缩放系数 | 影响特效视觉大小是否与地形匹配 | 实现时按 PPU 32 → 64 换算，再用预览图目视确认 |

以上三项均**不阻塞** `tile_destructor.gd` 的逻辑实现，只影响素材与表现层。