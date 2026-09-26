# pixelWindDragonGame

像素风飞龙游戏。本仓库包含两个独立开发、互不合并的分支。

## 分支说明

| 分支 | 引擎 | 用途 |
| --- | --- | --- |
| `main` | Godot 4 | 当前及未来的唯一主开发分支 |
| `unity-app` | Unity 2020.3.18f1c1 | 历史版本 / 参考实现，只读保留 |

两个分支拥有**互相独立**的 Git 历史，不做 merge。

## main（Godot 4）

```
pixelWindDragonGame/
├── project.godot
├── icon.svg
├── .gitignore
└── README.md
```

当前为最小可运行的 Godot 4 项目骨架，后续开发在此分支进行。

- 引擎版本：Godot 4.7
- 渲染后端：`gl_compatibility`

用 Godot 4 打开本目录（选择 `project.godot`）即可开始开发。

## unity-app（Unity）

保留完整的 Unity 项目，包括 `Assets/`、`Packages/`、`ProjectSettings/`、`UIElementsSchema/`、`imgreadme/` 等。

该分支仅作历史存档与参考，**不再更新**。请勿在其中删除 Unity 文件，也不要将其与 `main` 合并。