# SNKRX UrhoX 移植 — 开发参考手册

> 供后续开发使用的完整技术参考。涵盖架构、适配模式、已知问题、开发规范。

---

## 目录

1. [项目概况](#1-项目概况)
2. [目录结构](#2-目录结构)
3. [运行时架构](#3-运行时架构)
4. [生命周期与数据流](#4-生命周期与数据流)
5. [引擎适配层详解](#5-引擎适配层详解)
   - 5.1 渲染 (graphics.lua)
   - 5.2 物理 (physics.lua)
   - 5.3 输入 (input.lua)
   - 5.4 音频 (sound.lua / music.lua)
   - 5.5 Canvas (canvas.lua)
   - 5.6 Shader (shader.lua)
   - 5.7 LOVE2D 垫片 (shims.lua)
6. [关键设计模式](#6-关键设计模式)
7. [全局变量速查](#7-全局变量速查)
8. [已修复的 Bug](#8-已修复的-bug)
9. [已知限制与存根](#9-已知限制与存根)
10. [开发规范](#10-开发规范)
11. [原版对照表](#11-原版对照表)

---

## 1. 项目概况

| 项目 | 说明 |
|------|------|
| 游戏 | SNKRX — 贪吃蛇 × 自走棋 Roguelite |
| 原版引擎 | LOVE2D (OpenGL + Box2D + LuaJIT + SDL) |
| 移植引擎 | UrhoX (NanoVG + Box2D + Lua 5.4) |
| 原版作者 | [a327ex/SNKRX](https://github.com/a327ex/SNKRX) |
| Fork | [FanZeros/SNKRX](https://github.com/FanZeros/SNKRX) |
| 设计分辨率 | 480×270（16:9），运行时按屏幕比例动态扩展 |
| 移植方案 | 深度重写引擎层（56 个原版文件中仅 3 个未修改） |

### 为什么是「深度重写」而非「薄兼容层」

原版引擎**没有抽象层**——18 个引擎模块全部直接调用 `love.*` API（合计 205 次），不经过任何中间封装。加上以下结构性差异，无法用顶层垫片解决：

| 差异维度 | LOVE2D | UrhoX/NanoVG | 影响 |
|----------|--------|-------------|------|
| **绘图时序** | 即时模式：任意时刻调用 `love.graphics.*` | NanoVG 只能在 `NanoVGRender` 事件内绘制 | 所有绘图必须改为延迟队列 |
| **绘图 API 形态** | `love.graphics[shape](mode, ...)` 动态分发 | 每种形状是不同的 C 函数 + begin/end path | 逐函数重写 |
| **图片绘制** | `love.graphics.draw(image, ...)` 一步完成 | `nvgImagePattern` + `nvgBeginPath` + `nvgRect` + `nvgFill` 四步 | Image 类全部重写 |
| **帧缓冲** | `Canvas` = GPU FBO，支持离屏渲染 | NanoVG 无 FBO | 改为 record+replay 闭包 |
| **Shader** | GLSL fragment shader | NanoVG 不支持 | 存根，视觉降级 |
| **Stencil 蒙版** | GPU stencil buffer，任意形状 | `nvgScissor` 仅矩形 | 功能降级 |
| **物理对象模型** | `love.physics.newBody()` → 独立对象 | `node:CreateComponent("RigidBody2D")` → 组件 | physics.lua 全面重写 |
| **输入模型** | 事件回调填充 state 表 | 每帧轮询 `urho_input:GetKeyDown()` | input.lua 全面重写 |
| **Lua 版本** | LuaJIT (5.1 + FFI) | Lua 5.4 | 删除 FFI 依赖，外部库不可用 |

---

## 2. 目录结构

```
FanZeros-SNKRX/
├── scripts/                    # 所有 Lua 代码
│   ├── main.lua                # UrhoX 入口 (259 行)
│   │
│   ├── engine/                 # 引擎适配层 (8,138 行)
│   │   ├── init.lua            # 模块加载器 + 生命周期 API (251 行)
│   │   ├── _globals.lua        # EmmyLua LSP 全局声明 (92 行)
│   │   │
│   │   ├── game/               # 游戏系统适配
│   │   │   ├── object.lua      # OOP 基类 (未修改)
│   │   │   ├── gameobject.lua  # 游戏对象基类 (+134%)
│   │   │   ├── group.lua       # 对象组 + 层级管理 (+97%)
│   │   │   ├── physics.lua     # Box2D 适配 (+31%, 888 行)
│   │   │   ├── steering.lua    # 转向行为 (-37%)
│   │   │   ├── input.lua       # 输入系统 (+177%, 302 行)
│   │   │   ├── sound.lua       # 音效适配 (全新, 176 行)
│   │   │   ├── music.lua       # 音乐适配 (全新, 117 行)
│   │   │   ├── shims.lua       # love.*/steam/SoundTag 垫片 (全新, 233 行)
│   │   │   ├── shaders.lua     # Shader 存根 (全新, 8 行)
│   │   │   ├── system.lua      # 系统功能存根 (13 行)
│   │   │   ├── trigger.lua     # 定时器/缓动 (-5%)
│   │   │   ├── state.lua       # 状态机 (-28%)
│   │   │   ├── collision.lua   # 碰撞检测 (全新)
│   │   │   ├── observer.lua    # 观察者 (全新)
│   │   │   ├── container.lua   # 容器 (全新)
│   │   │   ├── flashes.lua     # 闪光效果
│   │   │   ├── hitfx.lua       # 受击特效
│   │   │   ├── springs.lua     # 弹簧组件
│   │   │   ├── parent.lua      # 父子关系 (未修改)
│   │   │   ├── anchor.lua      # 锚点 (全新)
│   │   │   ├── draft.lua       # 绘制辅助 (全新)
│   │   │   ├── stats.lua       # 统计 (全新)
│   │   │   ├── stepper.lua     # 步进器 (全新)
│   │   │   ├── timer.lua       # 定时器 (全新)
│   │   │   └── layer.lua       # 层级 (全新, 但未使用—Layer 在 graphics.lua 中定义)
│   │   │
│   │   ├── graphics/           # 渲染适配
│   │   │   ├── graphics.lua    # 核心渲染 + Layer 系统 (+145%, 959 行)
│   │   │   ├── camera.lua      # 相机 (-17%)
│   │   │   ├── canvas.lua      # Canvas record+replay (+8%)
│   │   │   ├── color.lua       # 颜色工具 (未修改)
│   │   │   ├── font.lua        # NanoVG 字体 (+437%)
│   │   │   ├── image.lua       # NanoVG 图片 (+115%)
│   │   │   ├── text.lua        # 文本渲染 (-14%)
│   │   │   ├── animation.lua   # 动画 (-4%)
│   │   │   ├── tileset.lua     # 瓦片集 (+100%)
│   │   │   └── shader.lua      # Shader 存根 (+16%)
│   │   │
│   │   ├── math/               # 数学/几何
│   │   │   ├── math.lua        # 数学工具 (-8%)
│   │   │   ├── vector.lua      # 向量 (-24%)
│   │   │   ├── random.lua      # 随机数 (-10%)
│   │   │   ├── spring.lua      # 弹簧 (-51%)
│   │   │   ├── circle.lua      # 圆 (-22%)
│   │   │   ├── polygon.lua     # 多边形 (-33%)
│   │   │   ├── line.lua        # 线段 (+2%)
│   │   │   ├── rectangle.lua   # 矩形 (+174%)
│   │   │   ├── triangle.lua    # 三角形 (+70%)
│   │   │   └── chain.lua       # 链条 (-18%)
│   │   │
│   │   └── datastructures/     # 数据结构
│   │       ├── table.lua       # 表扩展 (-23%)
│   │       └── string.lua      # 字符串扩展 (-22%)
│   │
│   └── game/                   # 游戏逻辑层 (12,420 行)
│       ├── data.lua            # 游戏数据 + init/update/draw (全新, 2,103 行, 从原版 main.lua 提取)
│       ├── arena.lua           # 战斗场景 (+4%)
│       ├── buy_screen.lua      # 商店界面 (+7%)
│       ├── player.lua          # 角色逻辑 (+1%, 4,075 行)
│       ├── enemies.lua         # 敌人 (+1%)
│       ├── objects.lua         # 游戏对象 (+0%)
│       ├── shared.lua          # 公共工具 (+2%)
│       ├── mainmenu.lua        # 主菜单 (+2%)
│       └── media.lua           # 资源定义 (+31%)
│
├── assets/                     # 游戏资源
│   ├── images/                 # 精灵图片 (PNG)
│   ├── sounds/                 # 音效 (OGG)
│   └── Fonts/                  # 字体
│
├── docs/                       # 文档
│   ├── dev-guide.md            # ← 本文件
│   ├── fork-analysis.md        # Fork 差异分析
│   └── characters-and-classes.md
│
└── .project/                   # UrhoX 项目配置
    └── project.json            # project_id, entry, version
```

---

## 3. 运行时架构

```
┌─────────────────────────────────────────────────────────────┐
│  main.lua — UrhoX 入口                                      │
│  Start() → HandleUpdate() → HandleNanoVGRender()            │
├─────────────────────────────────────────────────────────────┤
│  engine/init.lua — 生命周期 API                              │
│  M.init(nvg_ctx)  M.update(dt)  M.draw()                   │
├──────────────┬──────────────┬───────────────────────────────┤
│ Graphics     │ Physics      │ Input / Audio / Shims         │
│ (NanoVG)     │ (UrhoX Box2D)│ (UrhoX polling)              │
│              │              │                               │
│ ┌──────────┐ │ ┌──────────┐ │ ┌──────────┐ ┌─────────────┐ │
│ │ Layer    │ │ │RigidBody │ │ │ Input    │ │ Sound/Music │ │
│ │ 延迟队列  │ │ │2D + Coll │ │ │ polling  │ │ SoundSource │ │
│ │→ NanoVG  │ │ │ision*2D │ │ │→ action  │ │ component   │ │
│ └──────────┘ │ └──────────┘ │ └──────────┘ └─────────────┘ │
├──────────────┴──────────────┴───────────────────────────────┤
│  游戏逻辑层 (game/)                                          │
│  data.lua ← init() / update(dt) / draw()                   │
│  arena / buy_screen / player / enemies / objects / shared   │
├─────────────────────────────────────────────────────────────┤
│  UrhoX 引擎                                                 │
│  NanoVG · Box2D · Lua 5.4 · SoundSource · cache            │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. 生命周期与数据流

### 4.1 启动流程

```
UrhoX 启动
  ↓
main.lua Start()
  ├── SampleStart()                     # UrhoX 基础初始化
  ├── scene_ = Scene()                  # 创建音频场景
  ├── vg = nvgCreate(1)                 # 创建 NanoVG 上下文
  ├── Engine.init(vg)                   # 引擎适配层初始化
  │   ├── 计算动态视口 (gw, gh, sx, sy)
  │   ├── random = Random()
  │   ├── camera = Camera(gw/2, gh/2, gw, gh)
  │   ├── graphics = Graphics()         # 覆盖 UrhoX 的 graphics 全局变量
  │   └── input = Input()               # 覆盖 UrhoX 的 input 全局变量
  ├── mouse / last_mouse / trigger 初始化
  ├── 订阅 Update / NanoVGRender 事件
  ├── require("game.shared") ...        # 加载游戏模块 (pcall 保护)
  └── init()                            # 调用 data.lua 的 init()
      ├── shared_init()                 # 颜色/字体/Canvas/星星系统
      ├── input:bind(...)               # 输入绑定
      ├── Sound/Image/Music 加载        # ~90 音效, ~60 图片
      ├── 游戏数据表                     # 角色/职业/被动/关卡
      └── main = Main() → MainMenu     # 启动主状态机
```

### 4.2 每帧更新 (HandleUpdate)

```
HandleUpdate(dt)
  ├── Engine.update(dt)
  │   ├── time += dt
  │   ├── input:poll_urho()             # 轮询 UrhoX 输入 → 填 keyboard_state/mouse_state
  │   ├── input:update(dt)              # 计算 pressed/down/released
  │   └── camera:update(dt)
  ├── trigger:update(dt)                # 全局缓动/定时器
  ├── 鼠标坐标换算                       # 物理像素 → 设计坐标
  │   mx = urho_input.mousePosition.x / dpr
  │   mouse:set((mx - screen_ox) / sx, (my - screen_oy) / sy)
  ├── update(dt * slow_amount)          # data.lua: main:update(dt)
  │   └── 当前状态的 update()            # MainMenu / Arena / BuyScreen
  │       ├── group:update(dt)          # 物理步进 + 对象更新
  │       │   ├── world:Step()          # UrhoX Box2D 物理步进
  │       │   └── obj:update(dt)        # 每个游戏对象更新
  │       └── 绘制命令入队               # 调用 graphics.* → Layer 队列
  └── 帧尾清理 (input.last_key_pressed = nil, last_mouse 更新)
```

### 4.3 每帧渲染 (HandleNanoVGRender)

```
HandleNanoVGRender()
  ├── nvgBeginFrame(vg, logW, logH, dpr)
  ├── 绘制背景色
  ├── draw()                            # data.lua: shared_draw(main:draw())
  │   └── shared_draw(action)
  │       ├── game_canvas:draw_to(action)   # 录制绘制闭包
  │       ├── main_canvas:draw_to(...)      # 再包一层（原版做 shader 后处理）
  │       └── main_canvas:draw(...)         # 回放 → 触发 Layer 入队
  ├── Engine.draw()                     # graphics:draw()
  │   └── 遍历所有 Layer，按顺序回放
  │       ├── nvgSave / nvgScale(sx, sy)
  │       ├── camera:attach() → nvgTranslate + nvgScale + nvgRotate
  │       ├── 逐条执行队列中的绘图闭包   # nvgBeginPath → nvgRect/Circle → nvgFill/Stroke
  │       ├── camera:detach() → nvgRestore
  │       └── nvgRestore
  └── nvgEndFrame(vg)
```

---

## 5. 引擎适配层详解

### 5.1 渲染系统 (engine/graphics/graphics.lua, 959 行)

**核心改动**: 所有 `love.graphics.*` 调用替换为 NanoVG 等价物。

#### 5.1.1 绘图 API 映射

| 原版 (LOVE2D) | Fork (NanoVG) |
|---------------|---------------|
| `love.graphics.rectangle("fill", x, y, w, h)` | `nvgBeginPath` → `nvgRect` → `nvgFill` |
| `love.graphics.rectangle("line", x, y, w, h)` | `nvgBeginPath` → `nvgRect` → `nvgStrokeWidth` → `nvgStroke` |
| `love.graphics.circle("fill", x, y, r)` | `nvgBeginPath` → `nvgCircle` → `nvgFill` |
| `love.graphics.line(x1, y1, x2, y2)` | `nvgBeginPath` → `nvgMoveTo` → `nvgLineTo` → `nvgStroke` |
| `love.graphics.polygon("fill", verts)` | `nvgBeginPath` → `nvgMoveTo` → 多次 `nvgLineTo` → `nvgClosePath` → `nvgFill` |
| `love.graphics.print(text, font, x, y)` | `nvgFontFace` → `nvgFontSize` → `nvgText` |
| `love.graphics.draw(image, x, y)` | `nvgImagePattern` → `nvgBeginPath` → `nvgRect` → `nvgFillPaint` → `nvgFill` |
| `love.graphics.push()` / `pop()` | `nvgSave(vg)` / `nvgRestore(vg)` |
| `love.graphics.translate(x, y)` | `nvgTranslate(vg, x, y)` |
| `love.graphics.scale(sx, sy)` | `nvgScale(vg, sx, sy)` |
| `love.graphics.rotate(r)` | `nvgRotate(vg, r)` |
| `love.graphics.setColor(r, g, b, a)` | `nvgFillColor(vg, nvgRGBAf(r, g, b, a))` |
| `love.graphics.setLineWidth(w)` | `nvgStrokeWidth(vg, w)` |
| `love.graphics[shape](mode, ...)` (动态分发) | if-else 分支分发到具体函数 |

#### 5.1.2 Layer 延迟绘制系统

**原版**: `love.graphics.*` 即时执行，GPU 立即渲染。

**Fork**: 游戏逻辑中的绘图调用被捕获为闭包，存入 Layer 队列，在 `NanoVGRender` 事件中统一回放。

```lua
-- 游戏逻辑中 (Update 阶段)
graphics.circle(x, y, r, color)
  → Layer 当前层.queue[#queue+1] = function() ... end  -- 存闭包

-- 渲染阶段 (NanoVGRender)
Layer:draw()
  → for _, cmd in ipairs(self.queue) do cmd() end      -- 回放
```

**注意事项**:
- 每帧产生大量闭包，有 GC 压力
- 绘制顺序由 Layer 名称的排序决定
- Layer 内部已包含 `nvgScale(sx, sy)` 和 camera attach/detach

#### 5.1.3 push 变换顺序

```lua
-- ⚠️ 重要：Fork 的变换顺序与原版不同
-- 原版: translate → scale → rotate → translate
-- Fork: translate → scale → rotate → translate (但 scale 和 rotate 交换了位置)
self.push = function(x, y, r, sx, sy)
  nvgSave(vg)
  if x and y then nvgTranslate(vg, x, y) end
  if sx then nvgScale(vg, sx, sy or sx) end      -- scale FIRST
  if r and r ~= 0 then nvgRotate(vg, r) end      -- rotate SECOND
  if x and y then nvgTranslate(vg, -x, -y) end
end
```

这个顺序在 commit `319f530` 中被修正过（之前是 rotate first → scale second，导致旋转物体形变）。

### 5.2 物理系统 (engine/game/physics.lua, 888 行)

**核心改动**: LOVE2D 的独立对象模型 → UrhoX 的组件系统。

| 原版 (LOVE2D) | Fork (UrhoX) |
|---------------|--------------|
| `love.physics.newWorld(gx, gy)` | `scene:CreateComponent("PhysicsWorld2D")` |
| `love.physics.newBody(world, x, y, "dynamic")` | `node:CreateComponent("RigidBody2D")` |
| `love.physics.newRectangleShape(w, h)` | `node:CreateComponent("CollisionBox2D")` |
| `love.physics.newCircleShape(r)` | `node:CreateComponent("CollisionCircle2D")` |
| `love.physics.newPolygonShape(verts)` | `node:CreateComponent("CollisionPolygon2D")` |
| `love.physics.newFixture(body, shape)` | 隐含在 CreateComponent 中 |
| `body:setPosition(x, y)` | `node.position2D = Vector2(x, y)` |
| `body:getLinearVelocity()` | `body.linearVelocity` (Vector2) |
| `body:applyForce(fx, fy)` | `body:ApplyForceToCenter(Vector2(fx, fy), true)` |
| `fixture:setSensor(true)` | `collision.trigger = true` |
| `world:setCallbacks(begin, end, pre, post)` | `SubscribeToEvent(node, "PhysicsBeginContact2D", ...)` |

**关键差异**:
- UrhoX 中 RigidBody2D 和 CollisionShape2D **必须在同一个 Node** 上
- 碰撞回调从 World 级别变为 Node 级别事件订阅
- 物理坐标使用 `position2D` (Vector2)，不是 `position` (Vector3)
- `steering_enabled` 标志控制转向行为是否覆盖物理速度（被 Juggernaut/Forcer 推开时禁用）

### 5.3 输入系统 (engine/game/input.lua, 302 行)

**核心改动**: 事件回调 → 每帧轮询。

```
原版:
  love.keypressed(key) → keyboard_state[key] = true
  love.keyreleased(key) → keyboard_state[key] = false

Fork:
  Input:poll_urho()  -- 每帧调用
    for key_name, urho_key in pairs(love_to_urho_key) do
      keyboard_state[key_name] = urho_input:GetKeyDown(urho_key)
    end
    mouse_state["m1"] = urho_input:GetMouseButtonDown(MOUSEB_LEFT)
    mouse_state["m2"] = urho_input:GetMouseButtonDown(MOUSEB_RIGHT)
```

**键码映射表**: `love_to_urho_key` 表将 LOVE2D 键名 (`"a"`, `"space"`, `"return"`) 映射到 UrhoX 枚举 (`KEY_A`, `KEY_SPACE`, `KEY_RETURN`)。

**动作绑定**: 沿用原版架构 `input:bind('move_left', {'a', 'left', 'm1'})`。游戏代码通过 `input.move_left.pressed/down/released` 读取状态，这一层不需要修改。

### 5.4 音频系统 (engine/game/sound.lua + music.lua)

**Sound (音效, 176 行)**:

| 原版 | Fork |
|------|------|
| `love.audio.newSource(path, "static")` | `cache:GetResource("Sound", "sounds/" .. path)` |
| `source:play()` | 在 `scene_` 上创建 `SoundSource` 组件并播放 |
| `source:clone()` | 创建新的 `SoundSource` 组件 |
| `source:setVolume(v)` | `soundSource.gain = v` |

**Music (音乐, 117 行)**:

| 原版 | Fork |
|------|------|
| `love.audio.newSource(path, "stream")` | `cache:GetResource("Sound", path)` + `SetLooped(true)` |
| `source:play()` | `SoundSource` 组件 + `Play(resource)` |

**注意**: 音效路径需要加 `sounds/` 前缀（UrhoX 资源路径规范）。

### 5.5 Canvas (engine/graphics/canvas.lua, 73 行)

**原版**: LOVE2D Canvas = GPU 帧缓冲对象 (FBO)，支持离屏渲染。

**Fork**: 改为 **record+replay 闭包模式** — 没有真正的离屏渲染。

```lua
-- 录制
canvas:draw_to(function()
  -- 绘制命令被记录为闭包
  graphics.circle(x, y, r, color)
end)

-- 回放（带变换）
canvas:draw(x, y, r, sx, sy)  -- 执行闭包，然后清除
canvas:draw2(x, y, r, sx, sy) -- 执行闭包，但保留（可重复回放）
```

**⚠️ draw() vs draw2()**:
- `draw()` 回放后**清除** `_draw_action`（一次性）
- `draw2()` 回放后**保留** `_draw_action`（可重复使用）
- 之前有一个 bug：`draw2()` 也清除了 `_draw_action`，导致棋盘格镂空（commit `319f530` 修复）

**限制**: 原版通过 Canvas 做的**多 pass 后处理**（阴影、发光等 shader 效果）在 Fork 中**不执行**。

### 5.6 Shader (engine/graphics/shader.lua, 36 行 + shaders.lua 8 行)

**完全存根**。`Shader:init()` 返回空对象，`graphics.set_shader()` 是空操作。

原版使用的 shader：
- `shadow.frag` — 阴影渲染
- stencil mask shader — `draw_intersection()` 中使用
- 其他后处理 shader

全部在 Fork 中**静默失效**，不报错但不产生视觉效果。

### 5.7 LOVE2D 垫片 (engine/game/shims.lua, 233 行)

提供游戏代码偶尔直接调用的 `love.*` API 存根：

| 垫片 | 行为 |
|------|------|
| `love.timer.getTime()` | 返回全局 `time` 变量 |
| `love.event.quit()` | 调用 `engine:Exit()` |
| `love.window.setMode()` | 空操作（UrhoX 不支持） |
| `love.window.getMode()` | 返回当前屏幕尺寸 |
| `love.mouse.setCursor()` | 空操作 |
| `love.filesystem.read(path)` | 尝试用 UrhoX `File` 读取 |
| `love.filesystem.write(path, data)` | 返回 `true`（未真正写入） |
| `love.audio.newSource()` | 返回空 Source 存根 |
| `steam.*` | 全部空操作 |
| `SoundTag` | 音量/播放管理对象 |
| `GradientImage` | 渐变图片（NanoVG 线性渐变实现） |
| `Contact` | 碰撞接触点包装 |

---

## 6. 关键设计模式

### 6.1 UrhoX 全局变量保护

引擎适配层会**覆盖** UrhoX 的同名全局变量：

```lua
-- engine/init.lua 中保存原始引用
urho_graphics = graphics    -- 保存 UrhoX graphics 子系统
urho_input = input          -- 保存 UrhoX input 子系统

-- 之后被 SNKRX 引擎类覆盖
graphics = Graphics()       -- SNKRX 渲染管理器
input = Input()             -- SNKRX 输入管理器
```

**规则**: 需要 UrhoX 原生功能时，使用 `urho_graphics` / `urho_input`。

### 6.2 坐标系与分辨率

```
物理像素 (physW × physH)
  ÷ DPR
逻辑像素 (logW × logH)
  - screen_ox/oy (letterbox 偏移，当前为 0)
  ÷ sx/sy (缩放系数)
设计坐标 (gw × gh ≈ 480 × 270，按屏幕比例动态扩展)
```

**鼠标坐标换算**:
```lua
local dpr = urho_graphics:GetDPR()
local mx = urho_input.mousePosition.x / dpr
local my = urho_input.mousePosition.y / dpr
mouse:set((mx - screen_ox) / sx, (my - screen_oy) / sy)
```

### 6.3 动态视口扩展

原版固定 480×270。Fork 根据屏幕比例动态扩展：

```lua
-- 屏幕比 16:9 更宽 → 固定高度 270，扩展宽度
-- 屏幕比 16:9 更窄 → 固定宽度 480，扩展高度
-- 缩放系数 sx = sy = logW / gw
```

这意味着 `gw` 和 `gh` 在不同设备上可能不同。游戏逻辑中使用设计坐标定位的代码（如 `gw/2`, `gh/2` 作为屏幕中心）会自动适应。

### 6.4 pcall 保护

`main.lua` 中的模块加载和 `init()` 调用都用 `pcall` 包裹：

```lua
local ok, err = pcall(function()
  require("game.shared") ...
end)
```

即使游戏模块加载失败，`HandleNanoVGRender` 仍然运行，会显示红色错误信息。这确保了调试时始终有视觉反馈。

---

## 7. 全局变量速查

### 7.1 UrhoX 引擎全局

| 变量 | 类型 | 说明 |
|------|------|------|
| `vg` | userdata | NanoVG 上下文 |
| `scene_` | Scene | UrhoX 场景（音频播放需要） |
| `urho_graphics` | subsystem | UrhoX graphics 子系统（原始引用） |
| `urho_input` | subsystem | UrhoX input 子系统（原始引用） |

### 7.2 SNKRX 引擎全局

| 变量 | 类型 | 说明 |
|------|------|------|
| `graphics` | Graphics | 渲染管理器（覆盖了 UrhoX 同名全局） |
| `input` | Input | 输入管理器（覆盖了 UrhoX 同名全局） |
| `camera` | Camera | 主相机 |
| `random` | Random | 随机数生成器 |
| `trigger` | Trigger | 全局缓动/定时器 |
| `mouse` | Vector | 鼠标位置（设计坐标） |
| `last_mouse` | Vector | 上一帧鼠标位置 |
| `mouse_dt` | Vector | 鼠标移动量 |

### 7.3 SNKRX 游戏全局

| 变量 | 类型 | 说明 |
|------|------|------|
| `main` | Main | 游戏主状态机 |
| `gw`, `gh` | number | 动态视口尺寸（设计坐标） |
| `dgw`, `dgh` | number | 固定设计分辨率 (480, 270) |
| `sx`, `sy` | number | 缩放系数 |
| `screen_ox`, `screen_oy` | number | letterbox 偏移（当前为 0） |
| `time` | number | 运行时间（秒） |
| `frame` | number | 帧计数 |
| `fixed_dt` | number | 固定时间步长 (1/60) |
| `slow_amount` | number | 慢动作系数 (1 = 正常) |
| `gold` | number | 当前金币 |
| `new_game_plus` | number | 循环轮数 |
| `max_units` | number | 最大单位数 |
| `passives` | table | 已获取的被动技能 |

---

## 8. 已修复的 Bug

### commit 319f530 — 核心引擎修复

| Bug | 文件 | 修复内容 |
|-----|------|---------|
| **steering_enabled 被忽略** | `engine/game/physics.lua` | `steering_update()` 开头检查 `self.steering_enabled == false` 则 return |
| **push 变换顺序错误** | `engine/graphics/graphics.lua` | 调整为 scale first → rotate second（原来反了，导致旋转物体形变） |
| **draw_with_mask 棋盘镂空** | `engine/graphics/graphics.lua` | `draw2()` 不再清除 `_draw_action`，允许 Canvas 重复回放 |
| **Camera 居中偏移** | `engine/init.lua` | `Camera(gw/2, gh/2, ...)` 替换 `Camera(dgw/2, dgh/2, ...)`，修复动态视口下的位移 |
| **main.lua 入口重构** | `main.lua` | Start() + pcall 保护 + 事件订阅前置 |
| **LSP 506 个未定义全局错误** | `engine/_globals.lua` | 新增 92 行全局类型声明 |

### 其他 commit 的修复

| Bug | commit | 修复内容 |
|-----|--------|---------|
| 子弹撞墙不销毁 | `845d967` | 启用 CCD + 边界 fallback 检查 |
| Area 碰撞检测失败 | `56bc5ab` | shape 位置随物理体同步 |
| 左右墙壁反弹失败 | `0a6cb00` | mover/wall_obj 用 vertices 识别 |
| 子弹回收机制 | `19e1d77` | die() 先设 dead 标记 + TTL + 越界安全网 |
| 双击选中判定 | `ef68dc5` | hit_test 精确碰撞检测替代 colliding_with_mouse |
| 主菜单自锁 | `8c5a030` | trigger 用原始 dt，删除无效按钮 |
| DPR 鼠标坐标错位 | `942a52b` | 物理像素 ÷ DPR → 逻辑像素 |

---

## 9. 已知限制与存根

### 9.1 功能缺失

| 优先级 | 特性 | 状态 | 说明 |
|:------:|------|:----:|------|
| **P0** | 存档系统 | 🔴 存根 | `love.filesystem.write()` 返回 true 但不写入；`system.lua` 仅 13 行。需接入 UrhoX `File` API |
| **P1** | Canvas 后处理 | 🟡 降级 | record+replay 工作，但原版的 shader 后处理（阴影/发光）不执行 |
| **P1** | Stencil 蒙版 | 🟡 降级 | `draw_with_mask` 使用 NanoVG scissor（仅矩形裁剪），不如原版精确 |
| **P2** | 自定义 Shader | 🔴 存根 | `Shader:init()` 返回空对象 |
| **P2** | GradientImage | 🟡 替代实现 | 使用 NanoVG 线性渐变近似（非原版的 Mesh） |
| **P3** | 手柄输入 | 🔴 未实现 | `love.joystick.getJoysticks()` 返回空数组 |
| **P3** | Steam 集成 | 🔴 存根 | 平台不适用 |

### 9.2 几何模块的绘制存根

以下几何类的 `:draw()` 方法只有注释 `-- NanoVG draw stub`，未实现：

- `engine/math/chain.lua` — Chain:draw()
- `engine/math/circle.lua` — Circle:draw()
- `engine/math/line.lua` — Line:draw()
- `engine/math/polygon.lua` — Polygon:draw()
- `engine/math/rectangle.lua` — Rectangle:draw()
- `engine/math/triangle.lua` — Triangle:draw()
- `engine/math/vector.lua` — Vector:draw()

这些存根**不影响游戏运行**——SNKRX 的绘制主要通过 `graphics.circle/rectangle/line` 全局函数（在 graphics.lua 中已实现），而非几何对象的 `:draw()` 方法。

### 9.3 延迟绘制的性能注意

每帧为每个绘图调用创建一个闭包并存入 Layer 队列。在对象密集的战斗场景中（几百个单位 + 弹幕），可能产生大量短期闭包，增加 GC 压力。

可能的优化方向：
- 闭包对象池
- 命令缓冲（结构化数据替代闭包）

---

## 10. 开发规范

### 10.1 修改引擎层代码时

1. **理解原版行为**: 先查看原版 `/workspace/a327ex-SNKRX/` 中的对应文件
2. **保持 API 签名一致**: 游戏逻辑层通过函数名/参数调用引擎，修改时不要改签名
3. **注意 UrhoX 全局变量保护**: `graphics` 和 `input` 已被覆盖，用 `urho_graphics` / `urho_input` 访问原生功能
4. **NanoVG 只能在 NanoVGRender 中绘制**: 所有绘图必须通过 Layer 队列或直接在 HandleNanoVGRender 中执行

### 10.2 修改游戏逻辑层代码时

1. **尽量不改动**: 游戏层的改动越少，合并上游更新越容易
2. **资源路径**: 音效路径加 `sounds/` 前缀；图片路径加 `images/` 前缀（Image 类内部处理）
3. **避免直接 `love.*` 调用**: 通过引擎封装的 `graphics.*` / `input.*` 调用
4. **DPR 注意**: 鼠标坐标需要除以 DPR 才是逻辑像素

### 10.3 添加新功能时

1. **不要修改 engine/ 中已有模块的 API 签名** — 游戏层依赖这些接口
2. **新功能写在 engine/game/ 下新文件中** — 在 `engine/init.lua` 中添加 require
3. **需要 UrhoX 原生功能时** — 通过 `urho_graphics` / `urho_input` / `scene_` 访问
4. **需要持久化存储** — 使用 UrhoX 的 `File` API（参考 `engine-docs/recipes/file-storage.md`）

### 10.4 调试技巧

```lua
-- 在 HandleUpdate 中打印信息
print(string.format("[DEBUG] mouse: %.1f, %.1f | units: %d", mouse.x, mouse.y, #main.units))

-- 检查物理体状态
local body = self.body
print(string.format("[PHYS] pos: %.1f, %.1f | vel: %.1f, %.1f",
  body.linearVelocity.x, body.linearVelocity.y))

-- 在 NanoVGRender 中绘制调试信息
nvgFontSize(vg, 16)
nvgFillColor(vg, nvgRGBAf(1, 1, 0, 1))
nvgText(vg, 10, 20, "FPS: " .. tostring(math.floor(1/dt)))
```

---

## 11. 原版对照表

### 仓库位置

```
原版: /workspace/a327ex-SNKRX/        56 files, 21,960 lines
Fork: /workspace/FanZeros-SNKRX/       60 files, 20,817 lines
```

### 文件对应关系

| 原版路径 | Fork 路径 | 状态 |
|---------|----------|:----:|
| `main.lua` | `scripts/main.lua` | 重写 |
| `arena.lua` | `scripts/game/arena.lua` | 重定位+修改 |
| `buy_screen.lua` | `scripts/game/buy_screen.lua` | 重定位+修改 |
| `enemies.lua` | `scripts/game/enemies.lua` | 重定位+修改 |
| `mainmenu.lua` | `scripts/game/mainmenu.lua` | 重定位+修改 |
| `media.lua` | `scripts/game/media.lua` | 重定位+修改 |
| `objects.lua` | `scripts/game/objects.lua` | 重定位+修改 |
| `player.lua` | `scripts/game/player.lua` | 重定位+修改 |
| `shared.lua` | `scripts/game/shared.lua` | 重定位+修改 |
| *(无)* | `scripts/game/data.lua` | 新增 (从 main.lua 提取) |
| `engine/init.lua` | `scripts/engine/init.lua` | 重写 |
| `engine/game/*` | `scripts/engine/game/*` | 大部分重写 |
| `engine/graphics/*` | `scripts/engine/graphics/*` | 大部分重写 |
| `engine/math/*` | `scripts/engine/math/*` | 中度修改 |
| `engine/datastructures/*` | `scripts/engine/datastructures/*` | 精简 |
| `engine/external/*` (5 files) | *(删除)* | LuaJIT/LOVE2D 依赖 |
| `engine/map/*` (2 files) | *(删除)* | 游戏未使用 |
| `engine/sound.lua` (4 行) | `scripts/engine/game/sound.lua` (176 行) | 全新重写 |
| `engine/system.lua` (187 行) | `scripts/engine/game/system.lua` (13 行) | 存根 |
| `conf.lua` | *(删除)* | LOVE2D 配置 |

---

*生成日期: 2025-05-05*
*基于 commit: 48bd545*
