# M0 Project Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ตั้งโปรเจกต์ Godot 4.7.2 ของ Ember Vigil ให้ export เป็นเว็บแบบปิด threads ได้ และพิสูจน์ด้วยหน้าแรกที่เปิดบนเบราว์เซอร์ได้จริง

**Architecture:** โปรเจกต์ Godot เปล่าที่ใช้ renderer Compatibility ความละเอียดฐาน 640×360 stretch `canvas_items`/`expand` หน้าแรกเป็น `main.tscn` ตัวเดียว (Node2D + CanvasLayer + Label) ที่แสดง FPS/เวอร์ชัน/renderer เพื่อให้มองออกด้วยตาว่า build ถูกต้อง คอนฟิกที่สำคัญต่อ web export ถูกล็อกด้วย GUT test ไม่ใช่ความทรงจำของคน

**Tech Stack:** Godot 4.7.2.stable (GDScript เท่านั้น), GUT 9.7.1, web export template `web_nothreads_release`, Python http.server + Playwright สำหรับตรวจผล

**Spec:** `docs/superpowers/specs/2026-10-30-m0-project-setup-design.md`

---

## File Structure

| ไฟล์ | หน้าที่ |
|---|---|
| `project.godot` | คอนฟิกเดียวของโปรเจกต์: renderer, ความละเอียด, stretch, input map |
| `icon.svg` | ไอคอนโปรเจกต์ (เปลวไฟ) ใช้ทั้งหน้าต่างและ web export |
| `main.tscn` | หน้าแรก M0: พื้นหลัง + ชื่อเกม + ข้อมูลวินิจฉัย |
| `main.gd` | หน้าที่เดียว — อัปเดตข้อความวินิจฉัยทุก 0.25 วิ (ของชั่วคราว แทนด้วย state switch ใน M2) |
| `export_presets.cfg` | preset `Web` แบบ `thread_support=false` |
| `tests/test_project_config.gd` | regression guard ของคอนฟิกที่ web build พึ่งพา |
| `.gitignore` | กัน `.godot/` และ `build/` ไม่ให้เข้า git |
| `CLAUDE.md` | เปลี่ยนชื่อจาก `CLAUDE_1.md` + แก้คำสั่งให้ตรงกับที่ทดสอบจริง |

**หมายเหตุลำดับงาน:** `project.godot` ถูกเขียนสองรอบโดยเจตนา — รอบแรกแค่ bootstrap ให้ Godot รู้จักโปรเจกต์ (Task 3) เพื่อให้ติดตั้ง GUT และเขียนเทสต์ได้ก่อน แล้วค่อยเติมค่า renderer/ความละเอียดใน Task 5 ด้วยวงจร TDD จริง (เทสต์แดงก่อน แล้วค่อยเขียนคอนฟิก)

**ข้อตกลงเรื่องคำสั่ง:** ทุกคำสั่งในแผนนี้ใช้ path เต็ม `/Applications/Godot.app/Contents/MacOS/Godot` และรันจาก root ของ repo (`/Users/ittichaib/Documents/GitHub/ember-vigil-games`)

---

### Task 1: เตรียม toolchain

**Files:** ไม่มีไฟล์ในโปรเจกต์เปลี่ยน

- [ ] **Step 1: ย้าย Godot ไป /Applications**

```bash
mv ~/Downloads/Godot.app /Applications/Godot.app
```

ถ้าคำสั่งถูกบล็อก (sandbox หรือสิทธิ์) ให้หยุดและขอให้เจ้าของเครื่องรันเองด้วย `! mv ~/Downloads/Godot.app /Applications/Godot.app` แล้วรอยืนยันก่อนไปต่อ ห้ามเปลี่ยนไปใช้ path ใน Downloads เพราะเจ้าของโปรเจกต์เลือกตัวเลือกนี้ไว้แล้ว

- [ ] **Step 2: ยืนยันเวอร์ชัน**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --version
```

Expected: `4.7.2.stable.official.ed1daf0bf`

- [ ] **Step 3: ยืนยัน export template ที่ต้องใช้**

```bash
ls ~/Library/Application\ Support/Godot/export_templates/4.7.2.stable/web_nothreads_release.zip
```

Expected: พิมพ์ path ออกมา ไม่ใช่ `No such file or directory` ถ้าหาย ให้หยุดและรายงาน (ต้องติดตั้ง export templates ของ 4.7.2 ก่อน ดาวน์โหลดจากเมนู Editor > Manage Export Templates)

---

### Task 2: จัดระเบียบ repo และ commit แรกของไฟล์ที่มีอยู่

**Files:**
- Create: `.gitignore`
- Rename: `CLAUDE_1.md` → `CLAUDE.md`

- [ ] **Step 1: สร้าง .gitignore**

```bash
cat > .gitignore <<'EOF'
# Godot 4
.godot/
/build/

# macOS
.DS_Store

# local-only
.claude/settings.local.json
*.tmp
EOF
```

`export_presets.cfg` **ไม่** อยู่ใน ignore list โดยเจตนา — preset ฝั่ง web ไม่มีข้อมูลลับ และ build ต้องทำซ้ำได้จากใน repo ถ้าวันหลังเพิ่ม preset Android/iOS ที่เก็บรหัส keystore ต้องย้าย preset ชุดนั้นออกจาก git

- [ ] **Step 2: เปลี่ยนชื่อไฟล์คำสั่ง**

```bash
git mv CLAUDE_1.md CLAUDE.md 2>/dev/null || mv CLAUDE_1.md CLAUDE.md
```

(ไฟล์ยังไม่อยู่ใน git เพราะ repo ยังไม่มี commit ของมัน `git mv` จึงอาจไม่ผ่าน — fallback เป็น `mv` ธรรมดา)

- [ ] **Step 3: commit**

```bash
git add .gitignore CLAUDE.md docs/design.md .vscode/
git commit -m "Add project instructions, design doc and gitignore"
```

ยังไม่ `git add .mcp.json` เพราะ path ในไฟล์เป็นค่าปลอม รอการตัดสินใจใน Task 10

---

### Task 3: Bootstrap โปรเจกต์ Godot ให้ Godot รู้จัก

**Files:**
- Create: `project.godot`
- Create: `icon.svg`

- [ ] **Step 1: เขียน project.godot ขั้นต่ำ**

```bash
cat > project.godot <<'EOF'
; Engine configuration file.
; It's best edited using the editor UI and not directly,
; since the parameters that go here are not all obvious.

config_version=5

[application]

config/name="Ember Vigil"
config/features=PackedStringArray("4.7")
config/icon="res://icon.svg"
EOF
```

ยังไม่ใส่ `run/main_scene` และค่า rendering/display — สองอย่างนั้นมาทีหลังผ่านวงจร TDD

- [ ] **Step 2: เขียน icon.svg**

```bash
cat > icon.svg <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <rect width="128" height="128" rx="18" fill="#140d14"/>
  <path d="M64 14c11 19 4 27 13 36 10 10 19 19 19 34 0 18-14 30-32 30s-32-12-32-30c0-14 8-22 14-32 6-9 6-21 18-38z" fill="#ff7a1a"/>
  <path d="M64 52c5 10 2 15 7 20 5 5 10 9 10 17 0 10-8 17-17 17s-17-7-17-17c0-7 4-11 7-16 4-5 4-11 10-21z" fill="#ffd34d"/>
</svg>
EOF
```

- [ ] **Step 3: import แล้วยืนยันว่าโปรเจกต์โหลดได้**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import 2>&1 | tail -20
```

Expected: ไม่มีบรรทัดที่ขึ้นต้นด้วย `ERROR:` หรือ `SCRIPT ERROR:` และเกิดโฟลเดอร์ `.godot/` พร้อมไฟล์ `icon.svg.import`

- [ ] **Step 4: commit**

```bash
git add project.godot icon.svg
git commit -m "Bootstrap Godot project with flame icon"
```

---

### Task 4: ติดตั้ง GUT 9.7.1

**Files:**
- Create: `addons/gut/**` (จาก upstream)
- Modify: `project.godot` (เปิด plugin)

- [ ] **Step 1: ดึง GUT ลงมาแล้วก๊อปแค่โฟลเดอร์ addon**

```bash
rm -rf /tmp/gut-src && git clone -q --depth 1 --branch v9.7.1 https://github.com/bitwes/Gut.git /tmp/gut-src
mkdir -p addons && cp -R /tmp/gut-src/addons/gut addons/gut
rm -rf /tmp/gut-src
cat addons/gut/plugin.cfg
```

Expected: แสดง `version="9.7.1"` — GUT สาย 9.x คือสายของ Godot 4.x

- [ ] **Step 2: เปิด plugin ใน project.godot**

เพิ่มท้ายไฟล์:

```bash
cat >> project.godot <<'EOF'

[editor_plugins]

enabled=PackedStringArray("res://addons/gut/plugin.cfg")
EOF
```

- [ ] **Step 3: import ใหม่เพื่อให้ Godot รู้จักคลาสของ GUT**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import 2>&1 | tail -20
```

Expected: ไม่มี `ERROR:` ขั้นนี้จำเป็นเพราะ `gut_cmdln.gd` จะเช็คว่าคลาสทั้งหมดถูก import แล้วหรือยัง ถ้ายังมันจะ quit ทันที

- [ ] **Step 4: ยืนยันว่า CLI รันได้ (ยังไม่มีเทสต์)**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1 | tail -20
```

Expected: GUT แสดงหัวข้อรายงานและจบด้วยจำนวนเทสต์ 0 (ไม่มีโฟลเดอร์ `tests/` ก็ยังถือว่าผ่านขั้นนี้) สิ่งที่ต้องไม่เจอคือ `SCRIPT ERROR` หรือข้อความว่าคลาสยัง import ไม่ครบ
**ถ้าขั้นนี้พังเพราะ GUT เข้ากับ Godot 4.7 ไม่ได้ ให้หยุดทั้ง task แล้วรายงานข้อความ error ตัวจริงพร้อมเสนอทางเลือก (ลองลด tag เป็น v9.6.1 หรือย้ายไป GdUnit4) ห้ามแก้โค้ดใน `addons/gut` และห้ามข้ามเทสต์เพื่อให้ผ่าน**

- [ ] **Step 5: commit**

```bash
git add addons/gut project.godot
git commit -m "Add GUT 9.7.1 test framework"
```

---

### Task 5: ล็อกคอนฟิก renderer และความละเอียดด้วย TDD

**Files:**
- Create: `tests/test_project_config.gd`
- Modify: `project.godot`

- [ ] **Step 1: เขียนเทสต์ที่ต้องแดง**

```bash
mkdir -p tests && cat > tests/test_project_config.gd <<'EOF'
extends GutTest

## Locks the project settings that the web build depends on.
## Switching to Forward+ or changing the base resolution silently breaks
## the browser demo, so these are asserted instead of remembered.


func test_renderer_is_gl_compatibility() -> void:
	var method: String = str(ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	assert_eq(method, "gl_compatibility", "web export requires the Compatibility renderer")


func test_project_godot_pins_mobile_renderer_to_gl_compatibility() -> void:
	# ProjectSettings does not expose feature-tagged overrides (".mobile") at
	# runtime, so the raw config line is asserted instead. Mobile browsers pick
	# the .mobile renderer, which must not fall back to Forward+ / Mobile.
	var text: String = FileAccess.get_file_as_string("res://project.godot")
	assert_string_contains(text, 'rendering_method.mobile="gl_compatibility"')


func test_base_viewport_is_640x360() -> void:
	assert_eq(int(ProjectSettings.get_setting("display/window/size/viewport_width")), 640)
	assert_eq(int(ProjectSettings.get_setting("display/window/size/viewport_height")), 360)


func test_stretch_is_canvas_items_expand() -> void:
	assert_eq(str(ProjectSettings.get_setting("display/window/stretch/mode")), "canvas_items")
	assert_eq(str(ProjectSettings.get_setting("display/window/stretch/aspect")), "expand")


func test_canvas_texture_filter_is_nearest() -> void:
	# 0 = Nearest in the "Nearest,Linear,Linear Mipmap,Nearest Mipmap" enum.
	# Pixel art must not be filtered.
	var filter: int = int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"))
	assert_eq(filter, 0)
EOF
```

- [ ] **Step 2: รันแล้วยืนยันว่าแดง**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import >/dev/null 2>&1
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1 | tail -30
```

Expected: FAIL — ทั้ง 5 เทสต์ตก เพราะ `project.godot` ยังไม่มีคีย์เหล่านี้ (`get_setting` คืน `null` → `str(null)` ไม่เท่ากับค่าที่ต้องการ)

- [ ] **Step 3: เติมคอนฟิกให้เทสต์ผ่าน**

แก้ `project.godot` ให้ `config/features` มี `GL Compatibility` และเพิ่มสองหมวดใหม่ ผลลัพธ์ที่ต้องได้คือไฟล์หน้าตาแบบนี้ (ส่วน `[editor_plugins]` จาก Task 4 ยังอยู่):

```ini
; Engine configuration file.
; It's best edited using the editor UI and not directly,
; since the parameters that go here are not all obvious.

config_version=5

[application]

config/name="Ember Vigil"
config/features=PackedStringArray("4.7", "GL Compatibility")
config/icon="res://icon.svg"

[display]

window/size/viewport_width=640
window/size/viewport_height=360
window/size/window_width_override=1280
window/size/window_height_override=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[editor_plugins]

enabled=PackedStringArray("res://addons/gut/plugin.cfg")

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/canvas_textures/default_texture_filter=0
```

`window_width_override`/`window_height_override` คือขนาดหน้าต่างตอนรันบนเครื่อง (1280×720) ขณะที่ viewport ยังเป็น 640×360 ตาม design.md

- [ ] **Step 4: รันแล้วยืนยันว่าเขียว**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1 | tail -15
```

Expected: PASS ทั้ง 5 เทสต์ รายงานลงท้ายด้วย `0 failing`

- [ ] **Step 5: commit**

```bash
git add project.godot tests/test_project_config.gd
git commit -m "Pin Compatibility renderer and 640x360 viewport with tests"
```

---

### Task 6: โครงสร้างโฟลเดอร์และ input map

**Files:**
- Create: `core/.gitkeep`, `data/**/.gitkeep`, `run/**/.gitkeep`, `meta/.gitkeep`, `ui/.gitkeep`
- Modify: `project.godot` (เพิ่ม `[input]`)

- [ ] **Step 1: สร้างโฟลเดอร์ตามผังใน CLAUDE.md**

```bash
for d in core data data/classes data/weapons data/passives data/enemies data/evolutions data/meta run run/weapons meta ui; do
  mkdir -p "$d" && touch "$d/.gitkeep"
done
find core data run meta ui -name .gitkeep | sort
```

Expected: 11 บรรทัด ตรงกับผังใน CLAUDE.md
ไม่สร้างไฟล์ `.gd` เปล่าล่วงหน้า — ไฟล์สคริปต์เกิดเมื่อมีโค้ดจริงใน M1 ขึ้นไป

- [ ] **Step 2: เพิ่ม input map**

เพิ่มหมวด `[input]` ท้าย `project.godot` (ต่อจาก `[rendering]`):

```ini

[input]

move_up={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":87,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194320,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
move_down={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":83,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194322,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
move_left={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":65,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194319,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
move_right={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":68,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194321,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
pause={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194305,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":80,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
toggle_debug={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194334,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
```

คีย์โค้ดที่ใช้: W=87 A=65 S=83 D=68 (physical_keycode เพื่อให้ถูกตำแหน่งบนคีย์บอร์ดทุกเลย์เอาต์), ลูกศร Left=4194319 Up=4194320 Right=4194321 Down=4194322, Escape=4194305, P=80, F3=4194334
ยังไม่ใส่ action เลือกการ์ด (`card_1..3`) เพราะหน้าจอเลเวลอัปเกิดใน M2

- [ ] **Step 2b: เพิ่มเทสต์ยืนยัน input map**

ต่อท้าย `tests/test_project_config.gd`:

```gdscript


func test_movement_and_system_actions_exist() -> void:
	var required: Array[String] = [
		"move_up", "move_down", "move_left", "move_right", "pause", "toggle_debug",
	]
	for action: String in required:
		assert_true(InputMap.has_action(action), "missing input action: %s" % action)
```

- [ ] **Step 3: รันเทสต์**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import >/dev/null 2>&1
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1 | tail -15
```

Expected: PASS ทั้ง 6 เทสต์ `0 failing` ถ้า `test_movement_and_system_actions_exist` ตก แปลว่าหมวด `[input]` วางผิดที่หรือ syntax เพี้ยน — แก้ไฟล์ ไม่ใช่แก้เทสต์

- [ ] **Step 4: commit**

```bash
git add project.godot tests/test_project_config.gd core data run meta ui
git commit -m "Add project folder structure and input map"
```

---

### Task 7: หน้าแรก main.tscn

**Files:**
- Create: `main.gd`
- Create: `main.tscn`
- Modify: `project.godot` (`run/main_scene`)
- Modify: `tests/test_project_config.gd`

- [ ] **Step 1: เขียนเทสต์ที่ต้องแดง**

ต่อท้าย `tests/test_project_config.gd`:

```gdscript


func test_main_scene_is_set_and_loadable() -> void:
	var main_scene: String = str(ProjectSettings.get_setting("application/run/main_scene"))
	assert_eq(main_scene, "res://main.tscn")
	assert_true(ResourceLoader.exists(main_scene), "main scene must exist on disk")
```

- [ ] **Step 2: รันแล้วยืนยันว่าแดง**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1 | tail -15
```

Expected: FAIL เฉพาะ `test_main_scene_is_set_and_loadable` (ยังไม่มีทั้งคีย์และไฟล์)

- [ ] **Step 3: เขียน main.gd**

```bash
cat > main.gd <<'EOF'
extends Node2D

## M0 placeholder screen.
##
## Its only job is to prove, from inside a browser, that the web build renders,
## the main loop runs and the project really uses the Compatibility renderer.
## Replaced by the Camp / Run / Results state switch in M2.

const REFRESH_INTERVAL: float = 0.25

@onready var _info_label: Label = $UI/InfoLabel

var _time_since_refresh: float = 0.0


func _ready() -> void:
	_refresh_info()


func _process(delta: float) -> void:
	_time_since_refresh += delta
	if _time_since_refresh < REFRESH_INTERVAL:
		return
	_time_since_refresh = 0.0
	_refresh_info()


func _refresh_info() -> void:
	var version: String = str(Engine.get_version_info().get("string", "unknown"))
	var renderer: String = str(ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	_info_label.text = "FPS %d\nGodot %s\n%s" % [
		Engine.get_frames_per_second(),
		version,
		renderer,
	]
EOF
```

- [ ] **Step 4: เขียน main.tscn**

```bash
cat > main.tscn <<'EOF'
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://main.gd" id="1_main"]

[node name="Main" type="Node2D"]
script = ExtResource("1_main")

[node name="UI" type="CanvasLayer" parent="."]

[node name="Background" type="ColorRect" parent="UI"]
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0.078, 0.051, 0.078, 1)

[node name="TitleLabel" type="Label" parent="UI"]
anchor_right = 1.0
anchor_bottom = 1.0
offset_top = -24.0
grow_horizontal = 2
grow_vertical = 2
theme_override_colors/font_color = Color(1, 0.627, 0.251, 1)
theme_override_font_sizes/font_size = 32
text = "EMBER VIGIL"
horizontal_alignment = 1
vertical_alignment = 1

[node name="SubtitleLabel" type="Label" parent="UI"]
anchor_right = 1.0
anchor_bottom = 1.0
offset_top = 28.0
grow_horizontal = 2
grow_vertical = 2
theme_override_colors/font_color = Color(0.639, 0.6, 0.667, 1)
theme_override_font_sizes/font_size = 12
text = "M0 — web export check"
horizontal_alignment = 1
vertical_alignment = 1

[node name="InfoLabel" type="Label" parent="UI"]
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -150.0
offset_top = -58.0
offset_right = -8.0
offset_bottom = -8.0
theme_override_colors/font_color = Color(0.478, 0.541, 0.569, 1)
theme_override_font_sizes/font_size = 11
text = "FPS -"
horizontal_alignment = 2
vertical_alignment = 2
EOF
```

- [ ] **Step 5: ตั้ง main scene ใน project.godot**

เพิ่มบรรทัด `run/main_scene="res://main.tscn"` ในหมวด `[application]` ให้หมวดนั้นเป็น:

```ini
[application]

config/name="Ember Vigil"
run/main_scene="res://main.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")
config/icon="res://icon.svg"
```

- [ ] **Step 6: import แล้วรันเทสต์**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import 2>&1 | grep -E "ERROR|SCRIPT ERROR" ; echo "import exit: $?"
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1 | tail -15
```

Expected: `grep` ไม่เจออะไร (exit 1 จาก grep คือดี) และเทสต์ PASS ทั้ง 7 ตัว `0 failing`

- [ ] **Step 7: รันหน้าจอจริงบนเดสก์ท็อปสั้น ๆ**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . --quit-after 180 2>&1 | tail -20
```

Expected: ไม่มี `SCRIPT ERROR` หน้าต่างเปิดแล้วปิดเองหลัง 180 เฟรม
ถ้าเจอ `Node not found: "UI/InfoLabel"` แปลว่าชื่อหรือลำดับชั้นใน `main.tscn` ไม่ตรงกับ path ใน `main.gd` — แก้ไฟล์ scene

- [ ] **Step 8: commit**

```bash
git add main.gd main.tscn project.godot tests/test_project_config.gd
git commit -m "Add M0 placeholder main scene with diagnostics readout"
```

---

### Task 8: Web export preset และ build

**Files:**
- Create: `export_presets.cfg`
- Output: `build/web/**` (ไม่เข้า git)

- [ ] **Step 1: เขียน export preset**

```bash
cat > export_presets.cfg <<'EOF'
[preset.0]

name="Web"
platform="Web"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="build/web/index.html"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.0.options]

custom_template/debug=""
custom_template/release=""
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=false
vram_texture_compression/for_mobile=false
html/export_icon=true
html/custom_html_shell=""
html/head_include=""
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=false
progressive_web_app/enabled=false
EOF
```

- `variant/thread_support=false` คือหัวใจของ M0 — ทำให้ build ไม่ต้องใช้ `SharedArrayBuffer` จึงไม่ต้องตั้ง header `Cross-Origin-Opener-Policy` / `Cross-Origin-Embedder-Policy` บนโฮสต์ และอัปขึ้น itch.io ได้ตรง ๆ
- `html/canvas_resize_policy=2` = adaptive เหมาะกับการฝังใน iframe ของ itch.io
- `vram_texture_compression/*=false` เพราะเกมเป็น 2D พิกเซลอาร์ต ไม่ต้องมี texture variant บีบอัดมาถ่วงขนาดไฟล์

- [ ] **Step 2: export**

```bash
mkdir -p build/web
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Web" build/web/index.html 2>&1 | tail -20
```

Expected: ลงท้ายด้วยข้อความว่า export สำเร็จ ไม่มี `ERROR:` ถ้าบอกว่าหา export template ไม่เจอ ให้ย้อนไปเช็ค Task 1 Step 3

- [ ] **Step 3: ตรวจไฟล์ที่ออกมา**

```bash
ls -la build/web/
echo "--- worker check ---"
ls build/web/ | grep -c "worker.js" || true
```

Expected:
- มี `index.html`, `index.wasm`, `index.pck`, `index.js`, `index.audio.worklet.js`, `index.icon.png`, `index.apple-touch-icon.png`
- บรรทัดหลัง `--- worker check ---` ต้องเป็น `0` — การมี `index.worker.js` หมายถึง build เปิด threads ซึ่งแปลว่า preset ไม่ถูกใช้ ให้หยุดและแก้
- `index.audio.worklet.js` **ไม่ใช่** worker ตัวนั้น มันต้องมีอยู่เป็นเรื่องปกติ

- [ ] **Step 4: commit**

```bash
git add export_presets.cfg
git commit -m "Add Web export preset without thread support"
```

(`build/` ถูก ignore ไว้แล้วจาก Task 2 จึงไม่เข้า commit)

---

### Task 9: ตรวจบนเบราว์เซอร์จริง

**Files:**
- Output: `build/web.zip`

- [ ] **Step 1: เสิร์ฟ build**

```bash
python3 -m http.server 8000 -d build/web
```

ต้องรันแบบ background (`run_in_background: true`) เพราะคำสั่งนี้ไม่จบเอง

- [ ] **Step 2: เปิดด้วย Playwright แล้วรอให้ engine บูต**

ใช้ MCP tool: `browser_navigate` ไปที่ `http://localhost:8000/index.html` แล้ว `browser_wait_for` ประมาณ 10 วินาที (Godot web ต้องโหลด wasm + pck ก่อนจะวาดเฟรมแรก)

- [ ] **Step 3: อ่าน console**

ใช้ `browser_console_messages`

Expected: ไม่มี message ระดับ `error` ข้อความที่ยอมรับได้คือ log ปกติของ Godot (เช่นบรรทัดบอกเวอร์ชันหรือ WebGL) ถ้าเจอ error เกี่ยวกับ `SharedArrayBuffer` แปลว่า build ยังเปิด threads — กลับไป Task 8

- [ ] **Step 4: เก็บ screenshot**

ใช้ `browser_take_screenshot`

Expected: เห็นพื้นหลังเข้ม ข้อความ "EMBER VIGIL" สีส้มกลางจอ บรรทัด "M0 — web export check" ใต้ชื่อ และมุมขวาล่างแสดง FPS / `Godot 4.7.2.stable` / `gl_compatibility`
**ถ้ามุมขวาล่างขึ้นค่าอื่นที่ไม่ใช่ `gl_compatibility` ถือว่า M0 ไม่ผ่าน**

- [ ] **Step 5: ปิด server แล้วทำ zip สำหรับ itch.io**

```bash
cd build/web && zip -q -r ../web.zip . && cd - && ls -lh build/web.zip
```

itch.io ต้องการ `index.html` อยู่ที่ราก zip ซึ่งคำสั่งนี้ให้ผลตามนั้น
**การอัปโหลดขึ้น itch.io เป็นงานของเจ้าของโปรเจกต์ ห้าม agent ไปแตะบัญชีหรือ API ของ itch.io**

- [ ] **Step 6: ขอให้เจ้าของโปรเจกต์ตรวจ Safari**

รายงานกลับว่าต้องเปิด `http://localhost:8000/index.html` ใน Safari เอง (เครื่องมืออัตโนมัติคุม Safari ไม่ได้) และเงื่อนไขผ่านของ design.md M0 คือ "เปิดได้ใน Chrome และ Safari" จึงยังไม่ปิด milestone จนได้คำยืนยัน

---

### Task 10: อัปเดต CLAUDE.md ให้ตรงกับความจริง

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: แก้หมวด Tech stack**

เปลี่ยนบรรทัดเวอร์ชันจาก `Godot 4 (ใช้เวอร์ชัน stable ล่าสุด ตั้งแต่ 4.5 ขึ้นไป)` เป็น:

```markdown
- Godot **4.7.2.stable** (pin ไว้เพราะ export templates ที่ติดตั้งในเครื่องเป็นเวอร์ชันนี้)
```

และเพิ่มบรรทัดต่อท้ายรายการ:

```markdown
- Unit test: GUT 9.7.1 (`addons/gut`) — รองรับ JUnit XML ผ่าน `-gjunit_xml_file` ถ้าวันหลังทำ CI
```

(แทนบรรทัด `- Unit test: GUT (addons/gut)` เดิม)

- [ ] **Step 2: แก้หมวด Commands ให้เป็นคำสั่งที่ทดสอบแล้ว**

แทนทั้งบล็อกด้วย:

```markdown
บน macOS ตัวโปรแกรมอยู่ที่ `/Applications/Godot.app/Contents/MacOS/Godot` ตั้ง alias ได้ด้วย
`alias godot="/Applications/Godot.app/Contents/MacOS/Godot"`

```bash
# import และเช็คว่าโปรเจกต์โหลดได้ไม่มี error
godot --headless --path . --import

# รันเทสต์ทั้งหมด
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit

# export เวอร์ชันเว็บ
godot --headless --path . --export-release "Web" build/web/index.html

# เปิดเวอร์ชันเว็บในเครื่อง แล้วเข้า http://localhost:8000
python3 -m http.server 8000 -d build/web

# ทำ zip สำหรับอัปขึ้น itch.io (index.html ต้องอยู่ที่รากของ zip)
cd build/web && zip -r ../web.zip . && cd -
```

ถ้าแก้คอนฟิกที่กระทบ web export ให้เช็คว่า `build/web/` **ไม่มี** ไฟล์ `index.worker.js` — ถ้ามีแปลว่า thread support ถูกเปิดโดยไม่ได้ตั้งใจ และจะต้องตั้ง COOP/COEP header บนโฮสต์ซึ่ง itch.io ทำให้ไม่ได้
```

- [ ] **Step 3: ถามเรื่อง .mcp.json**

ถามเจ้าของโปรเจกต์ว่า `godot-mcp` ที่ชี้ไป `/path/เต็ม/ไปที่/Godot-MCP/server/dist/index.js` จะลบทิ้ง หรือมีไฟล์จริงอยู่ที่ไหน แล้วทำตามคำตอบ ห้ามเดา path

- [ ] **Step 4: commit**

```bash
git add CLAUDE.md
git commit -m "Update commands and pinned Godot version to match verified setup"
```

---

## เกณฑ์ปิด M0

| # | เกณฑ์ | หลักฐาน |
|---|---|---|
| 1 | โปรเจกต์โหลดได้ | Task 7 Step 6 — import ไม่มี error |
| 2 | เทสต์ผ่าน | Task 7 Step 6 — GUT `0 failing` 7 เทสต์ |
| 3 | web build nothreads | Task 8 Step 3 — ไม่มี `index.worker.js` |
| 4 | เปิดบน Chromium ได้ | Task 9 Step 3–4 — console ไม่มี error + screenshot เห็น `gl_compatibility` |
| 5 | เปิดบน Safari ได้ | เจ้าของโปรเจกต์ยืนยันเอง |
| 6 | พร้อมอัป itch.io | `build/web.zip` |

ข้อ 5 และ 6 ต้องรออินพุตจากคน — agent ปิด milestone เองไม่ได้
