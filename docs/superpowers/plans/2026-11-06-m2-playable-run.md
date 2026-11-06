# M2 — หนึ่งรอบที่เล่นจบได้ Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** เล่นจบหนึ่งรอบด้วย Knight ได้ครบวงจร Camp → Run → Results → Camp โดยมี XP gem, เลเวลอัปเลือกการ์ด และอาวุธ Greatsword / Shield Bash / Warhorn

**Architecture:** `run.gd` ยังเป็นเจ้าของลำดับต่อเฟรม (ระบบลูกไม่มี `_physics_process`) อาวุธเป็น `RefCounted` เรียก API สาธารณะของ `EnemySystem` (`query_radius`, `damage`, `knockback`, `stun`) ผ่าน `WeaponContext.deal_damage()` จุดเดียว `RunState` เป็นแหล่งความจริงของ XP เลเวลและบิลด์ UI ฟัง signal อย่างเดียว และ `main.gd` เป็น state machine ของ 3 หน้า

**Tech Stack:** Godot 4.7.2 GDScript (static type), GUT 9.7.1, renderer Compatibility

**Spec:** `docs/superpowers/specs/2026-11-06-m2-playable-run-design.md` (อ่านคู่กัน ตัวเลขอาวุธอยู่หัวข้อ 5.2 ของ spec และหัวข้อ 5 ของ `docs/design.md`)

## Global Constraints

- GDScript เท่านั้น ใส่ static type ทุกที่ (`var hp: float = 0.0`, `func f(x: int) -> void`) ไฟล์ `snake_case.gd` คลาส `PascalCase` ค่าคงที่ `UPPER_CASE` ไฟล์เกิน ~300 บรรทัดให้พิจารณาแยก
- **ห้ามสร้าง Node ต่อศัตรู ต่อกระสุน ต่อ XP gem หรือต่อเอฟเฟกต์การโจมตี** ห้ามใช้ `Area2D`/physics body กับศัตรู ทุกอย่างที่เกิดบ่อยผ่าน `Pool` ห้าม allocate (Array/Dictionary ใหม่) ในลูปต่อเฟรมของระบบหลัก
- **ห้ามส่ง `Packed*Array` ออกจากระบบ** ให้รับ buffer เข้ามาเติม หรือใช้ getter ต่อ id (กฎ copy-on-write ใน CLAUDE.md)
- ตัวเลข gameplay ทุกตัวอยู่ใน `.tres` ใต้ `data/` (อาวุธใน `WeaponDef`, ค่ารวมใน `RunTuning`) ห้าม hardcode ในสคริปต์ ถ้าแก้ตัวเลข ต้องแก้ตารางใน `docs/design.md` ให้ตรงด้วย
- ระบบสื่อสารกันด้วย signal UI ฟัง signal อย่างเดียว ห้ามแก้ค่าของระบบเกมตรง ๆ (การเลือกการ์ดคือ signal `card_picked` ที่ Run เป็นคนนำไปใช้)
- `.tres` เขียนด้วยมือโดยใส่**ทุกฟิลด์ชัดเจนรวมค่าศูนย์** เพราะ `ResourceSaver` ไม่เก็บค่า default ห้ามพึ่งค่า default ในสคริปต์ แล้วให้เทสต์โหลดไฟล์ตรวจค่าตามตาราง
- headless renderer ไม่เก็บข้อมูล MultiMesh อ่านกลับด้วย `get_instance_transform_2d` ไม่ได้ ให้เทสต์ผ่านฟังก์ชันที่คืน transform (เช่น `transform_of`) แล้วตรวจการวาดจริงบน renderer จริงเมื่อจำเป็น
- ไม่ commit `build/`, `.godot/` และ**ไม่ stage `project.godot`**: ไฟล์นี้มีการแก้ที่ยังไม่ commit ของผู้ใช้ (คอมเมนต์หัวไฟล์ที่ Godot เติม + บรรทัด `default_texture_filter=0`) ที่ผู้ใช้ยังไม่ได้ตัดสินใจ ห้ามแก้ `project.godot` ในแผนนี้ (หน้าเลือกการ์ดจับคีย์ 1/2/3 เองใน `_unhandled_input`; หยุดเกมใช้ action `pause` ที่มีอยู่แล้ว)
- ห้ามเริ่ม sub-task ถัดไปโดยผู้ใช้ไม่สั่ง ห้าม merge PR ห้ามแตะ `main`

### ขั้นตอนมาตรฐาน (อ้างถึงจากทุก task)

Godot ในเครื่องนี้คือ `/d/Godot_v4.7.2-stable_win64.exe` (ตั้ง `G=` ให้เป็นค่านี้ใน bash)

**Verify:** รันสองคำสั่งนี้แล้วอ่านผลจริง
```bash
$G --headless --path . --import 2>&1 | grep -iE "error"        # ต้องไม่มีบรรทัดใดออกมา
$G --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1 | grep -E "Passing|Failing|SCRIPT ERROR|Parse"
```
เพื่อรันเทสต์ไฟล์เดียวให้เติม `-gselect=test_<ชื่อไฟล์ไม่มี .gd>` ผ่านต้องไม่มี `Failing Tests` และไม่มี `SCRIPT ERROR`

**Finish `<ID>: <ข้อความ>`:**
1. คืนไฟล์ `.import` ที่ Godot แก้เฉพาะ line ending: `git status --short | grep '\.import$' | awk '{print $2}' | xargs -r git checkout --`
2. ติ๊ก ✅ หน้ารหัสงานใน `docs/roadmap.md` และติ๊ก `- [ ]` ของ task นี้ในไฟล์ plan นี้ (ถ้าต่างจากแผน เพิ่มบรรทัด `> **สถานะ:**` ใต้หัวข้อ task) ไฟล์เอกสารเหล่านี้ใช้ CRLF ให้แก้ด้วยสคริปต์ที่เปิดแบบ `newline=''`
3. `git add` เฉพาะไฟล์ของ task (ห้าม `git add -A`) แล้ว commit ข้อความ `<ID>: <ข้อความ>` ปิดท้ายด้วยบรรทัด `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`
4. `git push origin development` แล้ว `git push origin HEAD:refs/heads/feature/<id>-<slug>`
5. เปิด PR แบบ draft เข้า `main` (`gh pr create --draft --base main --head <branch>`) body ระบุ: ทำอะไร ตรวจอย่างไร (ผลจริงของสองคำสั่งข้างบน) ข้อไหนใน roadmap ที่ติ๊ก ลำดับ merge (PR แบบซ้อน: oldest first) และข้อที่ยังไม่ได้ทำ ปิดท้ายด้วย `🤖 Generated with [Claude Code](https://claude.com/claude-code)`
6. รายงาน commit, ลิงก์ PR, ผล Verify และสิ่งที่ไม่ได้ทำ แล้วหยุดรอคำสั่ง

## Review Focus

ห้าอินพุต/เงื่อนไขที่ spec บอกเป็นนัยแต่ไม่มีเทสต์ใดครอบเอง (เรียงตามโอกาสเกิดมากสุด) แต่ละข้อมีเทสต์ใน task ที่ระบุ:

1. **เก็บ gem ก้อนใหญ่หรือหลาย gem ในเฟรมเดียว** ขึ้นหลายเลเวลต้องแสดงการ์ดต่อเนื่องทีละใบ ไม่ตกหล่น (Task 8, Task 23)
2. **ช่อง gem เต็ม** XP ต้องไม่หาย (Task 20, Task 28)
3. **กด Esc/P ระหว่างเลือกการ์ด หรือหลังผู้เล่นตาย** ต้องไม่เปิดหน้าหยุดเกมซ้อนและไม่ทำให้สถานะรวน (Task 28)
4. **ช่องอาวุธเต็ม หรือไม่มีตัวเลือกจริงเหลือ** ต้องไม่เสนอของใหม่เมื่อเต็ม และต้องเติมการ์ดสำรองจนครบ 3 ใบ (Task 21)
5. **เริ่มรอบใหม่หลายครั้งติดกัน** รอบที่สองและสามเริ่มที่เวลา 0 เลเวล 1 ไม่มีศัตรู gem อาวุธ หรือบัฟของรอบก่อนค้าง (Task 29)

---

## ลำดับงาน

| Task | รหัส roadmap | งาน |
|---|---|---|
| 1 | M2-27 (ใหม่) | ตัวเลขใหม่ลง design.md + RunTuning + เพิ่มงานใหม่ลง roadmap |
| 2 | M2-4 | `WeaponDef` / `WeaponLevelDef` + ฟิลด์ใหม่ของ `ClassDef` |
| 3 | M2-22 (ใหม่) | `EnemySystem.query_radius` + `damage` |
| 4 | M2-8 | knockback |
| 5 | M2-23 (ใหม่) | stun |
| 6 | M2-1 | `RunState` แกน: เวลา kills ช่องบิลด์ signal |
| 7 | M2-2 | XP curve + XP ล้น |
| 8 | M2-15 | คิวเลเวลอัปใน `RunState` |
| 9 | M2-21 | ติดตามดาเมจรวมต่ออาวุธ |
| 10 | M2-18 | สูตร Embers |
| 11 | M2-26 (ใหม่) | `StatBlock` ขนาดเล็ก + `Player.heal` |
| 12 | M2-28 (ใหม่) | `FxLayer` |
| 13 | M2-5 | `WeaponBase` + `WeaponContext` + `WeaponLoadout` |
| 14 | M2-6 | Greatsword LV1 |
| 15 | M2-7 | Greatsword LV2–5 |
| 16 | M2-9 | Oathguard ดูดเลือด |
| 17 | M2-24 (ใหม่) | Shield Bash LV1–5 |
| 18 | M2-25 (ใหม่) | Warhorn LV1–5 |
| 19 | M2-10 | `PickupSystem` โครง |
| 20 | M2-11 | ดูด/เก็บ gem + ช่องเต็ม |
| 21 | M2-12 | `LevelUpDeck` + `Rng.weighted_pick` |
| 22 | M2-13 | การ์ดสำรอง |
| 23 | M2-14 | `LevelUpPanel` |
| 24 | M2-16 | `HUD` |
| 25 | M2-17 | `PauseScreen` |
| 26 | M2-19 | `RunSummary` + `ResultsScreen` |
| 27 | M2-20 | `CampScreen` |
| 28 | M2-29 (ใหม่) | ต่อทุกระบบเข้า `Run` + สถานะของรอบ |
| 29 | M2-3 | state machine Camp → Run → Results ใน `main` |
| 30 | M2-30 (ใหม่) | overlay แสดงเวลาขั้นใหม่ + F4 ให้อาวุธครบ |
| 31 | M2-31 (ใหม่) | ปิด M2: เล่นจริง วัด perf export เว็บ |

---

### Task 1 (M2-27): ตัวเลขใหม่ลง design.md + RunTuning + งานใหม่ลง roadmap

**Files:**
- Modify: `data/run_tuning.gd`, `data/tuning/run_tuning.tres`, `tests/test_run_tuning.gd`, `docs/design.md`, `docs/roadmap.md`

**Interfaces:**
- Produces: ฟิลด์ใหม่ของ `RunTuning` — `xp_base: float = 5.0`, `xp_per_level: float = 4.5`, `embers_kills_divisor: int = 10`, `embers_seconds_divisor: int = 15`, `knockback_duration: float = 0.2`, `gem_pull_speed: float = 180.0`, `gem_capacity: int = 512`, `gem_radius: float = 3.0`

- [x] **Step 1: เพิ่มเทสต์ใน `tests/test_run_tuning.gd`** ให้ `test_run_tuning_matches_the_design_numbers` ตรวจเพิ่ม:
```gdscript
assert_eq(tuning.xp_base, 5.0)
assert_eq(tuning.xp_per_level, 4.5)
assert_eq(tuning.embers_kills_divisor, 10)
assert_eq(tuning.embers_seconds_divisor, 15)
assert_eq(tuning.knockback_duration, 0.2)
assert_eq(tuning.gem_pull_speed, 180.0)
assert_eq(tuning.gem_capacity, 512)
assert_eq(tuning.gem_radius, 3.0)
```
- [x] **Step 2: Verify (ต้องตก)** เพราะยังไม่มีฟิลด์
- [x] **Step 3: เพิ่มฟิลด์ลง `data/run_tuning.gd` และเขียนค่าชัดเจนลง `run_tuning.tres`** ใน `docs/design.md` เพิ่มย่อหน้า "**ค่าปรับจูนของ M2**" ต่อท้ายหัวข้อ 9: หน่วยผลัก "ผลัก N" = ระยะ N px รวม ส่งเป็นความเร็วที่ลดลงเป็นศูนย์ใน 0.2 วิ, XP gem ดูดที่ 180 px/s เมื่ออยู่ในรัศมีเก็บ เก็บเมื่อแตะตัว มีได้ 512 อัน เต็มแล้วให้ XP ทันที, เลเวลไม่มีเพดาน และเพิ่มในตารางหัวข้อ 5 ว่า Warhorn ไม่มีดาเมจ บัฟคือตัวคูณดาเมจทุกอาวุธของผู้เล่น ยิงซ้ำรีเซ็ตเวลาไม่ซ้อน ใน `docs/roadmap.md` เพิ่มแถวใต้ M2 (หลัง M2-21 ใช้รูปแบบตารางเดิม คอลัมน์ `# | งาน | ไฟล์ | T | ขนาด`): M2-22 `EnemySystem.query_radius` + `damage` (T, S) · M2-23 stun ใน EnemySystem (T, S) · M2-24 Shield Bash LV1–5 (T, M) · M2-25 Warhorn LV1–5 (T, M) · M2-26 `StatBlock` ขนาดเล็ก (ตัวคูณดาเมจชั่วคราว) + `Player.heal` (T, S) · M2-27 ตัวเลขใหม่ลง design.md + RunTuning (T, S) · M2-28 `FxLayer` (T, S) · M2-29 ต่อทุกระบบเข้า `Run` + สถานะของรอบ (T, L) · M2-30 overlay แสดงเวลาขั้นอาวุธ/pickup + F4 ให้อาวุธครบ LV5 (—, S) · M2-31 ปิด M2: เล่นจริง วัด perf export เว็บ (—, M) แล้วแก้ตัวเลข "26 sub-task" ในหัวข้อความเสี่ยงถ้ามีการอ้างถึง M2
- [x] **Step 4: Verify (ต้องผ่าน)**
- [x] **Step 5: Finish `M2-27: add M2 tuning numbers and new roadmap tasks`**

---

### Task 2 (M2-4): `WeaponDef` / `WeaponLevelDef` + ฟิลด์ใหม่ของ `ClassDef`

**Files:**
- Create: `data/weapon_level_def.gd`, `data/weapon_def.gd`, `tests/test_weapon_def.gd`
- Modify: `data/class_def.gd`, `tests/test_class_def.gd`

**Interfaces:**
- Produces: `WeaponLevelDef` (Resource) ฟิลด์ `cooldown: float`, `damage: float`, `arc_degrees: float`, `range: float`, `radius: float`, `knockback: float`, `stun_seconds: float`, `both_sides: bool`, `buff_percent: float`, `buff_seconds: float`, `heal: float` (ช่องที่อาวุธไม่ใช้ = 0)
- Produces: `WeaponDef` (Resource) ฟิลด์ `id: StringName`, `display_name: String`, `tag: StringName` (`&"steel"` / `&"holy"`), `class_id: StringName` (`&""` = อาวุธกลาง), `levels: Array[WeaponLevelDef]`; เมธอด `level_data(level: int) -> WeaponLevelDef` (level เริ่มที่ 1, ค่านอกช่วงคืน `null` พร้อม `push_error`), `max_level() -> int`
- Produces: `ClassDef` เพิ่ม `start_weapon: WeaponDef`, `class_weapons: Array[WeaponDef]`, `steel_lifesteal: float`

- [x] **Step 1: เขียน `tests/test_weapon_def.gd`**
```gdscript
func _def_with_levels(n: int) -> WeaponDef:
	var d: WeaponDef = WeaponDef.new()
	for i in n:
		var lv: WeaponLevelDef = WeaponLevelDef.new()
		lv.damage = float(10 * (i + 1))
		d.levels.append(lv)
	return d

func test_max_level_is_the_number_of_rows() -> void:
	assert_eq(_def_with_levels(5).max_level(), 5)

func test_level_data_is_one_based() -> void:
	assert_eq(_def_with_levels(5).level_data(1).damage, 10.0)
	assert_eq(_def_with_levels(5).level_data(5).damage, 50.0)

func test_level_data_out_of_range_returns_null() -> void:
	assert_null(_def_with_levels(5).level_data(0))
	assert_null(_def_with_levels(5).level_data(6))
```
และใน `tests/test_class_def.gd` เพิ่ม `test_class_def_has_weapon_fields` ที่สร้าง `ClassDef.new()` แล้วตรวจ `start_weapon == null`, `class_weapons.size() == 0`, `steel_lifesteal == 0.0` (ค่า Knight จริงตรวจใน Task 14, 17, 18)
- [x] **Step 2: Verify (ต้องตก)** เพราะไม่รู้จัก `WeaponDef`
- [x] **Step 3: สร้างสอง schema ตาม Interfaces** (`level_data` คืนช่วง 1..`levels.size()`) และเพิ่มสามฟิลด์ลง `ClassDef` (ยังไม่แก้ `knight.tres`)
- [x] **Step 4: Verify (ต้องผ่าน)**
- [x] **Step 5: Finish `M2-4: add WeaponDef schema and class weapon fields`**

---

### Task 3 (M2-22): `EnemySystem.query_radius` + `damage`

**Files:**
- Modify: `run/enemy_system.gd`, `tests/test_enemy_system.gd`

**Interfaces:**
- Produces: `query_radius(center: Vector2, radius: float, out: PackedInt32Array) -> int` เติม id ของศัตรูที่**มีชีวิต**และอยู่ในรัศมีจากตำแหน่งจริงลง `out` คืนจำนวน (ผู้เรียกต้องส่ง buffer ขนาดอย่างน้อย `capacity()`) ใช้ผลของ `tick_grid()` ล่าสุด
- Produces: `damage(id: int, amount: float) -> bool` ลด HP คืน `true` ถ้าตายครั้งนี้ (เรียก `kill(id)` เอง จึงยิง `enemy_died` ครั้งเดียว) id ไม่ถูกต้องหรือตายแล้วคืน `false` ไม่ทำอะไร
- Consumes: `_grid`, `_alive`, `_pos`, `_hp`, `kill()`

- [x] **Step 1: เพิ่มเทสต์ใน `tests/test_enemy_system.gd`**
```gdscript
func test_query_radius_returns_only_enemies_inside() -> void:
	var near: int = _sys.spawn(0, Vector2(10.0, 0.0), 0.0)
	_sys.spawn(0, Vector2(100.0, 0.0), 0.0)
	_sys.tick_grid()
	var buf: PackedInt32Array = PackedInt32Array(); buf.resize(8)
	assert_eq(_sys.query_radius(Vector2.ZERO, 20.0, buf), 1)
	assert_eq(buf[0], near)

func test_query_radius_skips_enemies_killed_after_the_grid_was_built() -> void:
	var id: int = _sys.spawn(0, Vector2(5.0, 0.0), 0.0)
	_sys.tick_grid()
	_sys.kill(id)
	var buf: PackedInt32Array = PackedInt32Array(); buf.resize(8)
	assert_eq(_sys.query_radius(Vector2.ZERO, 20.0, buf), 0)

func test_damage_reduces_hp_without_killing() -> void:
	var id: int = _sys.spawn(0, Vector2.ZERO, 0.0)
	assert_false(_sys.damage(id, 4.0))
	assert_almost_eq(_sys.hp_of(id), 6.0, 0.001)
	assert_true(_sys.is_alive(id))

func test_lethal_damage_kills_once_and_emits_enemy_died() -> void:
	watch_signals(_sys)
	var id: int = _sys.spawn(0, Vector2(3.0, 3.0), 0.0)
	assert_true(_sys.damage(id, 10.0))
	assert_false(_sys.is_alive(id))
	assert_false(_sys.damage(id, 10.0), "a dead enemy cannot die twice")
	assert_signal_emit_count(_sys, "enemy_died", 1)

func test_damage_ignores_bad_ids() -> void:
	assert_false(_sys.damage(-1, 5.0))
	assert_false(_sys.damage(99, 5.0))
```
- [x] **Step 2: Verify (ต้องตก)**
- [x] **Step 3: เพิ่มสองเมธอดตาม Interfaces** `query_radius` เรียก `_grid.query_radius` ลง buffer ของผู้เรียกแล้วคัดตัวที่ตายออกในที่เดิม (เขียนทับ `out` โดยไม่สร้างอาร์เรย์ใหม่)
- [x] **Step 4: Verify (ต้องผ่าน)**
- [x] **Step 5: Finish `M2-22: add enemy query_radius and damage API`**

---

### Task 4 (M2-8): knockback

**Files:**
- Modify: `run/enemy_system.gd`, `tests/test_enemy_system.gd`

**Interfaces:**
- Produces: `knockback(id: int, direction: Vector2, distance: float) -> void` ผลักศัตรูออกรวม `distance` px ตามทิศ `direction` (normalize ภายใน, ศูนย์ = ไม่ผลัก) ความเร็วเริ่มต้น `2 * distance / knockback_duration` ลดเชิงเส้นเป็นศูนย์ใน `knockback_duration` ของ `RunTuning` ผลักซ้ำระหว่างผลักอยู่ = เริ่มใหม่ด้วยค่าใหม่ ไม่บวกทับ
- Produces: SoA `_kb_vel: PackedVector2Array`, `_kb_left: PackedFloat32Array` (เวลาที่เหลือ) ล้างตอน `spawn()` เมื่อใช้ slot ซ้ำ
- Consumes: `tick_movement(delta, player_pos)` เดิม เพิ่มการเลื่อนตำแหน่งจาก knockback ด้วย trapezoid ต่อก้าว (`pos += kb_vel * delta * (f_start + f_end) / 2` โดย `f = left / duration` และตัดที่ศูนย์) เพื่อให้ผลรวมระยะเท่ากับ `distance` พอดีไม่ว่า `delta` เป็นเท่าไร

- [x] **Step 1: เพิ่มเทสต์** (ใช้ศัตรูความเร็ว 0 ผ่านเมธอดช่วย `_use_still_enemies()` ที่มีอยู่แล้ว และตั้งผู้เล่นที่ `Vector2.ZERO`)
```gdscript
func _run_ticks(n: int, delta: float) -> void:
	for i in n:
		_sys.tick_movement(delta, Vector2.ZERO)

func test_knockback_moves_the_total_distance() -> void:
	_use_still_enemies()
	var id: int = _sys.spawn(0, Vector2(100.0, 0.0), 0.0)
	_sys.knockback(id, Vector2.RIGHT, 20.0)
	_run_ticks(30, 1.0 / 60.0)    # 0.5 s, longer than the 0.2 s push
	assert_almost_eq(_sys.position_of(id).x, 120.0, 0.01)

func test_knockback_total_is_independent_of_frame_rate() -> void:
	_use_still_enemies()
	var id: int = _sys.spawn(0, Vector2(100.0, 0.0), 0.0)
	_sys.knockback(id, Vector2.RIGHT, 20.0)
	_run_ticks(5, 0.1)
	assert_almost_eq(_sys.position_of(id).x, 120.0, 0.01)

func test_knockback_stops_after_the_duration() -> void:
	_use_still_enemies()
	var id: int = _sys.spawn(0, Vector2(100.0, 0.0), 0.0)
	_sys.knockback(id, Vector2.RIGHT, 20.0)
	_run_ticks(20, 1.0 / 60.0)
	var settled: float = _sys.position_of(id).x
	_run_ticks(20, 1.0 / 60.0)
	assert_eq(_sys.position_of(id).x, settled)

func test_a_pushed_enemy_resumes_chasing() -> void:
	var id: int = _sys.spawn(0, Vector2(100.0, 0.0), 0.0)   # ghoul speed 45
	_sys.knockback(id, Vector2.RIGHT, 20.0)
	_run_ticks(60, 1.0 / 60.0)                              # 1 s
	assert_lt(_sys.position_of(id).x, 120.0, "it walked back towards the player")

func test_a_new_knockback_restarts_instead_of_stacking() -> void:
	_use_still_enemies()
	var id: int = _sys.spawn(0, Vector2(100.0, 0.0), 0.0)
	_sys.knockback(id, Vector2.RIGHT, 20.0)
	_sys.knockback(id, Vector2.RIGHT, 20.0)
	_run_ticks(30, 1.0 / 60.0)
	assert_almost_eq(_sys.position_of(id).x, 120.0, 0.01)

func test_knockback_with_a_zero_direction_does_nothing() -> void:
	_use_still_enemies()
	var id: int = _sys.spawn(0, Vector2(100.0, 0.0), 0.0)
	_sys.knockback(id, Vector2.ZERO, 20.0)
	_run_ticks(30, 1.0 / 60.0)
	assert_eq(_sys.position_of(id), Vector2(100.0, 0.0))

func test_a_reused_slot_does_not_inherit_a_knockback() -> void:
	_use_still_enemies()
	var a: int = _sys.spawn(0, Vector2(100.0, 0.0), 0.0)
	_sys.knockback(a, Vector2.RIGHT, 20.0)
	_sys.kill(a)
	var b: int = _sys.spawn(0, Vector2(200.0, 0.0), 0.0)
	_run_ticks(30, 1.0 / 60.0)
	assert_eq(_sys.position_of(b), Vector2(200.0, 0.0))
```
- [x] **Step 2: Verify (ต้องตก)**
- [x] **Step 3: เพิ่ม SoA และเมธอดตาม Interfaces** ข้ามตัวที่ตายเหมือนเดิม และแยกเนื้อที่เลื่อนตำแหน่งเป็นฟังก์ชันย่อยเพื่อไม่ให้ `tick_movement` ยาวเกินไป
- [x] **Step 4: Verify (ต้องผ่าน)**
- [x] **Step 5: Finish `M2-8: add enemy knockback`**

---

### Task 5 (M2-23): stun

**Files:**
- Modify: `run/enemy_system.gd`, `tests/test_enemy_system.gd`

**Interfaces:**
- Produces: `stun(id: int, seconds: float) -> void` ตั้งเวลามึนงงเหลือ `seconds` (ติดซ้ำ = ตั้งใหม่ ไม่บวกทับ) `is_stunned(id: int) -> bool`
- Produces: SoA `_stun_left: PackedFloat32Array` ล้างตอน `spawn()` ตัวที่มึนงงไม่ไล่ผู้เล่น (ความเร็วไล่ = 0) แต่ยังถูก knockback และ separation ผลักได้ เวลามึนงงลดใน `tick_movement`
- Consumes: `tick_movement`, `knockback` (Task 4)

- [x] **Step 1: เพิ่มเทสต์**
```gdscript
func test_a_stunned_enemy_does_not_chase() -> void:
	var id: int = _sys.spawn(0, Vector2(100.0, 0.0), 0.0)
	_sys.stun(id, 0.5)
	_sys.tick_movement(0.1, Vector2.ZERO)
	assert_eq(_sys.position_of(id).x, 100.0)
	assert_true(_sys.is_stunned(id))

func test_stun_wears_off_and_the_enemy_chases_again() -> void:
	var id: int = _sys.spawn(0, Vector2(100.0, 0.0), 0.0)
	_sys.stun(id, 0.5)
	for i in 6:
		_sys.tick_movement(0.1, Vector2.ZERO)     # 0.6 s
	assert_false(_sys.is_stunned(id))
	_sys.tick_movement(0.1, Vector2.ZERO)
	assert_almost_eq(_sys.position_of(id).x, 95.5, 0.01, "walks at 45 px/s again")

func test_stunning_again_resets_instead_of_adding() -> void:
	var id: int = _sys.spawn(0, Vector2(100.0, 0.0), 0.0)
	_sys.stun(id, 0.5)
	_sys.tick_movement(0.3, Vector2.ZERO)
	_sys.stun(id, 0.5)
	_sys.tick_movement(0.4, Vector2.ZERO)
	assert_true(_sys.is_stunned(id), "0.2 s of the reset stun is left")
	_sys.tick_movement(0.2, Vector2.ZERO)
	assert_false(_sys.is_stunned(id), "not stacked up to 0.8 s")

func test_a_stunned_enemy_can_still_be_knocked_back() -> void:
	_use_still_enemies()
	var id: int = _sys.spawn(0, Vector2(100.0, 0.0), 0.0)
	_sys.stun(id, 1.0)
	_sys.knockback(id, Vector2.RIGHT, 20.0)
	for i in 30:
		_sys.tick_movement(1.0 / 60.0, Vector2.ZERO)
	assert_almost_eq(_sys.position_of(id).x, 120.0, 0.01)

func test_a_reused_slot_is_not_stunned() -> void:
	var a: int = _sys.spawn(0, Vector2.ZERO, 0.0)
	_sys.stun(a, 5.0)
	_sys.kill(a)
	var b: int = _sys.spawn(0, Vector2.ZERO, 0.0)
	assert_false(_sys.is_stunned(b))

func test_stun_on_a_dead_or_bad_id_is_ignored() -> void:
	_sys.stun(-1, 1.0)
	_sys.stun(99, 1.0)
	assert_false(_sys.is_stunned(-1))
```
- [x] **Step 2: Verify (ต้องตก)**
- [x] **Step 3: เพิ่ม SoA, `stun`, `is_stunned` และปรับ `tick_movement`** ให้ตัวที่มึนงงไม่บวกความเร็วไล่
- [x] **Step 4: Verify (ต้องผ่าน)**
- [x] **Step 5: Finish `M2-23: add enemy stun`**

---

### Task 6 (M2-1): `RunState` แกน

**Files:**
- Create: `run/run_state.gd`, `tests/test_run_state.gd`

**Interfaces:**
- Produces: `class_name RunState extends RefCounted`; ค่าคงที่ `WEAPON_SLOTS: int = 4`, `PASSIVE_SLOTS: int = 4`
- Produces: ฟิลด์ `elapsed: float`, `kills: int`, `level: int` (เริ่ม 1), `xp: int`; `setup(tuning: RunTuning) -> void` (รีเซ็ตทุกอย่าง)
- Produces: signal `kills_changed(kills: int)`, `build_changed()`
- Produces: `tick(delta: float) -> void` (เพิ่ม `elapsed`), `add_kill() -> void`
- Produces (บิลด์): `add_weapon(def: WeaponDef) -> bool` (เริ่ม LV1, คืน `false` ถ้าเต็มหรือมีอยู่แล้ว), `upgrade_weapon(id: StringName) -> bool` (คืน `false` ถ้าไม่มีหรือเต็มเลเวล), `weapon_level(id: StringName) -> int` (0 = ไม่มี), `weapon_count() -> int`, `has_weapon_room() -> bool`, `weapon_ids() -> Array[StringName]` (ลำดับที่เพิ่ม; เรียกเฉพาะตอนเปลี่ยนบิลด์ ไม่ใช่ทุกเฟรม) ทุกครั้งที่บิลด์เปลี่ยนยิง `build_changed`

- [x] **Step 1: เขียน `tests/test_run_state.gd`** (มีเมธอดช่วย `_weapon(id, levels)` สร้าง `WeaponDef` ที่มี `levels` ตามจำนวน)
```gdscript
func test_a_fresh_state_starts_at_level_one() -> void:
	assert_eq(_s.level, 1); assert_eq(_s.kills, 0); assert_eq(_s.elapsed, 0.0)

func test_tick_advances_the_clock() -> void:
	_s.tick(0.5); _s.tick(0.25)
	assert_almost_eq(_s.elapsed, 0.75, 0.0001)

func test_add_kill_counts_and_signals() -> void:
	watch_signals(_s)
	_s.add_kill(); _s.add_kill()
	assert_eq(_s.kills, 2)
	assert_signal_emit_count(_s, "kills_changed", 2)

func test_add_weapon_starts_at_level_one_and_signals() -> void:
	watch_signals(_s)
	assert_true(_s.add_weapon(_weapon(&"a", 5)))
	assert_eq(_s.weapon_level(&"a"), 1)
	assert_signal_emitted(_s, "build_changed")

func test_the_same_weapon_cannot_be_added_twice() -> void:
	_s.add_weapon(_weapon(&"a", 5))
	assert_false(_s.add_weapon(_weapon(&"a", 5)))
	assert_eq(_s.weapon_count(), 1)

func test_weapon_slots_cap_at_four() -> void:
	for n in ["a", "b", "c", "d"]:
		assert_true(_s.add_weapon(_weapon(StringName(n), 5)))
	assert_false(_s.has_weapon_room())
	assert_false(_s.add_weapon(_weapon(&"e", 5)))

func test_upgrade_stops_at_the_last_level() -> void:
	_s.add_weapon(_weapon(&"a", 3))
	assert_true(_s.upgrade_weapon(&"a")); assert_true(_s.upgrade_weapon(&"a"))
	assert_false(_s.upgrade_weapon(&"a"))
	assert_eq(_s.weapon_level(&"a"), 3)

func test_upgrading_a_weapon_you_do_not_have_fails() -> void:
	assert_false(_s.upgrade_weapon(&"nope"))
	assert_eq(_s.weapon_level(&"nope"), 0)

func test_setup_again_clears_everything() -> void:
	_s.add_weapon(_weapon(&"a", 5)); _s.add_kill(); _s.tick(5.0)
	_s.setup(RunTuning.new())
	assert_eq(_s.weapon_count(), 0); assert_eq(_s.kills, 0); assert_eq(_s.elapsed, 0.0)
```
- [x] **Step 2: Verify (ต้องตก)**
- [x] **Step 3: เขียน `run/run_state.gd` ตาม Interfaces** เก็บบิลด์เป็น `Dictionary` id → level และ `Array[WeaponDef]` ตามลำดับเพิ่ม
- [x] **Step 4: Verify (ต้องผ่าน)**
- [x] **Step 5: Finish `M2-1: add RunState core`**

---

### Task 7 (M2-2): XP curve + XP ล้น

**Files:**
- Modify: `run/run_state.gd`, `tests/test_run_state.gd`

**Interfaces:**
- Produces: `xp_needed(for_level: int) -> int` = `roundi(tuning.xp_base + for_level * tuning.xp_per_level)` (lv1 = 10, lv2 = 14, lv3 = 19 เพราะ `roundi(18.5)` ปัดครึ่งออกจากศูนย์, lv10 = 50)
- Produces: `add_xp(amount: int) -> void` เพิ่ม XP แล้วขึ้นเลเวลซ้ำตราบที่ `xp >= xp_needed(level)` โดยหัก XP ที่ใช้ เหลือเศษไว้ ขึ้นแต่ละเลเวลเพิ่ม `level` ทีละ 1 และยิง `level_up_queued(new_level: int)` ครั้งหนึ่งต่อเลเวล `amount <= 0` ไม่ทำอะไร
- Produces: signal `xp_changed(xp: int, needed: int, level: int)` ยิงหลัง `add_xp` ทุกครั้งที่ amount > 0 (ด้วยค่าสุดท้าย)

- [x] **Step 1: เพิ่มเทสต์**
```gdscript
func test_xp_curve_matches_the_design() -> void:
	assert_eq(_s.xp_needed(1), 10)    # round(5 + 1 * 4.5) = round(9.5)
	assert_eq(_s.xp_needed(2), 14)
	assert_eq(_s.xp_needed(3), 19)    # round(18.5) rounds half away from zero
	assert_eq(_s.xp_needed(10), 50)

func test_enough_xp_levels_up_and_keeps_the_remainder() -> void:
	_s.add_xp(13)
	assert_eq(_s.level, 2); assert_eq(_s.xp, 3)

func test_one_big_gem_can_gain_several_levels() -> void:
	watch_signals(_s)
	_s.add_xp(10 + 14 + 19 + 5)       # lv1->2, 2->3, 3->4 then 5 left
	assert_eq(_s.level, 4); assert_eq(_s.xp, 5)
	assert_signal_emit_count(_s, "level_up_queued", 3)

func test_exact_threshold_levels_up_with_zero_left() -> void:
	_s.add_xp(10)
	assert_eq(_s.level, 2); assert_eq(_s.xp, 0)

func test_one_xp_short_does_not_level_up() -> void:
	_s.add_xp(9)
	assert_eq(_s.level, 1)

func test_zero_or_negative_xp_is_ignored() -> void:
	watch_signals(_s)
	_s.add_xp(0); _s.add_xp(-5)
	assert_eq(_s.xp, 0); assert_signal_not_emitted(_s, "xp_changed")

func test_xp_changed_reports_final_values() -> void:
	watch_signals(_s)
	_s.add_xp(13)
	assert_signal_emitted_with_parameters(_s, "xp_changed", [3, 14, 2])
```
- [x] **Step 2: Verify (ต้องตก)**
- [x] **Step 3: เพิ่ม `xp_needed`, `add_xp`, signal ตาม Interfaces** (`RunState` เก็บ `_tuning` จาก `setup`)
- [x] **Step 4: Verify (ต้องผ่าน)**
- [x] **Step 5: Finish `M2-2: add xp curve and multi-level overflow`**

---

### Task 8 (M2-15): คิวเลเวลอัป

**Files:**
- Modify: `run/run_state.gd`, `tests/test_run_state.gd`

**Interfaces:**
- Produces: `pending_levelups() -> int` จำนวนเลเวลอัปที่ยังไม่ถูกจัดการ; `pop_levelup() -> int` คืนเลเวลใหม่ของเลเวลอัปที่เก่าที่สุดในคิวแล้วนำออก (คืน `-1` ถ้าคิวว่าง) ทุกการขึ้นเลเวลใน `add_xp` เพิ่มเข้าคิวตามลำดับ `setup()` ล้างคิว

- [x] **Step 1: เพิ่มเทสต์** (ครอบ Review Focus ข้อ 1)
```gdscript
func test_each_level_gained_is_queued_in_order() -> void:
	_s.add_xp(10 + 14 + 19)            # reaches level 4
	assert_eq(_s.pending_levelups(), 3)
	assert_eq(_s.pop_levelup(), 2)
	assert_eq(_s.pop_levelup(), 3)
	assert_eq(_s.pop_levelup(), 4)
	assert_eq(_s.pop_levelup(), -1)

func test_a_level_gained_while_one_is_pending_is_not_lost() -> void:
	_s.add_xp(10)
	_s.add_xp(14)                       # second level before the first was popped
	assert_eq(_s.pending_levelups(), 2)
	assert_eq(_s.pop_levelup(), 2)
	assert_eq(_s.pop_levelup(), 3)

func test_popping_an_empty_queue_is_safe() -> void:
	assert_eq(_s.pop_levelup(), -1)
	assert_eq(_s.pending_levelups(), 0)

func test_setup_clears_the_queue() -> void:
	_s.add_xp(100)
	_s.setup(RunTuning.new())
	assert_eq(_s.pending_levelups(), 0)
```
- [x] **Step 2: Verify (ต้องตก)**
- [x] **Step 3: เพิ่มคิวด้วย `PackedInt32Array` ที่ใช้เป็น FIFO** และเรียกเข้าคิวใน `add_xp`
- [x] **Step 4: Verify (ต้องผ่าน)**
- [x] **Step 5: Finish `M2-15: queue level-ups so none are lost`**

---

### Task 9 (M2-21): ติดตามดาเมจรวมต่ออาวุธ

**Files:**
- Modify: `run/run_state.gd`, `tests/test_run_state.gd`

**Interfaces:**
- Produces: `record_damage(weapon_id: StringName, amount: float) -> void` (ค่าลบหรือศูนย์ไม่นับ), `damage_of(weapon_id: StringName) -> float` (ไม่เคยบันทึก = 0.0), `damage_by_weapon() -> Dictionary` (id → float ใหม่ทุกครั้งที่เรียก ใช้ตอนสรุปผลเท่านั้น)

- [ ] **Step 1: เพิ่มเทสต์**
```gdscript
func test_damage_accumulates_per_weapon() -> void:
	_s.record_damage(&"a", 20.0); _s.record_damage(&"a", 5.0); _s.record_damage(&"b", 8.0)
	assert_eq(_s.damage_of(&"a"), 25.0); assert_eq(_s.damage_of(&"b"), 8.0)

func test_an_unused_weapon_has_zero_damage() -> void:
	assert_eq(_s.damage_of(&"never"), 0.0)

func test_non_positive_damage_is_ignored() -> void:
	_s.record_damage(&"a", 0.0); _s.record_damage(&"a", -3.0)
	assert_eq(_s.damage_by_weapon().size(), 0)

func test_setup_clears_recorded_damage() -> void:
	_s.record_damage(&"a", 9.0); _s.setup(RunTuning.new())
	assert_eq(_s.damage_of(&"a"), 0.0)
```
- [ ] **Step 2: Verify (ต้องตก)**
- [ ] **Step 3: เพิ่มเมธอดตาม Interfaces**
- [ ] **Step 4: Verify (ต้องผ่าน)**
- [ ] **Step 5: Finish `M2-21: track total damage per weapon`**

---

### Task 10 (M2-18): สูตร Embers

**Files:**
- Modify: `run/run_state.gd`, `tests/test_run_state.gd`

**Interfaces:**
- Produces: `embers_from_kills() -> int` = `kills / tuning.embers_kills_divisor` (หารจำนวนเต็มปัดลง), `embers_from_time() -> int` = `int(elapsed) / tuning.embers_seconds_divisor`, `add_embers_bonus(amount: int) -> void`, `embers_bonus() -> int`, `embers_total() -> int` = ผลรวมสามส่วน (ส่วนของ Elite และบอส = 0 ใน M2)

- [ ] **Step 1: เพิ่มเทสต์**
```gdscript
func test_embers_from_kills_is_one_per_ten() -> void:
	for i in 29: _s.add_kill()
	assert_eq(_s.embers_from_kills(), 2)

func test_embers_from_time_is_one_per_fifteen_seconds() -> void:
	_s.tick(44.9)
	assert_eq(_s.embers_from_time(), 2)
	_s.tick(0.1)
	assert_eq(_s.embers_from_time(), 3)

func test_ember_purse_bonus_is_added() -> void:
	_s.add_embers_bonus(5)
	assert_eq(_s.embers_bonus(), 5); assert_eq(_s.embers_total(), 5)

func test_total_is_the_sum_of_all_sources() -> void:
	for i in 30: _s.add_kill()          # 3
	_s.tick(30.0)                       # 2
	_s.add_embers_bonus(5); _s.add_embers_bonus(5)
	assert_eq(_s.embers_total(), 3 + 2 + 10)

func test_a_run_that_just_started_earns_nothing() -> void:
	assert_eq(_s.embers_total(), 0)

func test_setup_clears_the_bonus() -> void:
	_s.add_embers_bonus(5); _s.setup(RunTuning.new())
	assert_eq(_s.embers_bonus(), 0)
```
- [ ] **Step 2: Verify (ต้องตก)**
- [ ] **Step 3: เพิ่มเมธอดตาม Interfaces**
- [ ] **Step 4: Verify (ต้องผ่าน)**
- [ ] **Step 5: Finish `M2-18: add the embers formula`**

---

### Task 11 (M2-26): `StatBlock` ขนาดเล็ก + `Player.heal`

**Files:**
- Create: `run/stat_block.gd`, `tests/test_stat_block.gd`
- Modify: `run/player.gd`, `tests/test_player.gd`

**Interfaces:**
- Produces: `class_name StatBlock extends RefCounted`; `apply_damage_buff(percent: float, seconds: float) -> void` (ตั้งใหม่ทับค่าเดิม ไม่ซ้อน; `percent` เป็นหน่วยเปอร์เซ็นต์ เช่น 15.0), `tick(delta: float) -> void` (ลดเวลาที่เหลือ หมดแล้วบัฟเป็น 0), `damage_multiplier() -> float` = `1.0 + percent / 100` ขณะบัฟทำงาน ไม่งั้น `1.0`, `buff_time_left() -> float`, `reset() -> void`
- Produces: `Player.heal(amount: float) -> void` เพิ่ม HP ไม่เกิน `max_hp` ยิง `health_changed` ถ้าค่าเปลี่ยน ไม่ทำอะไรถ้าตายแล้วหรือ `amount <= 0`
- (ตัวเต็มที่รวมพาสซีฟ/แท็ก/meta เป็นของ M3-1 ไฟล์นี้จะถูกขยายตอนนั้น)

- [ ] **Step 1: เขียน `tests/test_stat_block.gd` และเพิ่มเทสต์ heal**
```gdscript
func test_the_multiplier_is_one_without_a_buff() -> void:
	assert_eq(_s.damage_multiplier(), 1.0)

func test_a_buff_raises_the_multiplier() -> void:
	_s.apply_damage_buff(15.0, 3.0)
	assert_almost_eq(_s.damage_multiplier(), 1.15, 0.0001)

func test_the_buff_expires_after_its_duration() -> void:
	_s.apply_damage_buff(15.0, 3.0)
	_s.tick(2.9)
	assert_almost_eq(_s.damage_multiplier(), 1.15, 0.0001)
	_s.tick(0.1)
	assert_eq(_s.damage_multiplier(), 1.0)

func test_recasting_refreshes_and_does_not_stack() -> void:
	_s.apply_damage_buff(15.0, 3.0)
	_s.tick(2.0)
	_s.apply_damage_buff(15.0, 3.0)
	assert_almost_eq(_s.damage_multiplier(), 1.15, 0.0001, "not 1.30")
	assert_almost_eq(_s.buff_time_left(), 3.0, 0.0001)

func test_a_stronger_recast_replaces_the_weaker_one() -> void:
	_s.apply_damage_buff(15.0, 3.0)
	_s.apply_damage_buff(25.0, 3.0)
	assert_almost_eq(_s.damage_multiplier(), 1.25, 0.0001)

func test_reset_clears_the_buff() -> void:
	_s.apply_damage_buff(15.0, 3.0); _s.reset()
	assert_eq(_s.damage_multiplier(), 1.0)
```
และใน `tests/test_player.gd`:
```gdscript
func test_heal_restores_hp_up_to_the_maximum() -> void:
	_player.take_damage(25.0)            # 140 - 23 = 117
	_player.heal(10.0)
	assert_almost_eq(_player.hp, 127.0, 0.01)
	_player.heal(1000.0)
	assert_eq(_player.hp, 140.0)

func test_heal_signals_only_when_hp_changes() -> void:
	watch_signals(_player)
	_player.heal(10.0)                   # already full
	assert_signal_not_emitted(_player, "health_changed")

func test_a_dead_player_cannot_be_healed() -> void:
	_player.take_damage(1000.0)
	_player.heal(50.0)
	assert_eq(_player.hp, 0.0)

func test_non_positive_heal_is_ignored() -> void:
	_player.take_damage(25.0)
	_player.heal(0.0); _player.heal(-5.0)
	assert_almost_eq(_player.hp, 117.0, 0.01)
```
- [ ] **Step 2: Verify (ต้องตก)**
- [ ] **Step 3: สร้าง `StatBlock` และเพิ่ม `Player.heal` ตาม Interfaces**
- [ ] **Step 4: Verify (ต้องผ่าน)**
- [ ] **Step 5: Finish `M2-26: add temporary damage buff and player heal`**

---

### Task 12 (M2-28): `FxLayer`

**Files:**
- Create: `run/fx_layer.gd`, `tests/test_fx_layer.gd`

**Interfaces:**
- Produces: `class_name FxLayer extends Node2D`; `const CAPACITY: int = 32`; `add_arc(origin: Vector2, facing: Vector2, arc_degrees: float, range: float, color: Color, lifetime: float) -> void`, `add_ring(origin: Vector2, radius: float, color: Color, lifetime: float) -> void`, `tick(delta: float) -> void` (เพิ่มอายุ ปล่อยช่องที่หมดอายุ แล้วเรียก `queue_redraw()` เมื่อมีเอฟเฟกต์ทำงาน), `active_count() -> int`, `clear() -> void`
- ข้อมูลเก็บเป็น SoA ขนาดคงที่ `CAPACITY` ไม่สร้างโหนด/Array ใหม่ต่อเอฟเฟกต์ เต็มแล้วเอฟเฟกต์ใหม่**ทับช่องที่เก่าที่สุด** (ไม่ทิ้ง ไม่ error) `_draw()` วาดส่วนโค้งด้วย `draw_arc` และวงด้วย `draw_arc` เต็มวง โดยโปร่งใสลงตามอายุ

- [ ] **Step 1: เขียน `tests/test_fx_layer.gd`** (สร้าง `FxLayer.new()` ผ่าน `autofree`)
```gdscript
func test_a_new_effect_is_active_then_expires() -> void:
	_fx.add_arc(Vector2.ZERO, Vector2.RIGHT, 140.0, 48.0, Color.WHITE, 0.2)
	assert_eq(_fx.active_count(), 1)
	_fx.tick(0.19); assert_eq(_fx.active_count(), 1)
	_fx.tick(0.02); assert_eq(_fx.active_count(), 0)

func test_arcs_and_rings_share_the_same_capacity() -> void:
	for i in 10: _fx.add_arc(Vector2.ZERO, Vector2.UP, 90.0, 40.0, Color.WHITE, 1.0)
	for i in 10: _fx.add_ring(Vector2.ZERO, 70.0, Color.WHITE, 1.0)
	assert_eq(_fx.active_count(), 20)

func test_a_full_layer_overwrites_the_oldest_instead_of_dropping_the_new_one() -> void:
	for i in FxLayer.CAPACITY:
		_fx.add_ring(Vector2(float(i), 0.0), 10.0, Color.WHITE, 10.0)
	_fx.add_ring(Vector2(999.0, 0.0), 10.0, Color.WHITE, 10.0)
	assert_eq(_fx.active_count(), FxLayer.CAPACITY, "never grows past capacity")
	assert_true(_fx.has_effect_at(Vector2(999.0, 0.0)), "the new one is kept")
	assert_false(_fx.has_effect_at(Vector2(0.0, 0.0)), "the oldest was replaced")

func test_clear_removes_everything() -> void:
	_fx.add_ring(Vector2.ZERO, 10.0, Color.WHITE, 1.0); _fx.clear()
	assert_eq(_fx.active_count(), 0)

func test_a_zero_facing_does_not_break_an_arc() -> void:
	_fx.add_arc(Vector2.ZERO, Vector2.ZERO, 90.0, 40.0, Color.WHITE, 0.1)
	_fx.tick(0.01)
	assert_eq(_fx.active_count(), 1)
```
(เทสต์ใช้ `has_effect_at(origin: Vector2) -> bool` เป็นเมธอดตรวจสถานะสำหรับเทสต์ ให้เพิ่มด้วย)
- [ ] **Step 2: Verify (ต้องตก)**
- [ ] **Step 3: เขียน `run/fx_layer.gd` ตาม Interfaces** วาดจริงตรวจบน renderer ใน Task 31 (ตอนนี้ตรวจด้วย headless ว่าไม่มี error ตอน `tick`)
- [ ] **Step 4: Verify (ต้องผ่าน)**
- [ ] **Step 5: Finish `M2-28: add FxLayer for weapon visuals`**

---

### Task 13 (M2-5): `WeaponBase` + `WeaponContext` + `WeaponLoadout`

**Files:**
- Create: `run/weapons/weapon_base.gd`, `run/weapon_context.gd`, `run/weapons/weapon_loadout.gd`, `tests/helpers/counting_weapon.gd`, `tests/test_weapon_base.gd`, `tests/test_weapon_loadout.gd`

**Interfaces:**
- Produces: `WeaponBase extends RefCounted` — `var def: WeaponDef`, `var level: int` (เริ่ม 1), `setup(weapon_def: WeaponDef) -> void`, `tick(delta: float, ctx: WeaponContext) -> void` (นับคูลดาวน์ลง เมื่อถึงศูนย์เรียก `_fire(ctx, level_data)` แล้วตั้งคูลดาวน์ใหม่ = `level_data.cooldown` ของเลเวล**ตอนยิง** (ไม่สะสมเศษเวลา); **ยิงทันทีที่ tick แรก**), `_fire(ctx: WeaponContext, lv: WeaponLevelDef) -> void` (virtual, ว่าง), `current() -> WeaponLevelDef`, `static in_cone(origin: Vector2, facing: Vector2, arc_degrees: float, range: float, point: Vector2) -> bool` (จริงถ้า `point` ห่างจาก `origin` ไม่เกิน `range` และมุมระหว่าง `facing` กับ `point - origin` ไม่เกิน `arc_degrees / 2`; จุดที่ทับ `origin` พอดีนับว่าอยู่ใน; จุดบนขอบมุมพอดีนับว่าอยู่ใน (ความคลาดเคลื่อน 0.0001 rad); `facing` ศูนย์ = ไม่อยู่ใน)
- Produces: `WeaponContext extends RefCounted` — ฟิลด์ `player: Player`, `enemies: EnemySystem`, `fx: FxLayer` (อาจเป็น `null` ในเทสต์), `state: RunState`, `stats: StatBlock`, `steel_lifesteal: float`, `hits: PackedInt32Array` (สำหรับ `query_radius` ขนาด `enemies.capacity()`); `setup(player, enemies, fx, state, stats, lifesteal) -> void`; `player_pos() -> Vector2`, `facing() -> Vector2` (= `player.last_move_dir`); `deal_damage(id: int, amount: float, weapon: WeaponBase) -> bool` คูณ `stats.damage_multiplier()` แล้วเรียก `enemies.damage`, `state.record_damage(weapon.def.id, final)` และดูดเลือด (Task 16 เติมส่วนนี้) คืน `true` ถ้าศัตรูตาย
- Produces: `WeaponLoadout extends RefCounted` — `sync(state: RunState, catalog: Dictionary) -> void` (`catalog` = id → `WeaponDef`; สร้างอาวุธที่ยังไม่มีและตั้ง `level` ให้ตรง `state` เรียกเมื่อ `build_changed`), `tick(delta: float, ctx: WeaponContext) -> void`, `weapon_count() -> int`, `get_weapon(id: StringName) -> WeaponBase`; การสร้างอาวุธเลือกคลาสจาก `def.id` ผ่านตัวแปรอินสแตนซ์ `factories: Dictionary` (id → GDScript) ที่ `_init` เติมให้ (Task 14, 17, 18 เพิ่มทีละชิ้น) เทสต์เพิ่มรายการเองได้ id ที่ไม่รู้จักใช้ `WeaponBase` ธรรมดา (ไม่ทำอะไร)
- Produces (ตัวช่วยเทสต์): `tests/helpers/counting_weapon.gd` — `CountingWeapon extends WeaponBase` ที่ `_fire` เพิ่ม `var fired: int` (โฟลเดอร์ `tests/` ไม่ติดไปกับ build เว็บ)

- [ ] **Step 1: เขียนเทสต์**
```gdscript
# tests/test_weapon_base.gd — ใช้ CountingWeapon ที่ _fire เพิ่มตัวนับ
func test_fires_on_the_first_tick() -> void:
	_w.tick(0.016, null)
	assert_eq(_w.fired, 1)

func test_waits_for_the_cooldown_between_shots() -> void:
	_w.tick(0.016, null)          # fire, cooldown 1.0
	_w.tick(0.9, null);  assert_eq(_w.fired, 1)
	_w.tick(0.1, null);  assert_eq(_w.fired, 2)

func test_a_long_frame_fires_once_not_many() -> void:
	_w.tick(0.016, null); _w.tick(5.0, null)
	assert_eq(_w.fired, 2)

func test_the_cooldown_comes_from_the_level_at_the_time_of_firing() -> void:
	# level 1 row has cooldown 1.0, level 2 row has cooldown 0.5
	_w.tick(0.016, null)                  # fires (1), cooldown 1.0
	_w.level = 2
	_w.tick(1.0, null)                    # fires (2), cooldown now 0.5
	_w.tick(0.5, null)                    # fires (3)
	assert_eq(_w.fired, 3)

func test_in_cone_accepts_points_inside_and_rejects_outside() -> void:
	assert_true(WeaponBase.in_cone(Vector2.ZERO, Vector2.RIGHT, 140.0, 48.0, Vector2(30.0, 0.0)))
	assert_false(WeaponBase.in_cone(Vector2.ZERO, Vector2.RIGHT, 140.0, 48.0, Vector2(49.0, 0.0)), "too far")
	assert_false(WeaponBase.in_cone(Vector2.ZERO, Vector2.RIGHT, 140.0, 48.0, Vector2(-30.0, 0.0)), "behind")

func test_in_cone_boundary_angle() -> void:
	# half angle is 70 degrees
	var inside: Vector2 = Vector2.from_angle(deg_to_rad(69.0)) * 30.0
	var outside: Vector2 = Vector2.from_angle(deg_to_rad(71.0)) * 30.0
	assert_true(WeaponBase.in_cone(Vector2.ZERO, Vector2.RIGHT, 140.0, 48.0, inside))
	assert_false(WeaponBase.in_cone(Vector2.ZERO, Vector2.RIGHT, 140.0, 48.0, outside))

func test_in_cone_counts_the_exact_edge_as_inside() -> void:
	assert_true(WeaponBase.in_cone(Vector2.ZERO, Vector2.RIGHT, 180.0, 56.0, Vector2(0.0, 30.0)))

func test_in_cone_degenerate_inputs() -> void:
	assert_true(WeaponBase.in_cone(Vector2.ZERO, Vector2.RIGHT, 140.0, 48.0, Vector2.ZERO), "on top of the origin")
	assert_false(WeaponBase.in_cone(Vector2.ZERO, Vector2.ZERO, 140.0, 48.0, Vector2(10.0, 0.0)), "no facing")

# tests/test_weapon_loadout.gd
func test_sync_creates_a_weapon_for_each_one_in_the_build() -> void:
	_state.add_weapon(_def(&"a")); _loadout.sync(_state, {&"a": _def(&"a")})
	assert_eq(_loadout.weapon_count(), 1)

func test_sync_follows_upgrades_without_recreating_the_weapon() -> void:
	_state.add_weapon(_def(&"a")); _loadout.sync(_state, _catalog)
	var first: WeaponBase = _loadout.get_weapon(&"a")
	_state.upgrade_weapon(&"a"); _loadout.sync(_state, _catalog)
	assert_same(_loadout.get_weapon(&"a"), first)
	assert_eq(first.level, 2)

func test_an_upgrade_does_not_reset_the_cooldown() -> void:
	_loadout.factories[&"counting"] = CountingWeapon
	_state.add_weapon(_counting_def(&"counting")); _loadout.sync(_state, _catalog)
	_loadout.tick(0.016, null)                               # fires once
	var w: CountingWeapon = _loadout.get_weapon(&"counting")
	_state.upgrade_weapon(&"counting"); _loadout.sync(_state, _catalog)
	_loadout.tick(0.016, null)
	assert_eq(w.fired, 1, "the upgrade must not make it fire again at once")

func test_tick_runs_every_weapon() -> void:
	_loadout.factories[&"c1"] = CountingWeapon; _loadout.factories[&"c2"] = CountingWeapon
	_state.add_weapon(_counting_def(&"c1")); _state.add_weapon(_counting_def(&"c2"))
	_loadout.sync(_state, _catalog)
	_loadout.tick(0.016, null)
	assert_eq((_loadout.get_weapon(&"c1") as CountingWeapon).fired, 1)
	assert_eq((_loadout.get_weapon(&"c2") as CountingWeapon).fired, 1)

func test_unknown_ids_get_a_harmless_default_weapon() -> void:
	_state.add_weapon(_def(&"mystery")); _loadout.sync(_state, {&"mystery": _def(&"mystery")})
	_loadout.tick(0.1, null)
	assert_eq(_loadout.weapon_count(), 1)
```
(`_counting_def(id)` สร้าง `WeaponDef` สองแถว: LV1 cooldown 1.0, LV2 cooldown 0.5 และ `_catalog` ใส่ทุก id ที่ใช้)
และใน test ของ `deal_damage` (วางในไฟล์ `tests/test_weapon_base.gd`): สร้าง `EnemySystem` จริง + `RunState` + `StatBlock` แล้วตรวจ
```gdscript
func test_deal_damage_applies_the_buff_and_records_the_final_amount() -> void:
	_stats.apply_damage_buff(25.0, 3.0)
	_ctx.deal_damage(_enemy_id, 8.0, _weapon)       # 8 * 1.25 = 10
	assert_almost_eq(_state.damage_of(&"w"), 10.0, 0.001)
	assert_almost_eq(_enemies.hp_of(_enemy_id), 90.0, 0.001)   # enemy hp 100

func test_deal_damage_reports_a_kill() -> void:
	assert_true(_ctx.deal_damage(_enemy_id, 1000.0, _weapon))

func test_deal_damage_on_a_dead_enemy_records_nothing() -> void:
	_enemies.kill(_enemy_id)
	assert_false(_ctx.deal_damage(_enemy_id, 10.0, _weapon))
	assert_eq(_state.damage_of(&"w"), 0.0)
```
- [ ] **Step 2: Verify (ต้องตก)**
- [ ] **Step 3: เขียนสามคลาสตาม Interfaces** `deal_damage` บันทึกดาเมจเต็มหลังคูณบัฟ ไม่ตัดตาม HP ที่เหลือของศัตรู
- [ ] **Step 4: Verify (ต้องผ่าน)**
- [ ] **Step 5: Finish `M2-5: add weapon base, context and loadout`**

---

### Task 14 (M2-6): Greatsword LV1

**Files:**
- Create: `run/weapons/greatsword.gd`, `data/weapons/greatsword.tres`, `tests/test_greatsword.gd`
- Modify: `run/weapons/weapon_loadout.gd` (ลงทะเบียน `&"greatsword"` ใน `factories`), `data/classes/knight.tres` (ตั้ง `start_weapon = greatsword.tres`, `class_weapons = [greatsword]`, `steel_lifesteal = 0.03`), `tests/test_class_def.gd`

**Interfaces:**
- Produces: `Greatsword extends WeaponBase` — `_fire` หาศัตรูด้วย `ctx.enemies.query_radius(ctx.player_pos(), lv.range, ctx.hits)` แล้วคัดด้วย `in_cone(origin, facing, lv.arc_degrees, lv.range, enemy_pos)` ศัตรูที่ผ่านแต่ละตัวถูก `ctx.deal_damage(id, lv.damage, self)` และ `ctx.enemies.knockback(id, enemy_pos - origin, lv.knockback)` พร้อมเรียก `ctx.fx.add_arc(...)` เมื่อ `fx != null` ยิงแม้ไม่มีศัตรูในระยะ
- `data/weapons/greatsword.tres`: `id = &"greatsword"`, `display_name = "Greatsword"`, `tag = &"steel"`, `class_id = &"knight"`, `levels` มีแถว LV1 แถวเดียว: `cooldown 1.1, damage 20.0, arc_degrees 140.0, range 48.0, radius 0.0, knockback 20.0, stun_seconds 0.0, both_sides false, buff_percent 0.0, buff_seconds 0.0, heal 0.0`

- [ ] **Step 1: เขียน `tests/test_greatsword.gd`** (เมธอดช่วยสร้าง `EnemySystem` จริงและ `WeaponContext`; ผู้เล่นอยู่ที่ศูนย์กลางหันขวา **ศัตรูในเทสต์อาวุธทุกไฟล์ใช้ `EnemyDef` ที่ `hp = 1000`, `move_speed = 0`** เพื่อไม่ตายและไม่เดินจนตำแหน่งที่ตรวจเพี้ยน; `_spawn(pos)` สร้างศัตรู, `_swing()` เรียก `_weapon.tick(0.0, _ctx)`, `_advance(t)` เรียก `_enemies.tick_movement` ซ้ำจนครบเวลา `t` ที่ก้าว 1/60)
```gdscript
func test_the_data_file_matches_the_design_table() -> void:
	var d: WeaponDef = load("res://data/weapons/greatsword.tres")
	assert_eq(d.id, &"greatsword"); assert_eq(d.tag, &"steel")
	var lv: WeaponLevelDef = d.level_data(1)
	assert_eq(lv.damage, 20.0); assert_eq(lv.cooldown, 1.1); assert_eq(lv.arc_degrees, 140.0)
	assert_eq(lv.range, 48.0); assert_eq(lv.knockback, 20.0)

func test_hits_an_enemy_in_front() -> void:
	var id: int = _spawn(Vector2(30.0, 0.0))
	_swing()
	assert_almost_eq(_enemies.hp_of(id), 980.0, 0.01)

func test_misses_an_enemy_behind() -> void:
	var id: int = _spawn(Vector2(-30.0, 0.0))
	_swing()
	assert_eq(_enemies.hp_of(id), 1000.0)

func test_misses_an_enemy_out_of_range() -> void:
	var id: int = _spawn(Vector2(60.0, 0.0))
	_swing()
	assert_eq(_enemies.hp_of(id), 1000.0)

func test_pushes_the_enemy_away_from_the_player() -> void:
	var id: int = _spawn(Vector2(30.0, 0.0))
	_swing()
	_advance(0.5)
	assert_almost_eq(_enemies.position_of(id).x, 50.0, 0.5)   # 30 + knockback 20

func test_swings_with_no_enemies_without_error() -> void:
	_swing()
	assert_eq(_enemies.alive_count(), 0)

func test_follows_the_last_move_direction() -> void:
	_player.apply_input(Vector2.UP)
	var up: int = _spawn(Vector2(0.0, -30.0))
	var right: int = _spawn(Vector2(30.0, 0.0))
	_swing()
	assert_lt(_enemies.hp_of(up), 1000.0); assert_eq(_enemies.hp_of(right), 1000.0)

func test_damage_is_recorded_for_the_results_screen() -> void:
	_spawn(Vector2(30.0, 0.0)); _swing()
	assert_eq(_state.damage_of(&"greatsword"), 20.0)
```
และใน `tests/test_class_def.gd` ตรวจ Knight: `start_weapon.id == &"greatsword"`, `class_weapons` มี `greatsword`, `steel_lifesteal == 0.03`
- [ ] **Step 2: Verify (ต้องตก)**
- [ ] **Step 3: เขียน `greatsword.gd` และ `.tres` (ทุกฟิลด์ชัดเจน) ปรับ `knight.tres`** ลงทะเบียน `&"greatsword"` ใน `WeaponLoadout.factories` (เติมใน `_init`)
- [ ] **Step 4: Verify (ต้องผ่าน)**
- [ ] **Step 5: Finish `M2-6: add Greatsword level 1`**

---

### Task 15 (M2-7): Greatsword LV2–5

**Files:**
- Modify: `data/weapons/greatsword.tres`, `run/weapons/greatsword.gd`, `tests/test_greatsword.gd`

**Interfaces:**
- แถวใน `.tres` (สะสมจากเลเวลก่อนหน้า ทุกฟิลด์ชัดเจน): LV2 `damage 25`; LV3 `damage 25, arc 180, range 56`; LV4 `damage 25, arc 180, range 56, cooldown 0.9`; LV5 เหมือน LV4 และ `both_sides = true`
- `_fire` เมื่อ `both_sides` ฟันทั้ง `facing` และ `-facing` โดยศัตรูหนึ่งตัวโดน**ครั้งเดียวต่อการฟัน** (เก็บ id ที่โดนแล้วใน buffer ที่ใช้ซ้ำ ไม่สร้าง Array ใหม่)

- [ ] **Step 1: เพิ่มเทสต์**
```gdscript
func test_level_table_matches_the_design() -> void:
	var d: WeaponDef = load("res://data/weapons/greatsword.tres")
	assert_eq(d.max_level(), 5)
	assert_eq(d.level_data(2).damage, 25.0)
	assert_eq(d.level_data(3).arc_degrees, 180.0); assert_eq(d.level_data(3).range, 56.0)
	assert_almost_eq(d.level_data(4).cooldown, 0.9, 0.0001)
	assert_true(d.level_data(5).both_sides); assert_false(d.level_data(4).both_sides)
	for n in range(2, 6):
		assert_eq(d.level_data(n).knockback, 20.0, "knockback never changes")

func test_level_two_hits_for_25() -> void:
	_set_level(2); var id: int = _spawn(Vector2(30.0, 0.0)); _swing()
	assert_almost_eq(_enemies.hp_of(id), 975.0, 0.01)

func test_level_three_reaches_further_and_wider() -> void:
	_set_level(3)
	var far: int = _spawn(Vector2(54.0, 0.0))
	var wide: int = _spawn(Vector2.from_angle(deg_to_rad(85.0)) * 30.0)   # outside 140 deg, inside 180
	_swing()
	assert_lt(_enemies.hp_of(far), 1000.0); assert_lt(_enemies.hp_of(wide), 1000.0)

func test_level_five_also_hits_behind() -> void:
	_set_level(5); var id: int = _spawn(Vector2(-30.0, 0.0)); _swing()
	assert_lt(_enemies.hp_of(id), 1000.0)

func test_level_four_does_not_hit_behind() -> void:
	_set_level(4); var id: int = _spawn(Vector2(-30.0, 0.0)); _swing()
	assert_eq(_enemies.hp_of(id), 1000.0)

func test_level_five_hits_an_enemy_beside_the_player_only_once() -> void:
	_set_level(5)
	var id: int = _spawn(Vector2(0.0, 30.0))         # in both the front and back half-planes' edge
	_swing()
	assert_almost_eq(_enemies.hp_of(id), 975.0, 0.01, "25, not 50")

func test_level_four_swings_faster() -> void:
	_set_level(4); _weapon.tick(0.0, _ctx)            # first swing
	_weapon.tick(0.89, _ctx); assert_eq(_swings(), 1)
	_weapon.tick(0.02, _ctx); assert_eq(_swings(), 2)
```
(`_set_level`, `_swings` เป็นเมธอดช่วยในไฟล์เทสต์)
- [ ] **Step 2: Verify (ต้องตก)**
- [ ] **Step 3: เพิ่มแถว LV2–5 และพฤติกรรม `both_sides`**
- [ ] **Step 4: Verify (ต้องผ่าน)**
- [ ] **Step 5: Finish `M2-7: add Greatsword levels 2 to 5`**

---

### Task 16 (M2-9): Oathguard ดูดเลือด

**Files:**
- Modify: `run/weapon_context.gd`, `tests/test_weapon_base.gd`

**Interfaces:**
- `WeaponContext.deal_damage` เพิ่ม: ถ้า `weapon.def.tag == &"steel"` เรียก `player.heal(final_damage * steel_lifesteal)` (ใช้ดาเมจหลังคูณบัฟ และนับเฉพาะส่วนที่ทำจริงต่อศัตรูที่ยังมีชีวิต) อาวุธแท็กอื่นไม่ดูด

- [ ] **Step 1: เพิ่มเทสต์** (ผู้เล่นต้องเสียเลือดก่อนจึงเห็นผลฮีล)
```gdscript
func test_a_steel_weapon_heals_three_percent_of_damage() -> void:
	_player.take_damage(32.0)                       # 140 - 30 = 110
	_ctx.deal_damage(_enemy_id, 100.0, _steel_weapon)
	assert_almost_eq(_player.hp, 113.0, 0.01)

func test_lifesteal_uses_the_buffed_damage() -> void:
	_player.take_damage(32.0); _stats.apply_damage_buff(25.0, 3.0)
	_ctx.deal_damage(_enemy_id, 100.0, _steel_weapon)   # 125 damage
	assert_almost_eq(_player.hp, 110.0 + 3.75, 0.01)

func test_a_holy_weapon_does_not_heal() -> void:
	_player.take_damage(32.0)
	_ctx.deal_damage(_enemy_id, 100.0, _holy_weapon)
	assert_almost_eq(_player.hp, 110.0, 0.01)

func test_lifesteal_never_exceeds_max_hp() -> void:
	_ctx.deal_damage(_enemy_id, 100.0, _steel_weapon)
	assert_eq(_player.hp, 140.0)

func test_a_blocked_hit_on_a_dead_enemy_does_not_heal() -> void:
	_player.take_damage(32.0); _enemies.kill(_enemy_id)
	_ctx.deal_damage(_enemy_id, 100.0, _steel_weapon)
	assert_almost_eq(_player.hp, 110.0, 0.01)
```
- [ ] **Step 2: Verify (ต้องตก)**
- [ ] **Step 3: เพิ่มดูดเลือดใน `deal_damage`**
- [ ] **Step 4: Verify (ต้องผ่าน)**
- [ ] **Step 5: Finish `M2-9: add Oathguard lifesteal for STEEL weapons`**

---

### Task 17 (M2-24): Shield Bash LV1–5

**Files:**
- Create: `run/weapons/shield_bash.gd`, `data/weapons/shield_bash.tres`, `tests/test_shield_bash.gd`
- Modify: `run/weapons/weapon_loadout.gd` (ลงทะเบียน `&"shield_bash"`), `data/classes/knight.tres` (เพิ่มเข้า `class_weapons`), `tests/test_class_def.gd`

**Interfaces:**
- `.tres`: `id &"shield_bash"`, `tag &"steel"`, `class_id &"knight"`; ทุกแถว `range 40, arc_degrees 90, knockback 60, radius 0, both_sides false, buff 0, heal 0`; LV1 `damage 8, cooldown 3, stun_seconds 0.5`; LV2 `damage 12`; LV3 `damage 16, stun_seconds 1.0`; LV4 `damage 20`; LV5 `damage 24, cooldown 2` (สะสมค่าจากเลเวลก่อนหน้า ทุกฟิลด์ชัดเจน)
- `ShieldBash._fire`: กรวยหน้าตาม `facing` เหมือน Greatsword (ใช้ `in_cone`) ศัตรูที่โดนได้ดาเมจ + `knockback` + `ctx.enemies.stun(id, lv.stun_seconds)`

- [ ] **Step 1: เขียน `tests/test_shield_bash.gd`** (ศัตรูนิ่งแบบเดียวกับ Task 14; `_bash()` = `_weapon.tick(0.0, _ctx)`)
```gdscript
func test_the_level_table_matches_the_design() -> void:
	var d: WeaponDef = load("res://data/weapons/shield_bash.tres")
	assert_eq(d.max_level(), 5); assert_eq(d.tag, &"steel")
	assert_eq(d.level_data(1).damage, 8.0); assert_eq(d.level_data(1).cooldown, 3.0)
	assert_eq(d.level_data(1).stun_seconds, 0.5); assert_eq(d.level_data(1).knockback, 60.0)
	assert_eq(d.level_data(3).stun_seconds, 1.0)
	assert_eq(d.level_data(5).damage, 24.0); assert_eq(d.level_data(5).cooldown, 2.0)
	for n in range(1, 6):
		assert_eq(d.level_data(n).arc_degrees, 90.0); assert_eq(d.level_data(n).range, 40.0)

func test_hits_stuns_and_pushes_an_enemy_in_the_cone() -> void:
	var id: int = _spawn(Vector2(30.0, 0.0)); _bash()
	assert_almost_eq(_enemies.hp_of(id), 992.0, 0.01)
	assert_true(_enemies.is_stunned(id))

func test_misses_outside_the_ninety_degree_cone() -> void:
	var id: int = _spawn(Vector2.from_angle(deg_to_rad(50.0)) * 30.0)   # half angle is 45
	_bash()
	assert_eq(_enemies.hp_of(id), 1000.0); assert_false(_enemies.is_stunned(id))

func test_misses_beyond_range_forty() -> void:
	var id: int = _spawn(Vector2(41.0, 0.0)); _bash()
	assert_eq(_enemies.hp_of(id), 1000.0)

func test_pushes_sixty_pixels() -> void:
	var id: int = _spawn(Vector2(30.0, 0.0)); _bash(); _advance(0.5)
	assert_almost_eq(_enemies.position_of(id).x, 90.0, 0.5)

func test_level_three_stuns_for_a_full_second() -> void:
	_set_level(3); var id: int = _spawn(Vector2(30.0, 0.0)); _bash()
	_advance(0.9); assert_true(_enemies.is_stunned(id))
	_advance(0.2); assert_false(_enemies.is_stunned(id))

func test_it_heals_through_oathguard_because_it_is_steel() -> void:
	_player.take_damage(32.0); _spawn(Vector2(30.0, 0.0)); _bash()
	assert_almost_eq(_player.hp, 110.0 + 8.0 * 0.03, 0.01)

func test_bashing_with_no_enemies_is_harmless() -> void:
	_bash(); assert_eq(_enemies.alive_count(), 0)
```
และใน `tests/test_class_def.gd` ตรวจว่า `class_weapons` ของ Knight มี `shield_bash`
- [ ] **Step 2: Verify (ต้องตก)**
- [ ] **Step 3: เขียน `shield_bash.gd`, `.tres`, ลงทะเบียนใน `factories`, แก้ `knight.tres`**
- [ ] **Step 4: Verify (ต้องผ่าน)**
- [ ] **Step 5: Finish `M2-24: add Shield Bash levels 1 to 5`**

---

### Task 18 (M2-25): Warhorn LV1–5

**Files:**
- Create: `run/weapons/warhorn.gd`, `data/weapons/warhorn.tres`, `tests/test_warhorn.gd`
- Modify: `run/weapons/weapon_loadout.gd` (ลงทะเบียน `&"warhorn"`), `data/classes/knight.tres`, `tests/test_class_def.gd`

**Interfaces:**
- `.tres`: `id &"warhorn"`, `tag &"holy"`, `class_id &"knight"`; ทุกแถว `damage 0, knockback 30, stun 0, arc 0, range 0, cooldown 6, both_sides false, buff_seconds 3`; LV1 `radius 70, buff_percent 15, heal 0`; LV2 `radius 80`; LV3 `radius 90`; LV4 `radius 100, buff_percent 25`; LV5 `radius 110, buff_percent 25, heal 10` (สะสมค่า)
- `Warhorn._fire`: ผลักศัตรูทุกตัวในรัศมี (`query_radius`) ออกจากผู้เล่น `knockback`, เรียก `ctx.stats.apply_damage_buff(lv.buff_percent, lv.buff_seconds)`, ถ้า `lv.heal > 0` เรียก `ctx.player.heal(lv.heal)` และ `ctx.fx.add_ring` (ถ้ามี) **ไม่ทำดาเมจ** และไม่เรียก `deal_damage`

- [ ] **Step 1: เขียน `tests/test_warhorn.gd`** (ใช้ศัตรูนิ่งแบบเดียวกับ Task 14 และเมธอดช่วย `_spawn`, `_blow()` = `_weapon.tick(0.0, _ctx)`, `_advance`, `_set_level`)
```gdscript
func test_the_level_table_matches_the_design() -> void:
	var d: WeaponDef = load("res://data/weapons/warhorn.tres")
	assert_eq(d.max_level(), 5); assert_eq(d.tag, &"holy")
	assert_eq(d.level_data(1).radius, 70.0); assert_eq(d.level_data(1).buff_percent, 15.0)
	assert_eq(d.level_data(1).buff_seconds, 3.0); assert_eq(d.level_data(1).cooldown, 6.0)
	assert_eq(d.level_data(1).knockback, 30.0); assert_eq(d.level_data(1).damage, 0.0)
	assert_eq(d.level_data(4).buff_percent, 25.0); assert_eq(d.level_data(5).radius, 110.0)
	assert_eq(d.level_data(5).heal, 10.0); assert_eq(d.level_data(4).heal, 0.0)

func test_it_pushes_every_enemy_in_the_ring_and_does_no_damage() -> void:
	var a: int = _spawn(Vector2(60.0, 0.0)); var b: int = _spawn(Vector2(0.0, -60.0))
	_blow(); _advance(0.5)
	assert_gt(_enemies.position_of(a).x, 60.0 + 25.0); assert_lt(_enemies.position_of(b).y, -60.0 - 25.0)
	assert_eq(_enemies.hp_of(a), 1000.0); assert_eq(_state.damage_of(&"warhorn"), 0.0)

func test_it_ignores_enemies_outside_the_radius() -> void:
	var id: int = _spawn(Vector2(75.0, 0.0)); _blow(); _advance(0.5)
	assert_eq(_enemies.position_of(id), Vector2(75.0, 0.0), "radius is 70, so 75 is not pushed")

func test_it_buffs_the_players_damage_for_three_seconds() -> void:
	_blow()
	assert_almost_eq(_stats.damage_multiplier(), 1.15, 0.0001)
	_stats.tick(3.0)
	assert_eq(_stats.damage_multiplier(), 1.0)

func test_blowing_again_refreshes_the_buff_without_stacking() -> void:
	_blow(); _stats.tick(2.0); _blow()
	assert_almost_eq(_stats.damage_multiplier(), 1.15, 0.0001)
	assert_almost_eq(_stats.buff_time_left(), 3.0, 0.0001)

func test_level_four_gives_a_stronger_buff() -> void:
	_set_level(4); _blow()
	assert_almost_eq(_stats.damage_multiplier(), 1.25, 0.0001)

func test_only_level_five_heals() -> void:
	_player.take_damage(52.0)                       # 140 - 50 = 90
	_set_level(4); _blow(); assert_almost_eq(_player.hp, 90.0, 0.01)
	_set_level(5); _blow(); assert_almost_eq(_player.hp, 100.0, 0.01)

func test_it_works_with_no_enemies_nearby() -> void:
	_blow(); assert_almost_eq(_stats.damage_multiplier(), 1.15, 0.0001)
```
และเพิ่มเทสต์รวมใน `tests/test_weapon_base.gd` หรือไฟล์ใหม่ว่า **บัฟ Warhorn เพิ่มดาเมจ Greatsword**: เป่า Warhorn แล้วฟัน → ศัตรูได้ `20 * 1.15 = 23`
- [ ] **Step 2: Verify (ต้องตก)**
- [ ] **Step 3: เขียน `warhorn.gd`, `.tres`, ลงทะเบียนใน `factories`, แก้ `knight.tres`**
- [ ] **Step 4: Verify (ต้องผ่าน)**
- [ ] **Step 5: Finish `M2-25: add Warhorn levels 1 to 5`**

---

### Task 19 (M2-10): `PickupSystem` โครง

**Files:**
- Create: `run/pickup_system.gd`, `tests/test_pickup_system.gd`

**Interfaces:**
- Produces: `class_name PickupSystem extends MultiMeshInstance2D`; `setup(tuning: RunTuning) -> void` (ขนาดช่อง = `tuning.gem_capacity`), `spawn(pos: Vector2, xp: int) -> bool` (คืน `false` ถ้าช่องเต็ม ไม่ทำอะไร), `active_count() -> int`, `position_of(id: int) -> Vector2`, `is_active(id: int) -> bool`, `transform_of(id: int) -> Transform2D` (ขนาดตาม `gem_radius`, ช่องว่าง = `DEAD_TRANSFORM`), `sync_multimesh() -> void`, `clear() -> void`; ข้อมูลเก็บแบบ SoA (`_pos`, `_xp`, `_active`) + `Pool` ไม่มี Node ต่อ gem
- (ดูด/เก็บเป็นของ Task 20)

- [ ] **Step 1: เขียนเทสต์** (ใช้ `RunTuning` ที่ตั้ง `gem_capacity = 4`)
```gdscript
func test_spawn_returns_true_and_counts_the_gem() -> void:
	assert_true(_p.spawn(Vector2(5.0, 5.0), 1)); assert_eq(_p.active_count(), 1)

func test_spawn_stores_position() -> void:
	_p.spawn(Vector2(5.0, 5.0), 1)
	assert_eq(_p.position_of(0), Vector2(5.0, 5.0))

func test_spawn_returns_false_when_full_and_changes_nothing() -> void:
	for i in 4: assert_true(_p.spawn(Vector2.ZERO, 1))
	assert_false(_p.spawn(Vector2.ZERO, 1)); assert_eq(_p.active_count(), 4)

func test_the_multimesh_has_one_instance_per_slot() -> void:
	assert_eq(_p.multimesh.instance_count, 4)
	assert_eq(_p.multimesh.transform_format, MultiMesh.TRANSFORM_2D)

func test_a_gem_is_drawn_at_its_position_with_the_gem_radius() -> void:
	_p.spawn(Vector2(20.0, 5.0), 1)
	assert_eq(_p.transform_of(0).origin, Vector2(20.0, 5.0))
	assert_almost_eq(_p.transform_of(0).x.length(), 3.0, 0.001)

func test_empty_slots_are_hidden() -> void:
	assert_eq(_p.transform_of(2), PickupSystem.DEAD_TRANSFORM)

func test_the_system_has_no_child_nodes() -> void:
	for i in 4: _p.spawn(Vector2.ZERO, 1)
	assert_eq(_p.get_child_count(), 0)

func test_clear_empties_the_system() -> void:
	_p.spawn(Vector2.ZERO, 1); _p.clear()
	assert_eq(_p.active_count(), 0)
```
- [ ] **Step 2: Verify (ต้องตก)**
- [ ] **Step 3: เขียน `pickup_system.gd`** สร้าง MultiMesh เหมือน `EnemySystem._build_multimesh` (quad ขนาด 2 ปรับด้วย scale)
- [ ] **Step 4: Verify (ต้องผ่าน)**
- [ ] **Step 5: Finish `M2-10: add PickupSystem storage and drawing`**

---

### Task 20 (M2-11): ดูด/เก็บ gem + ช่องเต็ม

**Files:**
- Modify: `run/pickup_system.gd`, `tests/test_pickup_system.gd`

**Interfaces:**
- Produces: signal `xp_collected(amount: int)`; `tick(delta: float, player_pos: Vector2, pickup_radius: float, player_radius: float) -> void` gem ที่ห่างจากผู้เล่นไม่เกิน `pickup_radius` เคลื่อนเข้าหาผู้เล่นด้วย `gem_pull_speed` (ไม่เลยตำแหน่งผู้เล่นในก้าวเดียว) gem ที่ห่างไม่เกิน `player_radius + gem_radius` ถูกเก็บ: ปล่อยช่องคืน `Pool` และยิง `xp_collected(xp)` ครั้งเดียวต่อ gem; ไม่อยู่ในรัศมี = นิ่ง
- Produces: `spawn_or_grant(pos: Vector2, xp: int) -> int` คืน `xp` ที่ต้องให้ทันที (`0` ถ้าวาง gem ได้, `xp` ถ้าช่องเต็ม) เพื่อให้ผู้เรียกบวกเข้า `RunState` เอง (ครอบ Review Focus ข้อ 2)

- [ ] **Step 1: เพิ่มเทสต์**
```gdscript
func test_a_gem_outside_the_pickup_radius_stays_put() -> void:
	_p.spawn(Vector2(100.0, 0.0), 1)
	_p.tick(0.5, Vector2.ZERO, 40.0, 7.0)
	assert_eq(_p.position_of(0), Vector2(100.0, 0.0))

func test_a_gem_inside_the_radius_is_pulled_at_the_tuned_speed() -> void:
	_p.spawn(Vector2(30.0, 0.0), 1)
	_p.tick(0.1, Vector2.ZERO, 40.0, 7.0)
	assert_almost_eq(_p.position_of(0).x, 30.0 - 18.0, 0.01)     # 180 px/s * 0.1 s

func test_touching_the_player_collects_the_gem_once() -> void:
	watch_signals(_p)
	_p.spawn(Vector2(9.0, 0.0), 3)                              # 7 + 3 = 10 reach
	_p.tick(0.016, Vector2.ZERO, 40.0, 7.0)
	assert_signal_emitted_with_parameters(_p, "xp_collected", [3])
	assert_eq(_p.active_count(), 0)
	_p.tick(0.016, Vector2.ZERO, 40.0, 7.0)
	assert_signal_emit_count(_p, "xp_collected", 1)

func test_a_gem_is_never_pulled_past_the_player() -> void:
	_p.spawn(Vector2(11.0, 0.0), 1)                             # just outside touch range
	_p.tick(1.0, Vector2.ZERO, 40.0, 7.0)                       # 180 px of pull in one step
	assert_eq(_p.active_count(), 0, "it arrived and was collected, not overshot")

func test_a_collected_slot_is_reused() -> void:
	_p.spawn(Vector2(9.0, 0.0), 1); _p.tick(0.016, Vector2.ZERO, 40.0, 7.0)
	_p.spawn(Vector2(50.0, 0.0), 1)
	assert_eq(_p.position_of(0), Vector2(50.0, 0.0))

func test_a_larger_pickup_radius_pulls_from_further_away() -> void:
	_p.spawn(Vector2(60.0, 0.0), 1)
	_p.tick(0.1, Vector2.ZERO, 40.0, 7.0); assert_eq(_p.position_of(0).x, 60.0)
	_p.tick(0.1, Vector2.ZERO, 70.0, 7.0); assert_lt(_p.position_of(0).x, 60.0)

func test_spawn_or_grant_places_a_gem_when_there_is_room() -> void:
	assert_eq(_p.spawn_or_grant(Vector2.ZERO, 5), 0); assert_eq(_p.active_count(), 1)

func test_spawn_or_grant_returns_the_xp_when_full() -> void:
	for i in 4: _p.spawn(Vector2.ZERO, 1)
	assert_eq(_p.spawn_or_grant(Vector2.ZERO, 5), 5); assert_eq(_p.active_count(), 4)

func test_many_gems_collected_in_one_tick_all_report() -> void:
	watch_signals(_p)
	for i in 4: _p.spawn(Vector2(5.0, 0.0), 2)
	_p.tick(0.016, Vector2.ZERO, 40.0, 7.0)
	assert_signal_emit_count(_p, "xp_collected", 4)
```
- [ ] **Step 2: Verify (ต้องตก)**
- [ ] **Step 3: เพิ่ม `tick`, `xp_collected`, `spawn_or_grant`** ลูปอ่าน SoA อย่างเดียว ไม่ allocate
- [ ] **Step 4: Verify (ต้องผ่าน)**
- [ ] **Step 5: Finish `M2-11: pull and collect XP gems`**

---

### Task 21 (M2-12): `LevelUpDeck` + `Rng.weighted_pick`

**Files:**
- Create: `run/level_up_card.gd`, `run/level_up_deck.gd`, `tests/test_level_up_deck.gd`
- Modify: `core/rng.gd`, `tests/test_rng.gd`

**Interfaces:**
- Produces: `Rng.weighted_pick(weights: PackedFloat32Array) -> int` คืน index ตามน้ำหนัก (น้ำหนัก 0 ไม่ถูกเลือก; ถ้ารวมเป็น 0 หรืออาร์เรย์ว่างคืน `-1`)
- Produces: `LevelUpCard extends RefCounted` — `enum Kind { WEAPON, FALLBACK }`, `kind: Kind`, `weapon: WeaponDef`, `new_level: int` (เลเวลที่จะได้ เช่น ได้ใหม่ = 1, อัป LV2→LV3 = 3), `fallback: CardDef` (Task 22 สร้าง `CardDef`; ในงานนี้ `fallback` ใช้ได้เฉพาะ `null` จึงให้ Task 21 ประกาศ `CardDef` ว่างขั้นต่ำใน `data/card_def.gd` ที่มีแค่ `id: StringName` แล้ว Task 22 เติมฟิลด์), `is_upgrade() -> bool`
- Produces: `LevelUpDeck` — `static draw(state: RunState, class_def: ClassDef, fallbacks: Array[CardDef], rng: Rng, count: int = 3) -> Array[LevelUpCard]` พูลอาวุธ = `class_def.class_weapons` ที่ (ยังไม่มีและช่องว่าง) หรือ (มีแล้วและยังไม่เต็มเลเวล) น้ำหนักของที่ถืออยู่ = 2.0 ของใหม่ = 1.0 สุ่มแบบไม่ซ้ำจนครบ `count` หรือพูลหมด ที่เหลือเติมด้วย `fallbacks` ตามลำดับวนซ้ำ (ใบสำรองซ้ำกันได้เมื่อไม่มีทางเลือกอื่น) คืนอาร์เรย์ขนาด `count` เสมอเมื่อ `fallbacks` ไม่ว่าง

- [ ] **Step 1: เขียนเทสต์** (เมธอดช่วยสร้าง `ClassDef` ที่มี 3 อาวุธ `a b c` และ `fallbacks` สองใบ)
```gdscript
# tests/test_rng.gd
func test_weighted_pick_never_chooses_a_zero_weight() -> void:
	var r: Rng = Rng.new(1)
	for i in 200: assert_ne(r.weighted_pick(PackedFloat32Array([0.0, 1.0, 0.0])), 0)
func test_weighted_pick_follows_the_weights() -> void:
	var r: Rng = Rng.new(1); var counts: Array[int] = [0, 0]
	for i in 3000: counts[r.weighted_pick(PackedFloat32Array([1.0, 2.0]))] += 1
	assert_between(float(counts[1]) / float(counts[0]), 1.7, 2.3)
func test_weighted_pick_degenerate_inputs_return_minus_one() -> void:
	var r: Rng = Rng.new(1)
	assert_eq(r.weighted_pick(PackedFloat32Array()), -1)
	assert_eq(r.weighted_pick(PackedFloat32Array([0.0, 0.0])), -1)

# tests/test_level_up_deck.gd
func test_draws_three_distinct_cards() -> void:
	var cards: Array[LevelUpCard] = LevelUpDeck.draw(_state, _class, _fallbacks, Rng.new(3))
	assert_eq(cards.size(), 3)
	assert_eq(cards[0].weapon != cards[1].weapon, true); assert_ne(cards[1].weapon, cards[2].weapon)

func test_held_weapons_are_twice_as_likely() -> void:
	_state.add_weapon(_a)                                 # a held, b and c new
	var a_first: int = 0
	for s in 600:
		var cards: Array[LevelUpCard] = LevelUpDeck.draw(_state, _class, _fallbacks, Rng.new(s), 1)
		if cards[0].weapon == _a: a_first += 1
	assert_between(float(a_first) / 600.0, 0.43, 0.57)    # weight 2 of 4 total

func test_a_held_weapon_card_is_an_upgrade_to_the_next_level() -> void:
	_state.add_weapon(_a); _state.upgrade_weapon(&"a")    # level 2
	var card: LevelUpCard = _first_card_for(_a)
	assert_true(card.is_upgrade()); assert_eq(card.new_level, 3)

func test_a_new_weapon_card_starts_at_level_one() -> void:
	assert_eq(_first_card_for(_b).new_level, 1)

func test_a_maxed_weapon_is_never_offered() -> void:
	_state.add_weapon(_a)
	for i in 4: _state.upgrade_weapon(&"a")
	for s in 100:
		for c in LevelUpDeck.draw(_state, _class, _fallbacks, Rng.new(s)):
			assert_ne(c.weapon, _a)

func test_no_new_weapon_is_offered_when_slots_are_full() -> void:
	for n in ["w1", "w2", "w3", "w4"]: _state.add_weapon(_weapon(StringName(n)))
	for s in 50:
		for c in LevelUpDeck.draw(_state, _class, _fallbacks, Rng.new(s)):
			assert_eq(c.kind, LevelUpCard.Kind.FALLBACK, "slots are full and none of the class weapons is held")

func test_only_the_classes_own_weapons_are_offered() -> void:
	var foreign: WeaponDef = _weapon(&"foreign")          # not in class_weapons
	for s in 50:
		for c in LevelUpDeck.draw(_state, _class, _fallbacks, Rng.new(s)):
			assert_ne(c.weapon, foreign)

func test_fallbacks_fill_the_hand_when_real_choices_run_out() -> void:
	_class.class_weapons = [_a] as Array[WeaponDef]       # only one real choice
	var cards: Array[LevelUpCard] = LevelUpDeck.draw(_state, _class, _fallbacks, Rng.new(1))
	assert_eq(cards.size(), 3); assert_eq(cards[0].kind, LevelUpCard.Kind.WEAPON)
	assert_eq(cards[1].kind, LevelUpCard.Kind.FALLBACK); assert_eq(cards[2].kind, LevelUpCard.Kind.FALLBACK)

func test_with_nothing_but_fallbacks_the_hand_is_all_fallback() -> void:
	_class.class_weapons = [] as Array[WeaponDef]
	var cards: Array[LevelUpCard] = LevelUpDeck.draw(_state, _class, _fallbacks, Rng.new(1))
	assert_eq(cards.size(), 3)
	for c in cards: assert_eq(c.kind, LevelUpCard.Kind.FALLBACK)

func test_the_same_seed_gives_the_same_hand() -> void:
	var one: Array[LevelUpCard] = LevelUpDeck.draw(_state, _class, _fallbacks, Rng.new(9))
	var two: Array[LevelUpCard] = LevelUpDeck.draw(_state, _class, _fallbacks, Rng.new(9))
	for i in 3: assert_eq(one[i].weapon, two[i].weapon)
```
- [ ] **Step 2: Verify (ต้องตก)**
- [ ] **Step 3: เพิ่ม `Rng.weighted_pick`, เขียน `LevelUpCard`, `CardDef` ขั้นต่ำ และ `LevelUpDeck.draw`**
- [ ] **Step 4: Verify (ต้องผ่าน)**
- [ ] **Step 5: Finish `M2-12: add level-up deck with weighted draws`**

---

### Task 22 (M2-13): การ์ดสำรอง

**Files:**
- Modify: `data/card_def.gd`
- Create: `data/cards/hearth_bread.tres`, `data/cards/ember_purse.tres`, `tests/test_card_def.gd`

**Interfaces:**
- `CardDef extends Resource`: `id: StringName`, `display_name: String`, `description: String`, `heal_amount: float`, `embers_bonus: int`
- `hearth_bread.tres`: `id &"hearth_bread"`, `display_name "Hearth Bread"`, `heal_amount 30.0`, `embers_bonus 0`; `ember_purse.tres`: `id &"ember_purse"`, `display_name "Ember Purse"`, `heal_amount 0.0`, `embers_bonus 5` (`description` เป็นข้อความสั้นภาษาอังกฤษของการ์ด ใส่ในไฟล์ได้ตามสะดวก ทุกฟิลด์ชัดเจน)

- [ ] **Step 1: เขียน `tests/test_card_def.gd`**
```gdscript
func test_hearth_bread_heals_thirty() -> void:
	var c: CardDef = load("res://data/cards/hearth_bread.tres")
	assert_eq(c.id, &"hearth_bread"); assert_eq(c.heal_amount, 30.0); assert_eq(c.embers_bonus, 0)

func test_ember_purse_gives_five_embers() -> void:
	var c: CardDef = load("res://data/cards/ember_purse.tres")
	assert_eq(c.id, &"ember_purse"); assert_eq(c.embers_bonus, 5); assert_eq(c.heal_amount, 0.0)

func test_every_fallback_has_a_display_name() -> void:
	for p in ["hearth_bread", "ember_purse"]:
		assert_ne((load("res://data/cards/%s.tres" % p) as CardDef).display_name, "")
```
- [ ] **Step 2: Verify (ต้องตก)**
- [ ] **Step 3: เติมฟิลด์ `CardDef` และเขียนสอง `.tres`**
- [ ] **Step 4: Verify (ต้องผ่าน)**
- [ ] **Step 5: Finish `M2-13: add fallback level-up cards`**

---

### Task 23 (M2-14): `LevelUpPanel`

**Files:**
- Create: `ui/level_up_panel.gd`, `ui/level_up_panel.tscn`, `tests/test_level_up_panel.gd`

**Interfaces:**
- Produces: `LevelUpPanel extends CanvasLayer`; signal `card_picked(index: int)`; `show_cards(cards: Array[LevelUpCard], old_level: int, new_level: int) -> void` (แสดงหน้า ข้อความ "เลเวล old → new" และ 3 การ์ดพร้อมแท็ก/ชื่อ/เลเวลเดิม→ใหม่ของอาวุธ หรือข้อความการ์ดสำรอง), `hide_panel() -> void`, `is_open() -> bool`; รับอินพุตใน `_unhandled_input` เฉพาะเมื่อเปิดอยู่: คีย์ `KEY_1/2/3` เลือกใบที่ 1/2/3 (ถ้ามีใบนั้น) และคลิกบนปุ่มการ์ด; เลือกแล้วยิง `card_picked(index)` และ**ปิดตัวเอง** ไม่แก้ระบบเกมใด ๆ
- Produces: `static card_title(card: LevelUpCard) -> String` (ฟังก์ชันล้วนสำหรับเทสต์: อาวุธใหม่ = `"<ชื่อ>"`, อัป = `"<ชื่อ> LV<ใหม่>"`, สำรอง = `fallback.display_name`) และ `static key_to_index(keycode: Key, count: int) -> int` (`KEY_1`→0 … `KEY_3`→2, ไม่มีใบนั้นหรือคีย์อื่น = -1)

- [ ] **Step 1: เขียนเทสต์**
```gdscript
func test_card_titles() -> void:
	assert_eq(LevelUpPanel.card_title(_new_weapon_card("Greatsword")), "Greatsword")
	assert_eq(LevelUpPanel.card_title(_upgrade_card("Greatsword", 3)), "Greatsword LV3")
	assert_eq(LevelUpPanel.card_title(_fallback_card("Hearth Bread")), "Hearth Bread")

func test_number_keys_map_to_card_indices() -> void:
	assert_eq(LevelUpPanel.key_to_index(KEY_1, 3), 0); assert_eq(LevelUpPanel.key_to_index(KEY_3, 3), 2)

func test_a_key_for_a_missing_card_is_ignored() -> void:
	assert_eq(LevelUpPanel.key_to_index(KEY_3, 2), -1); assert_eq(LevelUpPanel.key_to_index(KEY_A, 3), -1)

func test_the_panel_is_closed_until_cards_are_shown() -> void:
	assert_false(_panel.is_open())
	_panel.show_cards(_three_cards(), 1, 2); assert_true(_panel.is_open())

func test_picking_emits_the_index_and_closes() -> void:
	_panel.show_cards(_three_cards(), 1, 2); watch_signals(_panel)
	_panel._pick(1)
	assert_signal_emitted_with_parameters(_panel, "card_picked", [1])
	assert_false(_panel.is_open())

func test_keys_do_nothing_while_closed() -> void:
	watch_signals(_panel); _panel._unhandled_input(_key_event(KEY_1))
	assert_signal_not_emitted(_panel, "card_picked")

func test_pressing_one_while_open_picks_the_first_card() -> void:
	_panel.show_cards(_three_cards(), 1, 2); watch_signals(_panel)
	_panel._unhandled_input(_key_event(KEY_1))
	assert_signal_emitted_with_parameters(_panel, "card_picked", [0])

func test_a_second_pick_while_closed_is_ignored() -> void:
	_panel.show_cards(_three_cards(), 1, 2); _panel._pick(0)
	watch_signals(_panel); _panel._pick(0)
	assert_signal_not_emitted(_panel, "card_picked")

func test_showing_the_next_queued_hand_reopens_the_panel() -> void:
	_panel.show_cards(_three_cards(), 1, 2); _panel._pick(0)
	_panel.show_cards(_three_cards(), 2, 3)
	assert_true(_panel.is_open())
```
(เมธอดช่วย `_three_cards()` สร้างการ์ดจริง; `_key_event(k)` สร้าง `InputEventKey` ที่ `pressed = true`)
- [ ] **Step 2: Verify (ต้องตก)**
- [ ] **Step 3: เขียน script และฉากด้วยโหนด `Control` มาตรฐาน** (`Label`, `Button` สามปุ่ม) สีตัวอักษร/ขนาดตามฉาก `debug_overlay.tscn` เป็นแนวทาง ฟอนต์ขนาดเล็กเหมาะกับ 640×360 ตรวจด้วยตาใน Task 31
- [ ] **Step 4: Verify (ต้องผ่าน)**
- [ ] **Step 5: Finish `M2-14: add the level-up card panel`**

---

### Task 24 (M2-16): `HUD`

**Files:**
- Create: `ui/hud.gd`, `ui/hud.tscn`, `tests/test_hud.gd`

**Interfaces:**
- Produces: `HUD extends CanvasLayer` — `bind(state: RunState, player: Player) -> void` ต่อ signal: `RunState.xp_changed`, `kills_changed`, `build_changed`, `Player.health_changed`; `set_clock(seconds: float) -> void` (Run เรียกทุกเฟรมหรือถี่พอ); `set_embers(total: int) -> void`; องค์ประกอบ: แถบ XP บนสุดเต็มความกว้าง, HP ซ้ายบน (`"HP 117 / 140"`), เวลากลางบน, `kills` และ `Embers` ขวาบน, ช่องอาวุธ 4 ช่อง (ชื่อ + เลเวล) และพาสซีฟ 4 ช่อง (ว่างใน M2) ซ้ายล่าง HUD **อ่านอย่างเดียว** ไม่เรียกเมธอดที่แก้ `RunState`/`Player`
- Produces: `static format_time(seconds: float) -> String` (`"MM:SS"` ปัดลง, `0.0` = `"00:00"`, `125.9` = `"02:05"`, `3599.0` = `"59:59"`, `3600.0` = `"60:00"`), `static format_hp(hp: float, max_hp: float) -> String` (`"HP 117 / 140"` ปัดเศษเป็นจำนวนเต็มปัดขึ้นสำหรับ HP ที่เหลือเศษ แต่ HP 0 < hp < 1 แสดง `1`)

- [ ] **Step 1: เขียนเทสต์**
```gdscript
func test_time_formatting() -> void:
	assert_eq(HUD.format_time(0.0), "00:00"); assert_eq(HUD.format_time(125.9), "02:05")
	assert_eq(HUD.format_time(3599.0), "59:59"); assert_eq(HUD.format_time(3600.0), "60:00")

func test_negative_time_is_clamped_to_zero() -> void:
	assert_eq(HUD.format_time(-3.0), "00:00")

func test_hp_formatting() -> void:
	assert_eq(HUD.format_hp(117.0, 140.0), "HP 117 / 140")
	assert_eq(HUD.format_hp(0.4, 140.0), "HP 1 / 140", "a living player never shows 0")
	assert_eq(HUD.format_hp(0.0, 140.0), "HP 0 / 140")

func test_binding_shows_the_current_state() -> void:
	_hud.bind(_state, _player)
	assert_eq(_hud.hp_text(), "HP 140 / 140")
	assert_eq(_hud.kills_text(), "0")

func test_it_updates_from_signals() -> void:
	_hud.bind(_state, _player)
	_state.add_kill(); _state.add_kill()
	_player.take_damage(25.0)
	assert_eq(_hud.kills_text(), "2"); assert_eq(_hud.hp_text(), "HP 117 / 140")

func test_weapon_slots_follow_the_build() -> void:
	_hud.bind(_state, _player)
	_state.add_weapon(_weapon(&"greatsword", "Greatsword"))
	assert_eq(_hud.weapon_slot_text(0), "Greatsword 1"); assert_eq(_hud.weapon_slot_text(1), "")
	_state.upgrade_weapon(&"greatsword")
	assert_eq(_hud.weapon_slot_text(0), "Greatsword 2")

func test_xp_bar_reflects_progress() -> void:
	_hud.bind(_state, _player); _state.add_xp(5)
	assert_almost_eq(_hud.xp_fraction(), 0.5, 0.001)       # 5 of 10 needed
```
(เมธอดที่ลงท้าย `_text`/`xp_fraction` เป็น getter สำหรับเทสต์ที่อ่านจากโหนดจริง)
- [ ] **Step 2: Verify (ต้องตก)**
- [ ] **Step 3: เขียน script + ฉาก** วางตำแหน่งตามหัวข้อ 11 ข้อ 2 ของ design.md
- [ ] **Step 4: Verify (ต้องผ่าน)**
- [ ] **Step 5: Finish `M2-16: add the in-run HUD`**

---

### Task 25 (M2-17): `PauseScreen`

**Files:**
- Create: `ui/pause_screen.gd`, `ui/pause_screen.tscn`, `tests/test_pause_screen.gd`

**Interfaces:**
- Produces: `PauseScreen extends CanvasLayer` — `show_build(lines: PackedStringArray) -> void` (แสดงบิลด์ปัจจุบัน หนึ่งบรรทัดต่อรายการ), `hide_screen() -> void`, `is_open() -> bool`; ไม่รับอินพุตเอง (Run เป็นคนสลับสถานะจาก action `pause`) ไม่แก้ระบบเกม
- Produces: `static build_lines(state: RunState, name_of: Dictionary) -> PackedStringArray` (ฟังก์ชันล้วน: `"Greatsword  LV2"` ต่อหนึ่งอาวุธตามลำดับที่เพิ่ม; ไม่มีอาวุธเลย = `["(empty)"]`; `name_of` = id → ชื่อที่แสดง ถ้าไม่มี id ใช้ id เป็นชื่อ)

- [ ] **Step 1: เขียนเทสต์**
```gdscript
func test_build_lines_list_each_weapon_with_its_level() -> void:
	_state.add_weapon(_weapon(&"greatsword")); _state.upgrade_weapon(&"greatsword")
	_state.add_weapon(_weapon(&"warhorn"))
	var lines: PackedStringArray = PauseScreen.build_lines(_state, {&"greatsword": "Greatsword", &"warhorn": "Warhorn"})
	assert_eq(lines, PackedStringArray(["Greatsword  LV2", "Warhorn  LV1"]))

func test_an_empty_build_says_so() -> void:
	assert_eq(PauseScreen.build_lines(_state, {}), PackedStringArray(["(empty)"]))

func test_an_unknown_id_falls_back_to_the_id() -> void:
	_state.add_weapon(_weapon(&"mystery"))
	assert_eq(PauseScreen.build_lines(_state, {})[0], "mystery  LV1")

func test_open_and_close() -> void:
	assert_false(_screen.is_open())
	_screen.show_build(PackedStringArray(["x"])); assert_true(_screen.is_open())
	_screen.hide_screen(); assert_false(_screen.is_open())
```
- [ ] **Step 2: Verify (ต้องตก)**
- [ ] **Step 3: เขียน script + ฉาก**
- [ ] **Step 4: Verify (ต้องผ่าน)**
- [ ] **Step 5: Finish `M2-17: add the pause screen`**

---

### Task 26 (M2-19): `RunSummary` + `ResultsScreen`

**Files:**
- Create: `run/run_summary.gd`, `ui/results_screen.gd`, `ui/results_screen.tscn`, `tests/test_run_summary.gd`, `tests/test_results_screen.gd`

**Interfaces:**
- Produces: `RunSummary extends RefCounted` ฟิลด์ `survived_seconds: float`, `kills: int`, `level: int`, `damage_by_weapon: Dictionary` (id → float), `embers_from_kills: int`, `embers_from_time: int`, `embers_bonus: int`, `embers_total: int`; `static from_state(state: RunState) -> RunSummary` สำเนาค่าจาก `RunState` ณ ขณะนั้น (ไม่เก็บ reference ของ state)
- Produces: `ResultsScreen extends CanvasLayer` — signal `back_pressed()`, `show_summary(summary: RunSummary, name_of: Dictionary) -> void`, `static summary_lines(summary: RunSummary, name_of: Dictionary) -> PackedStringArray` (ฟังก์ชันล้วน แต่ละบรรทัดข้อความภาษาอังกฤษ: `"Survived 02:05"`, `"Kills 29"`, `"Level 4"`, หนึ่งบรรทัดต่ออาวุธเรียงดาเมจมากไปน้อย `"Greatsword  1,250"` (คั่นหลักพันด้วยจุลภาค ปัดเป็นจำนวนเต็ม), แล้วที่มา Embers ทีละบรรทัด `"Embers from kills +2"`, `"Embers from time +8"`, `"Embers from Ember Purse +5"` (บรรทัด Purse แสดงเฉพาะเมื่อ > 0) และ `"Embers total 15"`)

- [ ] **Step 1: เขียนเทสต์**
```gdscript
func test_from_state_copies_the_numbers() -> void:
	for i in 29: _state.add_kill()
	_state.tick(125.0); _state.add_xp(24); _state.add_embers_bonus(5)
	_state.record_damage(&"greatsword", 1250.4)
	var s: RunSummary = RunSummary.from_state(_state)
	assert_eq(s.kills, 29); assert_almost_eq(s.survived_seconds, 125.0, 0.001); assert_eq(s.level, 3)
	assert_eq(s.embers_from_kills, 2); assert_eq(s.embers_from_time, 8); assert_eq(s.embers_bonus, 5)
	assert_eq(s.embers_total, 15); assert_almost_eq(s.damage_by_weapon[&"greatsword"], 1250.4, 0.01)

func test_the_summary_does_not_change_when_the_state_does() -> void:
	var s: RunSummary = RunSummary.from_state(_state)
	_state.add_kill()
	assert_eq(s.kills, 0)

func test_lines_report_time_kills_level() -> void:
	var lines: PackedStringArray = ResultsScreen.summary_lines(_summary(), {&"greatsword": "Greatsword"})
	assert_eq(lines[0], "Survived 02:05"); assert_eq(lines[1], "Kills 29"); assert_eq(lines[2], "Level 3")

func test_weapons_are_listed_by_damage_descending_with_thousands_separators() -> void:
	var lines: PackedStringArray = ResultsScreen.summary_lines(_summary_two_weapons(), {&"a": "Greatsword", &"b": "Shield Bash"})
	assert_true(lines.has("Greatsword  1,250")); assert_true(lines.has("Shield Bash  96"))
	assert_lt(lines.find("Greatsword  1,250"), lines.find("Shield Bash  96"))

func test_embers_sources_are_listed_one_per_line() -> void:
	var lines: PackedStringArray = ResultsScreen.summary_lines(_summary(), {})
	assert_true(lines.has("Embers from kills +2")); assert_true(lines.has("Embers from time +8"))
	assert_true(lines.has("Embers from Ember Purse +5")); assert_true(lines.has("Embers total 15"))

func test_the_purse_line_is_hidden_when_zero() -> void:
	var s: RunSummary = _summary(); s.embers_bonus = 0; s.embers_total = 10
	for l in ResultsScreen.summary_lines(s, {}): assert_false(l.contains("Purse"))

func test_a_run_with_no_damage_or_kills_still_renders() -> void:
	var lines: PackedStringArray = ResultsScreen.summary_lines(RunSummary.new(), {})
	assert_true(lines.has("Kills 0")); assert_true(lines.has("Embers total 0"))

func test_the_back_button_signal() -> void:
	watch_signals(_screen); _screen._on_back_pressed()
	assert_signal_emitted(_screen, "back_pressed")
```
- [ ] **Step 2: Verify (ต้องตก)**
- [ ] **Step 3: เขียน `RunSummary`, `ResultsScreen` (script + ฉาก)**
- [ ] **Step 4: Verify (ต้องผ่าน)**
- [ ] **Step 5: Finish `M2-19: add run summary and results screen`**

---

### Task 27 (M2-20): `CampScreen`

**Files:**
- Create: `ui/camp_screen.gd`, `ui/camp_screen.tscn`, `tests/test_camp_screen.gd`

**Interfaces:**
- Produces: `CampScreen extends CanvasLayer` — signal `start_pressed()`, `set_embers(total: int) -> void`, `static embers_text(total: int) -> String` (`"Embers 0"`, `"Embers 1,234"`), ปุ่ม "เริ่มคืน" (ข้อความบนปุ่มเป็น `"Begin the night"`) ยิง `start_pressed` ไม่ทำอย่างอื่น (ร้านและเลือกอาชีพเป็นของ M3–M4)

- [ ] **Step 1: เขียนเทสต์**
```gdscript
func test_embers_text() -> void:
	assert_eq(CampScreen.embers_text(0), "Embers 0")
	assert_eq(CampScreen.embers_text(1234), "Embers 1,234")

func test_set_embers_updates_the_label() -> void:
	_camp.set_embers(15); assert_eq(_camp.embers_label_text(), "Embers 15")

func test_pressing_start_emits_once_per_press() -> void:
	watch_signals(_camp); _camp._on_start_pressed(); _camp._on_start_pressed()
	assert_signal_emit_count(_camp, "start_pressed", 2)

func test_negative_embers_are_clamped_to_zero() -> void:
	assert_eq(CampScreen.embers_text(-5), "Embers 0")
```
- [ ] **Step 2: Verify (ต้องตก)**
- [ ] **Step 3: เขียน script + ฉาก** (พื้นหลังสีเดียวกับ `main.tscn` เดิม ชื่อเกมและปุ่ม)
- [ ] **Step 4: Verify (ต้องผ่าน)**
- [ ] **Step 5: Finish `M2-20: add the minimal camp screen`**

---

### Task 28 (M2-29): ต่อทุกระบบเข้า `Run` + สถานะของรอบ

**Files:**
- Modify: `run/run.gd`, `run/run.tscn`, `tests/test_run.gd`
- (ต่อ: `RunState`, `WeaponLoadout`, `WeaponContext`, `StatBlock`, `PickupSystem`, `FxLayer`, `HUD`, `LevelUpPanel`, `PauseScreen`, `Player`)

**Interfaces:**
- Produces: `Run.State { RUNNING, LEVEL_UP, PAUSED, ENDED }`, `var state: State`; signal `run_ended(summary: RunSummary)`; `step(delta)` ทำงานเฉพาะเมื่อ `RUNNING` ตามลำดับ: `player.tick` → `stats.tick` → `state.tick` → `spawner.tick` → `enemies.tick_grid` → `loadout.tick` → `separation` → `contact` → `movement` → `pickups.tick` → `sync_multimesh` ทั้งสอง → `fx.tick` → `hud.set_clock`
- Produces: `pick_card(index: int) -> void` (เรียกจาก `card_picked`): อาวุธใหม่ = `state.add_weapon`, อัป = `state.upgrade_weapon`, สำรอง = `player.heal(fallback.heal_amount)` + `state.add_embers_bonus(fallback.embers_bonus)` แล้ว `loadout.sync` ถ้าคิวยังไม่ว่าง จั่วการ์ดชุดถัดไปแสดงต่อ ไม่งั้นกลับ `RUNNING`; `toggle_pause() -> void` (สลับ `RUNNING` ↔ `PAUSED` เท่านั้น; ใน `LEVEL_UP` และ `ENDED` ไม่ทำอะไร)
- Wiring: `enemies.enemy_died` → `state.add_kill()` และ `state.add_xp(pickups.spawn_or_grant(pos, xp))`; `pickups.xp_collected` → `state.add_xp`; `state.level_up_queued` → ถ้า `RUNNING` เข้า `LEVEL_UP` และแสดงการ์ด; `player.died` → สร้าง `RunSummary.from_state` → `state = ENDED` → ยิง `run_ended` (ครั้งเดียว); action `pause` ใน `_unhandled_input` → `toggle_pause()`; `PauseScreen` เปิด/ปิดตามสถานะ; `Player` ตั้งค่าจาก `KNIGHT` และอาวุธเริ่มต้นเข้า `state.add_weapon(KNIGHT.start_weapon)` ก่อน `loadout.sync`
- รักษาของเดิม: `spawn_burst_to_cap()` และปุ่ม F4 ยังทำงาน

- [ ] **Step 1: เพิ่มเทสต์ใน `tests/test_run.gd`** (ครอบ Review Focus ข้อ 1–3)
```gdscript
func test_a_run_starts_running_with_the_knights_starting_weapon() -> void:
	assert_eq(_run.state, Run.State.RUNNING)
	assert_eq(_run.run_state().weapon_level(&"greatsword"), 1)

func test_the_greatsword_swings_and_hurts_nearby_enemies() -> void:
	var enemies: EnemySystem = _run.get_node("EnemySystem")
	var id: int = enemies.spawn(0, _player_pos() + Vector2(30.0, 0.0), 0.0)
	var hp: float = enemies.hp_of(id)
	_run.step(1.0 / 60.0)
	assert_lt(enemies.hp_of(id), hp)

func test_a_kill_drops_a_gem_that_is_collected_into_xp() -> void:
	_kill_one_enemy_next_to_the_player()
	for i in 120: _run.step(1.0 / 60.0)
	assert_gt(_run.run_state().kills, 0)
	assert_true(_run.run_state().xp > 0 or _run.run_state().level > 1)

func test_enough_xp_opens_the_level_up_and_freezes_the_run() -> void:
	_run.run_state().add_xp(10)
	assert_eq(_run.state, Run.State.LEVEL_UP)
	var t: float = _run.elapsed
	_run.step(1.0)
	assert_eq(_run.elapsed, t, "nothing advances while choosing a card")

func test_picking_a_card_resumes_the_run() -> void:
	_run.run_state().add_xp(10)
	_run.pick_card(0)
	assert_eq(_run.state, Run.State.RUNNING)

func test_a_big_gem_shows_every_level_in_turn() -> void:
	_run.run_state().add_xp(10 + 14 + 19)        # three levels at once
	var shown: int = 0
	while _run.state == Run.State.LEVEL_UP:
		_run.pick_card(0); shown += 1
		assert_lt(shown, 10, "must terminate")
	assert_eq(shown, 3)
	assert_eq(_run.state, Run.State.RUNNING)

func test_a_new_weapon_card_adds_it_to_the_build_and_the_loadout() -> void:
	_run.apply_card_for_test(_new_weapon_card(&"shield_bash"))
	assert_eq(_run.run_state().weapon_level(&"shield_bash"), 1)
	assert_not_null(_run.loadout_weapon(&"shield_bash"))

func test_hearth_bread_heals_and_ember_purse_adds_embers() -> void:
	var player: Player = _run.get_node("Player"); player.take_damage(52.0)
	var before: float = player.hp
	_run.apply_card_for_test(_fallback_card("hearth_bread"))
	assert_almost_eq(player.hp, minf(before + 30.0, 140.0), 0.01)
	_run.apply_card_for_test(_fallback_card("ember_purse"))
	assert_eq(_run.run_state().embers_bonus(), 5)

func test_a_full_xp_pool_still_grants_xp() -> void:
	_fill_the_gem_pool(); _kill_one_enemy_next_to_the_player()
	assert_gt(_run.run_state().xp, 0)             # granted directly, not lost

func test_pause_toggles_between_running_and_paused() -> void:
	_run.toggle_pause(); assert_eq(_run.state, Run.State.PAUSED)
	var t: float = _run.elapsed; _run.step(1.0); assert_eq(_run.elapsed, t)
	_run.toggle_pause(); assert_eq(_run.state, Run.State.RUNNING)

func test_pause_does_nothing_while_choosing_a_card() -> void:
	_run.run_state().add_xp(10); _run.toggle_pause()
	assert_eq(_run.state, Run.State.LEVEL_UP)

func test_pause_does_nothing_after_death() -> void:
	(_run.get_node("Player") as Player).take_damage(100000.0)
	_run.toggle_pause()
	assert_eq(_run.state, Run.State.ENDED)

func test_death_ends_the_run_once_with_a_summary() -> void:
	watch_signals(_run)
	var player: Player = _run.get_node("Player")
	player.take_damage(100000.0)
	assert_eq(_run.state, Run.State.ENDED)
	assert_signal_emit_count(_run, "run_ended", 1)

func test_xp_gained_on_the_frame_of_death_does_not_open_a_level_up() -> void:
	(_run.get_node("Player") as Player).take_damage(100000.0)
	_run.run_state().add_xp(10)
	assert_eq(_run.state, Run.State.ENDED, "a dead run never shows a card")

func test_the_buff_and_the_clock_do_not_run_while_paused() -> void:
	_run.stats().apply_damage_buff(15.0, 3.0)
	_run.toggle_pause(); _run.step(5.0); _run.toggle_pause()
	assert_almost_eq(_run.stats().buff_time_left(), 3.0, 0.001)
```
(`run_state()`, `stats()`, `loadout_weapon(id)`, `apply_card_for_test(card)` เป็น accessor ที่ Run เปิดไว้ให้เทสต์; `_fill_the_gem_pool`, `_kill_one_enemy_next_to_the_player`, `_player_pos` เป็นเมธอดช่วยในไฟล์เทสต์)
- [ ] **Step 2: Verify (ต้องตก)**
- [ ] **Step 3: ต่อระบบตาม Interfaces และเพิ่มโหนดใน `run.tscn`** ถ้า `run.gd` ใกล้ 300 บรรทัด ให้แยกส่วนการ์ด/การ์ดสำรองออกเป็น `run/card_applier.gd` (RefCounted) ที่ `Run` เรียก
- [ ] **Step 4: Verify (ต้องผ่าน)** และรันฉากหลักแบบ headless `--quit-after 300` เช็คว่าไม่มี error
- [ ] **Step 5: Finish `M2-29: wire weapons, pickups, level-up and run states into Run`**

---

### Task 29 (M2-3): state machine Camp → Run → Results ใน `main`

**Files:**
- Modify: `main.gd`, `main.tscn`, `tests/test_main.gd`
- (`main.tscn` ไม่มีโหนดหน้าจอของ M0 เหลืออยู่ ถ้ามีให้ลบออก)

**Interfaces:**
- Produces: `enum Screen { CAMP, RUN, RESULTS }`; `var embers_total: int` (ในหน่วยความจำเท่านั้น เริ่ม 0); `show_screen(screen: Screen) -> void` (เดิม คงชื่อ), `current_screen() -> Node`; เริ่มที่ `CAMP` ไม่ใช่ `RUN`; `CampScreen.start_pressed` → `RUN` ใหม่; `Run.run_ended(summary)` → `embers_total += summary.embers_total` แล้ว `RESULTS` พร้อม `show_summary`; `ResultsScreen.back_pressed` → `CAMP` (แสดงยอดล่าสุด)
- ทุกการสลับ `queue_free()` ฉากเก่าและสร้างฉากใหม่ ไม่เก็บอะไรของรอบเก่า

- [ ] **Step 1: อัปเดต `tests/test_main.gd`** (เทสต์เดิมที่คาดว่าเริ่มที่ `Run` ให้ปรับเป็นเริ่มที่ Camp) ครอบ Review Focus ข้อ 5
```gdscript
func test_main_starts_on_the_camp_screen() -> void:
	assert_true(_main.current_screen() is CampScreen)

func test_pressing_start_enters_a_fresh_run() -> void:
	_main.current_screen().start_pressed.emit()
	assert_true(_main.current_screen() is Run)
	assert_eq((_main.current_screen() as Run).state, Run.State.RUNNING)

func test_death_goes_to_results_and_banks_the_embers() -> void:
	_main.current_screen().start_pressed.emit()
	var run: Run = _main.current_screen()
	run.run_state().tick(60.0)                              # 4 embers from time
	(run.get_node("Player") as Player).take_damage(100000.0)
	assert_true(_main.current_screen() is ResultsScreen)
	assert_eq(_main.embers_total, 4)

func test_back_from_results_returns_to_camp_showing_the_total() -> void:
	_die_once_with_embers(4)
	_main.current_screen().back_pressed.emit()
	assert_true(_main.current_screen() is CampScreen)
	assert_eq((_main.current_screen() as CampScreen).embers_label_text(), "Embers 4")

func test_embers_add_up_over_several_runs() -> void:
	_die_once_with_embers(4); _go_back(); _die_once_with_embers(4)
	assert_eq(_main.embers_total, 8)

func test_the_old_screen_is_freed_on_every_switch() -> void:
	var camp: Node = _main.current_screen()
	camp.start_pressed.emit()
	assert_true(camp.is_queued_for_deletion())

func test_a_second_and_third_run_start_clean() -> void:
	for round in 3:
		_main.current_screen().start_pressed.emit()
		var run: Run = _main.current_screen()
		assert_eq(run.elapsed, 0.0); assert_eq(run.run_state().level, 1)
		assert_eq(run.run_state().kills, 0); assert_eq(run.run_state().weapon_count(), 1)
		assert_eq((run.get_node("EnemySystem") as EnemySystem).alive_count(), 0)
		assert_almost_eq(run.stats().damage_multiplier(), 1.0, 0.0001)
		(run.get_node("Player") as Player).take_damage(100000.0)
		_go_back()

func test_embers_are_not_changed_by_showing_camp_again() -> void:
	_die_once_with_embers(4); _go_back(); _go_back_noop()
	assert_eq(_main.embers_total, 4)
```
(`_die_once_with_embers(n)`, `_go_back()` เป็นเมธอดช่วย; `_go_back_noop` คือการเรียก `show_screen(CAMP)` ซ้ำ)
- [ ] **Step 2: Verify (ต้องตก)**
- [ ] **Step 3: เขียน `main.gd` เป็น state machine** ต่อ signal ของแต่ละหน้า (ตัดการเชื่อมเมื่อฉากถูก free ตาม `queue_free` ปกติ)
- [ ] **Step 4: Verify (ต้องผ่าน)**
- [ ] **Step 5: Finish `M2-3: add the Camp, Run and Results screen switcher`**

---

### Task 30 (M2-30): overlay แสดงเวลาขั้นใหม่ + F4 ให้อาวุธครบ

**Files:**
- Modify: `run/run.gd`, `tests/test_run.gd`

**Interfaces:**
- `Run` จับเวลาขั้น `loadout.tick` และ `pickups.tick` เป็น `usec_weapons`, `usec_pickups` (ไมโครวินาที, `Time.get_ticks_usec()`) และ `_overlay_lines()` เพิ่มบรรทัด `"weapons %.2f  gems %.2f ms"` กับจำนวน gem ที่ใช้อยู่ `"gems %d / %d"`
- `spawn_burst_to_cap()` (F4) เพิ่ม: ให้ผู้เล่นมีอาวุธของ Knight ครบทุกชิ้นที่ LV5 ผ่าน `RunState` (`add_weapon` + `upgrade_weapon` จนเต็ม) เพื่อวัดประสิทธิภาพในสภาพจริง ใช้ได้เฉพาะ F4 ไม่มีเส้นทางอื่น

- [ ] **Step 1: เพิ่มเทสต์**
```gdscript
func test_overlay_lines_include_the_new_stage_timings_and_gem_count() -> void:
	var text: String = _run.overlay_text_for_test()
	assert_true(text.contains("weapons")); assert_true(text.contains("gems"))

func test_f4_fills_the_cap_and_maxes_the_build() -> void:
	_run.spawn_burst_to_cap()
	var s: RunState = _run.run_state()
	assert_eq((_run.get_node("EnemySystem") as EnemySystem).alive_count(), Run.TUNING.enemy_cap)
	for id in [&"greatsword", &"shield_bash", &"warhorn"]:
		assert_eq(s.weapon_level(id), 5)

func test_f4_twice_does_not_break_the_build() -> void:
	_run.spawn_burst_to_cap(); _run.spawn_burst_to_cap()
	assert_eq(_run.run_state().weapon_count(), 3)

func test_the_stage_timers_are_recorded() -> void:
	_run.step(1.0 / 60.0)
	assert_gte(_run.usec_weapons, 0); assert_gte(_run.usec_pickups, 0)
```
- [ ] **Step 2: Verify (ต้องตก)**
- [ ] **Step 3: เพิ่มตัวจับเวลา บรรทัด overlay และการให้อาวุธครบใน F4**
- [ ] **Step 4: Verify (ต้องผ่าน)**
- [ ] **Step 5: Finish `M2-30: show weapon and pickup timings and max the build on F4`**

---

### Task 31 (M2-31): ปิด M2 — เล่นจริง วัด perf export เว็บ

**Files:**
- Modify: `docs/roadmap.md` (ตาราง performance, ติ๊กครบ), `docs/design.md` (ถ้าแก้ตัวเลขระหว่างทำ), ไฟล์ plan/spec ที่เกี่ยวข้อง

**Interfaces:** — (ไม่มีโค้ดใหม่)

- [ ] **Step 1: Verify** (ต้องผ่านทั้งหมด) และรันเทสต์ทั้งชุดอีกรอบหลังลบ `.import` ที่เปลี่ยนเฉพาะ line ending
- [ ] **Step 2: เล่นจริงหนึ่งรอบครบวงจรบน renderer จริง** รัน `$G --path . --rendering-driver opengl3 --resolution 1280x720` (หรือเปิดในแอป) เริ่มที่ Camp → กดเริ่ม → เดินเก็บ gem → เลเวลอัปเลือกการ์ดด้วยคีย์ 1/2/3 และคลิกอย่างละครั้ง → เห็นภาพฟัน กรวย และคลื่น → กด Esc เปิด/ปิดหน้าหยุด → ปล่อยให้ตาย → Results แสดงครบบรรทัด → กลับ Camp ยอด Embers ขึ้นและเริ่มรอบใหม่ได้ จดผลเป็นข้อ ๆ ว่าอะไรอ่านออก/ไม่ออก (เทียบ checklist ข้อ 7 ของ design.md) ถ้าเจอข้อบกพร่องให้หยุดรายงานผู้ใช้ ห้ามแก้เงียบ ๆ ภายใต้ task นี้
- [ ] **Step 3: วัด perf พร้อมอาวุธครบ** กด F3 และ F4 (F4 ให้อาวุธครบ LV5) เดินวนกลางฝูง 15 วินาที อ่าน avg, 1% low และ ms ต่อขั้นรวม `weapons` และ `gems` จากนั้นจดแถวใหม่ลงตาราง performance ใน `docs/roadmap.md` (วันที่ / M2 / เครื่อง / 400 / avg+1% low / ms ต่อขั้น / หมายเหตุ) บนเดสก์ท็อปเสมอ และบนเว็บใน Chrome ถ้ามีเครื่องที่ใช้ได้ (ผู้ใช้วัดเองบน M3 ได้ในรอบก่อน) ถ้ายังไม่ได้วัดบนเว็บ ให้เขียนบอกชัดเจนในแถวว่า "ยังไม่ได้วัดบนเว็บ" ห้ามเดาตัวเลข
- [ ] **Step 4: export เว็บ** `$G --headless --path . --export-release "Web" build/web/index.html` ตรวจว่า `build/web/` **ไม่มี** `index.worker.js` และ pck ไม่มี `addons/gut`/`tests` เปิดในเบราว์เซอร์ ตรวจคอนโซลว่าไม่มี error และมีบรรทัด `single-threaded, no GDExtension support`
- [ ] **Step 5: ตัดสิน** ถ้า ms รวมต่อก้าว physics บนเว็บใกล้ 16 ms หรือ 1% low ตกเกณฑ์ของ M1 (avg ≥ 120, 1% low ≥ 90) ให้**หยุดและรายงานผู้ใช้** ว่าต้องกลับไปทำ M1-16 ก่อน M3 ห้ามไปต่อเอง
- [ ] **Step 6: ติ๊ก ✅ ทุกงาน M2 ใน roadmap และ Finish `M2-31: close M2 with a playtest, perf numbers and a web export check`** (เอกสารเท่านั้น ไม่มี binary ของ build ใน commit)

---

## Self-Review

**ครอบคลุม spec:** หัวข้อ 3.1 (หน้าจอ/สถานะ) → Task 28, 29 · 3.2 (ลำดับต่อเฟรม) → Task 28 · 3.3 (API อาวุธ↔ศัตรู) → Task 3, 4, 5, 13 · 4 (คอมโพเนนต์) → Task 6–13, 19, 21, 23–27 · 4.1 (วงจรรอบ) → Task 28, 29 · 4.2 (การ์ด) → Task 21, 22 · 5.1 (schema) → Task 1, 2, 22 · 5.2 (ตัวเลขอาวุธ) → Task 14, 15, 17, 18 · 5.3 (ตัวเลขใหม่) → Task 1 · 6 (การทดสอบ) → ทุก task · 8 (ความเสี่ยง perf) → Task 30, 31 · 9 (เช็กลิสต์ปิด) → Task 31

**ชนิดและชื่อ:** `query_radius/damage/knockback/stun/is_stunned` (Task 3–5) ถูกเรียกใน Task 13–18 ด้วยชื่อเดียวกัน · `RunState.add_weapon/upgrade_weapon/weapon_level/pop_levelup/record_damage/embers_*` (Task 6–10) ตรงกับที่ Task 13, 21, 24–26, 28 ใช้ · `StatBlock.apply_damage_buff/tick/damage_multiplier/buff_time_left` (Task 11) ตรงกับ Task 13, 18, 28 · `LevelUpCard`/`CardDef` (Task 21, 22) ตรงกับ Task 23, 28 · `WeaponDef.level_data/max_level` (Task 2) ตรงกับทุกอาวุธ

**ขนาดของ plan:** ยาวกว่า spec หลายเท่าเพราะขั้นเทสต์ต้องเป็นโค้ดพร้อมตัวเลขจริงของ spec ส่วนขั้น implement ระบุแค่ signature และข้อกำหนด ไม่มีเนื้อฟังก์ชัน จุดที่ผู้ทำต้องระวัง: `project.godot` ห้ามแตะและห้าม stage ตลอดแผน, ศัตรูในเทสต์อาวุธต้องนิ่ง (`move_speed = 0`) และการวาดจริงของ `FxLayer`/HUD/แผงการ์ดตรวจด้วยตาใน Task 31
