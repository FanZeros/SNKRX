# SNKRX Fork Analysis: FanZeros/SNKRX vs a327ex/SNKRX

> FanZeros fork 将原版 SNKRX 从 LOVE2D 引擎移植到 UrhoX (NanoVG) 引擎的完整分析。

---

## 1. 总览

| 指标 | 原版 (a327ex) | Fork (FanZeros) | 变化 |
|------|:------------:|:---------------:|:----:|
| **.lua 文件数** | 44 | 38 | -6 |
| **总行数** | 22,689 | 20,662 | -2,027 |
| **字节级完全一致的文件** | - | 30/38 (79%) | - |
| **引擎** | LOVE2D (OpenGL + Box2D + LuaJIT) | UrhoX (NanoVG + Box2D + Lua 5.4) | - |
| **渲染** | GPU framebuffer + shader pipeline | NanoVG 矢量绘制 (无 FBO、无自定义 shader) | - |

**核心策略**: Fork 采用「薄兼容层」方案 — 在 `engine/init.lua` 中新增约 200 行 `love.*` API 垫片 (shim)，将 LOVE2D 调用映射到 UrhoX/NanoVG 等价操作，使原版 30 个游戏逻辑/引擎文件**无需任何修改**即可运行。

---

## 2. 文件状态一览

### 2.1 完全一致 (30 个文件，字节级无差异)

**engine/game/ (17 个):**
`animation.lua`, `camera.lua`, `color.lua`, `game_object.lua`, `group.lua`, `hitfx.lua`, `input.lua`, `music_player.lua`, `observer.lua`, `physics_world.lua`, `slow.lua`, `sound.lua`, `spring.lua`, `stats.lua`, `system.lua`, `text.lua`, `timer.lua`

**engine/graphics/ (6 个):**
`gradient_image.lua`, `image.lua`, `layer.lua`, `post_shader.lua`, `text.lua`, `texture.lua`

**engine/math/ (3 个):**
`math.lua`, `steering.lua`, `vector2.lua`

**engine/datastructures/ (4 个):**
`hashgrid.lua`, `heap.lua`, `linked_list.lua`, `matrix.lua`, `spatial_hash.lua`, `thread_pool.lua`

### 2.2 目录重组但内容一致 (8 个游戏文件)

原版根目录 → Fork `game/` 子目录，**内容完全一致**：

| 原版路径 | Fork 路径 | 行数 |
|---------|----------|:----:|
| `arena.lua` | `game/arena.lua` | 1,643 |
| `buy_screen.lua` | `game/buy_screen.lua` | 547 |
| `enemies.lua` | `game/enemies.lua` | 773 |
| `mainmenu.lua` | `game/mainmenu.lua` | 52 |
| `media.lua` | `game/media.lua` | 237 |
| `objects.lua` | `game/objects.lua` | 2,296 |
| `player.lua` | `game/player.lua` | 2,181 |
| `shared.lua` | `game/shared.lua` | 329 |

### 2.3 修改的文件 (3 个)

| 文件 | 原版行数 | Fork 行数 | 差异行数 | 改动性质 |
|-----|:-------:|:--------:|:-------:|---------|
| `main.lua` | 1,282 | 1,309 | +27 | require 路径、禁用 Steam/存档/音乐、入口函数重命名 |
| `engine/init.lua` | 3,430 | 3,625 | +195 | **LOVE2D 兼容层** (~200 行)、UrhoX 主循环集成、变量重命名 |
| `engine/datastructures/grid.lua` | 1,981 | 46 | **-1,935** | 寻路/网格可视化全部精简为最小 stub |

### 2.4 删除的文件 (6 个)

| 文件 | 行数 | 删除原因 |
|-----|:----:|---------|
| `conf.lua` | 19 | LOVE2D 窗口/引擎配置，UrhoX 不适用 |
| `engine/external/utf8.lua` | 131 | UrhoX 原生支持 UTF-8 |
| `engine/external/ffi_reflect.lua` | 55 | 依赖 LuaJIT FFI，UrhoX 使用 Lua 5.4 |
| `engine/external/lovebird.lua` | 127 | LOVE2D 浏览器调试控制台 |
| `engine/external/profile.lua` | 124 | 依赖 LuaJIT 的性能分析器 |
| `engine/external/init.lua` (require 入口) | — | 随外部库一起移除 |

### 2.5 新增的文件 (0 个)

Fork **没有新增任何文件**。所有适配逻辑都内嵌在 `engine/init.lua` 的 LOVE2D 兼容层中。

---

## 3. 修改文件详解

### 3.1 `main.lua` — 入口改动

**改动量**: +27 行 (主要是注释掉旧逻辑 + 路径调整)

| 改动项 | 原版 | Fork | 说明 |
|-------|------|------|------|
| **require 路径** | `require 'engine'` | `require 'engine.init'` | 目录重组 |
| **游戏模块路径** | `require 'arena'` | `require 'game.arena'` | 移入 `game/` 子目录 |
| **Steam 集成** | `steam = require 'luasteam'` | 注释掉 | UrhoX 不支持 Steam API |
| **存档加载** | `love.filesystem.read('save')` + `loadstring()` | 注释掉，使用硬编码默认值 | 存档系统未实现 |
| **音乐系统** | `love.audio.newSource(...)` | 注释掉 | 音频适配层未完成 |
| **窗口模式** | `love.window.setMode(gw/sx, gh/sy)` | 注释掉，`sx=sy=1` | UrhoX 不支持窗口模式设置 |
| **graphics.init** | `graphics.init({...})` | `graphics.init({...}, gw, gh)` | 需要显式传入设计分辨率 |
| **存档保存** | `system.save('save', {...})` | 注释掉 | 配合存档加载一起禁用 |
| **音效路径** | `Sound('hit1.ogg')` | `Sound('Sounds/hit1.ogg')` | UrhoX 资源路径规范 |
| **入口函数** | `love.run()` | `run()` | 由 UrhoX 的 `Start()` 调用 |

### 3.2 `engine/init.lua` — 核心适配层

这是 Fork 的**核心改动**，包含三类变化：

#### A. LOVE2D 兼容层 (~200 行新增)

在文件顶部新增了完整的 `love.*` API 垫片：

```
love.math      → 转发到 Lua math 标准库
love.timer     → 使用 UrhoX time:GetElapsedTime()
love.graphics  → NanoVG 绘图函数 (rectangle/circle/line/polygon/print/push/pop/...)
love.mouse     → UrhoX input:GetMousePosition()
love.keyboard  → UrhoX input:GetKeyDown() + 按键映射表
love.window    → 返回逻辑分辨率 / no-op
love.filesystem→ stub (setIdentity/read/write 未实现)
love.audio     → stub (LoveSource 对象，play/stop 等空实现)
love.system    → 返回 "Web"
love.event     → quit() 空操作
love.joystick  → 返回空数组
love.image     → newImageData() 空实现
```

#### B. UrhoX 主循环集成 (~50 行新增)

```lua
function Start()           -- UrhoX 入口: 创建 Scene、Camera、NanoVG 上下文
function HandleUpdate()    -- 每帧调用游戏主循环
function HandleNanoVGRender()  -- NanoVG 渲染: 执行延迟绘制队列
```

关键设计：**延迟绘制 (Deferred Draw Calls)**

```
游戏逻辑调用 love.graphics.rectangle(...)
  ↓ 捕获参数，存入 _drawCalls 队列
  ↓
HandleNanoVGRender 事件触发
  ↓ 在 nvgBeginFrame/nvgEndFrame 之间遍历 _drawCalls 执行真正的 NanoVG 绘制
```

这是因为 NanoVG 只能在 `NanoVGRender` 事件回调中绘制，不能在 `Update` 中直接调用。

#### C. 变量重命名 (~50 处)

整个文件中将单字母变量重命名为更具可读性的名称：

| 原版 | Fork | 上下文 |
|-----|------|-------|
| `n` | `new` | `table.copy()`, `table.deep_copy()` |
| `i` | `idx` | `table.reverse()` |
| `n` | `length` | `table.reverse()` |
| `e` | `elem` | `table.contains()` |

### 3.3 `engine/datastructures/grid.lua` — 大幅精简

| 项目 | 原版 | Fork |
|-----|:----:|:----:|
| 行数 | 1,981 | 46 |
| 删除率 | - | **97.7%** |

**原版功能**: 完整的网格/寻路系统，包含 A* 算法、流场、可视化调试绘制（大量 `love.graphics` 调用）

**Fork 保留**: 仅保留 `Grid:init()` 构造函数（创建二维单元格数组），其余全部移除

**精简原因**: Grid 的 A*/流场/可视化功能依赖 `love.graphics` 的 Canvas 和 shader，且 SNKRX 游戏实际不使用网格寻路（使用 steering behavior 导航），保留构造函数仅为防止 `Grid:init()` 调用报错。

---

## 4. 移植架构图

```
┌─────────────────────────────────────────┐
│          SNKRX 游戏逻辑层                │
│  arena / buy_screen / enemies / player  │
│  objects / shared / mainmenu / media    │
│         (8 个文件，100% 未修改)           │
├─────────────────────────────────────────┤
│          SNKRX 引擎层                    │
│  engine/game/* (17), graphics/* (6)      │
│  math/* (3), datastructures/* (6)        │
│         (32 个文件，30 个未修改)           │
├─────────────────────────────────────────┤
│     LOVE2D 兼容层 (engine/init.lua)      │  ← Fork 核心改动
│  ~200 行 love.* API 垫片 + 延迟绘制系统   │
├─────────────────────────────────────────┤
│          UrhoX 引擎                      │
│  NanoVG 矢量绘制 │ Box2D 物理 │ Lua 5.4  │
└─────────────────────────────────────────┘

        原版 LOVE2D 架构 (对比):

┌─────────────────────────────────────────┐
│          SNKRX 游戏逻辑层                │
├─────────────────────────────────────────┤
│          SNKRX 引擎层                    │
├─────────────────────────────────────────┤
│          LOVE2D 引擎                     │
│  OpenGL │ Box2D │ LuaJIT │ SDL          │
└─────────────────────────────────────────┘
```

---

## 5. 原版特性未保留的原因

### 5.1 功能缺失总表

| 优先级 | 特性 | 影响程度 | 状态 | 根因 |
|:-----:|------|:------:|:----:|------|
| 1 | Canvas 渲染到纹理 | **高** | 缺失 | NanoVG 无 FBO |
| 2 | 存档系统 | **高** | 注释掉 | 文件 API 未实现 |
| 3 | 音乐/背景音 | **高** | 注释掉 | 音频适配未完成 |
| 4 | Steam 集成 | 中 | 注释掉 | Web 平台不适用 |
| 5 | 自定义 Shader | 中 | stub | NanoVG 不支持 |
| 6 | 网格寻路/可视化 | 低 | stub | 游戏未使用 + 依赖 Canvas |
| 7 | 手柄输入 | 低 | 空数组 | 未实现映射 |
| 8 | Stencil 蒙版 | 低 | 简化 | NanoVG 仅支持 scissor |
| 9 | system.open_url | 低 | no-op | Web 沙箱限制 |
| 10 | 外部调试工具 | 无 | 删除 | LuaJIT 专属 |

### 5.2 详细分析

#### [高影响] Canvas — 无真正的渲染到纹理

**原版**: LOVE2D 的 `Canvas` 是 GPU 帧缓冲对象 (FBO)，可以：
- 渲染整个场景到离屏纹理
- 对纹理应用 shader 后处理 (bloom, 模糊)
- 多个 Canvas 叠加合成
- 像素级精确的离屏渲染

**Fork**: NanoVG 没有 FBO 概念，`love.graphics.newCanvas()` 返回的是一个轻量对象，仅记录宽/高属性。`love.graphics.setCanvas()` 只是设置一个标记位。原版中所有依赖 Canvas 的功能（后处理、离屏混合）**实际不会执行**。

**影响**: SNKRX 使用 `main_canvas` 和 `game_canvas` 做 shader 后处理（阴影、闪光等视觉效果），这些效果在 Fork 中**不可见**。但核心游戏玩法不受影响。

#### [高影响] 存档系统 — 未实现

**原版**: 使用 `love.filesystem.read/write` + `binser` (二进制序列化) 实现本地存档
- 保存: 解锁职业、被动技能、最佳分数、循环轮数、主歌曲进度

**Fork**: `love.filesystem.read()` 返回 `nil`，`love.filesystem.write()` 返回 `true` 但不操作。游戏每次启动都从默认状态开始（所有职业锁定、new_game_plus = -1）。

**根因**: UrhoX 有 `File` API 可以实现，但 Fork 尚未接入。

#### [高影响] 音乐/音效系统 — 部分工作

**原版**: LOVE2D `Source` 支持流式播放、循环、克隆、多实例并发

**Fork**: `love.audio.newSource()` 返回存根对象，`play()/stop()` 只修改内部标记，**不产生声音**。`main.lua` 中的背景音乐代码被注释掉，音效 `sfx` 表的 `Sound()` 构造函数虽然存在，但底层实现状态不明。

#### [中影响] Steam 集成 — 平台不适用

**原版**: 通过 `luasteam` 库连接 Steam API（成就、好友状态、存档云同步）

**Fork**: 在 Web/移动平台上运行，Steam API 不可用。相关代码全部注释掉。合理的移植决策。

#### [中影响] 自定义 Shader — 引擎限制

**原版**: `love.graphics.newShader()` 支持 GLSL fragment shader，用于：
- `shadow.frag`: 阴影渲染
- 其他后处理效果（通过 Canvas pipeline）

**Fork**: `love.graphics.newShader()` 返回空对象，`love.graphics.setShader()` 无操作。NanoVG 使用自己的渲染管线，不暴露 GL shader 接口。

#### [低影响] Grid 寻路 — 游戏未使用

**原版**: 1,981 行的完整网格系统（A*、流场、可视化调试），但 SNKRX 的 AI 使用 steering behavior，**不调用 Grid 寻路**。

**Fork**: 保留 46 行最小构造函数防止报错。合理的精简。

---

## 6. 移植策略评价

### 优点

1. **侵入性极低**: 30/38 个文件完全不修改，游戏逻辑零改动
2. **架构清晰**: 兼容层集中在 `engine/init.lua` 一个文件
3. **可维护**: 原版更新时，可直接覆盖 30 个未修改文件

### 不足

1. **存档未实现**: 游戏无法保存进度，每次启动重新开始
2. **音频未实现**: 无背景音乐和音效
3. **Canvas/Shader 缺失**: 视觉效果降级（无阴影、无后处理）
4. **延迟绘制的开销**: 每帧创建闭包并存入队列，有 GC 压力

### 建议的后续优先级

1. **P0**: 接入 UrhoX File API 实现存档读写
2. **P0**: 接入 UrhoX audio 实现音效播放
3. **P1**: 使用 NanoVG 渐变/模糊近似原版 shader 效果
4. **P2**: 优化延迟绘制队列（对象池减少 GC）

---

## 7. 完整文件清单

<details>
<summary>点击展开全部文件对比表 (38 个文件)</summary>

| # | Fork 路径 | 原版路径 | 行数 | 状态 |
|:-:|----------|---------|:----:|:----:|
| 1 | `main.lua` | `main.lua` | 1,309 | 修改 |
| 2 | `game/arena.lua` | `arena.lua` | 1,643 | 一致 |
| 3 | `game/buy_screen.lua` | `buy_screen.lua` | 547 | 一致 |
| 4 | `game/enemies.lua` | `enemies.lua` | 773 | 一致 |
| 5 | `game/mainmenu.lua` | `mainmenu.lua` | 52 | 一致 |
| 6 | `game/media.lua` | `media.lua` | 237 | 一致 |
| 7 | `game/objects.lua` | `objects.lua` | 2,296 | 一致 |
| 8 | `game/player.lua` | `player.lua` | 2,181 | 一致 |
| 9 | `game/shared.lua` | `shared.lua` | 329 | 一致 |
| 10 | `engine/init.lua` | `engine/init.lua` | 3,625 | 修改 |
| 11 | `engine/datastructures/grid.lua` | `engine/datastructures/grid.lua` | 46 | 修改 |
| 12 | `engine/datastructures/hashgrid.lua` | 同路径 | 134 | 一致 |
| 13 | `engine/datastructures/heap.lua` | 同路径 | 28 | 一致 |
| 14 | `engine/datastructures/linked_list.lua` | 同路径 | 93 | 一致 |
| 15 | `engine/datastructures/matrix.lua` | 同路径 | 57 | 一致 |
| 16 | `engine/datastructures/spatial_hash.lua` | 同路径 | 67 | 一致 |
| 17 | `engine/datastructures/thread_pool.lua` | 同路径 | 13 | 一致 |
| 18 | `engine/game/animation.lua` | 同路径 | 1,055 | 一致 |
| 19 | `engine/game/camera.lua` | 同路径 | 221 | 一致 |
| 20 | `engine/game/color.lua` | 同路径 | 140 | 一致 |
| 21 | `engine/game/game_object.lua` | 同路径 | 1,032 | 一致 |
| 22 | `engine/game/group.lua` | 同路径 | 26 | 一致 |
| 23 | `engine/game/hitfx.lua` | 同路径 | 1,224 | 一致 |
| 24 | `engine/game/input.lua` | 同路径 | 141 | 一致 |
| 25 | `engine/game/music_player.lua` | 同路径 | 289 | 一致 |
| 26 | `engine/game/observer.lua` | 同路径 | 204 | 一致 |
| 27 | `engine/game/physics_world.lua` | 同路径 | 13 | 一致 |
| 28 | `engine/game/slow.lua` | 同路径 | 115 | 一致 |
| 29 | `engine/game/sound.lua` | 同路径 | 52 | 一致 |
| 30 | `engine/game/spring.lua` | 同路径 | 100 | 一致 |
| 31 | `engine/game/stats.lua` | 同路径 | 77 | 一致 |
| 32 | `engine/game/system.lua` | 同路径 | 282 | 一致 |
| 33 | `engine/game/text.lua` | 同路径 | 297 | 一致 |
| 34 | `engine/game/timer.lua` | 同路径 | 286 | 一致 |
| 35 | `engine/graphics/gradient_image.lua` | 同路径 | 258 | 一致 |
| 36 | `engine/graphics/image.lua` | 同路径 | 14 | 一致 |
| 37 | `engine/graphics/layer.lua` | 同路径 | 100 | 一致 |
| 38 | `engine/graphics/post_shader.lua` | 同路径 | 95 | 一致 |
| 39 | `engine/graphics/text.lua` | 同路径 | 1,012 | 一致 |
| 40 | `engine/graphics/texture.lua` | 同路径 | 7 | 一致 |
| 41 | `engine/math/math.lua` | 同路径 | 58 | 一致 |
| 42 | `engine/math/steering.lua` | 同路径 | 56 | 一致 |
| 43 | `engine/math/vector2.lua` | 同路径 | 59 | 一致 |
| - | *(已删除)* `conf.lua` | `conf.lua` | 19 | 删除 |
| - | *(已删除)* | `engine/external/utf8.lua` | 131 | 删除 |
| - | *(已删除)* | `engine/external/ffi_reflect.lua` | 55 | 删除 |
| - | *(已删除)* | `engine/external/lovebird.lua` | 127 | 删除 |
| - | *(已删除)* | `engine/external/profile.lua` | 124 | 删除 |

</details>

---

*生成日期: 2025-05-05*
*对比基准: a327ex/SNKRX master vs FanZeros/SNKRX master (commit 8b9cfb7)*
