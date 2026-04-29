# SNKRX 源码分析与 UrhoX 移植设计

> **源仓库**: https://github.com/a327ex/SNKRX
> **原引擎**: LÖVE2D 11.3 + 自研框架
> **目标引擎**: UrhoX (NanoVG 2D 渲染 + Physics2D)
> **文档版本**: v1.0
> **日期**: 2026-04-29

---

## 目录

- [第一部分：SNKRX 源码分析](#第一部分snkrx-源码分析)
  - [1. 项目概览](#1-项目概览)
  - [2. 文件结构与代码量](#2-文件结构与代码量)
  - [3. 引擎架构](#3-引擎架构)
  - [4. 核心游戏机制](#4-核心游戏机制)
  - [5. 关键设计模式](#5-关键设计模式)
- [第二部分：UrhoX 移植设计](#第二部分urhox-移植设计)
  - [6. 移植总体策略](#6-移植总体策略)
  - [7. 底层模块映射表](#7-底层模块映射表)
  - [8. 各模块详细移植方案](#8-各模块详细移植方案)
  - [9. 模块依赖关系与移植顺序](#9-模块依赖关系与移植顺序)
  - [10. 风险评估与注意事项](#10-风险评估与注意事项)

---

# 第一部分：SNKRX 源码分析

## 1. 项目概览

| 项目 | 说明 |
|------|------|
| **游戏类型** | Roguelike 自走蛇 (Auto-battler + Snake) |
| **核心玩法** | 蛇身节点=英雄角色，自动攻击敌人；波次间进商店购买/升级角色 |
| **引擎** | LÖVE2D 11.3 + 完全自研框架 |
| **语言** | Lua（LÖVE2D 使用 LuaJIT） |
| **设计分辨率** | 480×270 逻辑分辨率，2x 缩放至 960×540 窗口 |
| **渲染方式** | 纯几何图形（矩形、圆、线条），无 Sprite/贴图 |
| **物理** | Box2D（通过 LÖVE2D 的 love.physics） |
| **许可** | MIT |

### 游戏循环

```
主菜单 → 战斗(Arena) ←→ 商店(BuyScreen) → 胜利/失败 → 主菜单
                ↑                    |
                |   每3波结束进商店    |
                +--------------------+
```

---

## 2. 文件结构与代码量

### 游戏层（~12,000 行）

| 文件 | 行数 | 职责 |
|------|------|------|
| `player.lua` | 4,000 | 蛇体控制、55 个角色能力、投射物、AOE、召唤物 |
| `main.lua` | 2,144 | 入口、全局数据表（角色/职业/天赋/关卡配置） |
| `buy_screen.lua` | 2,082 | 商店场景（购买/升级/重掷/被动天赋） |
| `arena.lua` | 1,213 | 战斗场景（波次生成、碰撞配置、胜负判定） |
| `enemies.lua` | 1,103 | 敌人类型（Seeker/Critter/Boss/精英变体） |
| `shared.lua` | 878 | 渲染管线、颜色系统、视觉特效、UI 组件、物理墙 |
| `objects.lua` | 446 | Unit mixin、SpawnMarker、LightningLine、HPBar |
| `mainmenu.lua` | 213 | 主菜单 |
| `media.lua` | 35 | 资源预加载 |
| `conf.lua` | 7 | LÖVE 窗口配置 |

### 引擎层（~3,000 行）

```
engine/
├── init.lua              # 引擎启动、固定时间步循环
├── system.lua            # 状态持久化（save/load）
├── sound.lua             # 音频封装
├── game/
│   ├── object.lua        # OOP 基类（extend/implement/is）
│   ├── gameobject.lua    # 实体 mixin（定时器/弹簧/物理同步）
│   ├── group.lua         # 对象容器 + 空间哈希碰撞
│   ├── physics.lua       # Box2D 封装 + 碰撞标签
│   ├── steering.lua      # 转向行为 AI
│   ├── trigger.lua       # 定时器/Tween/Cooldown 系统
│   ├── springs.lua       # 弹簧集合管理
│   ├── hitfx.lua         # 受击闪烁特效
│   ├── flashes.lua       # 屏闪特效
│   ├── input.lua         # 输入封装
│   ├── state.lua         # 状态机（场景切换）
│   └── parent.lua        # 父子跟随
├── graphics/
│   ├── graphics.lua      # 绘图 API（矩形/圆/线/多边形）
│   ├── camera.lua        # 2D 相机（平移/缩放/震屏）
│   ├── canvas.lua        # 离屏渲染目标（RenderTarget）
│   ├── color.lua         # 颜色 + ColorRamp
│   ├── font.lua          # 字体
│   ├── image.lua         # 图片
│   ├── shader.lua        # 着色器
│   └── text.lua          # 富文本渲染
├── math/
│   ├── math.lua          # 数学工具（lerp/clamp/distance 等）
│   ├── vector.lua        # 2D 向量
│   ├── spring.lua        # 弹簧物理（阻尼谐振）
│   ├── chain.lua         # 链/多边形碰撞
│   ├── circle.lua        # 圆形碰撞
│   ├── line.lua          # 线段碰撞
│   ├── polygon.lua       # 多边形碰撞
│   ├── rectangle.lua     # 矩形碰撞
│   ├── triangle.lua      # 三角形碰撞
│   └── random.lua        # 随机数生成器
└── datastructures/
    ├── table.lua         # table 扩展（shuffle/flatten/delete 等）
    ├── string.lua        # string 扩展
    ├── graph.lua         # 图结构
    └── grid.lua          # 网格结构
```

---

## 3. 引擎架构

### 3.1 OOP 系统 — 原型继承 + Mixin

SNKRX 的 OOP 核心仅 ~50 行代码，实现了三个关键能力：

```lua
-- 继承：创建子类
Player = Object:extend()

-- Mixin：混入功能模块（类似组件）
Player:implement(GameObject)  -- 生命周期 + 定时器 + 弹簧
Player:implement(Physics)     -- Box2D 物理体 + 转向行为
Player:implement(Unit)        -- RPG 属性计算

-- 类型检查
if obj:is(Player) then ... end
```

**工作原理**：
- `extend()` — 通过 `setmetatable` 建立原型链，子类共享父类方法
- `implement()` — 将 mixin 类的所有方法**浅复制**到目标类，仅当目标类没有同名方法时
- `__call` — 类自身作为构造函数：`Player{x=100, y=200}` 等价于 `Player:init({x=100, y=200})`

**关键设计**：参数通过 key-value 表传递，`init_game_object` 中用 `for k,v in pairs(args)` 将所有参数直接赋值为对象属性。

### 3.2 GameObject — 实体生命周期

每个游戏对象通过 `implement(GameObject)` 获得：

| 组件 | 作用 |
|------|------|
| `self.t` (Trigger) | 定时器系统（after/every/tween/cooldown/during） |
| `self.spring` (Spring) | 缩放弹簧（用于打击感动画） |
| `self.springs` (Springs) | 弹簧集合 |
| `self.hfx` (HitFX) | 受击闪烁效果 |
| `self.flashes` (Flashes) | 屏闪效果 |
| `self.id` | 唯一标识符 |

生命周期：
```
init_game_object(args) → 参数赋值 + 组件创建 + 加入 group
update_game_object(dt) → 更新定时器/弹簧/特效 + 物理同步 + 鼠标交互
dead = true            → group 在下一帧将其移除并调用 destroy()
```

### 3.3 Group — 对象容器 + 空间哈希

Group 是 SNKRX 的核心管理器，职责：

1. **对象生命周期管理**：add / remove（标记 dead） / destroy
2. **按类查询**：`get_objects_by_class(Player)` — 内部维护 `by_class` 索引
3. **空间哈希碰撞**：`get_objects_in_shape(shape, types)` — 64px 网格的空间哈希加速
4. **物理世界宿主**：`set_as_physics_world(meter, gx, gy, tags)` — 创建 Box2D world
5. **碰撞标签系统**：`enable/disable_collision_between(tag1, tag2)` — 基于 category/mask
6. **绘制排序**：`sort_by_y()` — 2.5D 深度排序
7. **相机绑定**：绘制时自动 attach/detach 相机变换

典型用法（分层渲染）：
```lua
function Arena:on_enter()
  self.floor   = Group()                                    -- 地面层
  self.main    = Group():set_as_physics_world(32, 0, 0,     -- 游戏层（含物理）
    {'player', 'enemy', 'projectile', 'enemy_projectile', 'force_field', 'ghost'})
  self.effects = Group()                                    -- 特效层
  self.ui      = Group():no_camera()                        -- UI 层（不跟随相机）
end
```

### 3.4 Trigger — 定时器/Tween 系统

这是 SNKRX 最重要的系统之一，替代了传统状态机：

| 方法 | 作用 | 示例 |
|------|------|------|
| `after(delay, fn)` | 延迟执行 | `self.t:after(2, function() self.dead = true end)` |
| `every(delay, fn, times)` | 周期执行 | `self.t:every(2, function() self:shoot() end)` |
| `cooldown(delay, cond, fn)` | 条件冷却 | `self.t:cooldown(2, hasEnemies, attack)` |
| `tween(dur, target, goal, easing)` | 属性动画 | `self.t:tween(0.2, self, {sx=0}, math.linear)` |
| `during(dur, fn)` | 持续执行 | `self.t:during(1, function() self:glow() end)` |
| `cancel(tag)` | 取消 | `self.t:cancel('shoot')` |
| `set_every_multiplier(tag, m)` | 动态调速 | 攻速 buff 时动态改变 every 间隔 |

**关键特性**：
- 支持随机延迟：`every({2, 4}, fn)` → delay 随机取 2~4 秒
- 支持条件触发：`after(function() return self.ready end, fn)`
- 支持 tag 去重：同 tag 新注册自动取消旧的
- 所有角色能力都用 cooldown + every 实现，而非手写状态机

### 3.5 Spring — 弹簧动画

弹簧是 SNKRX "打击感" 的核心：

```lua
-- 阻尼谐振模型
Spring = { x, target_x, v, k(刚度), d(阻尼) }

update(dt):
  a = -k * (x - target_x) - d * v   -- 胡克定律 + 阻尼
  v = v + a * dt
  x = x + v * dt

-- 用法：拉伸后回弹
self.spring:pull(0.5)  -- 瞬间拉伸 0.5
-- 之后自动回弹到 target_x=1，产生弹性缩放效果

-- 绘制时应用：
graphics.push(self.x, self.y, self.r, self.spring.x, self.spring.x)
  -- 绘制内容（会被弹簧缩放）
graphics.pop()
```

### 3.6 Physics — Box2D 封装

SNKRX 的物理层封装了 LÖVE2D 的 Box2D 绑定：

| 方法 | 作用 |
|------|------|
| `set_as_rectangle(w, h, bodyType, tag)` | 创建矩形物理体 |
| `set_as_circle(rs, bodyType, tag)` | 创建圆形物理体 |
| `set_as_chain(loop, vertices, bodyType, tag)` | 创建链/多边形物理体 |
| `set_as_steerable(max_v, max_f)` | 启用转向行为 |
| `seek_point(x, y)` | 转向行为：追踪点 |
| `wander(rs, dist, jitter)` | 转向行为：漫游 |
| `steering_separate(rs, classes)` | 转向行为：分离 |
| `apply_steering_force(f, r, s)` | 施加转向力 |

**碰撞标签系统**：
- 每个 tag 对应一个 Box2D category bit
- `disable_collision_between` 设置 mask 排除
- `enable_trigger_between` 为穿透碰撞启用 sensor

### 3.7 Steering — 转向行为 AI

基于 《Programming Game AI by Example》 第3章实现，包括：

- **seek** — 追踪目标（含减速到达）
- **wander** — 投影圆上随机点漫游
- **separate** — 与同类保持距离
- 所有力通过 `calculate_steering_force` 合成，截断到 `max_f`
- 辅助工具：C2DMatrix（2D 变换矩阵），用于世界/局部坐标转换

### 3.8 渲染管线

```
┌──────────────────┐
│ background_canvas │ ← 棋盘格背景 + 渐变
├──────────────────┤
│ shadow_canvas     │ ← main_canvas 偏移 + shadow_shader
├──────────────────┤
│ main_canvas       │ ← 所有游戏对象 + 屏闪
├──────────────────┤
│ star_canvas       │ ← 背景星星粒子
└──────────────────┘

绘制顺序：background → shadow(偏移1.5px) → main → star（叠加）
```

所有游戏对象用**几何图形**绘制（矩形、圆、线条），只有少量 UI 图标使用贴图。

---

## 4. 核心游戏机制

### 4.1 蛇体移动

蛇体由 **Leader（蛇头）** + **Followers（蛇身）** 组成：

```
Leader (Player, leader=true)
  ├── Box2D 圆形刚体
  ├── 恒速前进（self.v 方向移动）
  ├── 左右键 → 改变角速度（angular velocity）
  └── followers[] → 蛇身节点数组

每个 Follower:
  ├── 也是 Player 对象，但 leader=false
  ├── 在 update 中追随前一个节点
  ├── 保持固定间距（通过 seek_point）
  └── 攻击范围检测独立运作
```

蛇身跟随通过 **seek_point 转向行为** 实现：每个节点追踪前一个节点的历史位置。

### 4.2 角色能力系统

所有 55 个角色的能力都在 `player.lua` 的 `Player:init` 中用 **巨型 if-elseif 链** 实现：

```lua
if self.character == 'vagrant' then
  -- 攻击传感器 + cooldown 自动射击
  self.attack_sensor = Circle(self.x, self.y, 96)
  self.t:cooldown(2, hasEnemies, function()
    self:shoot(self:angle_to_object(closest_enemy))
  end)

elseif self.character == 'swordsman' then
  -- 近战挥砍
  self.attack_sensor = Circle(self.x, self.y, 48)
  self.t:cooldown(3, hasEnemies, function()
    self:attack(96)  -- 96 像素范围的扇形挥砍
  end)

elseif self.character == 'wizard' then
  -- 远程魔法 + 链式闪电
  ...
end
```

**攻击模式分类**：

| 模式 | 方法 | 角色举例 |
|------|------|---------|
| 远程射击 | `self:shoot(angle, opts)` | Vagrant, Archer, Wizard |
| 近战挥砍 | `self:attack(range, opts)` | Swordsman, Blade |
| 定时施法 | `self.t:every(delay, cast)` | Gambler, Cleric |
| 被动触发 | 条件检测 | Squire, Chronomancer |
| 召唤物 | 创建独立实体 | Engineer(Turret), Beastmaster(Pet) |

### 4.3 职业协同系统

**数据结构**（在 `main.lua` 中定义）：

```
16 个职业：warrior/ranger/healer/mage/rogue/nuker/conjurer/enchanter/
           psyker/curser/forcer/swarmer/voider/sorcerer/mercenary/explorer

每个角色归属 1~2 个职业
职业协同触发条件：队伍中同职业角色达到 3/6 个

协同效果：全队属性加成（伤害/防御/攻速/范围等）
```

**属性计算公式**（`Unit:calculate_stats`）：

```
最终属性 = (base + class_add + buff_add) × class_mult × buff_mult

其中：
  base     = 基础值（由角色等级决定，每级×2）
  class_add/mult = 职业协同加成
  buff_add/mult  = 被动天赋加成
```

### 4.4 敌人系统

| 类型 | 行为 | 特殊 |
|------|------|------|
| **Seeker** | 追踪蛇头 (seek_point) | 基础敌人，有 Boss 变体 |
| **EnemyCritter** | 小型追踪 | 由 Swarmer 职业生成 |
| **ExploderMine** | 静止→接近自爆 | Boss 精英技能生成 |

**Boss 精英变体**（叠加在 Seeker 基础上）：

| 精英词缀 | 效果 |
|---------|------|
| speed_booster | 周期性加速其他敌人 |
| exploder | 死亡时爆炸 |
| swarmer | 死亡时分裂出小虫 |
| forcer | 释放力场推开玩家 |
| cluster | 死亡时释放追踪弹 |

**波次系统**：
- 25 关为一个循环（loop）
- 每 3 关 或 第 25 关是 Boss 关
- 普通关 3 波，每波敌人数量和类型由 `level_to_enemies` 数据表控制
- 击杀敌人掉落金币，用于商店购买

### 4.5 商店系统

商店循环（`buy_screen.lua`）：
1. 按稀有度权重随机生成 3~5 张角色卡
2. 花金币购买 → 角色加入蛇队尾部
3. 3 个同角色自动合成 → 等级 +1（最高 3 级）
4. 花金币重掷 → 刷新卡池
5. 可购买被动天赋（全局增益）
6. 确认出战 → 进入下一关

---

## 5. 关键设计模式

### 5.1 数据驱动

所有平衡性参数集中在 `main.lua` 的全局表中：

- `character_classes` — 角色→职业映射
- `character_tiers` — 角色→稀有度（1~4 星）
- `class_stat_multipliers` — 职业属性加成系数
- `level_to_enemies` — 每关敌人配置
- `passive_descriptions` — 被动天赋描述和效果

修改数值只需改表，不需要改逻辑代码。

### 5.2 "定时器即状态机"

传统做法：为角色编写状态机（Idle/Attack/Cooldown/...）
SNKRX 做法：用 `cooldown` + `every` + `after` 组合完成所有状态转换

**优势**：代码极其紧凑，55 个角色的能力在 4000 行内完成
**劣势**：嵌套回调较深时可读性下降

### 5.3 弹簧驱动的 "Juice"

所有视觉反馈都通过弹簧实现：
- 角色攻击 → `self.spring:pull(0.2)` → 缩放回弹
- 受击 → `hfx:use('hit', 0.25)` → 白色闪烁 + 弹簧抖动
- UI 按钮 → hover 时 `spring:pull` → 弹性放大
- 屏幕震动 → `camera:shake()` → 弹簧驱动的随机偏移

### 5.4 全局变量风格

SNKRX 大量使用 `_G` 全局变量：
- 所有声音：`hit1`, `explosion1`, `gold1` ...
- 所有图片：`warrior`, `ranger`, `star` ...
- 所有颜色：`red[0]`, `blue[-1]`, `fg[0]` ...
- 游戏状态：`gold`, `main`, `camera`, `input` ...

这是"快速发布"代码风格的特征。

---

# 第二部分：UrhoX 移植设计

## 6. 移植总体策略

### 6.1 核心判断

SNKRX 是一个 **纯 2D 几何图形** 游戏，没有 Sprite/贴图渲染，所有视觉元素都是用
矩形、圆形、线条等基础图形绘制。这决定了移植方案：

| 决策点 | 选择 | 理由 |
|--------|------|------|
| **渲染方案** | NanoVG（纯 2D 矢量） | 游戏全部由几何图形构成，NanoVG 完美匹配 |
| **物理方案** | UrhoX Physics2D (Box2D) | SNKRX 使用 Box2D，UrhoX 内置 Physics2D 同源 |
| **OOP 系统** | 直接移植（纯 Lua） | Object/extend/implement 是纯 Lua 代码，无引擎依赖 |
| **定时器系统** | 直接移植（纯 Lua） | Trigger 是纯 Lua 代码，唯一依赖 `love.timer.getTime()` 可替换 |
| **弹簧系统** | 直接移植（纯 Lua） | Spring 是纯数学，无外部依赖 |
| **转向行为** | 直接移植（纯 Lua） | Steering 是纯数学 + 向量运算，无外部依赖 |
| **向量/数学** | 使用 UrhoX Vector2 | UrhoX 内置 Vector2/Vector3，替换自研 Vector |
| **相机** | 简单偏移矩阵 | NanoVG 用 nvgTranslate/nvgScale 即可 |
| **输入** | UrhoX Input API | 替换 LÖVE2D 的 love.keyboard/love.mouse |
| **音频** | UrhoX Audio API | 替换 LÖVE2D 的 love.audio |
| **存档** | UrhoX File API | 替换 LÖVE2D 的 love.filesystem |
| **UI 系统** | urhox-libs/UI | 商店界面用 UI 组件库（替代原生代码绘制） |

### 6.2 移植分层

```
┌─────────────────────────────────────────────────┐
│             游戏逻辑层（大部分可移植）              │
│  player.lua / arena.lua / buy_screen.lua / ...  │
├─────────────────────────────────────────────────┤
│            适配层（需要重写）                      │
│  SNKRXEngine.lua — 桥接 SNKRX 引擎 API → UrhoX  │
├─────────────────────────────────────────────────┤
│            UrhoX 底层                            │
│  NanoVG / Physics2D / Input / Audio / ...        │
└─────────────────────────────────────────────────┘
```

**核心原则**：编写一个**适配层** `SNKRXEngine.lua`，模拟 SNKRX 原引擎的 API，
使游戏逻辑层的代码**尽量少改**。

---

## 7. 底层模块映射表

| SNKRX 引擎模块 | 移植方式 | UrhoX 对应 | 改动量 |
|----------------|---------|-----------|--------|
| **object.lua** (OOP) | 直接复用 | 纯 Lua，无需修改 | 无 |
| **trigger.lua** (定时器) | 几乎直接复用 | 替换 `love.timer.getTime()` → `time:GetElapsedTime()` | 极小 |
| **spring.lua** (弹簧) | 直接复用 | 纯数学，无需修改 | 无 |
| **steering.lua** (转向AI) | 微调 | 替换 Vector → UrhoX Vector2 或保留自研 Vector | 小 |
| **vector.lua** (2D向量) | 替换或保留 | 可保留自研 Vector（纯Lua），或全部换 UrhoX Vector2 | 中 |
| **math.lua** (数学工具) | 直接复用 | 纯 Lua math 扩展，无需修改 | 无 |
| **random.lua** (随机数) | 直接复用 | 纯 Lua，无需修改 | 无 |
| **几何碰撞** (circle/rect/polygon/chain) | 直接复用 | 纯数学碰撞检测，无外部依赖 | 无 |
| **table/string 扩展** | 直接复用 | 纯 Lua，无需修改 | 无 |
| **gameobject.lua** (实体) | 小幅修改 | 移除 love 相关引用 | 小 |
| **group.lua** (容器) | 中幅修改 | 物理世界创建改用 UrhoX Physics2D | 中 |
| **physics.lua** (Box2D) | **重写** | LÖVE2D Box2D API → UrhoX Physics2D API | **大** |
| **graphics.lua** (绘图) | **重写** | love.graphics → NanoVG API | **大** |
| **camera.lua** (相机) | **重写** | 用 NanoVG nvgTranslate/nvgScale 实现 | 中 |
| **canvas.lua** (离屏渲染) | **重写** | NanoVG 不支持多 Canvas，需简化渲染管线 | 中 |
| **input.lua** (输入) | **重写** | love.keyboard/mouse → UrhoX input API | 中 |
| **sound.lua** (音频) | **重写** | love.audio → UrhoX audio API | 中 |
| **system.lua** (存档) | **重写** | love.filesystem → UrhoX File API | 中 |
| **color.lua** (颜色) | 适配 | ColorRamp 纯 Lua，颜色构造函数需适配 NanoVG | 小 |
| **image.lua** (图片) | 适配 | love.graphics.newImage → NanoVG nvgCreateImage | 小 |
| **font.lua** (字体) | 适配 | love.graphics.newFont → NanoVG nvgCreateFont | 小 |
| **shader.lua** (着色器) | **删除/简化** | NanoVG 不支持自定义着色器，阴影效果需替代方案 | — |
| **state.lua** (场景切换) | 小幅修改 | 纯 Lua 状态机，移除 love 引用 | 小 |
| **hitfx/springs/flashes** | 直接复用 | 纯 Lua，依赖 Trigger 和 Spring | 无 |

---

## 8. 各模块详细移植方案

### 8.1 OOP + 纯 Lua 模块（直接复用）

以下模块是**纯 Lua 代码**，可以原封不动地复制到 `scripts/engine/` 目录：

```
scripts/engine/
├── object.lua           # OOP 基类（0 改动）
├── trigger.lua          # 定时器系统（改 1 行：love.timer.getTime → 自定义）
├── spring.lua           # 弹簧物理（0 改动）
├── springs.lua          # 弹簧集合（0 改动）
├── hitfx.lua            # 受击特效（0 改动）
├── flashes.lua          # 屏闪特效（0 改动）
├── parent.lua           # 父子跟随（0 改动）
├── random.lua           # 随机数（0 改动）
├── math_ext.lua         # 数学扩展（0 改动）
├── table_ext.lua        # table 扩展（0 改动）
├── string_ext.lua       # string 扩展（0 改动）
├── vector.lua           # 2D 向量（0 改动，保留自研）
├── circle.lua           # 圆形碰撞（0 改动）
├── rectangle.lua        # 矩形碰撞（0 改动）
├── polygon.lua          # 多边形碰撞（0 改动）
├── chain.lua            # 链式碰撞（0 改动）
├── line.lua             # 线段碰撞（0 改动）
├── triangle.lua         # 三角形碰撞（0 改动）
└── steering.lua         # 转向行为（0 改动，使用自研 Vector）
```

**Trigger 唯一修改**：

```lua
-- 原始（LÖVE2D）
function Trigger:init()
  self.time = love.timer.getTime()
end
function Trigger:get_time()
  self.time = love.timer.getTime()
  return self.time
end

-- UrhoX 替换
function Trigger:init()
  self.time = 0  -- 使用累加时间
end
-- get_time 直接使用 self.time（由 update 累加维护）
```

### 8.2 Graphics — NanoVG 适配（重写）

SNKRX 的 `graphics.lua` 封装了 LÖVE2D 的绘图 API，需要用 NanoVG 重新实现。

**SNKRX 使用的绘图原语**：

| SNKRX API | 用途 | NanoVG 等价 |
|-----------|------|------------|
| `graphics.rectangle(x, y, w, h, rx, ry, color)` | 绘制矩形 | `nvgRect` + `nvgFill/nvgStroke` |
| `graphics.circle(x, y, r, color)` | 绘制圆形 | `nvgCircle` + `nvgFill` |
| `graphics.line(x1, y1, x2, y2, color, w)` | 绘制线段 | `nvgMoveTo/nvgLineTo` + `nvgStroke` |
| `graphics.polyline(color, w, ...)` | 绘制折线 | `nvgMoveTo/nvgLineTo` 序列 |
| `graphics.polygon(vertices, color)` | 绘制多边形 | `nvgMoveTo/nvgLineTo` 序列 + `nvgFill` |
| `graphics.push(x, y, r, sx, sy)` | 变换压栈 | `nvgSave` + `nvgTranslate/nvgRotate/nvgScale` |
| `graphics.pop()` | 变换出栈 | `nvgRestore` |
| `graphics.set_color(color)` | 设置颜色 | `nvgFillColor` / `nvgStrokeColor` |
| `graphics.print(text, font, x, y)` | 绘制文本 | `nvgText` |
| `graphics.set_background_color(c)` | 背景色 | UrhoX `renderer:SetClearColor()` |
| `graphics.stencil(fn, action)` | 模板测试 | NanoVG `nvgScissor` 近似替代 |

**NanoVG 适配层核心代码**（设计）：

```lua
-- scripts/engine/graphics_nvg.lua
local G = {}

function G.rectangle(x, y, w, h, rx, ry, color, line_width)
  nvgBeginPath(vg)
  if rx and ry and rx > 0 then
    nvgRoundedRect(vg, x - w/2, y - h/2, w, h, rx)
  else
    nvgRect(vg, x - w/2, y - h/2, w, h)
  end
  if line_width then
    nvgStrokeColor(vg, G.to_nvg_color(color))
    nvgStrokeWidth(vg, line_width)
    nvgStroke(vg)
  else
    nvgFillColor(vg, G.to_nvg_color(color))
    nvgFill(vg)
  end
end

function G.circle(x, y, r, color, line_width)
  nvgBeginPath(vg)
  nvgCircle(vg, x, y, r)
  if line_width then
    nvgStrokeColor(vg, G.to_nvg_color(color))
    nvgStrokeWidth(vg, line_width)
    nvgStroke(vg)
  else
    nvgFillColor(vg, G.to_nvg_color(color))
    nvgFill(vg)
  end
end

function G.line(x1, y1, x2, y2, color, w)
  nvgBeginPath(vg)
  nvgMoveTo(vg, x1, y1)
  nvgLineTo(vg, x2, y2)
  nvgStrokeColor(vg, G.to_nvg_color(color))
  nvgStrokeWidth(vg, w or 1)
  nvgStroke(vg)
end

function G.push(x, y, r, sx, sy)
  nvgSave(vg)
  nvgTranslate(vg, x, y)
  if r and r ~= 0 then nvgRotate(vg, r) end
  if sx and sy then nvgScale(vg, sx, sy) end
  nvgTranslate(vg, -x, -y)
end

function G.pop()
  nvgRestore(vg)
end

function G.to_nvg_color(c)
  -- SNKRX 颜色 {r, g, b, a}（0~1 范围）
  return nvgRGBAf(c.r, c.g, c.b, c.a or 1)
end

return G
```

### 8.3 Physics — UrhoX Physics2D 适配（重写）

这是改动最大的模块。SNKRX 直接调用 LÖVE2D 的 Box2D API，需要完全替换为 UrhoX 的 Physics2D 组件系统。

**关键差异**：

| 维度 | SNKRX (LÖVE2D Box2D) | UrhoX Physics2D |
|------|----------------------|-----------------|
| 世界创建 | `love.physics.newWorld(gx, gy)` | `scene_:CreateComponent("PhysicsWorld2D")` |
| 刚体创建 | `love.physics.newBody(world, x, y, type)` | `node:CreateComponent("RigidBody2D")` |
| 碰撞形状 | `love.physics.newRectangleShape(w, h)` | `node:CreateComponent("CollisionBox2D")` |
| Fixture | `love.physics.newFixture(body, shape)` | CollisionShape2D 自动关联 RigidBody2D |
| Category/Mask | `fixture:setCategory(n)` / `fixture:setMask(...)` | `shape.categoryBits` / `shape.maskBits` |
| Sensor | `fixture:setSensor(true)` | `shape.trigger = true` |
| 速度 | `body:setLinearVelocity(vx, vy)` | `body.linearVelocity = Vector2(vx, vy)` |
| 施力 | `body:applyForce(fx, fy)` | `body:ApplyForceToCenter(Vector2(fx, fy), true)` |
| 碰撞回调 | world:setCallbacks(begin, end) | `SubscribeToEvent(node, "PhysicsBeginContact2D", ...)` |
| 坐标单位 | 像素（需设 meter） | 米（需缩放） |
| UserData | `fixture:setUserData(id)` | `node.name` 或自定义属性 |

**UrhoX Physics2D 适配层设计**：

```lua
-- scripts/engine/physics_urhox.lua
local P = {}

-- 碰撞标签 → category bit 映射
local tag_bits = {}
local tag_count = 0

function P.register_tags(tags)
  for _, tag in ipairs(tags) do
    tag_count = tag_count + 1
    tag_bits[tag] = bit32.lshift(1, tag_count - 1)
  end
end

-- 为 GameObject 创建物理体
function P.set_as_rectangle(obj, w, h, body_type, tag)
  -- SNKRX 坐标是像素，UrhoX 单位是米
  -- 使用缩放因子: 1像素 = 0.01米 (PPM = 100)
  local PPM = 100
  local node = scene_:CreateChild(obj.id)
  node.position2D = Vector2(obj.x / PPM, obj.y / PPM)

  local body = node:CreateComponent("RigidBody2D")
  body.bodyType = P.body_type_map[body_type or 'dynamic']
  body.fixedRotation = false

  local shape = node:CreateComponent("CollisionBox2D")
  shape:SetSize(Vector2(w / PPM, h / PPM))
  shape.categoryBits = tag_bits[tag] or 1
  shape.maskBits = 0xFFFF  -- 默认与所有碰撞
  shape.density = 1.0
  shape.friction = 0.0
  shape.restitution = 0.0

  obj._node = node
  obj._body = body
  obj._shape = shape
  obj._ppm = PPM
end

P.body_type_map = {
  static    = BT_STATIC,
  dynamic   = BT_DYNAMIC,
  kinematic = BT_KINEMATIC,
}

-- 位置同步：物理 → 逻辑
function P.sync_from_physics(obj)
  local pos = obj._node.position2D
  obj.x = pos.x * obj._ppm
  obj.y = pos.y * obj._ppm
  obj.r = obj._body.angle  -- 弧度
end

-- 速度控制
function P.set_velocity(obj, vx, vy)
  obj._body.linearVelocity = Vector2(vx / obj._ppm, vy / obj._ppm)
end

function P.get_velocity(obj)
  local v = obj._body.linearVelocity
  return v.x * obj._ppm, v.y * obj._ppm
end

-- 施力
function P.apply_force(obj, fx, fy)
  obj._body:ApplyForceToCenter(Vector2(fx / obj._ppm, fy / obj._ppm), true)
end

-- 碰撞控制
function P.disable_collision(tag1, tag2)
  -- 在对应 shape 的 maskBits 中排除对方的 categoryBits
  -- 需要在创建 shape 时应用
end

return P
```

**关键注意事项**：

1. **坐标缩放**：SNKRX 使用 480×270 像素坐标，UrhoX Physics2D 使用米。需要一个 PPM (Pixels Per Meter) 常量做转换，建议 PPM=100（即 1 像素 = 0.01 米，整个战场约 4.8m × 2.7m）。

2. **碰撞回调**：SNKRX 在 Group 中统一设置 `world:setCallbacks`，UrhoX 需要用 `SubscribeToEvent` 订阅 `PhysicsBeginContact2D` / `PhysicsEndContact2D` 事件。

3. **Sensor（触发器）**：SNKRX 区分物理碰撞和 Sensor 触发，UrhoX 通过 `CollisionShape2D.trigger = true` 实现。

### 8.4 Camera — NanoVG 变换矩阵（重写）

SNKRX 的相机通过 LÖVE2D 的变换矩阵实现平移、缩放、震屏。
在 UrhoX NanoVG 中，用 `nvgTranslate` / `nvgScale` 模拟：

```lua
-- scripts/engine/camera_nvg.lua
local Camera = Object:extend()

function Camera:init(x, y)
  self.x, self.y = x, y
  self.sx, self.sy = 1, 1
  self.r = 0
  self.shake_amount = 0
  self.shake_ox, self.shake_oy = 0, 0
  self.spring_x = Spring(0, 200, 15)  -- 震屏弹簧 X
  self.spring_y = Spring(0, 200, 15)  -- 震屏弹簧 Y
end

function Camera:update(dt)
  self.spring_x:update(dt)
  self.spring_y:update(dt)
  self.shake_ox = self.spring_x.x
  self.shake_oy = self.spring_y.x
end

function Camera:shake(intensity, duration)
  self.spring_x:pull(math.random() > 0.5 and intensity or -intensity)
  self.spring_y:pull(math.random() > 0.5 and intensity or -intensity)
end

function Camera:attach()
  nvgSave(vg)
  -- 先缩放，再平移（缩放中心为画面中心）
  nvgTranslate(vg, gw/2, gh/2)
  nvgScale(vg, self.sx, self.sy)
  nvgTranslate(vg, -self.x + self.shake_ox, -self.y + self.shake_oy)
end

function Camera:detach()
  nvgRestore(vg)
end

return Camera
```

### 8.5 Canvas / 渲染管线（简化）

SNKRX 使用 4 层 Canvas 实现阴影和分层效果。NanoVG 没有原生 Canvas 概念，
需要简化渲染管线：

**原始管线**：
```
background_canvas → shadow_canvas(shader) → main_canvas → star_canvas
```

**UrhoX 简化方案**：
```
直接在 NanoVGRender 事件中按顺序绘制:
  1. 绘制棋盘格背景（nvgRect 循环）
  2. 绘制渐变覆盖（nvgLinearGradient）
  3. camera:attach()
  4.   绘制所有游戏对象（floor → main → effects）
  5. camera:detach()
  6. 绘制 UI 层
```

**阴影效果替代**：
- 原版用 shader 偏移整个画面生成阴影
- NanoVG 替代：为每个对象单独绘制偏移的暗色版本
- 或者：直接放弃阴影效果（对游戏性无影响）

### 8.6 Input — UrhoX 输入适配（重写）

```lua
-- scripts/engine/input_urhox.lua
local I = {}

-- SNKRX 的输入 API → UrhoX 映射
local key_map = {
  -- SNKRX 名     → UrhoX 常量
  ['a']       = KEY_A,
  ['d']       = KEY_D,
  ['e']       = KEY_E,
  ['s']       = KEY_S,
  ['left']    = KEY_LEFT,
  ['right']   = KEY_RIGHT,
  ['space']   = KEY_SPACE,
  ['return']  = KEY_RETURN,
  ['escape']  = KEY_ESCAPE,
}

local bindings = {}  -- action_name → {keys...}
local pressed = {}   -- 本帧按下
local down = {}      -- 持续按住

function I.bind(action, keys)
  bindings[action] = {}
  for _, k in ipairs(keys) do
    if key_map[k] then
      table.insert(bindings[action], {type='key', code=key_map[k]})
    elseif k == 'm1' then
      table.insert(bindings[action], {type='mouse', button=MOUSEB_LEFT})
    elseif k == 'm2' then
      table.insert(bindings[action], {type='mouse', button=MOUSEB_RIGHT})
    end
  end
end

function I.is_pressed(action)
  for _, b in ipairs(bindings[action] or {}) do
    if b.type == 'key' and input:GetKeyPress(b.code) then return true end
    if b.type == 'mouse' and input:GetMouseButtonPress(b.button) then return true end
  end
  return false
end

function I.is_down(action)
  for _, b in ipairs(bindings[action] or {}) do
    if b.type == 'key' and input:GetKeyDown(b.code) then return true end
    if b.type == 'mouse' and input:GetMouseButtonDown(b.button) then return true end
  end
  return false
end

return I
```

### 8.7 Sound — UrhoX 音频适配（重写）

```lua
-- scripts/engine/sound_urhox.lua
local S = {}

-- SoundTag（音量分组）
local SoundTag = Object:extend()
function SoundTag:init()
  self.volume = 0.5
end

-- Sound 对象
local Sound = Object:extend()
function Sound:init(path, opts)
  self.resource = cache:GetResource("Sound", "Sounds/" .. path)
  if self.resource then
    self.resource.looped = false
  end
  self.tags = (opts and opts.tags) and opts.tags or {}
end

function Sound:play(opts)
  if not self.resource then return end
  local node = scene_:CreateChild("SFX")
  local source = node:CreateComponent("SoundSource")
  source:Play(self.resource)

  local vol = (opts and opts.volume) or 1.0
  -- 应用 tag 音量
  for _, tag in ipairs(self.tags) do
    vol = vol * (tag.volume or 1.0)
  end
  source:SetGain(vol)

  if opts and opts.pitch then
    source:SetFrequency(self.resource.frequency * (opts.pitch or 1.0))
  end
end

S.SoundTag = SoundTag
S.Sound = Sound
return S
```

### 8.8 Group — 适配 UrhoX Physics2D（中幅修改）

Group 的对象管理和空间哈希部分是纯 Lua，可以保留。
需要修改的部分：

```lua
-- 原始：创建 LÖVE2D Box2D 世界
function Group:set_as_physics_world(meter, xg, yg, tags)
  love.physics.setMeter(meter)
  self.world = love.physics.newWorld(xg, yg)
  self.world:setCallbacks(beginContact, endContact)
end

-- UrhoX 替换：在场景上创建 PhysicsWorld2D
function Group:set_as_physics_world(meter, xg, yg, tags)
  local PPM = meter or 100
  self.ppm = PPM

  -- 使用全局 scene_ 的 PhysicsWorld2D
  if not self.physics_world then
    self.physics_world = scene_:GetComponent("PhysicsWorld2D")
    if not self.physics_world then
      self.physics_world = scene_:CreateComponent("PhysicsWorld2D")
    end
  end
  self.physics_world.gravity = Vector2((xg or 0) / PPM, (yg or 0) / PPM)

  -- 注册碰撞标签
  self.tags = tags or {}
  physics_adapter.register_tags(self.tags)

  -- 订阅碰撞事件
  SubscribeToEvent("PhysicsBeginContact2D", function(eventType, eventData)
    -- 从 eventData 获取碰撞双方 node，查找对应 GameObject
    -- 调用 on_collision_enter / on_trigger_enter
  end)

  return self
end
```

### 8.9 State / 场景管理（小幅修改）

SNKRX 的 State mixin 提供 `on_enter` / `on_exit` 生命周期，
场景切换通过 `main:go_to(scene_name, ...)` 完成。

这部分是纯 Lua 逻辑，改动极小：

```lua
-- 原始
function State:go_to(state_name, ...)
  -- 调用旧场景 on_exit, 创建新场景, 调用 on_enter
end

-- UrhoX：保持不变，仅确保场景切换时清理 UrhoX 节点
function State:go_to(state_name, ...)
  if self.current and self.current.on_exit then
    self.current:on_exit()
  end
  -- 清理 UrhoX 场景节点
  if self.current and self.current.cleanup_nodes then
    self.current:cleanup_nodes()
  end
  self.current = self.states[state_name]
  self.current:on_enter(...)
end
```

### 8.10 存档系统（重写）

```lua
-- scripts/engine/system_urhox.lua

-- 原始：love.filesystem
-- UrhoX：使用 File API（沙箱内读写）

local cjson = require("cjson")

function system_save_state(state)
  local json_str = cjson.encode(state)
  local file = File("save.json", FILE_WRITE)
  if file then
    file:WriteString(json_str)
    file:Close()
  end
end

function system_load_state()
  local file = File("save.json", FILE_READ)
  if file then
    local json_str = file:ReadString()
    file:Close()
    return cjson.decode(json_str)
  end
  return {}
end
```

---

## 9. 模块依赖关系与移植顺序

### 9.1 依赖图

```
                     UrhoX Engine
                         │
         ┌───────────────┼───────────────┐
         ▼               ▼               ▼
    NanoVG API     Physics2D API    Input/Audio API
         │               │               │
         ▼               ▼               ▼
  ┌─────────────────────────────────────────────┐
  │              适配层 (SNKRXEngine)             │
  │  graphics_nvg / physics_urhox / input_urhox │
  │  sound_urhox / camera_nvg / system_urhox    │
  └──────────────────┬──────────────────────────┘
                     │
  ┌──────────────────┼──────────────────────┐
  │          纯 Lua 核心（直接复用）          │
  │  object / trigger / spring / steering   │
  │  vector / math_ext / random             │
  │  circle / rect / polygon / chain        │
  │  gameobject / group / state             │
  │  hitfx / springs / flashes / parent     │
  └──────────────────┬──────────────────────┘
                     │
  ┌──────────────────┼──────────────────────┐
  │             游戏逻辑层                   │
  │  shared / objects / player / enemies    │
  │  arena / buy_screen / mainmenu / main   │
  └─────────────────────────────────────────┘
```

### 9.2 推荐移植顺序（6 个阶段）

**阶段 1：纯 Lua 核心**（可立即开始，无需 UrhoX）
```
复制并验证：
  object.lua / trigger.lua / spring.lua / vector.lua
  math_ext.lua / random.lua / table_ext.lua / string_ext.lua
  circle.lua / rectangle.lua / polygon.lua / chain.lua / line.lua / triangle.lua
  springs.lua / hitfx.lua / flashes.lua / parent.lua
```

**阶段 2：渲染适配**
```
实现：
  graphics_nvg.lua   — NanoVG 绘图原语
  camera_nvg.lua     — 相机变换
  color_adapter.lua  — ColorRamp → NanoVG 颜色

验证：
  在空场景中测试绘制矩形、圆、线条
  测试 push/pop 变换嵌套
  测试弹簧动画的视觉效果
```

**阶段 3：物理适配**
```
实现：
  physics_urhox.lua  — Box2D 物理创建/同步/碰撞
  group 的物理世界部分

验证：
  创建几个矩形和圆形物理体
  测试碰撞检测和碰撞回调
  测试 category/mask 碰撞过滤
  测试 sensor（触发器）
```

**阶段 4：输入/音频/存档**
```
实现：
  input_urhox.lua    — 输入绑定和查询
  sound_urhox.lua    — 音效播放
  system_urhox.lua   — 存档读写

验证：
  测试键盘/鼠标输入
  测试音效播放和音量控制
  测试存档保存和加载
```

**阶段 5：游戏逻辑移植**
```
逐步移植：
  1. shared.lua       — 颜色/渲染管线/视觉特效
  2. objects.lua       — Unit mixin / SpawnMarker / HPBar
  3. player.lua        — 蛇体 + 角色能力（最大文件）
  4. enemies.lua       — 敌人类型
  5. arena.lua         — 战斗场景
  6. buy_screen.lua    — 商店场景（可用 urhox-libs/UI 重写）
  7. mainmenu.lua      — 主菜单
  8. main.lua          — 入口 + 数据表
```

**阶段 6：商店 UI 重写（可选优化）**
```
用 urhox-libs/UI 组件库重写 buy_screen.lua：
  - 角色卡片 → UI.Panel + UI.Label
  - 金币显示 → UI.Label
  - 被动天赋 → UI.ScrollView + UI.Button
  - 这是最大的优化空间，原版 2000+ 行手绘 UI 可简化
```

---

## 10. 风险评估与注意事项

### 10.1 高风险项

| 风险 | 等级 | 说明 | 缓解措施 |
|------|------|------|---------|
| **坐标系差异** | 高 | SNKRX 使用像素坐标，UrhoX Physics2D 使用米 | 统一 PPM 常量，所有物理接口做转换 |
| **物理碰撞回调差异** | 高 | LÖVE2D 回调携带 fixture，UrhoX 回调携带 node | 适配层中建立 node ↔ GameObject 映射表 |
| **Canvas 不可用** | 中 | NanoVG 无原生 Canvas/RenderTarget | 简化渲染管线为单 pass 绘制 |
| **阴影 Shader 不可用** | 中 | NanoVG 不支持自定义 shader | 放弃阴影效果，或用偏移绘制模拟 |
| **Stencil 差异** | 中 | SNKRX 用 stencil 做遮罩，NanoVG 用 scissor | 分析具体用法，用 nvgScissor 替代 |
| **性能**（大量对象） | 中 | NanoVG 每帧绘制所有对象 | 空间剔除（只绘制可见区域） |

### 10.2 不需要移植的部分

| 模块 | 原因 |
|------|------|
| `shader.lua` | NanoVG 不支持自定义着色器，放弃 |
| `canvas.lua` | NanoVG 无需离屏渲染，简化为单 pass |
| `tileset.lua` / `tilemap.lua` | SNKRX 未使用瓦片地图 |
| `graph.lua` / `grid.lua` | SNKRX 未使用图/网格数据结构 |
| `animation.lua` | SNKRX 未使用帧动画 |
| Steam 集成 | UrhoX 发布到 TapTap，不需要 Steam |

### 10.3 坐标系注意事项

```
SNKRX 坐标系（LÖVE2D 风格）：
  原点：左上角
  X 轴：向右
  Y 轴：向下 ← 注意！
  角度：0 = 向右，正值 = 顺时针

UrhoX 2D 坐标系：
  NanoVG：原点左上角，Y 向下（与 SNKRX 一致）
  Physics2D：Y 向上 ← 需要翻转！

缓解：
  渲染层 → NanoVG 与 SNKRX 一致，无需改动
  物理层 → 在适配层中翻转 Y 轴（y_physics = -y_game）
```

### 10.4 工作量估算

| 阶段 | 工作内容 | 文件数 | 估算复杂度 |
|------|---------|--------|-----------|
| 阶段 1 | 纯 Lua 核心复制 | ~18 | 极低（复制+微调） |
| 阶段 2 | NanoVG 渲染适配 | 3 | 中（核心适配层） |
| 阶段 3 | Physics2D 适配 | 2 | 高（API 差异大） |
| 阶段 4 | 输入/音频/存档 | 3 | 低（API 直接映射） |
| 阶段 5 | 游戏逻辑移植 | 8 | 高（代码量大，需逐步调试） |
| 阶段 6 | UI 重写（可选） | 1 | 中（用 UI 库简化） |

---

## 附录 A：项目文件结构设计

```
scripts/
├── main.lua                    # UrhoX 入口（Start/HandleUpdate）
├── engine/                     # SNKRX 引擎适配层
│   ├── object.lua              # OOP 基类（原样复用）
│   ├── gameobject.lua          # 实体 mixin（微调）
│   ├── group.lua               # 对象容器（修改物理部分）
│   ├── state.lua               # 场景状态机（微调）
│   ├── trigger.lua             # 定时器/Tween（微调）
│   ├── spring.lua              # 弹簧（原样复用）
│   ├── springs.lua             # 弹簧集合（原样复用）
│   ├── hitfx.lua               # 受击特效（原样复用）
│   ├── flashes.lua             # 屏闪特效（原样复用）
│   ├── parent.lua              # 父子跟随（原样复用）
│   ├── steering.lua            # 转向行为（原样复用）
│   ├── vector.lua              # 2D 向量（原样复用）
│   ├── random.lua              # 随机数（原样复用）
│   ├── math_ext.lua            # 数学扩展（原样复用）
│   ├── table_ext.lua           # table 扩展（原样复用）
│   ├── string_ext.lua          # string 扩展（原样复用）
│   ├── circle.lua              # 碰撞检测（原样复用）
│   ├── rectangle.lua           # 碰撞检测（原样复用）
│   ├── polygon.lua             # 碰撞检测（原样复用）
│   ├── chain.lua               # 碰撞检测（原样复用）
│   ├── line.lua                # 碰撞检测（原样复用）
│   ├── triangle.lua            # 碰撞检测（原样复用）
│   ├── graphics_nvg.lua        # 🆕 NanoVG 绘图适配
│   ├── camera_nvg.lua          # 🆕 NanoVG 相机
│   ├── physics_urhox.lua       # 🆕 UrhoX Physics2D 适配
│   ├── input_urhox.lua         # 🆕 UrhoX 输入适配
│   ├── sound_urhox.lua         # 🆕 UrhoX 音频适配
│   ├── system_urhox.lua        # 🆕 UrhoX 存档适配
│   └── color_adapter.lua       # 🆕 颜色系统适配
├── game/                       # SNKRX 游戏逻辑
│   ├── data.lua                # 数据表（角色/职业/关卡配置）
│   ├── shared.lua              # 渲染管线 + 视觉特效
│   ├── objects.lua             # 通用游戏对象
│   ├── player.lua              # 蛇体 + 角色能力
│   ├── enemies.lua             # 敌人系统
│   ├── arena.lua               # 战斗场景
│   ├── buy_screen.lua          # 商店场景
│   └── mainmenu.lua            # 主菜单
└── lib/                        # 第三方库
    ├── mlib.lua                # 数学/几何库（SNKRX 依赖）
    ├── binser.lua              # 序列化库
    └── clipper.lua             # 多边形裁剪库
```

## 附录 B：UrhoX 入口文件模板

```lua
-- scripts/main.lua (UrhoX 入口)
require "LuaScripts/Utilities/Sample"

-- 加载引擎适配层
require "engine.object"
require "engine.table_ext"
require "engine.string_ext"
require "engine.math_ext"
require "engine.random"
require "engine.vector"
require "engine.trigger"
require "engine.spring"
require "engine.springs"
require "engine.hitfx"
require "engine.flashes"
require "engine.parent"
require "engine.circle"
require "engine.rectangle"
require "engine.polygon"
require "engine.chain"
require "engine.line"
require "engine.triangle"
require "engine.gameobject"
require "engine.group"
require "engine.state"
require "engine.steering"
require "engine.graphics_nvg"
require "engine.camera_nvg"
require "engine.physics_urhox"
require "engine.input_urhox"
require "engine.sound_urhox"
require "engine.system_urhox"
require "engine.color_adapter"

-- 加载游戏逻辑
require "game.data"
require "game.shared"
require "game.objects"
require "game.player"
require "game.enemies"
require "game.arena"
require "game.buy_screen"
require "game.mainmenu"

-- 设计分辨率
gw, gh = 480, 270
sx, sy = 2, 2

function Start()
  -- 初始化 NanoVG
  vg = nvgCreate(NVG_ANTIALIAS | NVG_STENCIL_STROKES)

  -- 创建字体
  nvgCreateFont(vg, "fat", "Fonts/FatPixelFont.ttf")
  nvgCreateFont(vg, "pixul", "Fonts/PixulBrush.ttf")

  -- 初始化 UrhoX 场景（用于 Physics2D）
  scene_ = Scene()
  scene_:CreateComponent("PhysicsWorld2D")

  -- 初始化游戏
  init()  -- 调用 SNKRX 的 init 函数

  -- 注册渲染事件
  SubscribeToEvent("NanoVGRender", "HandleNanoVGRender")
  SubscribeToEvent("Update", "HandleUpdate")
end

function HandleUpdate(eventType, eventData)
  local dt = eventData["TimeStep"]:GetFloat()
  -- 固定时间步
  update(dt)
end

function HandleNanoVGRender(eventType, eventData)
  local w = graphics:GetWidth()
  local h = graphics:GetHeight()
  local dpr = graphics:GetDPR()
  nvgBeginFrame(vg, w / dpr, h / dpr, dpr)
  draw()  -- 调用 SNKRX 的 draw 函数
  nvgEndFrame(vg)
end
```

---

*文档完成 — 2026-04-29*
