# pixelWindDragonGame

像素风飞龙游戏。本仓库包含两个独立开发、互不合并的分支。

## 分支说明

| 分支 | 引擎 | 用途 |
| --- | --- | --- |
| `main` | Godot 4 | 当前及未来的唯一主开发分支 |
| `unity-app` | Unity 2020.3.18f1c1 | 历史版本 / 参考实现，只读保留 |

两个分支拥有**互相独立**的 Git 历史，不做 merge。

---

## main（Godot 4）

**本项目当前开发方向为 Godot 4。**
`unity-app` 只用于历史参考、素材来源与玩法参考，不再更新。

### 开发环境

| 项 | 值 |
| --- | --- |
| 引擎 | Godot 4.4 或更高（`project.godot` 声明 `config/features = ("4.4", "GL Compatibility")`） |
| 渲染后端 | `gl_compatibility` |
| 基准分辨率 | 640 × 360，窗口 1280 × 720 |
| 拉伸 | `canvas_items` + `keep` 宽高比 + `integer` 缩放（像素对齐） |
| 纹理过滤 | Nearest（`default_texture_filter = 0`） |
| 瓦片尺寸 | 32 px（由 `assets/environment/tiles/` 素材实测反推） |

> **macOS 12 用户注意**：Godot 4.7.x 链接了 `MetalFX.framework`，在 macOS 12 上会
> `dyld: Library not loaded` 直接启动失败。若本机是 macOS 12，请使用 Godot 4.4.x；
> 或升级到 macOS 13+ 后再使用 4.7。

用 Godot 打开本目录（选择 `project.godot`），按 F5 运行主场景。

### 目录结构

```
assets/                     美术素材（从 unity-app 整理而来，见下文）
├── characters/dragon/      龙人动画帧：idle / walk_down / walk_up / walk_side / run
├── characters/npc/         佟湘玉立绘
├── enemies/hanba/          旱魃 启动/未启动
├── items/                  钩爪 / 锁链 / 飞镖
├── environment/tiles/      地面素材、九宫格过渡块、石障
├── environment/props/      树木 / 屋檐 / 朱门 / 池塘
├── effects/fire/           红焰 120 帧
├── effects/teleport/       传送圈 25 帧
└── ui/                     故事对话框

scenes/
├── characters/             player.tscn
├── items/                  （待 Phase 3/4）
├── levels/                 town.tscn、town_map.tscn（生成物）
├── effects/                （待 Phase 3/4）
└── ui/                     （待 Phase 5）

scripts/
├── player/                 player.gd、state_machine.gd、state.gd、states/
├── npc/ items/ world/ ui/  （待后续 Phase）
├── data/                   player_stats_data.gd
└── systems/                game_manager.gd（Autoload）

resources/
├── characters/             player_stats.tres、player_sprite_frames.tres
└── world/                  town_map.json（中间数据）、town_tileset.tres（生成物）

tools/                       开发期脚本（解析 Unity / 生成 Godot 资源）
├── convert_unity_scene.py   解析 unity-app 的 SampleScene → town_map.json
├── build_town_map.gd        由 town_map.json 生成 TileSet 与 town_map.tscn
├── build_town_map.sh        三步跑法（写打包图集 → --import → 建资源）
└── render_town_preview.gd   无头渲染预览图，供目视验收

tests/                       无头测试（SceneTree 脚本，退出码 0 = 通过）
├── test_player_animation.gd
└── test_town_map.gd
```

### 操作（Input Map）

| Action | 按键 | 用途 |
| --- | --- | --- |
| `move_up` | W / ↑ | 上移 |
| `move_down` | S / ↓ | 下移 |
| `move_left` | A / ← | 左移 |
| `move_right` | D / → | 右移 |
| `blast_tile` | Q | 炸石障 |
| `interact` | C | NPC 交互 |
| `hook` | E | 出钩 |
| `hook_fire` | 鼠标左键 | 发射飞钩 |

> 未创建 `jump` / `attack` / `skill_1` / `skill_2`：原 Unity 项目里代码从未使用，
> 等真正实现对应玩法时再加，不预留空 action。

### 物理层（Project Settings → Layer Names → 2D Physics）

| 层号 | 名称 | 对应 Unity 层 |
| --- | --- | --- |
| 1 | `world` | Default |
| 2 | `player` | player(11) |
| 3 | `npc` | npc(14) |
| 4 | `eaves` | 屋檐(15)，钩爪可抓取 |
| 5 | `town` | 城镇(16) |
| 6 | `teleport` | 传送圈(17) |
| 7 | `pond` | 池塘(18) |
| 8 | `interactable` | 新增，NPC 交互区 |

### Autoload

| 名称 | 脚本 | 职责 |
| --- | --- | --- |
| `GameManager` | `res://scripts/systems/game_manager.gd` | 查当前场景、记录目标出生点、切换场景 |

Phase 0 刻意只保留最小接口，玩法逻辑不放进全局单例。

### Player 结构与动画（Phase 1）

```
Player (CharacterBody2D)
├── AnimatedSprite2D        # SpriteFrames = player_sprite_frames.tres
├── CollisionShape2D
├── Camera2D
└── StateMachine
    ├── IdleState
    └── MoveState
```

动画名（用 `AnimatedSprite2D.play(name)` 按名播放，不引入 AnimationTree）。
素材只手工导出到 5 组动作，因此 `player_sprite_frames.tres` 里**只有 5 个动画**：

| 动画 | 帧数 | FPS | 来源文件夹 |
| --- | --- | --- | --- |
| `idle_down` | 2 | 4 | `站立` |
| `walk_down` | 4 | 8 | `正面走路` |
| `walk_up` | 3 | 6 | `背面走路` |
| `walk_side` | 4 | 8 | `走路` |
| `run_side` | 6 | 12 | `奔跑6帧` |

`idle_up` / `idle_side` / `run_down` / `run_up` 没有独立素材，`player.gd` 的
`ANIMATION_FALLBACK` 把它们映射到最接近的可用动画（向上/侧向待机 → `idle_down`，
向上/向下奔跑 → `run_side`）。补齐素材时删掉对应条目、往 `.tres` 里加动画即可，
状态机与移动逻辑不用改。

左右不做两套动画，靠 `AnimatedSprite2D.flip_h` 翻转（向右 `false`、向左 `true`）。

每帧已补齐到统一画布 94×81（RGBA，靴底对齐 y=75、头部中心 x=47），避免各帧
原始尺寸不一导致播放抖动。补的是透明像素，没有改动任何可见像素。

> 帧序来自文件名 `*_01.png`…，与原始 PSB 中的图层顺序一致。

朝向由 `player.gd` 收敛为上下左右四者之一（斜向按主导轴判定），状态机只读
`player.facing`，不自己猜方向。

移动参数集中在 `resources/characters/player_stats.tres`：

| 参数 | 值 | 说明 |
| --- | --- | --- |
| `walk_speed` | 60 px/s | 普通移动 |
| `run_speed` | 120 px/s | 双击同方向后 |
| `double_tap_window` | 0.5 s | 双击判定窗口 |

双击加速沿用 Unity `rolemove.cs` 原逻辑：`double_tap_window` 内再次按同一方向 → Run；
松开方向、改变方向、或超窗口后单次按 → 回到 Walk。不单独开 `SprintState`，只用
`player.is_sprinting` 切换速度与动画名；不做体力 / 冲刺条。

### Camera2D（Phase 1）

- `position_smoothing_enabled = true`，`position_smoothing_speed = 8`
- `drag_horizontal_enabled` / `drag_vertical_enabled = true`，margin `0.1`
- `limit_left / top / right / bottom = -1856 / -1280 / 2112 / 640`

> Phase 2 完成后按真实地图边界设置：地形格 `gx ∈ [-29, 32]`、`gy ∈ [-20, 9]`，
> 格 64px → 世界 `x ∈ [-1856, 2112]`、`y ∈ [-1280, 640]`。

### 瓦片世界（Phase 2）

地形与道具**由脚本从 Unity 场景还原**，不手工重画。数据流：

```
unity-app:Assets/Scenes/SampleScene.unity
        │  tools/convert_unity_scene.py        （解析 Unity YAML）
        ▼
resources/world/town_map.json                 （中间数据，可人工核对）
        │  tools/build_town_map.gd             （生成 Godot 资源）
        ▼
resources/world/town_tileset.tres  +  scenes/levels/town_map.tscn
        │
        ▼  scenes/levels/town.tscn 实例化 TownMap
```

重新生成（幂等）：

```bash
python3 tools/convert_unity_scene.py     # 需要能 git show unity-app 分支
./tools/build_town_map.sh                # 写打包图集 → --import → 建资源
```

目视验收（不需要窗口，直接渲染一张 PNG）：

```bash
godot --headless --path . --script res://tools/render_town_preview.gd -- /tmp/town_preview.png
```

坐标约定（`convert_unity_scene.py` 头部也有同样说明）：

- Unity y 轴向上、Godot y 轴向下 → `godot_y = -unity_y`
- 1 Unity 单位 = 1 格 = `spritePixelsToUnits` = **64px**
- 格 `(ux, uy)` 中心在 Unity `(ux+0.5, uy+0.5)` → Godot 格 `(gx, gy) = (ux, -uy - 1)`
- 图集 rect 的 y 自下而上 → `godot_atlas_y = atlas_h - rect.y - rect.h`

实测结果：地面 1546 格、障碍 118 格、道具 14 个、池塘区域 1 个；
格范围 `gx ∈ [-29, 32]`、`gy ∈ [-20, 9]`。

场景结构与碰撞：

| 节点 | 类型 | 说明 |
| --- | --- | --- |
| `World` | Node2D | `y_sort_enabled = true` |
| `World/TownMap/Ground` | TileMapLayer | `collision_enabled = false`，`z_index = -2` |
| `World/TownMap/Obstacles` | TileMapLayer | `collision_enabled = true`，物理层 0 = **1 world**，`z_index = -1` |
| `World/TownMap/Props` | Node2D | 每个道具一个 `StaticBody2D` + `Sprite2D` + `CollisionShape2D` |
| `World/TownMap/Zones` | Node2D | 池塘 = `Area2D`，层 **7 pond**（不阻挡玩家） |
| `World/Entities/Player` | CharacterBody2D | 与 Props 同一 Y-sort 层级 |

道具碰撞层：树木 / 朱门 = **1 world**，屋檐 = **1 world + 4 eaves**，池塘 = **7 pond**。
玩家 `collision_mask = 1`，所以树木/朱门/屋檐会挡住玩家，池塘不会。

Y-sort 基准点 = **脚底**：`AnimatedSprite2D.offset = (0, -34.5)`（帧高 81、靴底 y=75）、
`CollisionShape2D.position = (0, -16)`。`World`、`TownMap`、`Props`、`Zones`、`Entities`
都必须开 `y_sort_enabled`，Godot 会把嵌套的 Y-sort 子树摊平到同一排序里。

两点实现注意（踩过的坑）：

- Unity 图集切片不在 64 网格上（如 `y=224`），无法直接当 `TileSetAtlasSource` 用；
  `build_town_map.gd` 会把用到的切片**重新打包**成规整图集 `town_tiles.png`（每格 64px、8 列）。
- `PackedScene.pack()` 会**忽略 `owner` 未指向根节点的子节点**，所以生成器最后要显式
  递归指派 `owner`，否则保存出来的场景只有根节点。

### 测试

两个 SceneTree 无头测试，退出码 `0` = 全部通过、`1` = 有失败项。

本机 Godot 位于 `/Applications/Godot.app/Contents/MacOS/Godot`；若已将 Godot
加入 `PATH`，可将下列命令中的完整路径替换为 `godot`。

**Phase 1 — 玩家动画**（72 项）：场景加载、5 个动画的帧数/尺寸/FPS、四方向移动、
停止切回 Idle、双击奔跑、左右 `flip_h`、动画不逐帧重启。

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_player_animation.gd
```

**Phase 2 — 瓦片世界**（35 项）：场景结构、`y_sort_enabled`、地面/障碍格数与 atlas 坐标、
障碍碰撞层与物理多边形、空间点查询、道具与池塘区域、玩家被障碍挡住。

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_town_map.gd
```

**Phase 3 — 石障破坏**（15 项）：玩家前方目标格计算、石障清除、非石障无副作用、
碎石特效生成定位、7 帧贴图加载与自动回收。

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_tile_destructor.gd
```

> 无头环境下 `Input.action_press` 需要至少 1 个物理帧才会被
> `is_action_just_pressed` 观察到，所以测试里的"轻点"要按住 2～3 帧；
> 检查 `is_sprinting` 时也必须保持按住，松开后它会立刻被清零。

### 素材说明

`assets/` 里的图片从 `unity-app` 分支的 `Assets/img/` 整理而来，已按用途重新分类，
**没有**复制任何 Unity 专属内容（`*.unity`、`*.prefab`、`*.controller`、`*.anim`、
`2d-extras-2020.3`、`ProjectSettings/`、`Packages/`、`Library/` 等）。

两处整理动作：

- `Assets/img/role/dragin/红焰_00099.png` 与 `Assets/img/fire/红焰/红焰_00099.png`
  内容完全相同，只保留 `assets/effects/fire/` 下的那份。
- `Assets/img/map/地面素材/baf84f959c00fd73f8a06d6c0207a68.jpg`（4×4 灌木丛参考图，
  无文件名含义）转存为 `assets/environment/props/灌木丛_16种参考图.png`。
  该图是白底参考图，直接当精灵用需要先抠背景。

#### PSB 帧的导出情况

`unity-app` 里的 `*.psb` **没有**被导入 Godot，也不打算自动转换（`sips` 导出的
扁平图各图层在画布上位置不规则，无法可靠切帧）。龙人的 5 组动作已由人工拆帧、
导出为 PNG 序列帧，放进 `assets/characters/dragon/`：

| PSB 文件 | 对应输出 | 状态 |
| --- | --- | --- |
| `Assets/img/role/dragin/龙人站立.psb` | `assets/characters/dragon/idle/`（2 帧） | ✅ 已导出 |
| `Assets/img/role/dragin/正身走路.psb` | `assets/characters/dragon/walk_down/`（4 帧） | ✅ 已导出 |
| `Assets/img/role/dragin/背身走路.psb` | `assets/characters/dragon/walk_up/`（3 帧） | ✅ 已导出 |
| `Assets/img/role/dragin/走路.psb` | `assets/characters/dragon/walk_side/`（4 帧） | ✅ 已导出 |
| `Assets/img/role/dragin/跑路6帧.psb` | `assets/characters/dragon/run/`（6 帧） | ✅ 已导出 |
| `Assets/img/map/地面素材/碎石动画.psb` | `assets/effects/stone_break/`（7 帧） | ✅ 已导出并接入 |

碎石当前由桌面素材文件夹提供 7 帧，文件名 `7.png`（完整石头）至 `1.png`（碎裂残片）；
Godot 场景按 `7 → 1` 播放。各帧保持原始尺寸与透明通道，在场景中按 ×2 缩放匹配 64px 世界格。

> 环境说明：本机 macOS 的 `sips` 能读取 PSB 并导出扁平化 PNG，但实测各图层在画布上
> 位置不规则（例如 `走路.psb` 只有 3 个可见图形、`背身走路.psb` 只有 2 个，
> 且间距不均），无法可靠地切分出帧边界。因此这里不做自动切片，避免产出错误帧。

### 开发进度

Phase 3 基于 `7e20afe`（`feat: add tilemap world`）继续开发。2026-09-27 已用 Godot
4.7.2 重新验证：Phase 1 测试 72/72、Phase 2 测试 35/35、Phase 3 测试 15/15，均通过。

- ✅ **Phase 0**：Godot 基础骨架（项目配置、Input Map、物理层、目录结构、GameManager、town 空场景、Player 骨架 + Idle/Move 状态机、素材整理）
- ✅ **Phase 1**：玩家移动与动画（四向 facing、`AnimatedSprite2D` + 5 组真实动画帧、walk/run、双击加速、`Camera2D` 平滑跟随 + limit、左右 `flip_h`）
- ✅ **Phase 2**：瓦片世界 + 碰撞（Unity 地形/道具脚本还原 → `town_map.tscn`、TileSet + TileMapLayer、Y-sort 遮挡、障碍与道具碰撞、池塘 Area2D）
- ✅ **Phase 3**：石头破坏（Q）（前方格检测、Tile 与碰撞清除、7 帧碎石动画、自动回收；15 项无头测试）

下一步与阻塞项见 [TODO.md](TODO.md)。完整迁移设计与 Unity 侧证据见 `MIGRATION_PLAN.md`；已完成阶段的实施复盘放在 `.trae/documents/`。

---

## unity-app（Unity）

保留完整的 Unity 项目，包括 `Assets/`、`Packages/`、`ProjectSettings/`、`UIElementsSchema/`、`imgreadme/` 等。

该分支仅作历史存档与参考，**不再更新**。请勿在其中删除 Unity 文件，也不要将其与 `main` 合并。

Unity 侧的关键实现信息（供迁移参考）：

- 玩家移动、钩爪、炸石、交互：`Assets/c#/role/dragin/rolemove.cs`
- 飞钩：`Assets/c#/role/atk/feibiao.cs`
- NPC 游荡与对话：`Assets/c#/role/npc/npcMove.cs`、`Assets/c#/role/npc/npcdialog.cs`
- 相机跟随：`Assets/c#/role/camera/keepcamera.cs`
- 入水表现：`Assets/c#/mapItem/Swimming.cs`（`SpriteMaskInteraction.VisibleInsideMask`）
- 场景切换 / 跨场景单例：`Assets/c#/checkoutScence.cs`、`Assets/c#/keep.cs`
- 场景：`Assets/Scenes/SampleScene.unity`、`Assets/场景/旱魃图.unity`

> 当前 Unity 分支可确认的是城镇探索原型：移动、炸石、钩爪、传送、NPC 对话和入水表现。
> 未发现普攻、技能、敌人 AI、装备或掉落系统的游戏代码；这些属于未来新功能，而非现有迁移范围。
