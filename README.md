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
├── characters/dragon/      龙人：站立/出钩/冲刺/游泳遮罩
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
├── levels/                 town.tscn
├── effects/                （待 Phase 3/4）
├── world/                  （待 Phase 2）
└── ui/                     （待 Phase 5）

scripts/
├── player/                 player.gd、state_machine.gd、state.gd、states/
├── npc/ items/ world/ ui/  （待后续 Phase）
├── data/                   player_stats_data.gd
└── systems/                game_manager.gd（Autoload）

resources/
├── characters/             player_stats.tres
└── world/                  （待后续 Phase）
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

#### 待人工导出的 PSB（Phase 1 前置）

`unity-app` 里 6 个 `*.psb` 目前**没有**被导入 Godot，也没有生成任何转换文件：

| PSB 文件 | 尺寸 | 内容 | 建议导出 |
| --- | --- | --- | --- |
| `Assets/img/role/dragin/龙人站立.psb` | 120×150 | 站立（约 1 帧） | `dragon_idle_down.png`，单帧 |
| `Assets/img/role/dragin/走路.psb` | 300×150 | 走路（正面/侧面，约 3 帧） | `dragon_walk_<dir>.png`，横向排列帧 |
| `Assets/img/role/dragin/正身走路.psb` | 300×150 | 正身走路（约 3 帧） | `dragon_walk_down.png` |
| `Assets/img/role/dragin/背身走路.psb` | 300×150 | 背身走路（约 2 帧） | `dragon_walk_up.png` |
| `Assets/img/role/dragin/跑路6帧.psb` | 500×150 | 跑/冲刺 6 帧 | `dragon_run_<dir>.png` |
| `Assets/img/map/地面素材/碎石动画.psb` | 64×32 | 石头破碎 | `stone_break.png`，横向排列帧 |

建议导出结构：**每个动作一张横向 sprite sheet**，帧宽一致、帧序从左到右、
背景透明（RGBA）、保持原始像素尺寸不做缩放。导出后放进
`assets/characters/dragon/` 与 `assets/effects/stone_break/`。

> 环境说明：本机 macOS 的 `sips` 能读取 PSB 并导出扁平化 PNG，但实测各图层在画布上
> 位置不规则（例如 `走路.psb` 只有 3 个可见图形、`背身走路.psb` 只有 2 个，
> 且间距不均），无法可靠地切分出帧边界。因此这里不做自动切片，避免产出错误帧。

### 开发进度

- ✅ **Phase 0**：Godot 基础骨架（项目配置、Input Map、物理层、目录结构、GameManager、town 空场景、Player 骨架 + Idle/Move 状态机、素材整理）
- ⏭ **Phase 1**：玩家移动动画 + 相机（**前置：先把上面 6 个 PSB 导出为 PNG**）

完整规划见 `MIGRATION_PLAN.md`。

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