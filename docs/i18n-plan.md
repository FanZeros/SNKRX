# SNKRX 中文翻译规划

## 概览

| 项目 | 数据 |
|------|------|
| 总可翻译字符串 | ~500 条 |
| 涉及文件 | 4 个主要文件 |
| 组织方式 | ~70% 集中在数据表，~30% 分散在 UI 代码中 |
| 预计翻译难度 | 中等 |

## 翻译范围

### 第一阶段：核心游戏数据（~200 条，难度低）

集中在 `scripts/game/data.lua` 的数据表中，可直接替换。

| 内容 | 位置 | 数量 | 示例 |
|------|------|------|------|
| 角色名称 | `character_names` | 60 | Vagrant → 流浪者, Swordsman → 剑士 |
| 职业名称 | `character_class_strings` | 16 | Warrior → 战士, Ranger → 游侠 |
| 技能名称 | `character_effect_names` | 60+ | Cleave → 劈砍, Magic Missile → 魔法飞弹 |

**操作方式**：直接替换数据表中的英文字符串为中文。

### 第二阶段：技能与角色描述（~120 条，难度中）

同样在 `data.lua` 中，但以函数形式存在，包含动态数值拼接和颜色标签。

| 内容 | 位置 | 数量 |
|------|------|------|
| 角色描述 | `character_descriptions` | 60+ |
| 被动技能描述 | `character_effect_descriptions` | 60+ |
| 灰色被动描述 | `character_effect_descriptions_gray` | 60+（与上面内容相同，仅颜色不同）|

**示例**：
```lua
-- 原文
function(lvl)
  return '[fg]shoots a projectile that deals [yellow]'
    .. get_character_stat('vagrant', lvl, 'dmg') .. '[fg] damage'
end

-- 译文
function(lvl)
  return '[fg]发射一枚弹丸，造成 [yellow]'
    .. get_character_stat('vagrant', lvl, 'dmg') .. '[fg] 点伤害'
end
```

**注意事项**：
- 保留 `[fg]`、`[yellow]` 等颜色标签
- 保留动态数值变量 `..` 拼接逻辑
- `character_effect_descriptions_gray` 需同步翻译（内容相同，仅颜色标签不同）

### 第三阶段：UI 界面文本（~80 条，难度中）

分散在多个文件中的按钮、标签、菜单文本。

| 内容 | 位置 | 数量 | 示例 |
|------|------|------|------|
| 商店界面 | `buy_screen.lua` | 40+ | GO! → 出发！, reroll → 刷新, lock → 锁定 |
| 战斗界面 | `arena.lua` | 20+ | arena clear! → 竞技场通关！ |
| 共享 UI | `shared.lua` | 10+ | — |

### 第四阶段：教程与系统提示（~50 条，难度中）

| 内容 | 位置 | 数量 |
|------|------|------|
| 新手教程 | `buy_screen.lua` 的 `on_enter()` | 15 |
| 错误提示 | `buy_screen.lua` | 10 |
| 胜利/失败文本 | `arena.lua` 的 `quit()`/`die()` | 25 |

**示例**：
```lua
-- 原文
'WELCOME TO SNKRX!'
'You control a snake of multiple heroes that auto-attack nearby enemies.'

-- 译文
'欢迎来到 SNKRX！'
'你控制一条由多个英雄组成的蛇，英雄会自动攻击附近的敌人。'
```

### 第五阶段：制作人员与其他（~30 条，难度低）

| 内容 | 位置 | 说明 |
|------|------|------|
| 制作人员标签 | `arena.lua` 的 `create_credits()` | 仅翻译标签（"main dev:" → "主要开发："），人名保持英文 |

## 特殊问题与应对

### 1. 颜色标签

游戏中大量使用 `[fg]`、`[yellow]`、`[wavy_mid, yellow]` 等标签控制文本样式。

**规则**：标签视为不可翻译，仅翻译标签之间的纯文本部分。

### 2. 动态数值拼接

```lua
'[yellow]' .. value .. '[fg] damage'
→ '[yellow]' .. value .. '[fg] 点伤害'
```

**规则**：保持 Lua 字符串拼接语法 (`..`) 不变，仅替换英文文本部分。

### 3. 按键提示

```lua
'A/D or left/right arrows'
→ 'A/D 或 方向键左/右'  -- 或保留原文

'esc - options'
→ 'ESC - 选项'
```

**规则**：按键名称保持英文（A、D、ESC），功能描述翻译为中文。

### 4. 灰色描述副本

`character_effect_descriptions` 和 `character_effect_descriptions_gray` 内容相同但颜色标签不同。

**方案**：翻译 `character_effect_descriptions` 后，复制到 `_gray` 版本并替换颜色标签。

### 5. 字体适配

中文字符需要中文字体支持。当前游戏使用的像素风格字体（`pixul`）可能不支持中文。

**方案**：
- 使用引擎内置的 `Fonts/MiSans-Regular.ttf`（支持中文）
- 在字体加载处替换或增加 fallback 字体
- 搜索 `pixul` 字体引用，评估是否需要全局替换

## 推荐翻译流程

```
1. 创建翻译对照表文件（scripts/game/i18n_zh.lua）
   ├── 角色名称对照表
   ├── 职业名称对照表
   ├── 技能名称对照表
   └── UI 文本对照表

2. 直接替换方式（推荐，简单直接）
   ├── 在 data.lua 中直接将英文替换为中文
   ├── 在 buy_screen.lua / arena.lua 中替换 UI 文本
   └── 不需要 i18n 框架（游戏只需要中文版本）

3. 字体适配
   ├── 检查 pixul 字体是否支持中文
   ├── 若不支持，替换为 MiSans 或类似字体
   └── 调整字号以适配中文字符宽度

4. 测试验证
   ├── 检查文本溢出/截断
   ├── 检查颜色标签是否正常
   └── 检查动态数值显示是否正确
```

## 文件影响清单

| 文件 | 修改内容 | 修改量 |
|------|---------|--------|
| `scripts/game/data.lua` | 角色名、职业名、技能名、描述文本 | 大（~350 条） |
| `scripts/game/buy_screen.lua` | 商店 UI、教程文本、错误提示 | 中（~80 条） |
| `scripts/game/arena.lua` | 战斗 UI、胜负文本、制作人员 | 中（~60 条） |
| `scripts/game/shared.lua` | 共享 UI 元素 | 小（~10 条） |
| `scripts/engine/graphics/text.lua` | 可能需要字体适配 | 小 |
