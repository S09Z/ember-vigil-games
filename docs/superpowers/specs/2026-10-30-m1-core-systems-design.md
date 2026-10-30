# M1 — Player + EnemySystem + SpatialGrid (Design Spec)

- วันที่: 2026-10-30
- phase: M1 ใน `docs/roadmap.md` / milestone M1 ใน `docs/design.md` หัวข้อ 13
- สถานะ: อนุมัติแล้ว

## 1. เป้าหมาย

สร้างแกนประสิทธิภาพของเกมให้เสร็จและพิสูจน์ว่ามันไหวบนเว็บ **ก่อน** ที่จะมีอาวุธ XP หรือ UI อะไรมาบังตัวเลข
เมื่อ M1 จบ: เปิดเว็บ เดินด้วย WASD หนีฝูง Ghoul ที่ไล่ตามและเบียดกันเอง โดนตีแล้ว HP ลด ตายได้ กด F3 ดูตัวเลข กด F4 อัดศัตรูให้เต็มเพดานทันที

**ยังไม่มีใน M1:** อาวุธ, XP, เลเวลอัป, HUD, Camp, Results, ศัตรูชนิดอื่น, เสียง, sprite จริง

## 2. เงื่อนไขผ่าน (hard gate)

วัดในฉาก run จริงบน **build เว็บ** ที่ Chrome บน MacBook M3 โดยกด F4 ให้ศัตรูเต็ม 400 ตัวและเดินอยู่กลางฝูง:

| ตัวชี้วัด | เกณฑ์ |
|---|---|
| FPS เฉลี่ยในหน้าต่าง 10 วินาที | **≥ 120** |
| 1% low ในหน้าต่างเดียวกัน | **≥ 90** |
| จำนวนศัตรูที่เดินอยู่จริง | 400 |

`docs/design.md` เขียนเกณฑ์ไว้ว่า "60 FPS บนแล็ปท็อประดับกลาง" แต่เครื่องที่ใช้วัดคือ M3 ซึ่งแรงกว่าหลายเท่า
เกณฑ์ ≥120 / ≥90 คือ proxy ที่เผื่อ headroom ประมาณ 2 เท่าให้เครื่องระดับกลาง ไม่ใช่การขยับเป้าให้ง่ายขึ้น

**ถ้าไม่ผ่าน ห้ามเริ่ม M2** ลำดับการแก้อยู่ในหัวข้อ 8

## 3. สถาปัตยกรรม

### 3.1 ฉาก

```
main.tscn (Node2D, main.gd)        state switcher — M1 มีสถานะเดียวคือ RUN
└─ run.tscn (Node2D, run.gd)       เจ้าของลำดับการอัปเดตทั้งหมดของหนึ่งรอบ
   ├─ EnemySystem (MultiMeshInstance2D)
   ├─ Player (CharacterBody2D)
   │  └─ Camera2D
   ├─ SpawnDirector (Node)
   └─ DebugOverlay (CanvasLayer)
```

`main.gd` ใน M1 ทำหน้าที่แค่โหลด `run.tscn` แต่เขียนเป็น state switcher ตั้งแต่ต้น เพื่อให้ M2-3 เพิ่ม Camp กับ Results
เข้ามาได้โดยไม่ต้องรื้อ หน้า placeholder ของ M0 ถูกแทนด้วย DebugOverlay

### 3.2 ลำดับการอัปเดต

`run.gd` เรียกทุกระบบเองตามลำดับนี้ใน `_physics_process(delta)` ที่ 60 Hz ระบบลูกไม่มี `_physics_process` ของตัวเอง
เพื่อให้ลำดับชัดเจน จับเวลาต่อระบบได้ และ test เรียก `tick()` ตรง ๆ ได้โดยไม่ต้องมี SceneTree

| # | ขั้น | ผู้รับผิดชอบ |
|---|---|---|
| 1 | อ่าน input → เดิน → จำ `last_move_dir` | `Player` |
| 2 | ปล่อยศัตรูตามเวลา | `SpawnDirector` |
| 3 | เคลียร์ grid แล้ว insert ศัตรูที่ยังไม่ตายทุกตัว | `EnemySystem` |
| 4 | separation: ผลักกันเอง | `EnemySystem` |
| 5 | chase: เดินเข้าหาผู้เล่น + ย้ายตัวที่หลงไกล | `EnemySystem` |
| 6 | contact: หาตัวที่แตะผู้เล่น → ส่งดาเมจ | `EnemySystem` → `Player` |
| 7 | เขียน transform ลง MultiMesh | `EnemySystem` |
| 8 | อ่านเวลาที่จับไว้ไปแสดง | `DebugOverlay` |

## 4. คอมโพเนนต์

### 4.1 `core/pool.gd` — `Pool`

free-list ของ index บน `PackedInt32Array` ความจุคงที่ ไม่โตกลางรอบ

```
_init(capacity: int)
acquire() -> int        # -1 เมื่อเต็ม
release(id: int) -> void
reset() -> void
active_count() -> int
capacity() -> int
```

`release()` ที่ซ้ำหรืออยู่นอกช่วงถือเป็นบั๊กของผู้เรียก → `push_error` แล้วไม่ทำอะไร ห้ามปล่อยให้ free-list เสียเงียบ ๆ

### 4.2 `core/rng.gd` — `Rng`

ครอบ `RandomNumberGenerator` ให้ seed ได้ เพื่อให้ benchmark วัดซ้ำได้ด้วยสภาพเดิม

```
_init(seed_value: int = 0)
set_seed(v: int) -> void
randf() -> float
randf_range(a: float, b: float) -> float
randi_range(a: int, b: int) -> int
point_in_ring(center: Vector2, r_min: float, r_max: float) -> Vector2
```

`weighted_pick()` ที่ roadmap M1-3 เขียนไว้ **เลื่อนไป M2** เพราะผู้ใช้คนแรกคือการสุ่มการ์ดเลเวลอัป (YAGNI)

### 4.3 `core/spatial_grid.gd` — `SpatialGrid`

hash grid สำหรับหาเพื่อนบ้าน ใช้ทั้งเรื่อง separation, การชนผู้เล่น และอาวุธใน M2+

```
_init(capacity: int, cell_size: float, table_size: int = 1024)   # table_size ต้องเป็นกำลังของ 2
clear() -> void
insert(id: int, pos: Vector2) -> void
query_radius(center: Vector2, radius: float, out: PackedInt32Array) -> int
```

**โครงสร้างข้อมูล:** per-cell singly-linked list บน packed array ไม่มี `Dictionary` และไม่มี prefix sum

| array | ขนาด | หน้าที่ |
|---|---|---|
| `_cell_head: PackedInt32Array` | `table_size` | id ตัวแรกของเซลล์ (−1 = ว่าง) |
| `_next: PackedInt32Array` | `capacity` | id ตัวถัดไปในเซลล์เดียวกัน |
| `_pos: PackedVector2Array` | `capacity` | ตำแหน่งที่ insert เข้ามา ใช้กรองระยะจริง |
| `_touched: PackedInt32Array` | `table_size` | เซลล์ที่ถูกใช้ในเฟรมนี้ ใช้เคลียร์แบบ O(จำนวนที่ใช้) |

- `insert`: `h = hash(cell_x, cell_y)` → ต่อหัว linked list ถ้าเซลล์นั้นว่างมาก่อนให้จด `h` ลง `_touched`
- `clear`: วน `_touched` เซ็ต `_cell_head` กลับเป็น −1 ไม่ต้องล้างทั้งตาราง
- `query_radius`: วนเซลล์ในกรอบ `ceil(radius / cell_size)` รอบจุดศูนย์กลาง เดิน linked list แล้ว**กรองด้วยระยะจริง** จาก `_pos` ก่อนใส่ `out`

เพราะกรองระยะจริงทุกครั้ง การที่สองเซลล์ชน hash กันจึงให้ผลลัพธ์ถูกต้องเสมอ เสียแค่เวลาตรวจเพิ่ม

**ค่าตั้งต้น:** `cell_size = 16`, `table_size = 1024` (ศัตรู 400 ตัว → load factor ≈ 0.4)

### 4.4 `run/player.gd` — `Player`

`CharacterBody2D` ตัวเดียวในเกม

- `setup(def: ClassDef, tuning: RunTuning)` ตั้ง max HP / ความเร็ว / armor / รัศมีตัว
- `tick(delta)`: `Input.get_vector(...)` → normalize → `velocity` → `move_and_slide()`; ถ้า input ไม่เป็นศูนย์ให้อัปเดต `last_move_dir` (อาวุธระยะใกล้ใน M2 ใช้ค่านี้)
- `take_damage(amount: float)`: ถ้ายังอมตะอยู่ให้ไม่สนใจ ไม่งั้น `hp -= max(1, amount - armor)` แล้วตั้งอมตะ 0.5 วิ
- signal: `health_changed(hp, max_hp)`, `died()`
- ไม่มี `_physics_process` — `run.gd` เรียก `tick()` ให้

การคำนวณทิศจาก input แยกเป็น static function `input_to_direction(raw: Vector2) -> Vector2` เพื่อ test ได้โดยไม่ต้องมี InputMap

### 4.5 `run/enemy_system.gd` — `EnemySystem`

`extends MultiMeshInstance2D` ตามโครงใน CLAUDE.md — เก็บข้อมูลเป็น struct-of-arrays และวาดเอง

| array | ชนิด | หมายเหตุ |
|---|---|---|
| `_pos` | `PackedVector2Array` | ตำแหน่ง |
| `_vel` | `PackedVector2Array` | ความเร็วรวม (chase + push) เก็บไว้ให้ knockback ใน M2 ใช้ |
| `_hp` | `PackedFloat32Array` | HP ปัจจุบัน |
| `_type` | `PackedByteArray` | index ของ EnemyDef |
| `_alive` | `PackedByteArray` | 1 = ยังอยู่ |

**slot คงที่ ไม่บีบอัด array** ตอนตายคืน slot เข้า `Pool` และเขียน transform scale 0
เหตุผล: index ของศัตรูต้องอ้างอิงข้ามเฟรมได้ เพราะ Rune Orbit (คูลดาวน์ต่อเป้า), Hawk (ล็อกเป้า) และกระสุนที่ทะลุแล้วห้ามตีตัวเดิมซ้ำ ใน M3 ต้องใช้
ราคาที่จ่ายคือวน loop ผ่าน slot ว่างด้วย ซึ่งที่เพดาน 400 ไม่มีผล

**ค่าจาก `EnemyDef` ถูก copy ลงตารางต่อ type ตอน `setup()`** (`_type_speed`, `_type_hp`, `_type_damage`, `_type_radius`, `_type_xp` เป็น `PackedFloat32Array`)
ห้ามอ่าน property ของ Resource ใน loop ต่อเฟรม

API:
```
setup(defs: Array[EnemyDef], tuning: RunTuning, rng: Rng, capacity: int)
spawn(type_index: int, pos: Vector2, elapsed: float) -> int
kill(id: int) -> void
tick_separation(delta: float) -> void
tick_movement(delta: float, player_pos: Vector2, elapsed: float) -> void
tick_contact(player: Player) -> void
sync_multimesh() -> void
alive_count() -> int
```

- **HP ตอนเกิด:** `def.hp * (1.0 + elapsed / tuning.hp_scale_divisor)` (ค่า 150 จาก design.md)
- **separation:** วนศัตรูที่ยังอยู่ทุกตัว query เพื่อนบ้านในรัศมี `radius_i * 2` แล้วคิดเฉพาะคู่ที่ `j > i` ผลักทั้งสองฝั่งพร้อมกัน (ครึ่งงาน ได้ผลเท่าเดิม) แรงผลักลดเชิงเส้นตามระยะและเข้าเป็น**ความเร็ว** ไม่ใช่การกระโดดตำแหน่ง เพื่อให้ผลไม่ขึ้นกับเฟรมเรต
- **chase:** `vel = (player_pos - pos).normalized() * speed + push`
- **recycle:** ตัวที่ห่างเกิน `tuning.recycle_distance` (600) ถูกย้ายไปวงแหวน spawn ใหม่ทันที ไม่ตาย ไม่เสียเวลา spawn
- **contact:** query รอบผู้เล่นด้วยรัศมี `player.radius + max_enemy_radius` แล้วส่ง **ดาเมจที่สูงสุด** ของตัวที่แตะอยู่ให้ `player.take_damage()` ครั้งเดียว เพราะ design.md ให้อมตะเป็นของผู้เล่น 0.5 วิแบบรวม ไม่ใช่คูลดาวน์ต่อศัตรู การเลือกค่าสูงสุดทำให้ผลไม่ขึ้นกับลำดับ slot
- signal: `enemy_died(pos, xp)` ให้ M2 เอาไปปล่อย XP gem

**การวาด:** `QuadMesh` ขนาดเท่าเส้นผ่านศูนย์กลาง, `transform_format = TRANSFORM_2D`, `instance_count = capacity` ตั้งครั้งเดียว
slot ที่ตายเขียน `Transform2D` ที่ scale 0 สีเดียวทั้ง MultiMesh ใน M1 (มีศัตรูชนิดเดียว) เรื่องสีต่อ type ไปอยู่ M3

### 4.6 `run/spawn_director.gd` — `SpawnDirector`

- อัตรา `min(cap_per_second, 1.0 + elapsed / 20.0)` ตัว/วินาที สะสมเศษไว้ใน accumulator ไม่ปัดทิ้ง
- ตำแหน่ง: `rng.point_in_ring(player_pos, 380, 420)`
- เพดาน: ไม่ spawn เมื่อ `alive_count >= tuning.enemy_cap`
- ค่าทุกตัวมาจาก `RunTuning` และ `EnemyDef` ไม่ hardcode
- `spawn_burst(count)` สำหรับ F4 และสำหรับ benchmark

### 4.7 `ui/debug_overlay.gd` — `DebugOverlay`

- F3 สลับเปิดปิด (`toggle_debug` มีใน input map แล้ว)
- แสดง: FPS ปัจจุบัน, **FPS เฉลี่ยและ 1% low ในหน้าต่าง 600 เฟรม**, จำนวนศัตรู, และ ms ของแต่ละขั้น (separation / movement / contact / multimesh)
- เก็บ frame time เป็น `PackedFloat32Array` ขนาดคงที่ 600 แบบ ring buffer
- 1% low: คัดลอกลง buffer สำรองแล้ว `sort()` อ่านค่าที่ตำแหน่ง 1% — คิดเฉพาะตอน overlay เปิดและไม่เกิน 2 ครั้ง/วินาที
- อ่านค่าผ่าน getter ของระบบเท่านั้น ห้ามเขียนกลับ
- F4 (`debug_spawn_burst`) ให้ `run.gd` สั่ง `SpawnDirector.spawn_burst()` ให้เต็มเพดาน — ต้องอยู่ใน build เว็บ เพราะ gate วัดบนเว็บ

## 5. ข้อมูล (data/)

| ไฟล์ | เนื้อหา |
|---|---|
| `data/class_def.gd` + `data/classes/knight.tres` | HP 140, speed 95, armor 2, pickup radius 40, body radius 7 |
| `data/enemy_def.gd` + `data/enemies/ghoul.tres` | HP 10, speed 45, contact damage 5, XP 1, body radius 6 |
| `data/run_tuning.gd` + `data/tuning/run_tuning.tres` | enemy_cap 400, spawn ring 380–420, recycle 600, spawn rate cap 12, hp_scale_divisor 150, iframe 0.5, separation_strength 60 (px/s ตอนซ้อนกันสนิท) |

**ต้องเพิ่มใน `docs/design.md`:** คอลัมน์/แถว "รัศมีตัว (px)" ของอาชีพและศัตรู และบรรทัดค่า separation_strength (60 px/s)
เพราะกฎใน CLAUDE.md บังคับว่าตัวเลข gameplay ทุกตัวต้องมีที่มาจากตารางใน design.md

## 6. การทดสอบ

| ไฟล์เทสต์ | ครอบอะไร |
|---|---|
| `tests/test_pool.gd` | acquire เรียงลำดับ, release แล้วใช้ slot ซ้ำ, เต็มแล้วคืน −1, release ซ้ำไม่ทำ free-list เสีย, reset |
| `tests/test_rng.gd` | seed เดียวกันได้ลำดับเดียวกัน, seed ต่างกันได้ต่างกัน, `point_in_ring` ระยะอยู่ในช่วงจริง |
| `tests/test_spatial_grid.gd` | เจอตัวในรัศมี, ไม่เอาตัวนอกรัศมี, ข้ามขอบเซลล์ยังเจอ, รัศมีใหญ่กว่า cell_size, `clear()` ล้างจริง, ขนาด buffer ที่ส่งเข้าไปไม่เปลี่ยน |
| `tests/test_player.gd` | normalize ทิศจาก input, ดาเมจ `max(1, dmg − armor)`, อมตะกันดาเมจซ้ำใน 0.5 วิ, HP ถึง 0 ยิง `died` ครั้งเดียว |
| `tests/test_enemy_system.gd` | spawn/kill คืน slot, HP scaling ตามเวลา, เดินเข้าหาผู้เล่น, ตัวที่ไกลเกินถูกย้ายกลับวงแหวน, separation ผลักให้ห่างขึ้นจริงและไม่ผลักตัวเองหรือตัวที่ตาย, contact ส่งดาเมจสูงสุดครั้งเดียว |
| `tests/test_spawn_director.gd` | อัตราที่ t=0 / t=20 / t=220 (เพดาน 12), สะสมเศษไม่หาย, ไม่เกินเพดานศัตรู, ตำแหน่งที่เกิดอยู่ในวงแหวน 380–420 |

ระบบทุกตัวถูกเรียกผ่าน `tick*()` จาก `run.gd` ทำให้เทสต์สร้าง object ขึ้นมา เรียก tick เองได้ ไม่ต้องรอ SceneTree
ส่วน `EnemySystem` ที่เป็น `MultiMeshInstance2D` เทสต์จะ assign `MultiMesh.new()` ให้เอง เส้นทางโค้ดจึงเหมือนตอนรันจริง

**ของที่เทสต์ไม่ได้และต้องดูด้วยตา:** การวาด MultiMesh, overlay, ความรู้สึกของการเบียดกัน และตัวเลข FPS

## 7. การตัดสินใจและสิ่งที่แลกไป

1. **slot คงที่แทนการบีบอัด array** — แลกการวน loop เผื่อ slot ว่าง กับการได้ index ที่อ้างอิงข้ามเฟรมได้ ซึ่งระบบใน M3 ต้องใช้
2. **hash grid ด้วย linked list บน packed array** — `Dictionary` allocate ทุกเฟรมซึ่งผิดกฎ CLAUDE.md; counting sort ต้องวนทั้งตาราง 2 รอบต่อเฟรม; linked list เคลียร์เฉพาะเซลล์ที่ใช้จริง
3. **ห้ามส่ง Packed array ออกจากระบบ** — GDScript ใช้ copy-on-write ถ้ามีคนถือ reference ที่สองไว้แล้วเจ้าของเขียนทับ จะเกิดการ copy ทั้งก้อนเงียบ ๆ ทุกเฟรม ดังนั้น `query_radius()` รับ buffer เข้ามาเติม และ `EnemySystem` วาดเองไม่แยก renderer ออกไป **ข้อนี้ต้องเพิ่มเป็นกฎใน CLAUDE.md**
4. **ศัตรูผลักกันเองตั้งแต่ M1** — ถ้าเพิ่มทีหลัง gate ของ M1 จะไม่มีความหมาย เพราะ separation เป็นงานที่หนักที่สุดในเฟรม
5. **ตัว benchmark อยู่ใน build เว็บ (F4) ไม่ใช่ฉากใต้ `tests/`** — เพราะ `exclude_filter` ตัด `tests/*` ออกจาก build เว็บ ถ้าวาง bench ไว้ที่นั่นจะวัดบนเว็บไม่ได้เลย (แก้ข้อผิดพลาดของ roadmap M1-14)

## 8. ถ้า gate ไม่ผ่าน

แก้ตามลำดับนี้ วัดใหม่ทุกครั้ง และบันทึกผลลงตาราง performance ใน `docs/roadmap.md`:

1. ดู ms ต่อขั้นใน overlay ก่อน ห้ามเดา
2. ปรับ `cell_size` ของ grid ให้เข้ากับรัศมี query ที่ใช้จริง
3. แบ่ง separation เป็นหลายเฟรม (เช็ค 1/2 หรือ 1/4 ของศัตรูต่อเฟรม แล้ววนไปเรื่อย ๆ)
4. เปลี่ยนไปบีบอัด array + handle แบบ (index, generation)
5. ลดเพดานศัตรูลงจาก 400 แล้ว**แก้ `docs/design.md` ให้ตรง** พร้อมเขียนเหตุผลกำกับ

## 9. เช็กลิสต์ก่อนปิด M1

- [ ] `godot --headless --path . --import` ไม่มี error
- [ ] เทสต์ GUT ผ่านทั้งหมด
- [ ] export เว็บแล้ว `build/web/` ไม่มี `index.worker.js`
- [ ] console เบราว์เซอร์ไม่มี error และมีบรรทัด `single-threaded, no GDExtension support`
- [ ] กด F4 แล้วศัตรู 400 ตัวเดินอยู่จริง และ FPS ผ่านเกณฑ์หัวข้อ 2
- [ ] บันทึกตัวเลขลงตาราง performance ใน `docs/roadmap.md`
- [ ] ตัวเลขใน `.tres` ตรงกับตารางใน `docs/design.md` ทุกตัว
