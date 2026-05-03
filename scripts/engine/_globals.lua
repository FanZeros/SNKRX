---@diagnostic disable: lowercase-global, undefined-global
--- Engine runtime globals declaration for LSP.
--- This file is never require'd at runtime; it exists only so the LSP knows these globals exist.
--- The actual values are injected by the UrhoX engine at startup.

cache = cache or {}
engine = engine or {}
fileSystem = fileSystem or {}
input = input or {}

function SubscribeToEvent(eventName, handler) end
function SampleStart() end
function Scene() return {} end
function Vector2(x, y) return {} end
function File(fileName, mode) return {} end

FILE_READ = 0
FILE_WRITE = 1
BT_STATIC = 0
BT_DYNAMIC = 1
BT_KINEMATIC = 2
MOUSEB_LEFT = 0
MOUSEB_MIDDLE = 1
MOUSEB_RIGHT = 2
NVG_ALIGN_LEFT = 0
NVG_ALIGN_CENTER = 0
NVG_ALIGN_TOP = 0
NVG_ALIGN_MIDDLE = 0
NVG_CW = 0

KEY_A = 0; KEY_B = 0; KEY_C = 0; KEY_D = 0; KEY_E = 0; KEY_F = 0
KEY_G = 0; KEY_H = 0; KEY_I = 0; KEY_J = 0; KEY_K = 0; KEY_L = 0
KEY_M = 0; KEY_N = 0; KEY_O = 0; KEY_P = 0; KEY_Q = 0; KEY_R = 0
KEY_S = 0; KEY_T = 0; KEY_U = 0; KEY_V = 0; KEY_W = 0; KEY_X = 0
KEY_Y = 0; KEY_Z = 0
KEY_0 = 0; KEY_1 = 0; KEY_2 = 0; KEY_3 = 0; KEY_4 = 0
KEY_5 = 0; KEY_6 = 0; KEY_7 = 0; KEY_8 = 0; KEY_9 = 0
KEY_SPACE = 0; KEY_RETURN = 0; KEY_ESCAPE = 0; KEY_BACKSPACE = 0; KEY_TAB = 0
KEY_DELETE = 0; KEY_INSERT = 0; KEY_HOME = 0
KEY_UP = 0; KEY_DOWN = 0; KEY_LEFT = 0; KEY_RIGHT = 0
KEY_PAGEUP = 0; KEY_PAGEDOWN = 0
KEY_LSHIFT = 0; KEY_RSHIFT = 0; KEY_LCTRL = 0; KEY_RCTRL = 0
KEY_LALT = 0; KEY_RALT = 0; KEY_LGUI = 0; KEY_RGUI = 0
KEY_CAPSLOCK = 0; KEY_SCROLLLOCK = 0; KEY_NUMLOCKCLEAR = 0; KEY_CLEAR = 0; KEY_MODE = 0
KEY_F1 = 0; KEY_F2 = 0; KEY_F3 = 0; KEY_F4 = 0; KEY_F5 = 0; KEY_F6 = 0
KEY_F7 = 0; KEY_F8 = 0; KEY_F9 = 0; KEY_F10 = 0; KEY_F11 = 0; KEY_F12 = 0
KEY_F13 = 0; KEY_F14 = 0; KEY_F15 = 0; KEY_F16 = 0; KEY_F17 = 0; KEY_F18 = 0
KEY_MINUS = 0; KEY_PLUS = 0; KEY_COMMA = 0; KEY_PERIOD = 0; KEY_SLASH = 0
KEY_SEMICOLON = 0; KEY_QUOTE = 0; KEY_QUOTEDBL = 0
KEY_HASH = 0; KEY_DOLLAR = 0; KEY_AMPERSAND = 0; KEY_ASTERISK = 0; KEY_EXCLAIM = 0
KEY_COLON = 0; KEY_LEFTPAREN = 0; KEY_RIGHTPAREN = 0
KEY_KP_0 = 0; KEY_KP_1 = 0; KEY_KP_2 = 0; KEY_KP_3 = 0; KEY_KP_4 = 0
KEY_KP_5 = 0; KEY_KP_6 = 0; KEY_KP_7 = 0; KEY_KP_8 = 0; KEY_KP_9 = 0
KEY_KP_DIVIDE = 0; KEY_KP_MULTIPLY = 0; KEY_KP_MINUS = 0; KEY_KP_PLUS = 0
KEY_KP_ENTER = 0; KEY_KP_PERIOD = 0; KEY_KP_EQUALS = 0

function nvgCreate(flags) return {} end
function nvgDelete(ctx) end
function nvgBeginFrame(ctx, w, h, ratio) end
function nvgEndFrame(ctx) end
function nvgSave(ctx) end
function nvgRestore(ctx) end
function nvgBeginPath(ctx) end
function nvgClosePath(ctx) end
function nvgMoveTo(ctx, x, y) end
function nvgLineTo(ctx, x, y) end
function nvgRect(ctx, x, y, w, h) end
function nvgRoundedRect(ctx, x, y, w, h, r) end
function nvgCircle(ctx, cx, cy, r) end
function nvgArc(ctx, cx, cy, r, a0, a1, dir) end
function nvgFill(ctx) end
function nvgStroke(ctx) end
function nvgFillColor(ctx, color) end
function nvgStrokeColor(ctx, color) end
function nvgFillPaint(ctx, paint) end
function nvgStrokeWidth(ctx, width) end
function nvgTranslate(ctx, tx, ty) end
function nvgRotate(ctx, angle) end
function nvgScale(ctx, sx, sy) end
function nvgScissor(ctx, x, y, w, h) end
function nvgRGBAf(r, g, b, a) return {} end
function nvgCreateFont(ctx, name, path) return 0 end
function nvgFontFaceId(ctx, fontId) end
function nvgFontSize(ctx, size) end
function nvgTextAlign(ctx, align) end
function nvgText(ctx, x, y, text, endPtr) return 0 end
function nvgTextBounds(ctx, x, y, text, endPtr) return 0, 0, 0, 0 end
function nvgCreateImage(ctx, filename, flags) return 0 end
function nvgImageSize(ctx, image) return 0, 0 end
function nvgImagePattern(ctx, ox, oy, ex, ey, img, angle, alpha) return {} end
function nvgImagePatternTinted(ctx, ox, oy, ex, ey, img, angle, color) return {} end
function nvgLinearGradient(ctx, sx, sy, ex, ey, startColor, endColor) return {} end
