# Unity → Godot 4 迁移方案（MIGRATION_PLAN）

> 状态：**Phase 0～7 已完成，Phase 8 待开始**。本文件保留规划与 Unity 侧调查证据。
> 参考实现：`unity-app` 分支（只读，未做任何修改）。
> 目标分支：`main`（Godot 4）。
> 分析日期：2026-09-26

---

## 0. 结论速览（先读这一段）

分析后有一个**必须先说清楚的事实**：

> 这个 Unity 项目是一个**早期原型**，不是完整游戏。
> README 里描述的"即时战斗 / 地牢 / 技能 / 装备 / NPC 交互"等内容，**绝大部分还没有实现**。

实际存在的可玩内容只有 **6 个机制**：

1. WASD 四向移动 + 双击方向加速跑
2. Q 键朝朝向炸掉石障瓦片（生成破碎特效）
3. E + 鼠标左键抛出飞钩，命中"屋檐"后把玩家拉过去（钩爪位移）
4. 走进"传送圈"切换场景
5. 朝 NPC 按 C 弹出对话框（3 秒自动关闭）
6. 进入"池塘"区域时角色做入水表现

**因此本方案的定位要调整**：

- **Phase 0 ~ 8 = 真正的"迁移"**（把上面 6 个机制在 Godot 里重建）
- **Phase 9+ = 新功能开发**（战斗 / 敌人 / 技能 / 装备 / 存档）——这些在 Unity 里也不存在，不是"迁移"，是"从零开发"

这样安排的好处：先花很少的工作量把现有原型在 Godot 跑通，验证手感，再在这个干净的基础上做新功能。

---

## 1. Unity 项目现状

### 1.1 工程信息

| 项 | 值 |
| --- | --- |
| Unity 版本 | 2020.3.18f1c1 |
| 渲染管线 | URP 10.6.0（2D Renderer） |
| 关键包 | Cinemachine 2.6.11、2D Animation 5.0.7、PSD Importer 4.1.0、2D Tilemap 1.0.0、TextMeshPro 3.0.6、Timeline 1.4.8 |
| 第三方插件 | `Assets/2d-extras-2020.3/`（Unity 官方 Tilemap Extras 包，37 个 .cs，**不是游戏代码**） |
| 目标平台 | 曾导出 WebGL（README 里有网页版地址） |

### 1.2 资产规模（`git ls-files` 实测）

| 类别 | 数量 | 说明 |
| --- | --- | --- |
| **游戏脚本（.cs）** | **9** | 其余 37 个 .cs 属于 `2d-extras` 第三方包 |
| 场景（.unity） | 2 | `SampleScene.unity`、`场景/旱魃图.unity` |
| 预制体（.prefab） | 14 | 含 2 个 Tilemap 调色板、7 个树木 |
| Animator Controller | 6 | |
| 动画剪辑（.anim） | 16 | |
| **ScriptableObject 数据资产** | **0** | 60+ 个 `.asset` 全是 Tile / RuleTile / URP 资产，**没有任何数据类 SO** |
| 位图（png） | 217 | 其中红焰 120 帧、传送圈 25 帧为序列帧 |
| 位图（jpg） | 1 | |
| Photoshop 源文件（psb） | 6 | 角色/碎石的图层源文件 |
| **音频（mp3/wav/ogg）** | **0** | 项目内完全没有音频 |
| **字体（ttf/otf）** | **0** | 无字体文件（TMP 用了默认字体） |
| 材质（.mat） | 3 | |
| Shader | 1 | `2d-extras` 自带，非游戏用 |

### 1.3 目录现状

```
Assets/
├── 2d render/            URP 2D Renderer 配置
├── 2d-extras-2020.3/     第三方 Tilemap Extras（将整体废弃）
├── Scenes/               SampleScene.unity（主场景）
├── animator/             6 个 Controller + 16 个 .anim
├── c#/                   9 个游戏脚本
│   ├── mapItem/Swimming.cs
│   ├── role/atk/feibiao.cs
│   ├── role/camera/keepcamera.cs
│   ├── role/dragin/rolemove.cs      ← 玩家控制器
│   ├── role/npc/npcMove.cs
│   ├── role/npc/npcdialog.cs
│   ├── checkoutScence.cs
│   ├── keep.cs
│   └── mapTile.cs
├── city/                 Tilemap 调色板
├── img/                  美术资源（249 文件）
│   ├── atk/              钩爪 / 锁链 / 飞镖
│   ├── fire/红焰/        120 帧火焰序列
│   ├── map/              地图素材 + 九宫格 + 树木预制体 + 传送圈 25 帧
│   ├── role/dragin/      龙人（6 个 psb + 出钩/冲 图）
│   ├── role/npc/佟湘玉/  NPC 立绘
│   └── ui/               故事对话框 UI
├── 场景/                 旱魃图.unity（第二张地图）
└── 预制体/               player / 佟湘玉 / 锁链 / 飞镖
```

### 1.4 层 / 标签

| Unity 层 | 索引 | 用途 |
| --- | --- | --- |
| Water | 4 | 未使用 |
| player | 11 | 玩家 |
| npc | 14 | NPC（C 键射线检测目标） |
| 屋檐 | 15 | 飞钩可抓取面（E 键射线检测目标） |
| 城镇 | 16 | 未使用 |
| 传送圈 | 17 | 场景切换 |
| 池塘 | 18 | 入水表现 |

标签（Tag）：`传送圈`、`屋檐`

### 1.5 输入

`ProjectSettings/InputManager.asset` 里**只有 Unity 默认轴**（Horizontal / Vertical / Fire1-3 / Jump / Mouse X / Mouse Y），没有自定义轴。

代码里实际用的是：
- `Input.GetAxisRaw("Horizontal")` / `("Vertical")` → WASD
- `Input.GetKeyDown(KeyCode.W/A/S/D)` → 双击检测
- `KeyCode.Q` 炸石头、`KeyCode.C` 对话、`KeyCode.E` + `GetMouseButtonDown(0)` 抛钩

---

## 2. 游戏核心玩法

### 2.1 类型判定

从场景截图（`imgreadme/image-20230519112353430.png`）与代码可确认：

> **俯视（Top-Down）2D 古风冒险游戏**，Tilemap 地面，HD 手绘风素材，玩家是"龙人"。

不是横版平台游戏——虽然有 `verticalY` 参数，但那是四向行走的上下方向，不是跳跃。

### 2.2 玩家能力（已实现）

| 能力 | 触发 | 实现位置 | 关键数值 |
| --- | --- | --- | --- |
| 四向移动 | WASD | `rolemove.cs` | `speed = 0.3` |
| 双击方向加速 | 0.5s 内同方向连按两次 | `rolemove.cs::setInterval` | `runSpeed` 1 → 2 |
| 朝向翻转 | 左右移动时 | `rolemove.cs` | 翻转 `role.localScale.x` |
| 炸石障 | Q | `rolemove.cs` → `mapTile.cs` | 朝向偏移 `0.8` 格 |
| NPC 对话 | C | `rolemove.cs` → `npcdialog.cs` | 射线 10f，仅 `npc` 层 |
| 抛飞钩/钩爪 | 按住 E + 左键 | `rolemove.cs` → `feibiao.cs` | `speed = 2f`，命中 `屋檐` 层 |
| 入水表现 | 进入池塘 | `Swimming.cs` | SpriteMask |

### 2.3 钩爪（最核心的机制，也最难迁）

```
按住 E + 左键
  → 生成 飞镖.prefab，target = 鼠标世界坐标
  → 飞镖朝 target 直线飞行
  → 到达 target.x 附近时：
      射线检测"屋檐"层
        ├─ 命中 → 切换飞镖贴图为"开合钩爪"，
        │        设 player.rotation = 飞镖.rotation，
        │        isFly = true，每帧把玩家往命中点拉
        │        距离 < 0.5 时 → 结束，重置 rotation
        └─ 未命中 → 直接销毁
  → 销毁时把玩家 Animator 的 ischong / isFly 置回 false
```

⚠️ 注意：`feibiao.cs` **直接反向操作 player 的 Transform 和 Animator**（位置、旋转、缩放、动画参数）。这是一种强耦合写法，在 Godot 里必须重构成"玩家状态机主动驱动钩爪"，而不是"钩爪反过来控制玩家"。

### 2.4 README 描述但**尚未实现**的内容

- ❌ 敌人（旱魃只有 `旱魃启动.png` / `旱魃未启动.png` 两张图和一张空地图，无 AI、无脚本）
- ❌ 战斗（无伤害、无 HP/MP、无受击、无死亡）
- ❌ 技能（无技能数据、无 CD、无 Hitbox）
- ❌ 装备 / 道具 / 背包 / 掉落（零代码、零数据）
- ❌ 存档
- ❌ 除一个 NPC 对话框外的全部 UI
- ❌ 音频（项目内没有任何音频文件）
- ❌ 地牢 / 雪山 / 岩浆地形（只有文字描述）

---

## 3. Unity 架构（实测依赖关系）

```
pixelWindDragonGame (unity-app)
│
├── 【玩家】Assets/预制体/player.prefab
│   └── player ................... Rigidbody2D + BoxCollider2D + rolemove.cs
│       ├── role ................. SpriteRenderer + Animator(role.controller)
│       │   └── Point Light 2D ... (URP 2D 光照)
│       └── fire/redFire ......... SpriteRenderer + Animator(redFire.controller)
│
├── 【NPC】Assets/预制体/佟湘玉.prefab
│   └── 佟湘玉 .................... Rigidbody2D + BoxCollider2D + npcMove.cs
│       ├── role ................. SpriteRenderer + Animator(佟湘玉_0.controller)
│       └── Canvas/npcDialog ..... Text(TMP) + npcdialog.cs
│
├── 【投掷物】Assets/预制体/飞镖.prefab
│   └── 飞镖 ...................... SpriteRenderer + feibiao.cs
│   └── (视觉) Assets/预制体/锁链.prefab → SpriteRenderer
│
├── 【机关】
│   ├── 传送圈.prefab ............. checkoutScence.cs + BoxCollider2D(Trigger)
│   │                              + Animator(25 帧) + Freeform Light 2D
│   ├── 石头.prefab ............... SpriteRenderer + Animator(石头破碎 8 帧)
│   └── Swimming.cs ............... SpriteMask 交互（池塘）
│
├── 【地图】Assets/Scenes/SampleScene.unity
│   ├── Grid + Tilemap ............ 309×156 格（地面 / 石障）
│   ├── 树木预制体 ×7 ............. 枫树 / 枫树夏天 / 枯树 / 树根 / 桃花直树 / 灌木丛 / 石头
│   ├── 屋檐 / 朱门 / 池塘 / 场景障碍
│   └── keep.cs ................... DontDestroyOnLoad 跨场景保留
│
├── 【相机】
│   ├── Main Camera
│   ├── CM vcam1 .................. Cinemachine 跟随
│   └── keepcamera.cs ............. 空脚本（无逻辑）
│
└── 【全局】
    ├── URP 2D Renderer + Global Light 2D
    └── EventSystem

第二张地图：Assets/场景/旱魃图.unity
  └── 122×84 + 189×152 Tilemap、Global Light 2D、障碍、传送圈、旱魃未启动
      （内容基本只有地形，属于未完成地图）
```

### 3.1 脚本依赖图

```
                    ┌──────────────────┐
                    │   rolemove.cs    │ 玩家控制器（唯一入口）
                    └────────┬─────────┘
          ┌──────────────────┼──────────────────┬───────────────┐
          ▼                  ▼                  ▼               ▼
   mapTile.cs         npcdialog.cs        feibiao.cs      (自身 Animator)
   炸石障逻辑          弹出对话框           生成飞钩         speed/verticalX/
          │                  ▲                  │            verticalY/ischong/isFly
          ▼                  │                  ▼
   Tilemap 读写        npcMove.cs 读          反向控制 player
                       Canvas.activeSelf      的 Transform + Animator
                              ▲
                              │
                       npcMove.cs（NPC 游荡）

   checkoutScence.cs ──→ SceneManager.LoadScene + 传送圈 Tag
   Swimming.cs ────────→ role.SpriteRenderer.maskInteraction
   keep.cs ────────────→ DontDestroyOnLoad 单例
   keepcamera.cs ──────→ 空
```

**重构要点**：`feibiao.cs` 与 `npcMove.cs` 存在"反向依赖 UI/玩家"的耦合，Godot 版本必须改为**单向依赖 + 信号（signal）通信**。

---

## 4. Unity → Godot 映射表

| Unity | Godot 4 | 说明 |
| --- | --- | --- |
| `MonoBehaviour` | `Node` + GDScript | 全部重写，不做逐行翻译 |
| `GameObject` / `Transform` | `Node2D` / `Node` | |
| `Prefab` | `PackedScene`（`.tscn`） | 结构需重新设计 |
| `Scene`（.unity） | `Scene`（`.tscn`） | 需重建 |
| `ScriptableObject` | `Resource`（`.tres`） | 本项目当前为 0 个 |
| `Rigidbody2D` + `MovePosition` | `CharacterBody2D` + `move_and_slide()` | Unity 用的是"运动学式"控制，对应 CharacterBody2D 而非 RigidBody2D |
| `Rigidbody2D`（真物理） | `RigidBody2D` | 本项目无此用法 |
| `BoxCollider2D`（实体） | `CollisionShape2D`（RectangleShape2D） | |
| `BoxCollider2D`（Trigger） | `Area2D` + `CollisionShape2D` | |
| `Physics2D.Raycast` | `RayCast2D` 节点 或 `PhysicsDirectSpaceState2D` | |
| `LayerMask.GetMask("npc")` | 物理层 + `collision_mask` / `collide_with_areas` | |
| `Animator` + `AnimatorController` | `AnimatedSprite2D` + `SpriteFrames` | 本项目全是序列帧 |
| `Animator` Blend Tree | 状态机代码 + `AnimatedSprite2D.play(name)` | **不用** AnimationTree，降低复杂度 |
| `Animation Clip`（改属性） | `AnimationPlayer` | 如"冲钩"改 transform |
| `Animation Event` | `AnimationPlayer` 的 `animation_finished` 信号 / `Call Method Track` | |
| `Cinemachine Virtual Camera` | `Camera2D`（`position_smoothing_enabled`） | |
| `DontDestroyOnLoad` | `Autoload`（单例） | `keep.cs` |
| `SceneManager.LoadScene` | `get_tree().change_scene_to_file()` | |
| `Coroutine` | `await` + `get_tree().create_timer()` | |
| `UnityEvent` | `Signal`（`signal` / `emit`） | |
| `SpriteMask` + `maskInteraction` | 着色器遮罩 或 `modulate` + 覆盖层 | 见 §12 |
| `Tilemap` + `RuleTile` | `TileMapLayer` + `TileSet`（Terrain 自动地形） | |
| `SpriteRenderer.sortingOrder` | `CanvasItem.z_index` + `y_sort_enabled` | 俯视游戏必须做 Y 排序 |
| URP `Light2D` / `Global Light 2D` | `PointLight2D` / `DirectionalLight2D` + `CanvasModulate` | |
| URP 材质 / Shader | Godot `Material` / `Shader` | 需重做 |
| `Text`（TMP） | `Label` / `RichTextLabel` | 中文需自带字体 |
| `Canvas` + `CanvasScaler` | `CanvasLayer` + `Control` + `ProjectSettings` 拉伸模式 | |
| `Image` | `TextureRect` | |
| `Button` | `Button` | |
| `Slider` | `HSlider` / `ProgressBar` | |
| `Panel` | `PanelContainer` / `Panel` | |
| `EventSystem` | Godot 内置（无需节点） | 直接删 |
| Unity Input（旧版） | `InputMap` + `Input.is_action_pressed()` | |
| `Debug.Log` | `print()` / `push_warning()` | |
| Addressables | `ResourceLoader` / `load()` | 本项目未使用 |

---

## 5. 资源迁移表

| 资源类型 | 数量 | 主要用途 | 可直接复用 | 需转换 | 建议重做 |
| --- | --- | --- | --- | --- | --- |
| PNG 位图 | 217 | 角色/地图/特效/UI | ✅ 直接复制 | — | — |
| JPG 位图 | 1 | 地面素材 | ✅ | — | — |
| **PSB 图层源文件** | 6 | 角色/碎石动画源 | ❌ | ⚠️ **必须导出为 PNG 精灵表** | — |
| 序列帧（红焰） | 120 | 火焰特效 | ✅ 帧可复制 | 需重建 `SpriteFrames` | — |
| 序列帧（传送圈） | 25 | 传送门 | ✅ | 需重建 `SpriteFrames` | — |
| 序列帧（石头破碎） | 8 | 破碎特效 | ✅ | 需重建 `SpriteFrames` | — |
| 角色帧（站立/走/跑/正身/背身/出钩/冲） | — | 龙人动画 | ✅（来自 PSB） | 需重建 4 向 `SpriteFrames` | 切片可能需重做 |
| 地图瓦片 | 113 文件 | 地面/石障/九宫格 | ✅ | 需重建 `TileSet` | — |
| **Tilemap 布局数据** | 2 场景 4 张图（最大 309×156） | 关卡地形 | ❌ | ⚠️ 需写脚本解析 Unity YAML | 或人工重画 |
| RuleTile 资产 | 60+ `.asset` | 自动拼接地形 | ❌ | 改用 Godot Terrain | 需重设 |
| Animator Controller | 6 | 状态/混合 | ❌ | 改 `SpriteFrames` + 代码状态机 | — |
| Animation Clip | 16 | 帧动画 | ❌ | 重建 `AnimatedSprite2D` / `AnimationPlayer` | — |
| URP 材质 | 3 | 池塘/锁链 | ❌ | 重建 Godot Material | — |
| URP 光照配置 | 2 `.asset` | 2D 光照 | ❌ | 删除，改 Light2D | — |
| **音频** | **0** | — | — | — | 需要新增素材 |
| **字体** | **0** | 中文 UI | — | — | 需自备中文字体 |
| 第三方 Tilemap Extras | 37 `.cs` | 编辑器扩展 | ❌ | 整体废弃 | — |

### 5.1 可直接复制的资源清单

```
Assets/img/role/dragin/*.png          → 龙人散图（人物出钩.png / 人物冲.png / 红焰_00099.png / 龙人游泳遮罩.png）
Assets/img/role/npc/佟湘玉/*.png      → NPC 立绘
Assets/img/fire/红焰/*.png (120 帧)    → 火焰特效
Assets/img/atk/*.png                  → 开合钩爪 / 锁链1 / 飞镖
Assets/img/map/地面素材/**             → 地面瓦片 + 传送圈 25 帧 + 石障
Assets/img/map/九宫格/*.png            → 地形过渡瓦片
Assets/img/map/*.png                  → 屋檐 / 朱门 / 池塘 / 旱魃 / "樱""桃"树
Assets/img/ui/*.png                   → 故事对话框
imgreadme/*.png (6 张)                → 仅作参考截图，不进游戏
```

---

## 6. Scene 迁移表

| Unity Scene | 用途 | 主要对象 | 对应 Godot Scene | 迁移难度 |
| --- | --- | --- | --- | --- |
| `Assets/Scenes/SampleScene.unity` | 主游戏场景（城镇） | Main Camera + CM vcam1、Grid + Tilemap(309×156)、玩家、佟湘玉(NPC)、13 个环境预制体实例、Canvas/npcDialog、EventSystem、屋檐、朱门、池塘、场景障碍、场景障碍、Global Light 2D | `scenes/levels/town.tscn`（地形层 + `entities/` 下的实例） | 高（Tilemap 数据量大） |
| `Assets/场景/旱魃图.unity` | 旱魃地图（未完成） | Main Camera、Grid + Tilemap(122×84 + 189×152)、障碍、传送圈、Global Light 2D、旱魃未启动 | `scenes/levels/hanba_map.tscn` | 中（内容少但仍有地形） |

### 6.1 建议的 Godot 场景组织

不要把整张地图塞进一个 `.tscn`（Unity 的 SampleScene 有 55 万字符，旱魃图 300 万字符）。Godot 版本建议：

```
scenes/levels/town.tscn
├── World (Node2D, y_sort_enabled = true)
│   ├── Ground        (TileMapLayer: 地面)
│   ├── Obstacles     (TileMapLayer: 石障, 可破坏)
│   ├── Props         (Node2D: 树木/朱门/屋檐 等 StaticBody2D 实例)
│   ├── Zones         (Node2D: 池塘/传送圈 Area2D)
│   └── Entities      (Node2D: player.tscn / npc.tscn 运行时生成)
├── Lighting          (CanvasModulate + PointLight2D)
└── UI                (CanvasLayer)
```

---

## 7. Prefab 迁移表

| Unity Prefab | 分类 | 组件 | 对应 Godot Scene | 备注 |
| --- | --- | --- | --- | --- |
| `预制体/player.prefab` | Player | Rigidbody2D, BoxCollider2D, rolemove, Animator×2, SpriteRenderer×2, Point Light 2D | `scenes/characters/player.tscn` | 加 Camera2D（原相机在场景里） |
| `预制体/佟湘玉.prefab` | NPC | Rigidbody2D, BoxCollider2D, npcMove, Animator, SpriteRenderer | `scenes/characters/npc.tscn` | 对话框拆出去 |
| `预制体/飞镖.prefab` | Projectile | SpriteRenderer, feibiao | `scenes/items/hook.tscn` | 改为 Area2D |
| `预制体/锁链.prefab` | Effect | SpriteRenderer | `scenes/effects/chain.tscn` | 钩爪绳索视觉 |
| `img/map/树木预制体/传送圈.prefab` | Zone | BoxCollider2D(Trigger), checkoutScence, Animator(25 帧), Freeform Light2D | `scenes/world/teleport_ring.tscn` | 改 Area2D |
| `img/map/树木预制体/石头.prefab` | Effect | SpriteRenderer, Animator(8 帧) | `scenes/effects/stone_break.tscn` | 一次性播放后自毁 |
| `枫树 / 枫树夏天 / 枯树 / 树根 / 桃花直树 / 灌木丛` | Environment | SpriteRenderer, BoxCollider2D | `scenes/world/props/*.tscn` | 6 个树，可合并为一个 `prop.tscn` + 不同贴图 |
| `city/Rectangular Palette.prefab` | Tile Palette | Tilemap 调色板 | ❌ 丢弃 | Godot TileSet 编辑器替代 |
| `img/role/dragin/2d调色板/2d.prefab` | Tile Palette | Tilemap 调色板 | ❌ 丢弃 | 同上 |

> 7 个树木预制体结构完全一致（SpriteRenderer + BoxCollider2D），建议在 Godot 里**合并成一个可复用场景** `scenes/world/prop.tscn`，用导出变量指定贴图和碰撞尺寸——这是比 Unity 原结构更干净的做法。

---

## 8. Script 迁移表

### 8.1 分类（按实际代码，不强行套用模板）

| 分类 | 文件 | 职责 |
| --- | --- | --- |
| **Player** | `role/rolemove/rolemove.cs` | 移动 / 朝向 / 加速 / 交互入口 |
| **Camera** | `role/camera/keepcamera.cs` | **空脚本**，无逻辑 |
| **Enemy** | — | **不存在** |
| **Combat** | — | **不存在** |
| **Skill** | — | **不存在** |
| **Equipment / Item / Inventory / Drop** | — | **不存在** |
| **World / Map** | `mapTile.cs` | Tilemap 石障破坏 |
| **World / Interaction** | `mapItem/Swimming.cs` | 入水表现 |
| **World / Transition** | `checkoutScence.cs` | 场景切换 + 出生点 |
| **NPC** | `role/npc/npcMove.cs` | NPC 游荡 |
| **UI** | `role/npc/npcdialog.cs` | 对话框显隐 + 3s 计时 |
| **Projectile** | `role/atk/feibiao.cs` | 飞钩飞行 + 拉拽玩家 |
| **Utility / Global** | `keep.cs` | DontDestroyOnLoad 单例 |
| **Animation** | — | 无代码，全靠 Animator |
| **Audio / Input / Network / Save / AI** | — | **不存在** |
| **第三方** | `2d-extras-2020.3/**` (37 个) | 整体废弃 |

### 8.2 逐文件迁移方案

| Unity 脚本 | 行数 | Godot 目标 | 方案 |
| --- | --- | --- | --- |
| `rolemove.cs` | 147 | `scripts/player/player.gd` + `scripts/player/states/*.gd` | 拆分：移动/加速→MoveState；Q→`world/tile_destructor.gd`；C→`npc/interactor.gd`；E+左键→HookThrowState |
| `feibiao.cs` | 117 | `scripts/items/hook.gd` | 反向控制玩家 → 改为钩爪只发 `hook_attached(point)` 信号，由玩家状态机决定是否拉拽 |
| `mapTile.cs` | 41 | `scripts/world/tile_destructor.gd` | `TileMapLayer.get_cell_source_id()` + `set_cell()` |
| `checkoutScence.cs` | 38 | `scripts/world/teleport.gd` + `scripts/systems/game_manager.gd` | 场景切换交给 GameManager，出生点用 GameManager 传递 |
| `npcMove.cs` | 80 | `scripts/npc/npc.gd` | 游荡逻辑保留；对话框状态改用信号而非直接读 `Canvas.activeSelf` |
| `npcdialog.cs` | 33 | `scripts/ui/npc_dialog.gd` | 用 `Timer` 替代手写倒计时 |
| `Swimming.cs` | 35 | `scripts/world/water_zone.gd` | 见 §12.3 |
| `keep.cs` | 19 | `scripts/systems/game_manager.gd`（Autoload） | 直接改用 Autoload，不需要"同名销毁"hack |
| `keepcamera.cs` | 17 | ❌ 删除 | 空脚本 |

> 合计约 **530 行 C#** → 预计 **600~800 行 GDScript**（含状态机与信号重构）。
> 这是**很小的量**。真正的成本在**资源转换（PSB 切片 + Tilemap 数据）**，不在代码。

---

## 9. ScriptableObject → Resource 设计

### 9.1 现状

**本项目 ScriptableObject 数量 = 0。** 所有数值都硬编码在 C# 里：

| 数值 | 位置 | 值 |
| --- | --- | --- |
| 玩家移动速度 | `rolemove.speed` | `0.3` |
| 加速倍率 | `rolemove.runSpeed` | `1` / `2` |
| 双击判定窗口 | `rolemove.setInterval` | `0.5s` |
| 炸石障偏移 | `rolemove` Q 分支 | `0.8` 格 |
| 交互射线长度 | `rolemove` C 分支 | `10f` |
| 飞钩速度 | `feibiao.speed` | `2f` |
| 飞钩命中阈值 | `feibiao` | `0.1` / `0.5` |
| NPC 速度 | `npcMove.speed` | `1f` |
| NPC 游荡间隔 | `npcMove.suiMove` | `5s` |
| 对话显示时长 | `npcdialog` | `3f` |

### 9.2 建议的 Resource 设计（**克制，不要过度设计**）

不要现在就造 `SkillData` / `ItemData` / `EquipmentData`——**它们没有任何数据可装**，造出来就是空壳。只把**真实存在的数值**抽出来：

```
resources/
├── characters/
│   └── player_stats.tres      # PlayerStatsData
└── world/
    └── world_tuning.tres      # WorldTuningData
```

```gdscript
# scripts/data/player_stats_data.gd
class_name PlayerStatsData
extends Resource

@export var walk_speed: float = 60.0          # px/s（替代 Unity 的 0.3f，按像素换算）
@export var sprint_multiplier: float = 2.0
@export var sprint_window: float = 0.5        # 双击判定窗口（秒）
@export var hook_speed: float = 400.0
@export var hook_range: float = 320.0
@export var body_size: Vector2 = Vector2(24, 32)
```

```gdscript
# scripts/data/world_tuning_data.gd
class_name WorldTuningData
extends Resource

@export var blast_offset: float = 32.0        # 炸石障朝向偏移（px，= 1 格）
@export var interact_ray_length: float = 160.0
@export var dialog_duration: float = 3.0
@export var npc_wander_interval: float = 5.0
```

### 9.3 未来（Phase 9+ 真要做新功能时再建）

```
resources/
├── enemies/    enemy_data.tres      # 旱魃等
├── skills/     skill_data.tres
├── items/      item_data.tres
└── equipment/  equipment_data.tres
```

**原则**：先有数据，再有 Resource。不为了"架构漂亮"提前造空类。

---

## 10. UI 迁移方案

### 10.1 现状

UI 只有**一个 NPC 对话框**：

```
Canvas (SampleScene)
└── npcDialog                     ← npcdialog.cs 控制显隐
    └── ... Text (TextMeshPro)    ← "逗仙全套UI-故事对话框" 贴图
```

`EventSystem` 是 Unity 必需节点，Godot 不需要。

### 10.2 映射

| Unity | Godot | 说明 |
| --- | --- | --- |
| `Canvas` | `CanvasLayer` | 独立于世界坐标 |
| `CanvasScaler` | Project Settings → Display → Stretch | 全局统一设置，不用每场景配 |
| `npcDialog` (Panel) | `Control` + `NinePatchRect` 或 `TextureRect` | 用"逗仙对话框"九宫格贴图 |
| `Text` (TMP) | `RichTextLabel` / `Label` | ⚠️ **项目内无字体文件，必须自备中文字体** |
| `EventSystem` | ❌ 删除 | Godot 内置 |

### 10.3 Godot 场景

```
scenes/ui/npc_dialog.tscn
└── NpcDialog (CanvasLayer)
    └── Panel (NinePatchRect, 逗仙对话框贴图)
        └── MarginContainer
            └── Label / RichTextLabel (中文文本)
```

接口设计（供 AI 后续扩展）：

```gdscript
# scripts/ui/npc_dialog.gd
signal dialog_closed
func show_dialog(speaker: String, text: String) -> void
```

### 10.4 中文显示注意

- 需要 1 个中文字体（如思源黑体 / 站酷字体），项目当前**没有任何字体文件**。
- 字体文件需要用户提供，或使用开源可商用字体。
- 像素风游戏建议关掉字体抗锯齿（`Font` → 关闭 antialiasing）保持风格统一。

---

## 11. Animator → Godot Animation 方案

### 11.1 Unity 现状

**玩家** `role.controller`：

```
参数：speed(Float), verticalX(Float), verticalY(Float), isFly(Bool), ischong(Bool)

状态：
  站立 / 移动 / 奔跑 / 正身 / 背身   ← 全部是 Blend Tree，按 speed + verticalX/verticalY 混合
  出钩 / 冲钩 / 冲钩左              ← 单帧姿势（由 ischong / isFly 驱动）
```

**NPC** `佟湘玉_0.controller`：

```
参数：speed, verticalX, verticalY
Blend Tree：verticalX × verticalY → static / topmove / downmove / leftandright
```

**特效**：`redFire`(120 帧) / `传送圈`(25 帧) / `石头破碎`(8 帧) / `飞镖旋转`(0 帧，旋转由代码控制)

### 11.2 Godot 方案（按类型分）

| 类型 | 用什么 | 原因 |
| --- | --- | --- |
| **角色 4 向行走**（站立/走/跑 × 上下左右） | `AnimatedSprite2D` + `SpriteFrames` | 全部是序列帧；用 `play("walk_down")` 这种**按名字播放**最直观，Godot 新手最好理解，AI 也最容易改 |
| **角色出钩/冲钩** | `AnimatedSprite2D` 单帧 + 状态机控制 | 单帧姿势，不需要动画系统 |
| **火焰 / 传送圈 / 碎石** | `AnimatedSprite2D` | 纯序列帧 |
| **非帧属性动画**（如"冲钩"改 transform） | `AnimationPlayer` | 需要改位置/旋转/缩放时用 |
| ❌ `AnimationTree` + `BlendSpace2D` | **不推荐** | 虽然最接近 Unity Blend Tree，但节点/参数配置复杂，对 Godot 新手和 AI 都不友好。用代码选动画名更简单 |

### 11.3 动画命名规范（建议）

```
SpriteFrames 动画名：
  idle_down / idle_up / idle_side
  walk_down / walk_up / walk_side
  run_down  / run_up  / run_side

左右方向用 flip_h 翻转，不做左右两套
```

播放逻辑放在 `MoveState`：

```gdscript
func _update_animation(dir: Vector2) -> void:
    if dir == Vector2.ZERO:
        sprite.play("idle_" + _dir_suffix())
    else:
        var prefix := "run_" if player.is_sprinting else "walk_"
        sprite.play(prefix + _dir_suffix())

func _dir_suffix() -> String:
    if absf(player.facing.x) > absf(player.facing.y):
        return "side"
    return "up" if player.facing.y < 0 else "down"
```

### 11.4 动画帧来源问题（关键风险）

角色帧来自 **PSB（Photoshop）多图层文件**，Unity 用 PSD Importer 自动切片。Godot **不支持 .psb/.psd 导入**。

必须做的事：
1. 在 Unity 中把每个 PSB 的各帧**导出为独立 PNG**（或整张精灵表 PNG）
2. 或者在 Photoshop 里导出
3. 再在 Godot 里切成 `AtlasTexture` 或按帧导入

这一步**无法由 AI 自动完成**（需要 Unity/PS 编辑器）。详见 §18 风险 R1。

---

## 12. Physics / Collision 迁移方案

### 12.1 物理层映射

Godot 物理层（Project Settings → Layer Names → 2D Physics）：

| 层号 | 名称 | 对应 Unity 层 |
| --- | --- | --- |
| 1 | `world` | Default |
| 2 | `player` | player(11) |
| 3 | `npc` | npc(14) |
| 4 | `eaves` | 屋檐(15)（钩爪可抓取） |
| 5 | `town` | 城镇(16) |
| 6 | `teleport` | 传送圈(17) |
| 7 | `pond` | 池塘(18) |
| 8 | `interactable` | 新增（NPC 交互区） |

### 12.2 按用途选节点（**不做一一替换**）

| 对象 | Unity | Godot | 理由 |
| --- | --- | --- | --- |
| 玩家 | Rigidbody2D(MovePosition) + BoxCollider2D | `CharacterBody2D` + `CollisionShape2D` | 代码完全控制移动 → 运动学体最合适 |
| NPC | Rigidbody2D(MovePosition) + BoxCollider2D | `CharacterBody2D` + `CollisionShape2D` | 同上 |
| 树木/朱门/障碍 | BoxCollider2D（静态） | `StaticBody2D` + `CollisionShape2D` | 不动 |
| 屋檐（钩爪目标） | 层 `屋檐` + 射线 | `StaticBody2D`，层 `eaves` | 射线要打物理体 |
| 传送圈 | BoxCollider2D(Trigger) | `Area2D` + `CollisionShape2D` | 只检测不阻挡 |
| 池塘 | 层 `池塘` + SpriteMask | `Area2D`（层 `pond`） | 只检测 |
| NPC 交互区 | 射线打 `npc` 层 | `Area2D`（层 `interactable`）**或**保留射线 | 建议改 Area2D，更直观 |
| 飞钩 | BoxCollider2D | `Area2D` | 只做检测，不参与物理 |
| 石头破碎特效 | 无碰撞 | 无碰撞（纯 `AnimatedSprite2D`） | |

### 12.3 入水表现（SpriteMask 的替代）

Unity 用 `SpriteMaskInteraction.VisibleInsideMask` 做"角色被水面遮住下半身"。

Godot 三种做法，按复杂度排序：

| 方案 | 实现 | 优点 | 缺点 |
| --- | --- | --- | --- |
| **A. 着色近似**（推荐起步） | 进入 `pond` Area2D → 玩家 `modulate` 变蓝 + 半透明 | 5 行代码，Godot 新手友好 | 不是真正的遮罩 |
| **B. 覆盖层** | 池塘上方加一个半透明水面 `Sprite2D`，`z_index` 高于玩家 | 视觉效果好，简单 | 需要正确设置层级 |
| **C. 遮罩 Shader** | 用 `SCREEN_TEXTURE` + 遮罩贴图写 `shader` | 最接近原效果 | 需要写着色器，调试成本高 |

建议：**先做 A + B**，如果用户觉得效果不够再上 C。

### 12.4 Y 排序（俯视游戏必须）

Unity 用 `SpriteRenderer.sortingOrder`。Godot 用：

```
World (Node2D) → y_sort_enabled = true
```

配合每个物体 `z_index` 微调。树木、玩家、NPC 必须同处一个 Y-sort 父节点下，否则遮挡关系会错。

---

## 13. Input 迁移方案

### 13.1 实测需要的动作

| Godot Action | 按键 | 来源 |
| --- | --- | --- |
| `move_up` | W / ↑ | `GetAxisRaw("Vertical")` |
| `move_down` | S / ↓ | 同上 |
| `move_left` | A / ← | `GetAxisRaw("Horizontal")` |
| `move_right` | D / → | 同上 |
| `blast_tile` | Q | `KeyCode.Q` |
| `interact` | C | `KeyCode.C` |
| `hook` | E | `KeyCode.E` |
| `hook_fire` | 鼠标左键 | `GetMouseButtonDown(0)` |

### 13.2 关于用户提到的其他动作

| 建议动作 | 现状 | 处理 |
| --- | --- | --- |
| `jump` | Unity 有 `Jump` 默认轴但**代码从未使用** | ❌ 暂不创建 |
| `skill_1` / `skill_2` | **不存在** | ❌ 等 Phase 9 做技能时再加 |
| `attack` | **不存在**（`hook` 不是普攻） | ❌ 等做战斗时再加 |

**原则：只创建代码真正用到的动作，不预留空 action。**

### 13.3 实现

```
Project Settings → Input Map → 添加上述 8 个 action
```

```gdscript
var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
```

注意：Unity 里 `movePlay` 是 `(moveX, moveY) * runSpeed` 的**原始向量**（未归一化，斜向会更快）。Godot 的 `get_vector()` **默认已归一化**。迁移时要决定：保留 Unity 的"斜向更快"手感，还是改成归一化（更规范）。**建议归一化，并在方案里标注为行为变更。**

---

## 14. StateMachine 方案

### 14.1 Unity 现状

**没有代码状态机**。状态完全由 `Animator` Blend Tree + 两个 bool（`isFly` / `ischong`）隐式表达，逻辑散在 `Update`/`FixedUpdate` 里。

问题：钩爪的"抛出 → 飞行 → 命中 → 拉拽 → 结束"这条流程横跨 `rolemove.cs` 和 `feibiao.cs` 两个脚本，靠反向操作 Transform 实现，很难调试。

### 14.2 Godot 方案

**玩家用轻量代码状态机**（因为钩爪/加速/交互需要明确的互斥逻辑）：

```
Player (CharacterBody2D)
└── StateMachine (Node)
    ├── IdleState
    ├── MoveState          ← 含 sprint 标志，不单独开 SprintState
    ├── HookThrowState     ← 出钩（不可移动）
    ├── HookPullState      ← 被拉拽（不可控）
    └── InteractState      ← 对话中锁定输入
```

状态切换：

```
Idle ──有输入──→ Move
Move ──无输入──→ Idle
Idle/Move ──按 E+左键──→ HookThrow
HookThrow ──钩爪命中屋檐(signal)──→ HookPull
HookThrow ──钩爪未命中/超时(signal)──→ Idle
HookPull ──到达目标(signal)──→ Idle
Idle/Move ──按 C 命中 NPC──→ Interact
Interact ──对话关闭(signal)──→ Idle
```

**共用逻辑**：`Idle` / `Move` 共用朝向与动画更新，抽到基类 `PlayerStateBase` 的辅助方法里，不做重复实现。

**为什么不为"冲刺"单独开状态**：Unity 里加速只是 `runSpeed` 从 1 变 2，移动逻辑完全相同。开成独立状态会增加无意义的重复。用 `MoveState` 里的 `is_sprinting` 标志 + 动画名切换即可。

### 14.3 Player 和 Enemy 是否复用状态机？

- **现在不复用**——因为**还没有敌人**。
- Phase 9 真做敌人时，再抽出 `CharacterStateMachine` 基类（`Idle`/`Move`/`Hit`/`Dead` 共用），Player 与 Enemy 各自继承。
- **不要现在为了"以后能复用"提前抽象**，那是过度工程。

### 14.4 NPC 状态机？

**不需要。** NPC 只有两个行为：
- 游荡（计时器驱动，左右走）
- 对话中（停止 + 播 idle）

用 `npc.gd` 里的 `is_talking` 布尔量 + `Timer` 足够。开状态机是浪费。

### 14.5 状态机实现建议（Godot 新手友好）

用最朴素的写法，不要上插件（不要 `limboai`、不要 `Beehave`）：

```gdscript
# scripts/player/state_machine.gd
class_name StateMachine
extends Node

@export var initial_state: State
var current: State

func _ready() -> void:
    for child in get_children():
        if child is State:
            child.state_machine = self
    current = initial_state
    current.enter()

func _physics_process(delta: float) -> void:
    current.physics_update(delta)

func transition_to(state_name: String) -> void:
    var next := get_node(state_name) as State
    if next == null or next == current:
        return
    current.exit()
    current = next
    current.enter()
```

```gdscript
# scripts/player/state.gd
class_name State
extends Node

var state_machine: StateMachine

func enter() -> void: pass
func exit() -> void: pass
func physics_update(_delta: float) -> void: pass
```

> 这套写法的好处：每个状态一个文件，AI 改一个状态不会影响其他状态；调试时 `print(current.name)` 一眼看到状态。

---

## 15. Godot 项目目录

**根据实际内容裁剪**，不创建空目录（空目录 Git 也无法跟踪）：

```
pixelWindDragonGame/                 ← main 分支根目录
├── project.godot
├── .gitignore
├── README.md
│
├── assets/                          ← 原始素材（从 Unity 复制）
│   ├── characters/
│   │   ├── dragon/                  ← 龙人（站立/走/跑/出钩/冲）
│   │   └── npc/tongxiangyu/         ← 佟湘玉
│   ├── enemies/hanba/               ← 旱魃启动/未启动（暂只有图）
│   ├── items/                       ← 开合钩爪 / 锁链 / 飞镖
│   ├── environment/
│   │   ├── tiles/                   ← 地面素材 / 九宫格 / 2d地面调色板
│   │   └── props/                   ← 树木 / 石头 / 朱门 / 屋檐 / 池塘
│   ├── effects/
│   │   ├── fire/                    ← 红焰 120 帧
│   │   ├── teleport/                ← 传送圈 25 帧
│   │   └── stone_break/             ← 石头破碎 8 帧
│   └── ui/                          ← 逗仙故事对话框
│
├── scenes/
│   ├── characters/player.tscn, npc.tscn
│   ├── items/hook.tscn, chain.tscn
│   ├── levels/town.tscn, hanba_map.tscn
│   ├── effects/fire.tscn, stone_break.tscn, teleport_ring.tscn
│   ├── world/prop.tscn, water_zone.tscn
│   └── ui/npc_dialog.tscn
│
├── scripts/
│   ├── player/player.gd
│   │   ├── state_machine.gd, state.gd
│   │   └── states/idle_state.gd, move_state.gd, hook_throw_state.gd,
│   │              hook_pull_state.gd, interact_state.gd
│   ├── npc/npc.gd
│   ├── items/hook.gd
│   ├── world/tile_destructor.gd, teleport.gd, water_zone.gd, prop.gd
│   ├── ui/npc_dialog.gd
│   ├── data/player_stats_data.gd, world_tuning_data.gd
│   ├── systems/game_manager.gd      ← Autoload
│   └── utils/                       ← 按需再加，不预先建空目录
│
├── resources/
│   ├── characters/player_stats.tres
│   └── world/world_tuning.tres
│
└── addons/                          ← 暂时空，需要插件时再建
```

**与用户给的模板的差异说明**：

| 模板目录 | 处理 | 原因 |
| --- | --- | --- |
| `scenes/enemies/` | ❌ 不建 | 没有敌人 |
| `scripts/enemies/` `combat/` `skills/` | ❌ 不建 | 没有对应代码 |
| `resources/enemies/ skills/ items/ equipment/` | ❌ 不建 | 没有数据 |
| `data/` | ❌ 不建 | 用 `resources/` 即可，两个目录会混淆 |
| `scripts/systems/` | ✅ 保留 | `game_manager.gd` 需要 |
| `scripts/utils/` | ⏸ 按需 | 不预先建空目录 |

---

## 16. Phase 0 ~ N 迁移计划

> 排序原则：**按"能否最快跑起来"**，不按 Unity 文件夹顺序。

### Phase 0 — Godot 基础骨架

| 项 | 内容 |
| --- | --- |
| 产出 | `project.godot` 配置、8 个 Input Map action、2D 物理层命名、目录结构、`game_manager.gd`（Autoload）、空的 `town.tscn` |
| 关键设置 | 基准分辨率、拉伸模式 `canvas_items`、像素对齐、渲染后端 |
| **验收标准** | ① Godot 4 打开项目**零报错** ② F5 能运行出一个空场景 ③ Input Map 里 8 个 action 齐全且可触发 ④ 物理层名字正确 |

### Phase 1 — 玩家移动 + 动画 + 相机

| 项 | 内容 |
| --- | --- |
| 产出 | `player.tscn`、`player.gd`、`StateMachine` + `IdleState`/`MoveState`、`SpriteFrames`（4 向 idle/walk）、`Camera2D`、双击加速 |
| 前置 | ⚠️ **需要用户先把 PSB 导出为 PNG 帧**（否则动画无法完成，可先用占位图跑通逻辑） |
| **验收标准** | ① WASD 四向移动流畅 ② 停下播 idle、移动播 walk、方向正确 ③ 左右自动翻转 ④ 双击方向 0.5s 内触发加速 ⑤ 相机平滑跟随不抖 |

### Phase 2 — 瓦片世界 + 碰撞

| 项 | 内容 |
| --- | --- |
| 产出 | `TileSet`、`town.tscn` 的 `Ground`/`Obstacles` 两个 `TileMapLayer`、树木/朱门/障碍 `StaticBody2D`、Y-sort |
| 前置 | ⚠️ 需从 Unity Tilemap 转换地形数据（脚本或人工） |
| **验收标准** | ① 地图正确显示，无错位 ② 玩家被树木/建筑/水阻挡 ③ 玩家能正确被树木遮挡（Y-sort 生效） |

### Phase 3 — 石头破坏（Q）

| 项 | 内容 |
| --- | --- |
| 产出 | `tile_destructor.gd`、`stone_break.tscn` |
| 逻辑 | 读玩家朝向 → 目标格 → 若为石障 tile → 清除 + 生成破碎特效（1.5s 后自毁） |
| **验收标准** | ① 朝石障按 Q，石障消失 ② 破碎动画播放正确 ③ 特效播完自动销毁 ④ 非石障格按 Q 无反应 |

### Phase 4 — 飞钩 / 钩爪（E + 左键）★核心

| 项 | 内容 |
| --- | --- |
| 产出 | `hook.tscn`、`hook.gd`、`HookThrowState`、`HookPullState`、`chain.tscn` |
| 重构 | 钩爪只发信号 `hook_attached(point)` / `hook_failed()`；玩家状态机决定拉拽 |
| **验收标准** | ① 按住 E + 左键朝鼠标方向抛钩 ② 钩飞出并旋转朝向 ③ 命中屋檐 → 玩家被拉过去 ④ 未命中 → 钩消失、玩家不动 ⑤ 拉拽结束玩家旋转归零 ⑥ 拉拽中玩家无法自由移动 |

### Phase 5 — 传送圈 + 多场景

| 项 | 内容 |
| --- | --- |
| 产出 | `teleport_ring.tscn`、`teleport.gd`、`town.tscn` + `hanba_map.tscn`、`game_manager.gd` 处理出生点 |
| **验收标准** | ① 走进传送圈切换到目标地图 ② 玩家出现在目标地图对应传送圈旁（偏移 1 格） ③ 双向传送都能用 ④ 切换过程无报错、无重复玩家 |

### Phase 6 — NPC + 对话框

| 项 | 内容 |
| --- | --- |
| 产出 | `npc.tscn`、`npc.gd`、`npc_dialog.tscn`、`npc_dialog.gd`、`InteractState` |
| **验收标准** | ① NPC 自动左右游荡，每隔 5s 换向 ② 朝 NPC 按 C 弹出对话框 ③ 3 秒后自动关闭 ④ 对话期间 NPC 停止移动 ⑤ 对话期间玩家输入锁定 |

### Phase 7 — 水域 / 游泳表现

| 项 | 内容 |
| --- | --- |
| 产出 | `water_zone.tscn`、`water_zone.gd` |
| **验收标准** | ① 进入池塘玩家表现变化（变色/半透明或覆盖层遮挡） ② 离开恢复正常 ③ 反复进出无残留状态 |

### Phase 8 — 2D 光照与视觉打磨

| 项 | 内容 |
| --- | --- |
| 产出 | `CanvasModulate`（全局环境光）、玩家 `PointLight2D`、火焰 `PointLight2D`、传送圈 `PointLight2D` |
| **验收标准** | ① 场景有环境光色调 ② 火焰/传送圈发光 ③ 性能无明显下降（≥60 FPS） |

### Phase 9+ — 新功能开发（**不是迁移**）

| Phase | 内容 | 说明 |
| --- | --- | --- |
| 9 | 战斗基础（伤害 / HitBox / HurtBox / 受击 / 死亡） | Unity 里不存在，从零做 |
| 10 | 敌人（旱魃）+ AI + 掉落 | 只有 2 张图，需设计 |
| 11 | 技能系统（`SkillData` Resource + CD + 特效） | 从零做 |
| 12 | 道具 / 背包 / 装备（`ItemData` / `EquipmentData`） | 从零做 |
| 13 | 存档 / 读档 | 从零做 |
| 14 | 音频系统 + 音效素材 | 项目内**零音频**，需新增素材 |
| 15 | 地牢 / 雪山 / 岩浆等新地形 | 只有 README 文字描述 |
| 16 | 优化 / 重构 / 代码清理 | — |

---

## 17. 每个阶段的验收标准

已在上文各 Phase 中逐条列出。汇总原则：

1. **可运行**：F5 启动零报错，无红色错误输出
2. **可复现**：验收操作步骤明确（按什么键 → 看到什么）
3. **不回归**：新 Phase 不能破坏已通过验收的旧 Phase
4. **无占位残留**：不允许"临时占位"长期留在代码里

---

## 18. 风险与无法自动迁移的部分

### 18.1 高风险 🔴

| ID | 风险 | 影响 | 应对 |
| --- | --- | --- | --- |
| **R1** | **PSB（Photoshop）源文件 Godot 无法导入** | 角色/碎石的**全部动画帧**无法使用，Phase 1 直接卡住 | 必须在 Unity 或 Photoshop 中导出为 PNG 精灵表。**需要用户操作，AI 无法代劳** |
| **R2** | **Unity Tilemap 数据格式不通用** | 两张地图（最大 309×156 格）需要重建 | 写脚本解析 Unity 场景 YAML 的压缩 tile 缓冲 → 生成 Godot TileMapLayer 数据；或人工重画。**必须人工校验结果** |
| **R3** | **Animator Blend Tree 无自动转换** | 16 个动画剪辑 + 6 个 Controller 全部要重建 | 手工重建 `SpriteFrames`（帧数量已知：火焰 120 / 传送圈 25 / 碎石 8） |
| **R4** | **URP 2D 光照 / 材质 / Shader 不可复用** | 光照效果需完全重做 | Godot `Light2D` + `CanvasModulate`；材质重建 |
| **R5** | **第三方素材授权不明** | "爱给网"素材（中国风 RPG 元件等）商用可能侵权 | **需要用户确认授权**，否则需替换素材 |

### 18.2 中风险 🟡

| ID | 风险 | 应对 |
| --- | --- | --- |
| R6 | Cinemachine → Camera2D 阻尼/边界需重新调参，手感会变 | Phase 1 预留调参时间，用 `position_smoothing_speed` 试值 |
| R7 | Unity UI (TMP) → Godot Control 需重建；**项目内无字体文件** | 需自备可商用中文字体 |
| R8 | Y-sort / 排序关系需重新设计（Unity 用 sortingOrder） | Phase 2 专门验证遮挡 |
| R9 | 像素完美设置需按素材实际像素尺寸确定（当前未知瓦片像素大小） | 需用户确认目标分辨率，或从 PNG 尺寸反推 |
| R10 | 斜向移动手感变更（Unity 未归一化 → Godot 归一化） | 明确标注为**有意的行为变更**，或手动保留原手感 |
| R11 | 钩爪的"反向控制玩家"耦合若不重构，会带进 Godot | Phase 4 必须按信号方案重构，不许照搬 |

### 18.3 低风险 🟢

| ID | 风险 | 应对 |
| --- | --- | --- |
| R12 | PNG/JPG 位图可直接复制 | 无 |
| R13 | 数值（0.3 / 1 / 2 / 2f / 3s / 5s）可直接搬 | 无 |
| R14 | 输入映射简单 | 无 |
| R15 | 2d-extras 第三方包整体废弃，无迁移成本 | 无 |

### 18.4 完全无法自动迁移（必须重做）

```
❌ 所有 MonoBehaviour            → GDScript 重写
❌ 所有 Prefab                   → .tscn 重建
❌ 所有 Scene                    → .tscn 重建
❌ Animator Controller / Blend Tree → SpriteFrames + 代码状态机
❌ Unity Tilemap                 → Godot TileMapLayer
❌ RuleTile（60+ 资产）          → Godot Terrain
❌ URP 材质 / Shader / 2D 光照    → Godot Material / Light2D
❌ Cinemachine                   → Camera2D
❌ Unity UI (uGUI + TMP)         → Godot Control
❌ SpriteMask                    → Shader 或着色近似
❌ DontDestroyOnLoad             → Autoload
❌ PSB 图层文件                   → 必须先导出 PNG
❌ 2d-extras 包（37 个 .cs）      → 整体丢弃
```

### 18.5 可复用的部分

```
✅ PNG / JPG 位图（217 + 1）
✅ 游戏数值常量
✅ 关卡布局（需转换，非直接可用）
✅ 游戏规则设计（双击加速 / 钩爪拉拽 / 石头可炸 / 传送圈换图 / NPC 对话 / 入水表现）
✅ 参考截图（imgreadme/ 6 张）
✅ 成品包 pixelWindDragonGame.zip（可作为行为参考）
```

---

## 19. 需要人工参与的事项

### 19.1 AI 可以完成 ✅

- 全部 GDScript 代码（状态机、钩爪、传送、NPC、UI 逻辑）
- 全部 `.tscn` 场景文件（文本格式，可直接生成）
- 全部 `.tres` Resource 数据文件
- `project.godot` 配置（分辨率 / 拉伸 / Input Map / 物理层）
- 从 `unity-app` 复制 PNG 素材到 Godot 目录并整理
- 编写 Unity Tilemap YAML → Godot TileMap 数据的转换脚本
- 根据帧序列生成 `SpriteFrames` 资源
- 目录结构搭建
- 代码重构（去掉 Unity 的反向耦合写法）

### 19.2 必须用户决定 ⚠️

1. **目标分辨率与像素比例**（决定所有相机/UI 尺寸）
2. **范围决策**：只迁移现有原型？还是同时实现 README 描述的完整愿景（敌人/地牢/技能/装备）？
3. **是否保留 URP 风格的 2D 光照**
4. **中文字体选型**（项目内无字体，需选可商用字体）
5. **第三方素材授权**（爱给网素材能否商用发布）
6. **渲染后端**：当前 `project.godot` 设为 `gl_compatibility`（轻量、兼容好）。是否改用 `forward_plus`？
7. **斜向移动是否归一化**（行为变更确认）
8. **入水表现方案选 A/B/C**（见 §12.3）

### 19.3 必须在 Godot 编辑器中操作 🖱️

1. 导入 PSB 导出的 PNG 并配置导入设置（过滤/切片）
2. 用 TileSet 编辑器校对/绘制瓦片地图（跑完转换脚本后校验）
3. 实际运行验证手感（移动速度、相机阻尼、钩爪速度）
4. 微调 Y-sort 遮挡关系

### 19.4 需要用户提供素材/信息 📦

1. **PSB → PNG 精灵表导出**（在 Unity 或 Photoshop 中操作）—— **这是 Phase 1 的硬前置**
2. 若有原始数值表 / 设计文档请提供
3. 中文字体文件
4. 确认是否可用 `pixelWindDragonGame.zip` 里的成品作为行为参考
5. 音频素材（项目内零音频，若要音效需新增）

---

## 20. 下一步建议

**下一步应该让我做的第一件事：Phase 0（Godot 基础骨架）**

理由：Phase 0 **不依赖任何被阻塞的资源**（不需要 PSB、不需要 Tilemap 转换），可以立刻做完并验收。做完后 Godot 项目就是一个"能跑、能按键、结构清晰"的可开发状态，后续每个 Phase 都能独立验证。

Phase 0 交付物：
```
project.godot            基准分辨率 / 拉伸模式 / 物理层 / 渲染后端
.gitignore               已存在
scripts/systems/game_manager.gd   Autoload 单例骨架
scenes/levels/town.tscn          空场景（仅 Camera2D）
8 个 Input Map action
目录结构（只建会被使用的目录）
```

**但在此之前，需要你先回答 §19.2 的 8 个决策问题**——尤其是第 1、2 条（分辨率、范围），它们会影响后面所有 Phase。

---

*本文件仅为分析与规划，未修改 `unity-app` 分支，未执行任何迁移操作。*
