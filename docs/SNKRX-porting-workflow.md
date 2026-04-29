# SNKRX → UrhoX 移植实施流程

> 本文档是移植的具体实施计划，涵盖每个阶段的文件清单、修改点和验证方式。

---

## 项目结构

```
/workspace/scripts/
├── main.lua                    # UrhoX 入口文件
├── engine/                     # SNKRX 引擎适配层
│   ├── object.lua              # OOP 基类（纯 Lua）
│   ├── trigger.lua             # 定时器/缓动系统
│   ├── spring.lua              # 弹簧阻尼系统
│   ├── springs.lua             # 弹簧集合
│   ├── hitfx.lua               # 打击特效
│   ├── flashes.lua             # 闪烁特效
│   ├── parent.lua              # 父子跟随
│   ├── state.lua               # 场景状态机
│   ├── steering.lua            # 转向行为 AI
│   ├── gameobject.lua          # 实体 Mixin
│   ├── group.lua               # 对象容器 + 物理世界
│   ├── physics.lua             # 物理 Mixin（适配 UrhoX Physics2D）
│   ├── graphics.lua            # 绘图 API（适配 NanoVG）
│   ├── camera.lua              # 相机系统（适配 NanoVG 变换）
│   ├── canvas.lua              # Canvas（简化/移除）
│   ├── color.lua               # 颜色类（纯 Lua）
│   ├── font.lua                # 字体（适配 NanoVG）
│   ├── image.lua               # 图片（适配 NanoVG）
│   ├── text.lua                # 富文本系统
│   ├── input.lua               # 输入适配层
│   ├── sound.lua               # 音频适配层
│   ├── system.lua              # 系统/存档适配层
│   ├── random.lua              # 随机数（纯 Lua 实现）
│   ├── math.lua                # 数学扩展（纯 Lua）
│   ├── vector.lua              # 2D 向量（纯 Lua）
│   ├── table.lua               # table 扩展
│   ├── string.lua              # string 扩展（纯 Lua）
│   ├── polygon.lua             # 多边形（纯 Lua + mlib 替换）
│   ├── circle.lua              # 圆（纯 Lua + mlib 替换）
│   ├── line.lua                # 线段
│   ├── rectangle.lua           # 矩形
│   ├── triangle.lua            # 三角形
│   ├── chain.lua               # 链
│   └── mlib.lua                # 几何碰撞库（纯 Lua 实现）
├── game/                       # SNKRX 游戏逻辑（后续阶段）
│   ├── shared.lua
│   ├── arena.lua
│   ├── buy_screen.lua
│   ├── player.lua
│   ├── enemies.lua
│   ├── objects.lua
│   └── mainmenu.lua
└── data/                       # 游戏数据
    └── media.lua               # 资源加载
```

---

## 阶段总览

| 阶段 | 内容 | 文件数 | 改动量 | 依赖 |
|------|------|--------|--------|------|
| 1 | 纯 Lua 核心模块 | ~18 | 极小 | 无 |
| 2 | NanoVG 渲染适配 | ~5 | 大（重写） | 阶段1 |
| 3 | Physics2D 物理适配 | ~3 | 大（重写） | 阶段1,2 |
| 4 | 输入/音频/存档适配 | ~3 | 中 | 阶段1 |
| 5 | 游戏逻辑层移植 | ~8 | 大（数据+逻辑） | 阶段1-4 |
| 6 | 整合入口 + 构建 | 1 | 中 | 全部 |

---

## 阶段 1：纯 Lua 核心模块

### 目标
复制所有不依赖 LÖVE2D 的纯 Lua 模块，仅修改极少量 `love.*` 调用。

### 文件清单与修改点

| 文件 | 修改量 | 说明 |
|------|--------|------|
| `object.lua` | 零修改 | OOP 基类，直接复制 |
| `spring.lua` | 零修改 | 弹簧阻尼，纯数学 |
| `springs.lua` | 零修改 | 弹簧集合管理 |
| `hitfx.lua` | 零修改 | 依赖 Springs + Flashes |
| `flashes.lua` | 零修改 | 依赖 Trigger |
| `parent.lua` | 零修改 | 父子跟随 |
| `color.lua` | 零修改 | 纯 Lua 颜色类 |
| `string.lua` | 零修改 | string 扩展方法 |
| `math.lua` | 零修改 | 数学函数，纯 Lua |
| `vector.lua` | 小修改 | 移除 3 处 `mlib` 引用，改用自实现 |
| `polygon.lua` | 中修改 | `mlib`→自实现；移除 `clipper`（不影响核心功能） |
| `circle.lua` | 中修改 | `mlib`→自实现 |
| `line.lua` | 中修改 | `mlib`→自实现 |
| `rectangle.lua` | 零修改 | 依赖 Polygon（已含 mlib 替换） |
| `triangle.lua` | 零修改 | 纯 Lua |
| `chain.lua` | 中修改 | `mlib`→自实现 |
| `trigger.lua` | 2行修改 | `love.timer.getTime()` → `GetTime():GetElapsedTime()` |
| `random.lua` | 重写 | `love.math.newRandomGenerator` → 纯 Lua PRNG |
| `table.lua` | 2行修改 | `love.math.random` → `math.random` |
| `mlib.lua` | 新建 | 实现几何碰撞检测（纯 Lua） |

### mlib 替换方案

SNKRX 使用 `mlib` 库的以下功能：
- `mlib.circle.checkPoint(x, y, cx, cy, r)` — 点在圆内
- `mlib.circle.getSegmentIntersection(cx, cy, r, x1, y1, x2, y2)` — 线段与圆交
- `mlib.circle.isCircleCompletelyInside(cx1, cy1, r1, cx2, cy2, r2)` — 圆包含
- `mlib.circle.getCircleIntersection(cx1, cy1, r1, cx2, cy2, r2)` — 圆相交
- `mlib.circle.isPolygonCompletelyInside(cx, cy, r, vertices)` — 多边形在圆内
- `mlib.polygon.checkPoint(x, y, vertices)` — 点在多边形内
- `mlib.polygon.isSegmentInside(x1, y1, x2, y2, vertices)` — 线段在多边形内
- `mlib.polygon.getCircleIntersection(cx, cy, r, vertices)` — 圆与多边形交
- `mlib.polygon.getSegmentIntersection(x1, y1, x2, y2, vertices)` — 线段与多边形交
- `mlib.polygon.isCircleCompletelyInside(cx, cy, r, vertices)` — 圆在多边形内
- `mlib.polygon.isPolygonInside(v1, v2)` — 多边形包含
- `mlib.segment.checkPoint(x, y, x1, y1, x2, y2)` — 点在线段上
- `mlib.segment.getIntersection(ax1, ay1, ax2, ay2, bx1, by1, bx2, by2)` — 线段相交

这些全部可以用纯 Lua 数学实现（SAT 分离轴、距离公式等）。

### 验证方式
- 所有模块可在纯 Lua 环境下 `require` 成功
- 构建不报 `love.*` 相关错误

---

## 阶段 2：NanoVG 渲染适配层

### 目标
重写 `graphics.lua`，将 SNKRX 的绘图 API 映射到 NanoVG。

### 设计分辨率
- SNKRX 游戏分辨率：**480×270**
- UrhoX 使用 NanoVG 渲染，采用**模式 A（设计分辨率）**
- `nvgBeginFrame(vg, 480, 270, dpr)`，实现像素级匹配

### 核心映射

| SNKRX (graphics.*) | NanoVG 实现 |
|---------------------|-------------|
| `graphics.push(x, y, r, sx, sy)` | `nvgSave` + `nvgTranslate` + `nvgRotate` + `nvgScale` |
| `graphics.pop()` | `nvgRestore` |
| `graphics.set_color(color)` | 设置全局颜色状态 `_current_color` |
| `graphics.rectangle(x, y, w, h, rx, ry, color, lw)` | `nvgBeginPath` + `nvgRoundedRect` + `nvgFill/nvgStroke` |
| `graphics.circle(x, y, r, color, lw)` | `nvgBeginPath` + `nvgCircle` + `nvgFill/nvgStroke` |
| `graphics.line(x1, y1, x2, y2, color, lw)` | `nvgBeginPath` + `nvgMoveTo` + `nvgLineTo` + `nvgStroke` |
| `graphics.polygon(vertices, color, lw)` | `nvgBeginPath` + `nvgMoveTo` + 多个 `nvgLineTo` + `nvgClosePath` |
| `graphics.print(text, font, x, y)` | `nvgFontFace` + `nvgFontSize` + `nvgText` |
| `graphics.set_background_color(color)` | 存储到全局，每帧先绘制全屏矩形 |
| `graphics.stencil / set_stencil_test` | NanoVG `nvgScissor` 近似（或暂不实现） |

### camera.lua 适配

原版 Camera 使用 `love.graphics.push/pop/translate/scale/rotate`，改为：
- `Camera:attach()` → `nvgSave` + `nvgTranslate(w/2, h/2)` + `nvgScale` + `nvgRotate` + `nvgTranslate(-x, -y)`
- `Camera:detach()` → `nvgRestore`
- `Camera:get_mouse_position()` → 通过 UrhoX `input:GetMousePosition()` + 坐标逆变换
- Shake 保持原始纯 Lua 逻辑（`love.math.random` → `math.random`）

### canvas.lua 适配

原版 Canvas 使用 `love.graphics.newCanvas` 做离屏渲染。在 NanoVG 模式下：
- **方案 A（推荐）**：移除 Canvas 概念，直接在同一 NanoVG frame 内按层级绘制
- SNKRX 使用 canvas 主要做 shadow shader 和 background，初期可简化为直接绘制

### font.lua 适配

```lua
Font = Object:extend()
function Font:init(asset_name, font_size)
    self.name = asset_name
    self.size = font_size
    self.h = font_size  -- 近似行高
    -- NanoVG 字体在 Start() 中统一创建
end
function Font:get_text_width(text)
    -- 使用 nvgTextBounds 获取宽度
end
```

### image.lua 适配

```lua
Image = Object:extend()
function Image:init(asset_name)
    -- nvgCreateImage 在渲染线程中创建
    self.path = "images/" .. asset_name .. ".png"
    self.nvg_image = nil  -- 延迟创建
end
function Image:draw(x, y, r, sx, sy, ox, oy, color)
    -- nvgSave + nvgTranslate + nvgRotate + nvgScale
    -- nvgImagePattern + nvgBeginPath + nvgRect + nvgFillPaint
end
```

### 验证方式
- 能绘制基本图形（矩形、圆、线、多边形）
- 文本正确显示
- Camera 的 attach/detach 正确实现视口变换

---

## 阶段 3：Physics2D 物理适配层

### 目标
将 SNKRX 的 LÖVE2D Box2D 接口映射到 UrhoX Physics2D。

### 关键差异

| | SNKRX (LÖVE2D) | UrhoX Physics2D |
|--|-----------------|-----------------|
| 单位 | 像素（meter=192） | 米 |
| Y 轴 | 向下 | 向上 |
| 对象模型 | body/fixture/shape | Node + RigidBody2D + CollisionShape2D |
| 碰撞分类 | category/mask bit 手动管理 | categoryBits/maskBits on CollisionShape2D |
| 碰撞回调 | world:setCallbacks | SubscribeToEvent NodeCollisionStart2D |

### PPM 转换

SNKRX 使用 `meter` 参数（通常 192 或 32）定义物理世界的 pixels-per-meter。
```
UrhoX 物理坐标 = SNKRX 像素坐标 / PPM
UrhoX Y = -SNKRX Y / PPM  (Y 轴翻转)
```

### physics.lua 适配

每个物理实体需要：
1. 创建 UrhoX `Node`
2. 添加 `RigidBody2D` 组件
3. 添加对应的 `CollisionShape2D`（Box/Circle/Polygon/Chain/Edge）
4. 设置 categoryBits 和 maskBits

```lua
-- SNKRX: self.body = love.physics.newBody(world, x, y, 'dynamic')
-- UrhoX:
self._node = scene_:CreateChild("PhysicsObj")
self._body = self._node:CreateComponent("RigidBody2D")
self._body.bodyType = BT_DYNAMIC
self._node.position2D = Vector2(x / PPM, -y / PPM)
```

### group.lua 物理世界适配

`Group:set_as_physics_world(meter, xg, yg, tags)` 改为：
```lua
function Group:set_as_physics_world(meter, xg, yg, tags)
    self.meter = meter
    self.ppm = meter  -- pixels per meter
    -- UrhoX 使用场景级 PhysicsWorld2D
    -- gravity: xg = 0, yg = 0 (SNKRX 无重力)
    self.collision_tags = tags
    self.collision_pairs = {}
    -- 设置碰撞位掩码映射
    for i, tag in ipairs(tags) do
        self.collision_bits[tag] = 1 << (i - 1)
    end
    return self
end
```

### 碰撞回调

SNKRX 的碰撞回调通过 `world:setCallbacks` 设置，UrhoX 使用事件：
```lua
SubscribeToEvent("PhysicsBeginContact2D", "HandleCollision")
```

### 验证方式
- 物理体正确创建和运动
- 碰撞事件正确触发
- 碰撞过滤（category/mask）正确工作

---

## 阶段 4：输入/音频/存档适配层

### input.lua 适配

SNKRX 的 Input 类使用 action 映射系统。UrhoX 有自己的输入 API。

```lua
Input = Object:extend()
function Input:init()
    self.actions = {}
    self.keyboard_state = {}
    self.previous_keyboard_state = {}
    self.mouse_state = {}
    self.previous_mouse_state = {}
end

function Input:update(dt)
    -- 从 UrhoX input 对象同步状态
    self.previous_keyboard_state = table.copy(self.keyboard_state)
    self.previous_mouse_state = table.copy(self.mouse_state)
    -- UrhoX: input:GetKeyDown(KEY_*) 等
end
```

### sound.lua 适配

SNKRX 使用 ripple + love.audio。简化为 UrhoX SoundSource：
```lua
function Sound(asset_name, options)
    return {
        path = "Sounds/" .. asset_name,
        play = function(self, args)
            -- 使用 UrhoX 音频播放
        end
    }
end
```

### system.lua 适配

存档使用 UrhoX 的 File API：
```lua
function system.save_state()
    -- 使用 cjson 序列化 state 表
    -- 使用 File 写入
end
function system.load_state()
    -- 使用 File 读取 + cjson 解析
end
```

---

## 阶段 5：游戏逻辑层移植

### 依赖关系
```
main.lua (init)
  ├── shared.lua (colors, fonts, canvases, shared_draw)
  ├── arena.lua (战斗场景)
  ├── buy_screen.lua (商店场景)
  ├── mainmenu.lua (主菜单)
  ├── objects.lua (弹丸、特效)
  ├── player.lua (玩家/单位逻辑 - 4000行，最大文件)
  └── enemies.lua (敌人逻辑)
```

### 移植顺序
1. `shared.lua` — 颜色定义、全局初始化
2. `data/media.lua` — 提取音效/图片加载（从 main.lua）
3. `mainmenu.lua` — 主菜单场景
4. `objects.lua` — 基础游戏对象
5. `enemies.lua` — 敌人系统
6. `player.lua` — 玩家/单位系统（最复杂）
7. `arena.lua` — 战斗场景
8. `buy_screen.lua` — 商店场景

### 关键修改点
- 所有 `love.*` 调用替换为适配层 API（理论上不需要，因为适配层模拟了原 API）
- `GradientImage` → NanoVG 线性渐变
- `Shader` → 移除或用 NanoVG 效果近似
- 全局变量 `gw, gh, sx, sy` 在 UrhoX 入口中设置

---

## 阶段 6：整合入口文件

### main.lua (UrhoX 入口)

```lua
-- UrhoX 入口
require "LuaScripts/Utilities/Sample"

-- 全局设计分辨率
gw, gh = 480, 270
sx, sy = 1, 1

function Start()
    SampleStart()
    -- 初始化 NanoVG
    vg = nvgCreate(1)
    -- 创建字体
    -- 加载引擎模块
    require "engine.object"
    require "engine.string"
    require "engine.table"
    require "engine.math"
    require "engine.vector"
    require "engine.random"
    -- ... 其余引擎模块
    -- 加载游戏模块
    require "game.shared"
    -- ... 其余游戏模块
    
    -- 初始化游戏
    init()
    
    -- 订阅事件
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent(vg, "NanoVGRender", "HandleNanoVGRender")
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    -- 调用 SNKRX 的 update 逻辑
    update(dt)
end

function HandleNanoVGRender(eventType, eventData)
    nvgBeginFrame(vg, gw, gh, dpr)
    draw()
    nvgEndFrame(vg)
end
```

### 验证方式
- 构建成功
- 游戏启动显示主菜单
- 基本游戏循环可运行

---

## 风险与简化策略

| 风险 | 影响 | 简化策略 |
|------|------|---------|
| Shader 效果（shadow, combine） | 视觉效果降级 | 初期移除 shader，直接绘制 |
| Canvas 离屏渲染 | 层级绘制 | 直接在同一 frame 按顺序绘制 |
| clipper 多边形运算 | polygon:inflate | 初期移除 inflate 功能 |
| mlib 几何碰撞 | 形状碰撞检测 | 自实现核心碰撞算法 |
| Image 精灵绘制 | 角色图标显示 | NanoVG image API |
| 音频同步播放 | 音效体验 | UrhoX 基础音频 API 足够 |

---

## 当前进度

- [x] 分析完成（SNKRX-analysis-and-urhox-porting.md）
- [x] 实施流程文档（本文档）
- [ ] 阶段 1：纯 Lua 核心模块
- [ ] 阶段 2：NanoVG 渲染适配
- [ ] 阶段 3：Physics2D 物理适配
- [ ] 阶段 4：输入/音频/存档
- [ ] 阶段 5：游戏逻辑移植
- [ ] 阶段 6：整合构建
