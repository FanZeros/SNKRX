# SNKRX Fork Analysis: FanZeros/SNKRX vs a327ex/SNKRX

> FanZeros fork 将原版 SNKRX 从 LOVE2D 引擎移植到 UrhoX (NanoVG) 引擎的完整分析。

---

## 1. 总览

| 指标 | 原版 (a327ex) | Fork (FanZeros) | 变化 |
|------|:------------:|:---------------:|:----:|
| **.lua 文件数** | 56 | 60 | +4 |
| **总行数** | 21,960 | 20,817 | -1,143 |
| **引擎层行数** | 9,839 | 8,138 | -1,701 |
| **游戏逻辑层行数** | 9,970 (8 files) | 12,420 (9 files) | +2,450 |
| **字节级完全一致的文件** | - | **3/56 (5.4%)** | - |
| **修改的文件** | - | **41** | - |
| **新增文件** | - | **16** | - |
| **删除的文件/目录** | - | **12** | - |
| **引擎** | LOVE2D (OpenGL + Box2D + LuaJIT) | UrhoX (NanoVG + Box2D + Lua 5.4) | - |
| **渲染** | GPU framebuffer + shader pipeline | NanoVG 矢量绘制 (无 FBO、无自定义 shader) | - |

**核心策略**: Fork 采用「**深度重写引擎层**」方案 — 原版 `engine/init.lua`（176 行模块加载器 + 游戏主循环）被重写为 251 行的新模块加载器；原版各引擎子模块被大幅改写以适配 UrhoX/NanoVG API；新增 `engine/game/shims.lua`（233 行）提供 `love.*` API 垫片；`main.lua` 从 2,144 行精简到 259 行（游戏数据提取到 `game/data.lua`）。仅 3 个文件保持字节级一致。

---

## 2. 文件状态统计

| 分类 | 数量 | 说明 |
|------|:----:|------|
| 完全一致 | 3 | `engine/game/object.lua`, `engine/game/parent.lua`, `engine/graphics/color.lua` |
| 引擎层修改 | 25 | 几乎所有引擎模块都有改动 |
| 游戏逻辑层修改 | 8 | 8 个游戏文件全部有改动（重定位 + 适配修改） |
| `main.lua` 修改 | 1 | 从 2,144 行精简到 259 行 |
| 新增文件 | 16 | 引擎适配模块 15 个 + 游戏数据 1 个 |
| 删除文件 | 12 | `conf.lua` + `engine/external/`(5) + `engine/map/`(2) + `engine/datastructures/`(2) + `engine/sound.lua` + `engine/system.lua` |

---

## 3. 引擎层文件详细对比

### 3.1 完全一致 (3 个文件)

| 文件 | 行数 |
|------|:----:|
| `engine/game/object.lua` | 53 |
| `engine/game/parent.lua` | 19 |
| `engine/graphics/color.lua` | 91 |

### 3.2 重大改写的引擎文件 (变化 > 50%)

| 文件 | 原版行数 | Fork 行数 | 变化率 | 改动性质 |
|-----|:-------:|:--------:|:------:|---------|
| `engine/graphics/font.lua` | 16 | 86 | **+437%** | NanoVG 字体系统重写（nvgCreateFont/nvgFontFace） |
| `engine/game/input.lua` | 109 | 302 | **+177%** | 键盘/鼠标/触摸输入全面适配 UrhoX API |
| `engine/math/rectangle.lua` | 39 | 107 | **+174%** | 矩形绘制改用 NanoVG（nvgRect/nvgFill/nvgStroke） |
| `engine/graphics/graphics.lua` | 392 | 959 | **+145%** | **核心渲染适配**: NanoVG 绑定, 延迟绘制队列, push/pop 变换 |
| `engine/game/gameobject.lua` | 78 | 183 | **+134%** | 游戏对象基类扩展（物理属性、碰撞回调） |
| `engine/graphics/image.lua` | 72 | 155 | **+115%** | 图片加载/绘制改用 NanoVG（nvgCreateImage/nvgImagePattern） |
| `engine/graphics/tileset.lua` | 27 | 54 | **+100%** | 瓦片集绘制适配 NanoVG |
| `engine/game/group.lua` | 427 | 843 | **+97%** | 对象组管理大幅重写（绘制队列、层级排序） |
| `engine/math/triangle.lua` | 31 | 53 | **+70%** | 三角形绘制改用 NanoVG 路径 |
| `engine/math/spring.lua` | 70 | 34 | **-51%** | 弹簧系统精简 |

### 3.3 中度改写的引擎文件 (变化 10-50%)

| 文件 | 原版行数 | Fork 行数 | 变化率 | 改动性质 |
|-----|:-------:|:--------:|:------:|---------|
| `engine/init.lua` | 176 | 251 | **+42%** | 模块加载器重写，更多子模块 require |
| `engine/game/physics.lua` | 674 | 888 | **+31%** | Box2D 适配层（UrhoX Box2D API 绑定） |
| `engine/game/steering.lua` | 317 | 199 | **-37%** | 转向行为精简（移除部分算法） |
| `engine/math/polygon.lua` | 227 | 152 | **-33%** | 多边形绘制改用 NanoVG |
| `engine/game/springs.lua` | 32 | 23 | **-28%** | 弹簧组件精简 |
| `engine/game/state.lua` | 114 | 81 | **-28%** | 状态机精简 |
| `engine/math/vector.lua` | 253 | 190 | **-24%** | 向量库精简 |
| `engine/datastructures/table.lua` | 507 | 389 | **-23%** | 表工具精简（移除依赖 LuaJIT 的功能） |
| `engine/datastructures/string.lua` | 53 | 41 | **-22%** | 字符串工具精简 |
| `engine/game/hitfx.lua` | 59 | 46 | **-22%** | 受击特效精简 |
| `engine/math/circle.lua` | 85 | 66 | **-22%** | 圆形绘制改用 NanoVG |
| `engine/math/chain.lua` | 115 | 94 | **-18%** | 链条绘制适配 |
| `engine/graphics/camera.lua` | 366 | 303 | **-17%** | 相机系统适配（坐标变换改用 NanoVG） |
| `engine/graphics/shader.lua` | 31 | 36 | **+16%** | Shader 存根（NanoVG 不支持自定义 shader） |
| `engine/graphics/text.lua` | 278 | 237 | **-14%** | 文本渲染改用 NanoVG 字体系统 |
| `engine/math/random.lua` | 94 | 84 | **-10%** | 随机数精简 |

### 3.4 轻微改动的引擎文件 (变化 < 10%)

| 文件 | 原版行数 | Fork 行数 | 变化率 | 改动性质 |
|-----|:-------:|:--------:|:------:|---------|
| `engine/graphics/canvas.lua` | 67 | 73 | +8% | Canvas record+replay 适配 |
| `engine/math/math.lua` | 635 | 580 | -8% | 数学库精简 |
| `engine/game/flashes.lua` | 30 | 23 | -23% | 闪光效果精简 |
| `engine/game/trigger.lua` | 288 | 272 | -5% | 触发器微调 |
| `engine/graphics/animation.lua` | 141 | 135 | -4% | 动画微调 |
| `engine/math/line.lua` | 96 | 98 | +2% | 线段绘制微调 |

---

## 4. 游戏逻辑层对比

游戏文件从原版根目录重定位到 Fork 的 `game/` 子目录，且**全部有内容修改**（非仅重定位）：

| 文件 | 原版行数 | Fork 行数 | 改动行数 | 改动性质 |
|-----|:-------:|:--------:|:-------:|---------|
| `game/buy_screen.lua` | 2,082 | 2,229 | 613 | UI 绘制适配 NanoVG（颜色格式、绘制 API） |
| `game/arena.lua` | 1,213 | 1,272 | 321 | 战斗场景绘制适配 |
| `game/player.lua` | 4,000 | 4,075 | 133 | 角色绘制适配 |
| `game/mainmenu.lua` | 213 | 219 | 90 | 菜单 UI 适配 |
| `game/shared.lua` | 878 | 903 | 67 | 共享工具适配 |
| `game/enemies.lua` | 1,103 | 1,125 | 46 | 敌人绘制微调 |
| `game/media.lua` | 35 | 46 | 19 | 资源路径调整（添加 `Sounds/` 前缀） |
| `game/objects.lua` | 446 | 448 | 2 | 极小改动 |

**新增**: `game/data.lua` (2,103 行) — 从原版 `main.lua` 提取的游戏数据表（角色定义、职业树、被动技能、配置等）+ init/update/draw 生命周期函数。

---

## 5. `main.lua` 重构

| 项目 | 原版 | Fork |
|-----|:----:|:----:|
| 行数 | 2,144 | 259 |
| 变化率 | - | **-87.9%** |

**原版 main.lua** 包含:
- 游戏数据定义（角色、职业、被动技能等）~1,700 行
- `init()`, `update()`, `draw()` 生命周期函数
- `love.run()` 游戏主循环
- Steam 集成、存档读写、音乐系统

**Fork main.lua** 精简为:
- UrhoX 引擎入口 (`Start()`, `HandleUpdate()`, `HandleNanoVGRender()`)
- `require "engine.init"` 加载引擎
- `require "game.data"` 加载游戏逻辑（原版数据提取到此文件）
- Steam/存档/音乐代码被注释掉或移除

---

## 6. 新增文件 (16 个)

### 6.1 引擎适配模块 (15 个)

| 文件 | 行数 | 用途 |
|-----|:----:|------|
| `engine/game/shims.lua` | 233 | **LOVE2D 兼容层**: love.timer/event/window/mouse/keyboard/filesystem/audio 垫片 |
| `engine/game/sound.lua` | 176 | 音效系统重写（适配 UrhoX 音频 API） |
| `engine/game/music.lua` | 117 | 音乐播放系统（适配 UrhoX 音频 API） |
| `engine/_globals.lua` | 92 | EmmyLua LSP 全局变量声明（KEY_* 常量、nvg* 函数等） |
| `engine/game/layer.lua` | 59 | 渲染层级管理 |
| `engine/game/container.lua` | 57 | 容器组件 |
| `engine/game/collision.lua` | 36 | 碰撞检测封装 |
| `engine/game/draft.lua` | 36 | 绘制辅助 |
| `engine/game/observer.lua` | 32 | 观察者模式实现 |
| `engine/game/stepper.lua` | 24 | 步进器组件 |
| `engine/game/timer.lua` | 22 | 定时器组件 |
| `engine/game/stats.lua` | 17 | 统计组件 |
| `engine/game/anchor.lua` | 16 | 锚点组件 |
| `engine/game/system.lua` | 13 | 系统功能存根（save/load） |
| `engine/game/shaders.lua` | 8 | Shader 存根 |

### 6.2 游戏数据 (1 个)

| 文件 | 行数 | 用途 |
|-----|:----:|------|
| `game/data.lua` | 2,103 | 从原版 main.lua 提取的游戏数据定义 + init/update/draw |

---

## 7. 删除的文件 (12 个)

| 文件 | 原版行数 | 删除原因 |
|-----|:-------:|---------|
| `conf.lua` | 19 | LOVE2D 窗口/引擎配置，UrhoX 不适用 |
| `engine/external/mlib.lua` | 1,411 | 数学碰撞库，功能由 UrhoX Box2D 替代 |
| `engine/external/binser.lua` | 747 | 二进制序列化库（LuaJIT FFI 依赖） |
| `engine/external/ripple.lua` | 518 | 音频管理库（LOVE2D 专用） |
| `engine/external/clipper.lua` | 274 | 多边形裁剪库（未使用 / NanoVG 替代） |
| `engine/datastructures/grid.lua` | 260 | 网格数据结构（含 A* 寻路，游戏未使用） |
| `engine/datastructures/graph.lua` | 283 | 图数据结构（游戏未使用） |
| `engine/system.lua` | 187 | 系统功能（重写为 `engine/game/system.lua` 13 行存根） |
| `engine/map/tilemap.lua` | 66 | 瓦片地图（游戏未使用） |
| `engine/map/solid.lua` | 19 | 固体碰撞（游戏未使用） |
| `engine/external/init.lua` | 8 | 外部库入口（随 external/ 一起删除） |
| `engine/sound.lua` | 4 | 原版极简音效（重写为 `engine/game/sound.lua` 176 行） |

**删除总行数**: 3,796 行

---

## 8. 架构对比图

```
原版 LOVE2D 架构:
┌─────────────────────────────────────────┐
│       main.lua (2,144 行)                │  ← 游戏数据 + 生命周期 + 入口
├─────────────────────────────────────────┤
│       游戏逻辑层 (8 files, 9,970 行)      │
│  arena / buy_screen / enemies / player  │
│  objects / shared / mainmenu / media    │
├─────────────────────────────────────────┤
│       引擎层 (9,839 行)                   │
│  engine/init.lua (176 行模块加载 + 主循环) │
│  engine/game/* + graphics/* + math/*    │
│  engine/external/* (2,958 行第三方库)     │
│  engine/map/* + engine/datastructures/* │
├─────────────────────────────────────────┤
│       LOVE2D 引擎                        │
│  OpenGL │ Box2D │ LuaJIT │ SDL          │
└─────────────────────────────────────────┘

Fork UrhoX 架构:
┌─────────────────────────────────────────┐
│       main.lua (259 行) — UrhoX 入口     │
├─────────────────────────────────────────┤
│       游戏逻辑层 (9 files, 12,420 行)     │
│  game/data.lua (2,103 行, 从 main 提取)  │
│  game/arena / buy_screen / enemies ...  │
│         (全部有适配修改)                  │
├─────────────────────────────────────────┤
│       引擎层 (8,138 行, 深度重写)         │  ← 核心变化
│  engine/init.lua (251 行模块加载器)       │
│  engine/game/shims.lua (233 行 love.* 垫片) │
│  engine/graphics/graphics.lua (959 行)   │
│  engine/game/sound.lua (176 行, 全新)    │
│  engine/game/music.lua (117 行, 全新)    │
│  ... (所有子模块适配 NanoVG/UrhoX API)    │
├─────────────────────────────────────────┤
│       UrhoX 引擎                         │
│  NanoVG 矢量绘制 │ Box2D │ Lua 5.4      │
└─────────────────────────────────────────┘
```

**关键区别**:
- 原版: `engine/init.lua` 是 176 行的薄加载器，引擎功能在各子模块中直接调用 LOVE2D API
- Fork: 各子模块被**逐个重写**以调用 NanoVG/UrhoX API，不是简单的垫片映射

---

## 9. 移植策略评价

### 方案定性: 深度重写 (非薄兼容层)

原版 56 个文件中仅 3 个保持不变（5.4%），其余 41 个文件（引擎 25 + 游戏 8 + main.lua）都有不同程度的修改，另有 16 个全新文件。这不是「在顶层加一层垫片」的方案，而是**深入每个引擎子模块，将 LOVE2D API 调用逐一替换为 NanoVG/UrhoX 等价调用**。

### 优点

1. **完整度高**: 几乎所有子系统都有适配，不是只做了表层映射
2. **模块化改进**: 原版 `main.lua` 的 2,144 行被合理拆分（259 + 2,103）
3. **依赖精简**: 删除 3,796 行不需要的第三方库和未使用模块
4. **音效系统**: 新写了 176 行的 Sound 适配和 117 行的 Music 适配

### 不足

1. **游戏逻辑非零侵入**: 8 个游戏文件全部有修改（共 ~1,291 行改动），与原版不完全兼容
2. **存档未实现**: `engine/game/system.lua` 仅 13 行存根
3. **Canvas/Shader 缺失**: NanoVG 无 FBO/自定义 shader，视觉效果降级
4. **合并上游困难**: 由于引擎层和游戏层都有大量改动，合并 a327ex 上游更新需要逐文件手动处理

### 与原版的兼容性

| 层级 | 可直接覆盖 | 需要手动合并 |
|------|:--------:|:---------:|
| 引擎层 (engine/) | 3 个文件 | 22+ 个文件 |
| 游戏逻辑层 (game/) | 0 个文件 | 8 个文件 |
| main.lua | 不可覆盖 | 需对比合并 |

---

## 10. 原版仓库位置

供后续对比使用：

```
原版: /workspace/a327ex-SNKRX/     (56 files, 21,960 lines)
Fork: /workspace/FanZeros-SNKRX/   (60 files, 20,817 lines)
```

---

*生成日期: 2025-05-05*
*对比基准: a327ex/SNKRX master vs FanZeros/SNKRX scripts/ (commit 319f530 后)*
