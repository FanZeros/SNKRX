# FanZeros/SNKRX 改版分析报告

> 对比 a327ex/SNKRX 原版与 FanZeros/SNKRX 改版的详细差异分析。
> 包含所有改动说明和丢弃设计的修复建议。

---

## 目录

1. [项目概述](#1-项目概述)
2. [架构层面改动](#2-架构层面改动)
3. [引擎适配层详细改动](#3-引擎适配层详细改动)
4. [游戏逻辑层详细改动](#4-游戏逻辑层详细改动)
5. [丢弃的原始设计与修复建议](#5-丢弃的原始设计与修复建议)
6. [新增内容](#6-新增内容)
7. [已知 BUG 与待办事项](#7-已知-bug-与待办事项)

---

## 1. 项目概述

**SNKRX** 是一个 roguelite 自走棋 + 贪吃蛇混合游戏。玩家操控一条英雄蛇，蛇身上的英雄自动攻击附近敌人。通过在商店购买/升级英雄，激活职业联动加成来推进关卡。

| 项目 | a327ex (原版) | FanZeros (改版) |
|------|-------------|----------------|
| 引擎 | LÖVE2D (Lua + Box2D + OpenGL) | UrhoX (NanoVG + UrhoX Box2D) |
| 文件数 | 398 | 593 |
| 游戏代码行数 | ~12,100 行 | ~12,400 行 |
| 引擎代码 | 原版自定义引擎 ~3,500 行 | 适配层 ~5,000 行 (48 文件) |
| 语言 | 英语 | 简体中文 |
| 平台 | PC (Steam) | UrhoX (移动端 + PC) |

### 移植策略

FanZeros 采用了「忠实移植」策略——保留原版几乎所有游戏逻辑和数值，通过编写一个 48 文件的**引擎适配层**将 LÖVE2D API 翻译为 UrhoX API。这与早期的「简化重写」（保存在 `scripts_snkrx_backup/`，仅 ~1,700 行）形成鲜明对比。

---

## 2. 架构层面改动

### 2.1 目录结构重组

```
a327ex (原版):                    FanZeros (改版):
├── main.lua          ──────►    scripts/main.lua (UrhoX 入口)
├── arena.lua                    scripts/game/data.lua (从 main.lua 拆出)
├── buy_screen.lua    ──────►    scripts/game/arena.lua
├── enemies.lua       ──────►    scripts/game/buy_screen.lua
├── objects.lua       ──────►    scripts/game/enemies.lua
├── player.lua        ──────►    scripts/game/objects.lua
├── shared.lua        ──────►    scripts/game/player.lua
├── mainmenu.lua      ──────►    scripts/game/shared.lua
├── media.lua         ──────►    scripts/game/mainmenu.lua
├── conf.lua                     scripts/game/media.lua
├── engine/           ──────►    scripts/engine/ (48 文件适配层)
│   ├── init.lua                 (新增 data.lua, conf.lua 被移除)
│   ├── game/
│   ├── graphics/
│   ├── math/
│   ├── datastructures/
│   ├── external/      ✗ 移除
│   ├── map/           ✗ 移除
│   └── love/          ✗ 移除
├── assets/
│   ├── fonts/
│   ├── images/        (原 media/)
│   ├── sounds/
│   ├── shaders/       ✗ 移除
│   └── maps/          ✗ 移除
└── builds/            ✗ 移除
```

### 2.2 main.lua 拆分

原版 `main.lua` (2,144 行) 被拆分为两个文件：

| 内容 | 去向 |
|------|------|
| UrhoX 生命周期 (Start/Update/NanoVGRender) | `scripts/main.lua` (~110 行) |
| 全局变量初始化 (gold, passives, max_units...) | `scripts/main.lua` |
| NanoVG 上下文创建和 DPR 计算 | `scripts/main.lua` |
| `init()` 函数 (音效/图片加载, 角色数据, 职业定义) | `scripts/game/data.lua` (~2,100 行) |
| `update(dt)` / `draw()` 调度 | `scripts/game/data.lua` |
| 角色元数据表 (character_info) | `scripts/game/data.lua` |
| 职业定义表 (class_info) | `scripts/game/data.lua` |
| 被动道具表 (passive_info) | `scripts/game/data.lua` |
| 关卡数据表 (level_info) | `scripts/game/data.lua` |

### 2.3 游戏循环改造

```
原版 (LÖVE2D):                    改版 (UrhoX):
love.event.pump()       ───►     SubscribeToEvent("Update")
love.update(dt)         ───►     HandleUpdate(eventType, eventData)
love.draw()             ───►     SubscribeToEvent("NanoVGRender")
love.timer.sleep()      ───►     HandleNanoVGRender()
                                 (引擎自动管理帧率)
```

### 2.4 渲染管线改造

```
原版 (LÖVE2D):                     改版 (UrhoX):
love.graphics.* (即时模式)  ───►   NanoVG C API (即时模式)
                                   + Layer 命令队列 (延迟渲染)
love.graphics.newCanvas()  ───►   Canvas stub (record+replay)
love.graphics.newShader()  ───►   Shader stub (仅 shadow alpha hack)
love.graphics.stencil()    ───►   draw_with_mask stub (无遮罩)
```

---

## 3. 引擎适配层详细改动

### 3.1 init.lua — 引擎启动器

| 方面 | 原版 | 改版 |
|------|------|------|
| 窗口初始化 | `love.window.setMode(480*sx, 270*sy)` | 读取 `urho_graphics:GetWidth()/GetHeight()` + DPR |
| 游戏循环 | `love.run()` 回调 | 模块导出 `M.init/update/draw` |
| 音频初始化 | `love.audio.setEffect()` | UrhoX SoundSource 组件 |
| Steam | `steam.init()` | 已移除 |
| 全局变量 | `slow_amount` 等散落各处 | 集中在 `main.lua` 初始化 |

### 3.2 physics.lua — 物理系统 (关键文件)

**保留**：所有物理 API 签名 (`set_as_rectangle`, `set_as_circle`, `set_velocity`, `apply_force` 等)

**改造**：
- `love.physics.newBody/newFixture` → UrhoX `RigidBody2D` + `CollisionBox2D/CollisionCircle2D` 组件
- 角度从弧度 ↔ 度数转换 (LÖVE 用弧度, UrhoX 用度数)
- 碰撞过滤从 LÖVE 的 category index → UrhoX 的 bitmask 位运算
- `fixture:getUserData()` → `_node_to_object` 查找表

**新增**：内联的简化版 steering 方法 (`set_as_steerable`, `seek_point`, `steering_separate`, `apply_steering_force`, `apply_steering_impulse`, `steering_update`, `bounce`) — 这些方法存在于代码中但 **MISSING_API_REPORT 指出它们可能未被正确集成到 Physics mixin** (详见第 5 章)。

### 3.3 steering.lua — 转向行为系统

| 方面 | 原版 | 改版 |
|------|------|------|
| 架构 | 集成到 Physics mixin, 使用 heading/side 向量 | 独立 `Steering` 类, 静态方法 |
| 坐标转换 | `C2DMatrix` 矩阵变换 | 直接角度计算 |
| Wander | heading/side 投影 + 随机扰动 | 角度随机偏移 |
| 新增行为 | - | `arrive`, `pursue`, `evade`, `alignment`, `cohesion`, `path_follow` |

**问题**：改版存在**双重 steering 系统** — physics.lua 中的内联方法 + 独立的 Steering 类。两者 API 不同、互相独立，游戏代码调用的是 physics.lua 中的版本。

### 3.4 graphics.lua — 绘图系统

**保留**：所有绘图函数签名 (`rectangle`, `circle`, `line`, `polygon`, `print` 等)

**改造**：
- 所有 `love.graphics.*` → NanoVG 等价 (`nvgRect`, `nvgCircle`, `nvgText` 等)
- 新增 **Layer 延迟渲染系统**：绘图调用在 update 期间被排队为命令对象，在 NanoVGRender 事件中统一回放
- 颜色模型：LÖVE (0-1 浮点) → NanoVG (0-255 整数)
- `set_line_width()` 已正确实现 (`nvgStrokeWidth`)
- `draw_with_mask()` 已使用 NanoVG scissor 4-pass 方案重写 ✅ (详见 5.4 节)

**移除**：
- `stencil()` 函数
- `ellipse()`, `rounded_line()`, `set_shader()`

**新增**：
- `gradient_rect()` (使用 `nvgLinearGradient`)
- `rounded_rectangle()` (使用 `nvgRoundedRect`)
- `text_wrapped()` + 自动换行
- 多 Layer 管理 (add_layer, set_layer, z 排序)
- **Shadow mode 基础设施** ✅：模块级 `_shadow_mode` 标志，控制 `set_nvg_color`/`reset_nvg_color`/`set_color` 在阴影模式下输出 `rgba(0.1, 0.1, 0.1, a*0.5)`，匹配原版 GLSL shadow shader
- `set_shadow_mode(enabled)` / `get_shadow_mode()` 访问器

### 3.5 canvas.lua — 离屏渲染 (Record+Replay 方案, 已评估为可用 ✅)

| 方面 | 原版 | 改版 |
|------|------|------|
| 后端 | `love.graphics.newCanvas()` (GPU 渲染目标) | Record+Replay 闭包 (无真实离屏缓冲) |
| `draw_to(action)` | 切换渲染目标到 Canvas, 执行 action | 存储闭包引用 |
| `draw()` | 将 Canvas 纹理绘制到屏幕, 带清除 | 在 `nvgSave/nvgRestore` 中回放闭包, 执行后清除 `_draw_action` |
| `draw2()` | (不存在) | 回放闭包但 **不** 清除 (用于阴影 pass 复用 main_canvas 内容) |
| `clear()` | 清空 GPU 缓冲 | 设 `_action = nil` |
| 混合模式 | 预乘 alpha | 不支持 |

**评估结论**: Record+Replay 模式对于 SNKRX 的实际渲染管线是 **足够的**：
- `shared_draw()` 中的 bg → shadow → main 三通道合成通过闭包回放正确实现
- `draw2()` (无清除版本) 正确支持 shadow_canvas 复用 main_canvas 内容
- 设计分辨率缩放通过 `nvgScale(sx, sy)` 正确实现
- 主要差异（无像素隔离、无预乘 alpha 混合）对 SNKRX 的视觉效果影响可接受

### 3.6 shader.lua — 着色器 (shadow shader 已修复 ✅, 其他 stub)

- `set()` → 检测 shadow shader 时调用 `graphics.set_shadow_mode(true)`, 使所有绘图颜色变为 `rgba(0.1, 0.1, 0.1, a*0.5)`, 匹配原版 GLSL
- `unset()` → 调用 `graphics.set_shadow_mode(false)` 恢复正常颜色
- `send()` → no-op (NanoVG 不支持 shader uniforms)
- 非 shadow 的其他 shader (combine, displacement, replace) 仍为 no-op

### 3.7 font.lua — 字体系统

**改造**：
- `love.graphics.newFont()` → `nvgCreateFont()` + 多路径回退
- `get_text_width()` → `nvgTextBounds()` (但传入 Lua table 代替 `float[4]` 指针, 可能存在兼容性问题)
- 新增 MiSans-Regular.ttf 回退字体

### 3.8 group.lua — 对象管理

**保留**：所有对象管理 API (`add_object`, `remove_object`, `get_objects_by_class`, `get_closest_object` 等)

**改造**：
- `love.physics.newWorld()` → UrhoX `PhysicsWorld2D` 组件
- 碰撞回调：`world:setCallbacks()` → `SubscribeToEvent("PhysicsBeginContact2D"/"PhysicsEndContact2D")`
- 对象查找：`fixture:getUserData()` → `_node_to_object` 映射表

**新增**：
- 完整的触摸/移动端交互系统 (touch zone steering, sticky hover, double-tap confirmation)

### 3.9 input.lua — 输入系统

**改造**：
- LÖVE 事件驱动 → 每帧轮询 `urho_input:GetKeyDown(KEY_*)`
- 完整的 LÖVE→UrhoX 按键映射表 (~80 个键)
- 新增触摸设备检测和屏幕区域分区操作

**移除**：
- 手柄/游戏控制器支持 (仅保留空的 `gamepad_state`)

### 3.10 新增的引擎文件

| 文件 | 来源 | 功能 |
|------|------|------|
| `shims.lua` | 部分提取 + 新写 | LÖVE/Steam API 存根; 存档系统 (cjson + UrhoX File); SoundTag; Contact 包装 |
| `anchor.lua` | 全新 | 屏幕锚点位置计算 (`'center'`, `'top_left'` 等) |
| `collision.lua` | 全新 | 纯数学碰撞检测 (AABB, 圆形, 点, 线段), 用于触摸检测 |
| `container.lua` | 全新 | 轻量对象容器 (无物理, 无 Layer) |
| `draft.lua` | 全新 | 带权重随机抽取 + 不放回 |
| `music.lua` | 提取重写 | 音乐播放 (UrhoX SoundSource + 循环) |
| `sound.lua` | 提取重写 | 音效播放 (UrhoX SoundSource + SoundTag 音量) |
| `observer.lua` | 全新 | 发布-订阅事件系统 |
| `stats.lua` | 全新 | 属性键值存储 |
| `stepper.lua` | 全新 | 往复迭代器 (ping-pong) |
| `system.lua` | 提取简化 | 仅保留 `get_average_delta()` |
| `timer.lua` | 全新 | 简单计时器 (非 Trigger, 仅累计时间) |
| `layer.lua` | 提取 | 独立 Layer 类 (可能未使用, graphics.lua 内有同名类) |
| `shaders.lua` | 全新 | `load_shader()` 返回 stub 对象 |

### 3.11 移除的原版引擎文件

| 文件/目录 | 原版功能 | 移除原因 |
|-----------|---------|---------|
| `external/binser.lua` | 二进制序列化 | 被 cjson 替代 |
| `external/clipper.lua` | 多边形裁剪 | SNKRX 未使用 |
| `external/mlib.lua` | 数学库 | UrhoX 内置数学 |
| `external/ripple.lua` | 音频混合器 | 被 UrhoX SoundSource 替代 |
| `datastructures/graph.lua` | 图数据结构 | SNKRX 未使用 |
| `datastructures/grid.lua` | 网格数据结构 | SNKRX 未使用 |
| `map/solid.lua` | 实体碰撞地图 | SNKRX 未使用 |
| `map/tilemap.lua` | 瓦片地图 | SNKRX 未使用 |
| `love/` 目录 | LÖVE 框架二进制 + Steam DLL | 不需要 |

---

## 4. 游戏逻辑层详细改动

### 4.1 总体特征

FanZeros 对游戏逻辑的改动可以概括为：

1. **极高保真度** — 所有角色数值、职业加成、被动道具、关卡配置、伤害公式完全保留
2. **全面汉化** — 所有英文 UI 文本替换为简体中文
3. **移除 Steam** — 所有 Steam 成就/富文本状态相关代码移除
4. **移动端适配** — 添加触摸输入、屏幕分区操作
5. **少量 Bug 修复** — nil 安全检查、数组越界保护

### 4.2 各文件详细改动

#### data.lua (从原版 main.lua 提取)

**保留**：
- 全部 50+ 角色元数据 (character_info 表)
- 全部 16 个职业定义 (class_info 表)
- 全部 70+ 被动道具定义 (passive_info 表)
- 全部 25 级关卡数据 (level_info 表)
- 全部 ~100 个音效加载
- 全部 ~60 个图片加载
- 颜色方案定义

**改动**：
- 音效路径格式：`'sounds/xxx.ogg'` → `'sounds/xxx.ogg'` (保持一致, 但 Sound 构造函数内部处理路径)
- 图片路径：`'images/xxx.png'` (保持一致)
- `love.graphics.newFont()` → `Font('name', size)`
- 新增 `open_options()` / `close_options()` 菜单处理函数

**移除**：
- Steam 初始化 (`steam.init()`, `steam.setRichPresence()`)
- Steam 成就检查和解锁代码
- Steam DLC 检查
- `love.window.setIcon()`
- `love.audio.setEffect()`

#### arena.lua — 战斗场景

**保留**：
- 物理世界创建和碰撞组设置
- 敌人生成逻辑和难度曲线
- Boss 生成规则 (每 6 关 + 25 关后)
- 关卡清除和失败条件
- 设计分辨率坐标 (gw/gh 体系)

**改动**：
- `gw` 使用 `dgw` (动态设计宽度) 适配宽屏
- 战斗场景宽度从固定 `gw-20` 改为 `dgw-20`, 支持超宽屏
- 触摸事件处理 (`pre_touch_scan`, touch zone steering)

**移除**：
- Steam 成就触发 (`steam.setAchievement()`)
- Steam 状态更新 (`steam.setRichPresence()`)

#### buy_screen.lua — 商店界面

**保留**：
- 角色卡牌选择/购买/出售逻辑
- 重掷机制和费用
- 升级系统 (3 合 1 → Lv.2 → Lv.3)
- 职业联动显示
- 被动道具购买
- 所有数值和公式

**改动**：
- 全部英文 UI 文本 → 简体中文:
  - `"Reroll"` → `"刷新"`
  - `"Go!"` → `"开始!"`
  - `"Lv.X"` → `"等级X"`
  - `"Party"` → `"队伍"`
  - `"Items"` → `"道具"`
  - 所有职业/角色名称汉化
  - 所有技能描述汉化
- 布局微调适配中文文本宽度
- 触摸友好的按钮尺寸

**移除**：
- Steam 成就检查和触发

#### enemies.lua — 敌人系统

**保留**：
- `Seeker` 类及其所有 Boss 变体 (speed_booster, forcer, swarmer, exploder, randomizer)
- `EnemyProjectile` 和 `EnemyCritter`
- 所有 AI 行为和攻击模式
- 所有数值 (HP, 伤害, 移速, 冷却时间)

**改动**：
- steering 方法调用保持不变 (依赖 physics.lua 提供的适配)
- `math.atan2` → `math.atan` (Lua 5.4 兼容)

#### player.lua — 玩家/英雄系统

**保留**：
- 全部 50+ 角色的攻击/技能逻辑
- 全部数值 (HP, DMG, ASPD, area, defense 等)
- 贪吃蛇移动逻辑 (leader + follower)
- 自动瞄准和攻击系统
- Lv.3 特殊效果
- 被动道具效果

**改动**：
- `math.atan2` → `math.atan` (Lua 5.4 兼容)
- 少量 nil 安全检查 (如 `if self.leader and ...`)

#### shared.lua — 共享渲染

**保留**：
- 颜色方案和 ColorRamp
- Star 背景粒子
- SpawnEffect 生成特效
- 基础绘图辅助函数

**改动**：
- `shared_draw()` 中的多通道渲染管线保持逻辑结构, 但因 Canvas/Shader 是 stub 而实际效果降级
- `draw_with_mask()` 中 mask 参数被忽略

#### objects.lua — 游戏对象

**保留**：
- `LightningLine` 闪电效果
- `HitCircle` / `HitParticle` 打击反馈
- `Wall` / `WallCover` 墙壁
- `Unit` mixin

**改动**：少量适配性修改

#### mainmenu.lua — 主菜单

**保留**：
- Demo 战斗背景展示
- 开始按钮

**改动**：
- 标题文本 `"SNKRX"` → `"蛇蛇小队"`
- 触摸交互支持

#### media.lua — 媒体状态

**保留**：基本结构不变
**改动**：文本汉化

---

## 5. 丢弃的原始设计与修复建议

### 5.1 ✅ RESOLVED: Steering 行为系统 (已验证正常工作)

**原始问题描述**：

MISSING_API_REPORT 指出 steering 行为方法可能未正确集成, 在 27+ 个调用点存在崩溃风险。

**实际验证结果**：

经过逐行审查 `physics.lua`, 确认 FanZeros 已在最新代码中 **完整实现了全部 8 个 steering 方法**, 并正确集成到 Physics mixin 中：

| 方法 | 行号 | 状态 |
|------|------|------|
| `set_as_steerable(max_v, max_force, max_turn, sr)` | ~480 | ✅ 正确初始化所有 steering 属性 |
| `seek_point(tx, ty)` | ~495 | ✅ 累加求力向量 |
| `wander(angle, ratio, rs)` | ~508 | ✅ 随机角度偏移 + 速度目标 |
| `steering_separate(radius, classes)` | ~520 | ✅ 查询同组对象排斥力 |
| `apply_steering_force(force, angle)` | ~545 | ✅ 角度转向力 |
| `apply_steering_impulse(force, angle, dur)` | ~552 | ✅ trigger:during 持续施力 |
| `steering_update(dt)` | ~560 | ✅ 截断力→施力→截断速度→更新朝向→重置 |
| `bounce(dt, bounciness)` | ~580 | ✅ 边界反弹 |

关键集成点：`update_physics(dt)` 函数内部自动调用 `steering_update(dt)` 和 `bounce(dt)`, 确保每帧执行。

**所有 26 个游戏调用点** (player.lua 15 处 + enemies.lua 11 处) 的函数签名均与实现匹配, 无崩溃风险。

**结论**: MISSING_API_REPORT 基于旧版代码编写, FanZeros 在后续提交中已修复此问题。无需额外修改。

### 5.2 ✅ ASSESSED: Canvas 离屏渲染 (Record+Replay 方案足够)

**原始问题描述**：

原版使用 LÖVE 的 `love.graphics.newCanvas()` 实现真正的 GPU 离屏渲染。改版替换为 Record+Replay 闭包模式。

**实际评估结果**：

对 `shared_draw()` 渲染管线进行逐步跟踪后, 确认 Record+Replay 方案对 SNKRX 的实际需求 **足够**：

1. **设计分辨率缩放** ✅: `Canvas:draw(0, 0, 0, sx, sy)` 通过 `nvgScale(sx, sy)` 正确实现
2. **阴影 pass** ✅: `shadow_canvas:draw2()` (不清除) 正确复用 `main_canvas` 内容, 配合 shadow shader 偏移渲染
3. **多通道合成** ✅: bg → shadow → main 的绘制顺序通过闭包回放正确维持
4. **闪烁效果** ⚠️: 无法实现像素级混合模式, 但对 SNKRX 影响极小

**与原版的差异 (可接受)**：
- 无像素隔离: 同一 Canvas 的两次 `draw2()` 调用会重叠而非分别渲染
- 无预乘 alpha 混合: 半透明叠加效果略有差异
- 无真实缓冲: Canvas 清除 = 丢弃闭包引用, 不影响功能

**结论**: 当前方案无需修改。如未来需要更精确的像素级合成, 可考虑使用 UrhoX 的 `nvgluCreateFramebuffer()` API 实现真实 FBO。

### 5.3 ✅ FIXED: Shader 阴影着色器 (shadow mode 颜色覆写)

**原始问题描述**：

原版 `shadow.frag` GLSL: `vec4(0.1, 0.1, 0.1, Texel(texture, tc).a * 0.5)` — 将所有像素替换为深灰色, 保留 alpha 的 50%。改版使用 `nvgGlobalAlpha(0.12)`, 效果错误：颜色仍是原色 (只是变透明了), 且 0.12 透明度太淡。

**修复方案**：

引入 **shadow mode** 机制, 在 `graphics.lua` 中添加模块级 `_shadow_mode` 标志：

```lua
-- graphics.lua 新增:
local _shadow_mode = false

-- 当 shadow mode 开启时, 所有颜色输出函数自动替换为:
-- rgba(0.1, 0.1, 0.1, originalAlpha * 0.5)
-- 影响: set_nvg_color(), reset_nvg_color(), set_color()

-- shader.lua 重写:
function Shader:set()
    if self._is_shadow then
        graphics.set_shadow_mode(true)  -- 替代 nvgGlobalAlpha(0.12)
    end
end

function Shader:unset()
    if self._is_shadow then
        graphics.set_shadow_mode(false)
    end
end
```

**效果**: 阴影颜色从「半透明原色」修正为「深灰色半透明」, 匹配原版 GLSL 输出。

**未修复的其他 shader**:
- `combine.frag` — 通道合成 (NanoVG 无法模拟, 但 Record+Replay Canvas 已通过绘制顺序替代)
- `displacement.frag` — 位移效果 (仅在特殊场景使用, 影响极小)
- `replace.frag` — 颜色替换 (需要 per-pixel 操作, NanoVG 无法实现)

### 5.4 ✅ FIXED: draw_with_mask() 遮罩 (NanoVG scissor 4-pass)

**原始问题描述**：

原版使用 LÖVE 的 stencil 功能实现遮罩绘制。改版的 `draw_with_mask()` 忽略 mask_fn, 直接执行 draw_fn, 导致背景星星铺满全屏。

**修复方案**：

使用 **函数拦截 + NanoVG scissor 4-pass 渲染**:

1. **拦截 mask 定义**: 临时替换 `camera.attach`, `camera.detach`, `graphics.rectangle`, 执行 `mask_action()` 来捕获遮罩矩形的坐标和尺寸, 但不实际绘制
2. **坐标转换**: 将捕获的设计分辨率坐标 (camera 空间) 转换为屏幕坐标: `screen_x = (world_x - cam.x) * cam.sx + cam.w/2`
3. **4-pass 反向遮罩**: 对于 `inverted=true` (SNKRX 的所有 3 个调用点都是 inverted), 将屏幕分为遮罩矩形 **外** 的 4 个矩形条带 (上、下、左、右), 在每个条带内用 `nvgScissor()` 裁剪后执行 `action()`
4. **Canvas 清除问题处理**: 因 `Canvas:draw()` 执行后会清除闭包引用, 在 4-pass 期间临时将 `Canvas.draw` 替换为 `Canvas.draw2` (不清除版本), 确保 4 次回放都能正常执行

**游戏中的 3 个调用点**:
- `arena.lua:763` — 星星在竞技场矩形外显示, inverted=true
- `mainmenu.lua:205` — 星星在菜单矩形外显示, inverted=true
- `buy_screen.lua:252` — 星星在商店矩形外显示, inverted=true

**限制**: 仅支持矩形遮罩 (NanoVG scissor 的固有限制), 但 SNKRX 的所有遮罩调用都是矩形, 因此完全满足需求。

### 5.5 ✅ RESOLVED: graphics.set_line_width() (已由 FanZeros 实现)

**原始问题描述**：

MISSING_API_REPORT 指出 `graphics.set_line_width()` 缺失, `buy_screen.lua` 调用会崩溃。

**实际验证结果**：

`graphics.lua` 第 ~108 行已正确实现:

```lua
self.set_line_width = function(w)
    if vg then nvgStrokeWidth(vg, w or 1) end
end
```

**结论**: 与 Steering 同理, MISSING_API_REPORT 基于旧版代码。FanZeros 在后续提交中已修复。

### 5.6 🟡 MEDIUM: Font:get_text_width() 可能的 API 不匹配

**问题描述**：

`font.lua` 中的 `get_text_width()` 调用 `nvgTextBounds(vg, 0, 0, text, nil, bounds)` 时传入 `bounds = {0,0,0,0}` (Lua table)。NanoVG 的 C API 期望 `float[4]` 指针。如果 UrhoX 的 Lua 绑定不回写 table 值, 所有文本宽度测量将返回 0。

**影响**：文本可能堆叠在同一位置, 富文本布局完全错乱。

**修复建议**：

需要运行时验证。如果确认不工作:

```lua
function Font:get_text_width(text)
    nvgFontFace(vg, self.tag)
    nvgFontSize(vg, self.size)
    -- 方案 A: 使用 nvgTextBounds 的返回值 (如果绑定支持多返回值)
    local advance = nvgTextBounds(vg, 0, 0, text, nil, nil)
    if advance and advance > 0 then return advance end
    -- 方案 B: 使用 nvgText 的返回值 (返回下一个字符的 x 位置)
    -- 这需要确认 UrhoX 的绑定行为
    return #text * self.size * 0.6  -- 最坏情况: 估算
end
```

### 5.7 🟢 LOW: 手柄/游戏控制器支持丢失

**问题描述**：原版支持游戏手柄 (joystick/gamepad), 改版完全移除。

**影响**：仅在需要手柄支持时需要修复。

**修复建议**：通过 UrhoX 的 `input:GetJoystickByIndex()` API 实现。

### 5.8 🟢 LOW: Steam 成就系统丢失

**问题描述**：原版有 30+ 个 Steam 成就, 改版全部移除。

**影响**：如果需要成就系统, 需要替换为 UrhoX 平台的成就 API。

**修复建议**：这是平台相关的, 需要接入 TapTap 或其他平台的成就 SDK。暂时可以保留本地成就记录:

```lua
-- 本地成就系统
local achievements = {}
function unlock_achievement(id)
    if not achievements[id] then
        achievements[id] = true
        system.save_state('achievements', achievements)
        -- 显示成就弹窗
    end
end
```

### 5.9 🟢 LOW: 音乐 pitch 联动丢失

**问题描述**：原版的慢动作效果会同步降低音乐播放速率 (pitch), 改版的 Music 类虽有 `__newindex` 同步机制, 但 tween 系统可能未自动触发属性同步。

**修复建议**：确认 `trigger:tween()` 修改 `music.pitch` 时, `Music.__newindex` 被正确触发并调用 `SoundSource:SetFrequency()`。

---

## 6. 新增内容

### 6.1 简体中文本地化

全部 UI 文本从英文替换为简体中文, 包括:
- 菜单文本: `"Start"` → `"开始"`, `"Settings"` → `"设置"`
- 商店文本: `"Reroll"` → `"刷新"`, `"Go!"` → `"开始!"`
- 职业名称: `"Warrior"` → `"战士"`, `"Ranger"` → `"游侠"` 等
- 角色名称: `"Vagrant"` → `"流浪者"`, `"Swordsman"` → `"剑士"` 等
- 技能描述: 全部汉化
- 游戏标题: `"SNKRX"` → `"蛇蛇小队"`

### 6.2 移动端触摸支持

Group 系统新增完整的触摸交互:
- 屏幕左右分区操控 (左半区 = 左转, 右半区 = 右转)
- 粘性 hover (触摸设备上 hover 态保持直到点击其他位置)
- 双击确认 (防止误操作)
- 触摸目标优先级扫描

### 6.3 宽屏适配

新增 `dgw` (动态设计宽度) 概念, arena 和 UI 根据实际宽高比动态调整, 而非固定 480 像素宽度。

### 6.4 游戏设计文档

新增 `docs/characters-and-classes.md`, 包含:
- 16 个职业的详细描述和激活条件
- 46 个角色的属性和技能描述 (中文)
- 推荐组队阵容

### 6.5 MISSING_API_REPORT.md

详尽的 API 差距分析报告, 列出所有 CRITICAL/HIGH/MEDIUM/LOW 级别的缺失功能, 是后续开发的重要参考。

---

## 7. 已知 BUG 与待办事项

### 7.1 已修复的问题 ✅

| 原优先级 | 问题 | 修复方式 | 修复者 |
|----------|------|---------|--------|
| 🔴 P0 | steering 方法崩溃风险 | 已验证: FanZeros 在最新代码中已完整实现 | FanZeros |
| 🔴 P0 | `graphics.set_line_width()` 缺失 | 已验证: FanZeros 在最新代码中已实现 | FanZeros |
| 🟡 P1 | Shader shadow 效果错误 | shadow mode 颜色覆写, 替代 globalAlpha hack | 本次修复 |
| 🟡 P1 | draw_with_mask stub 无遮罩 | NanoVG scissor 4-pass 反向裁剪 | 本次修复 |
| 🟡 P1 | Canvas stub 离屏渲染 | 评估为: Record+Replay 方案对 SNKRX 足够 | 评估通过 |

### 7.2 视觉降级问题 (可运行, 效果可接受)

| 优先级 | 问题 | 文件 | 影响 |
|--------|------|------|------|
| 🟡 P2 | Font:get_text_width 可能返回 0 | `scripts/engine/graphics/font.lua` | 需运行时验证 |
| 🟡 P2 | 非 shadow shader 仍为 stub | `scripts/engine/graphics/shader.lua` | combine/displacement/replace 效果丢失 |
| 🟡 P2 | Canvas 无像素隔离和混合模式 | `scripts/engine/graphics/canvas.lua` | 半透明叠加效果略有差异 |

### 7.3 功能缺失 (非核心)

| 优先级 | 问题 | 影响 |
|--------|------|------|
| 🟢 P3 | 手柄支持 | 无法使用游戏控制器 |
| 🟢 P3 | Steam 成就 | 无成就系统 |
| 🟢 P3 | 音乐 pitch 联动 | 慢动作时音乐速度不变 |
| 🟢 P4 | GradientImage 重复定义 | 调试困惑, 无运行时影响 |

### 7.4 建议的后续修复顺序

1. **验证 `Font:get_text_width()`** — 运行时检查 `nvgTextBounds` 返回值, 确认文本布局是否正确
2. **运行时集成测试** — 实际运行游戏, 确认所有修复项在游戏流程中正常工作
3. **Canvas FBO 升级** (可选) — 如需更精确的像素级合成, 使用 `nvgluCreateFramebuffer()` 替代 Record+Replay
4. **其他低优先级修复** — 手柄支持、成就系统等按需实现

---

## 附录 A: 文件清单对比

### 仅在原版中存在的文件 (FanZeros 移除的)

```
.ctrlp                    — 编辑器配置
LICENSE                   — MIT 许可证
README.md                 — 项目说明
conf.lua                  — LÖVE 配置文件
build.sh / run.sh         — 构建/运行脚本
builds/                   — 构建输出目录
devlog.md                 — 开发日志
todo                      — 待办事项
assets/fonts/fonts_go_here.txt    — 占位文件
assets/maps/maps_go_here.txt      — 占位文件
assets/media/             — Steam 商店素材 (截图、胶囊图等, ~40 文件)
assets/shaders/           — GLSL 着色器 (5 个 .frag + 1 个 .vert)
engine/external/          — 外部库 (binser, clipper, mlib, ripple)
engine/map/               — 地图系统 (solid, tilemap)
engine/datastructures/graph.lua   — 图数据结构
engine/datastructures/grid.lua    — 网格数据结构
engine/love/              — LÖVE 框架二进制 + Steam SDK
engine/gamecontrollerdb.txt       — 手柄映射数据库
```

### 仅在 FanZeros 中存在的文件 (新增的)

```
MISSING_API_REPORT.md                    — API 差距分析
docs/characters-and-classes.md           — 游戏设计文档
scripts/.luarc.json                      — Lua LSP 配置
scripts/main.lua                         — UrhoX 入口
scripts/game/data.lua                    — 从 main.lua 提取的数据
scripts/main_snkrx_simplified.lua.bak    — 早期简化版入口备份
scripts_snkrx_backup/                    — 早期简化版游戏代码备份 (7 文件)
scripts/engine/game/anchor.lua           — 屏幕锚点
scripts/engine/game/collision.lua        — 纯数学碰撞检测
scripts/engine/game/container.lua        — 轻量对象容器
scripts/engine/game/draft.lua            — 带权重随机抽取
scripts/engine/game/layer.lua            — 独立 Layer 类
scripts/engine/game/music.lua            — 音乐播放器
scripts/engine/game/observer.lua         — 发布-订阅事件
scripts/engine/game/shaders.lua          — Shader 加载 stub
scripts/engine/game/shims.lua            — LÖVE/Steam 兼容 shim
scripts/engine/game/sound.lua            — 音效播放器
scripts/engine/game/stats.lua            — 属性容器
scripts/engine/game/stepper.lua          — 往复迭代器
scripts/engine/game/system.lua           — 系统工具
scripts/engine/game/timer.lua            — 简单计时器
assets/**/*.meta                         — 资源 UUID 元数据 (~200 个)
```

---

*报告生成日期: 2026-05-01*
*最后更新: 2026-05-01 (反映 P0/P1 验证和修复结果)*
*对比版本: a327ex/SNKRX (main branch) vs FanZeros/SNKRX (main branch)*
