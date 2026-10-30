# M0 — Project Setup + Web Export (Design Spec)

- สถานะ: อนุมัติแล้ว 2026-10-30
- ขอบเขต: Milestone M0 ใน `docs/design.md` §13
- เงื่อนไขผ่านตามเอกสารต้นทาง: "ตั้งโปรเจกต์ + export เว็บหน้าเปล่า — เปิดได้ใน Chrome และ Safari"

## 1. เป้าหมาย

ตั้งโปรเจกต์ Godot ให้พร้อมสำหรับ M1 โดยพิสูจน์ให้ได้ว่า **สายการผลิตจากซอร์สถึงเว็บทำงานจริง** ก่อนจะมีโค้ดเกมแม้แต่บรรทัดเดียว
สิ่งที่ต้องพิสูจน์: renderer Compatibility ถูกใช้จริง, web export แบบปิด threads build ผ่าน, หน้าเกมขึ้นบนเบราว์เซอร์โดยไม่มี console error

สิ่งที่ **ไม่** อยู่ในขอบเขต: ผู้เล่น ศัตรู อาวุธ UI จริง เสียง และการอัปโหลดขึ้น itch.io

## 2. การตัดสินใจที่ล็อกแล้ว

| เรื่อง | ค่าที่เลือก | เหตุผล |
|---|---|---|
| Godot | 4.7.2.stable ย้ายไป `/Applications/Godot.app` | เป็นเวอร์ชันที่มี export templates ติดตั้งอยู่แล้ว และทำให้คำสั่งใน CLAUDE.md ใช้ได้ตามที่เขียน |
| เฟรมเวิร์กเทสต์ | GUT (`addons/gut`) | เทสต์ทั้งหมดที่ design.md §Testing ระบุเป็น logic ล้วน ไม่ต้องจำลอง input จึงไม่ต้องใช้ `scene_runner` ของ GdUnit4 และตรงกับที่ CLAUDE.md อ้างอิงไว้แล้ว |
| หน้าแรก | Label + FPS + เวอร์ชัน + renderer | จอดำแยกไม่ออกจาก build เสีย ต้องมีข้อมูลบนจอที่ยืนยันคอนฟิกได้ด้วยตา |
| ไฟล์คำสั่ง | `git mv CLAUDE_1.md CLAUDE.md` | ชื่อเดิม Claude Code ไม่โหลดอัตโนมัติ |

## 3. สภาพแวดล้อมจริง (สำรวจแล้ว 2026-10-30)

- Godot 4.7.2.stable อยู่ที่ `~/Downloads/Godot.app` (มี 4.6.2 zip ค้างอยู่ด้วย) → ย้ายไป `/Applications`
- `~/Library/Application Support/Godot/export_templates/4.7.2.stable/` มีเฉพาะชุด web ครบ 8 ไฟล์ รวม `web_nothreads_release.zip` → เพียงพอสำหรับ M0 แต่ export desktop ยังทำไม่ได้
- ยืนยันชื่อ export option จาก binary 4.7.2 แล้ว: `variant/thread_support`, `variant/extensions_support`, `html/canvas_resize_policy`, `html/focus_canvas_on_start`, `html/export_icon`
- repo ยังไม่มี commit (`main` ว่าง)
- `.mcp.json` ชี้ godot-mcp ไปที่ path ปลอม `/path/เต็ม/ไปที่/Godot-MCP/...` → ต้องถามเจ้าของโปรเจกต์ ไม่บล็อก M0

## 4. ส่วนประกอบที่จะสร้าง

### 4.1 `project.godot`

| คีย์ | ค่า |
|---|---|
| `application/config/name` | `Ember Vigil` |
| `application/run/main_scene` | `res://main.tscn` |
| `application/config/icon` | `res://icon.svg` |
| `rendering/renderer/rendering_method` | `gl_compatibility` |
| `rendering/renderer/rendering_method.mobile` | `gl_compatibility` |
| `display/window/size/viewport_width` / `viewport_height` | `640` / `360` |
| `display/window/size/window_width_override` / `window_height_override` | `1280` / `720` |
| `display/window/stretch/mode` | `canvas_items` |
| `display/window/stretch/aspect` | `expand` |
| `rendering/textures/canvas_textures/default_texture_filter` | `0` (nearest) |

Input map (ตาม design.md §3 เท่าที่ตัดสินแล้ว ส่วนการเลือกการ์ดรอ M2):

| action | ปุ่ม |
|---|---|
| `move_up` / `move_down` / `move_left` / `move_right` | W/A/S/D + ลูกศร |
| `pause` | Esc, P |
| `toggle_debug` | F3 |

### 4.2 โครงสร้างโฟลเดอร์

สร้างตามผังใน CLAUDE.md พร้อม `.gitkeep` ในโฟลเดอร์ว่าง:

```
core/  data/{classes,weapons,passives,enemies,evolutions,meta}/
run/{weapons}/  meta/  ui/  tests/
```

ไม่สร้างไฟล์สคริปต์เปล่าล่วงหน้า — ไฟล์เกิดเมื่อมีโค้ดจริงใน M1 ขึ้นไป

### 4.3 `export_presets.cfg` — preset ชื่อ `Web`

ค่าที่สำคัญต่อข้อนี้:

```
platform="Web"
runnable=true
export_path="build/web/index.html"
variant/thread_support=false        # หัวใจของ M0
variant/extensions_support=false
html/canvas_resize_policy=2         # adaptive เหมาะกับ iframe ของ itch.io
html/focus_canvas_on_start=true
html/export_icon=true
progressive_web_app/enabled=false
```

`variant/thread_support=false` ทำให้ build ไม่ต้องใช้ `SharedArrayBuffer` จึงไม่ต้องตั้ง header `Cross-Origin-Opener-Policy` / `Cross-Origin-Embedder-Policy` บนโฮสต์ — เป็นเงื่อนไขที่ทำให้อัปขึ้น itch.io ได้ตรง ๆ

ไฟล์นี้ **commit ลง git** เพราะฝั่ง web ไม่มีข้อมูลลับ ถ้าวันหลังเพิ่ม preset Android/iOS ที่เก็บรหัส keystore ต้องย้ายไฟล์ออกจาก git แล้ว ignore

### 4.4 `main.tscn` + `main.gd`

```
Main (Node2D)
└─ UI (CanvasLayer)
   ├─ TitleLabel     กลางจอ: "EMBER VIGIL"
   ├─ SubtitleLabel  "M0 — web export check"
   └─ InfoLabel      มุมขวาล่าง: FPS / Godot version / renderer ที่ใช้จริง
```

`main.gd` มีหน้าที่เดียว: อัปเดต `InfoLabel` ทุก 0.25 วินาที จาก `Engine.get_frames_per_second()`,
`Engine.get_version_info()` และค่า `rendering/renderer/rendering_method` ที่อ่านจาก `ProjectSettings`
ไฟล์นี้เป็นของชั่วคราวสำหรับ M0 และจะถูกแทนด้วย state switch (Camp/Run/Results) ใน M2

`icon.svg`: ไอคอนเปลวไฟเรียบ ๆ วาดเอง ไม่ต้องพึ่ง asset ภายนอก

### 4.5 GUT + เทสต์ตัวแรก

- ติดตั้ง `addons/gut` จาก GitHub ที่ tag ซึ่งรองรับ Godot 4.x
- เปิด plugin ใน `project.godot` (`editor_plugins/enabled`)
- `tests/test_project_config.gd` (extends `GutTest`) ยืนยันคอนฟิกที่ M0 ต้องไม่หลุด:
  - `rendering_method` และ `rendering_method.mobile` = `gl_compatibility`
  - viewport = 640 × 360
  - stretch mode = `canvas_items`, aspect = `expand`
  - main scene = `res://main.tscn`

เทสต์นี้ไม่ใช่ dummy — มันคือ regression guard ว่าไม่มีใครสลับ renderer กลับไป Forward+ ซึ่งจะพัง web export ทันที

**ความเสี่ยงที่รู้ตัว:** GUT ยังไม่ประกาศรองรับ Godot 4.7 อย่างเป็นทางการ ถ้ารันแล้วพัง ให้รายงานกลับพร้อมทางเลือก (เปลี่ยน tag / ย้ายไป GdUnit4) ห้ามแก้ให้ผ่านแบบกลบปัญหา

### 4.6 `.gitignore`

ignore: `.godot/`, `build/`, `.DS_Store`, `*.tmp`, `.claude/settings.local.json`
commit: `addons/`, `export_presets.cfg`, `.vscode/`

`.mcp.json` ยังไม่ commit ใน M0 จนกว่าจะตัดสินเรื่อง godot-mcp ตาม §7

## 5. เกณฑ์ผ่าน (ต้องมีหลักฐานของจริงทุกข้อ)

| # | เกณฑ์ | วิธีพิสูจน์ |
|---|---|---|
| 1 | โปรเจกต์โหลดได้ | `godot --headless --path . --import` ไม่มี error |
| 2 | เทสต์ผ่าน | `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` |
| 3 | web build ออกครบ | มี `index.html .wasm .pck .js .audio.worklet.js` และ **ไม่มี** `*.worker.js` (ยืนยัน nothreads) |
| 4 | เปิดบน Chromium ได้ | เสิร์ฟด้วย `python3 -m http.server` แล้วตรวจด้วย Playwright: canvas ขึ้น + console ไม่มี error + เก็บ screenshot |
| 5 | เปิดบน Safari ได้ | เจ้าของโปรเจกต์ตรวจเอง (ควบคุม Safari ด้วยเครื่องมือไม่ได้) |
| 6 | พร้อมอัป itch.io | สร้าง `build/web.zip` ให้ — การอัปโหลดเป็นงานของเจ้าของโปรเจกต์ |

## 6. งานเอกสารที่ทำพร้อมกัน

- `git mv CLAUDE_1.md CLAUDE.md`
- แก้ CLAUDE.md: pin Godot 4.7.2, path binary ที่ถูกต้อง, คำสั่งทุกบรรทัดต้องรันได้จริงตามที่ทดสอบใน M0
- ถามเรื่อง `.mcp.json` (ลบ หรือชี้ไป Godot-MCP ตัวจริง)

## 7. คำถามที่เปิดอยู่

- godot-mcp จะใช้ต่อไหม ถ้าใช้ไฟล์จริงอยู่ที่ไหน
- สไตล์ภาพ (design.md §15) ยังไม่ตัดสิน — ไม่บล็อก M0 เพราะตั้ง texture filter เป็น nearest ไว้แล้วซึ่งปลอดภัยกับพิกเซลอาร์ตทุกขนาด
