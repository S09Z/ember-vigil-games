# Ember Vigil — Roadmap (แตกงาน M1–M5)

- อัปเดตล่าสุด: 2026-10-30
- เอกสารนี้แตก milestone ในหัวข้อ 13 ของ `docs/design.md` ลงเป็น **epic** และ **sub-task**
- ตัวเลข gameplay ทุกตัวเป็นของ `docs/design.md` เอกสารนี้ไม่ตั้งตัวเลขใหม่ ถ้าขัดกันให้ถือ design.md เป็นหลัก
- หนึ่ง sub-task = หนึ่ง commit (ภาษาอังกฤษ imperative) และควรจบได้ในรอบเดียว
- ทำเสร็จแล้วใส่ ✅ หน้ารหัสงาน เช่น `| ✅ M1-1 | ... |`
- คอลัมน์ **T** = ต้องมี GUT test (`tests/`) / **—** = ตรวจด้วยตาหรือ debug overlay
- ขนาด: S ≈ ครึ่งวัน, M ≈ 1 วัน, L ≈ 2–3 วัน (ประมาณคร่าว ๆ เพื่อจัดลำดับ ไม่ใช่สัญญา)

**กฎการเริ่มแต่ละ phase:** ก่อนลงมือให้เขียน spec (`docs/superpowers/specs/`) และ plan (`docs/superpowers/plans/`) ของ phase นั้นก่อน แบบเดียวกับที่ทำใน M0 — เอกสารนี้เป็นแค่โครง ไม่ใช่ plan ที่พร้อมรัน

```mermaid
graph LR
  P0[P0 ปิดงานค้าง] --> M1[M1 แกนประสิทธิภาพ]
  M1 -->|gate 400 ตัว 60 FPS| M2[M2 หนึ่งรอบที่เล่นจบได้]
  M2 --> M3[M3 สามอาชีพ + บิลด์]
  M3 --> M4[M4 วงจร meta]
  M4 --> M5[M5 ความรู้สึก + เผยแพร่]
```

---

## P0 — ปิดงานค้างจาก M0 (ไม่ใช่ milestone, ครึ่งวัน)

| # | งาน | ไฟล์ | T | ขนาด |
|---|---|---|---|---|
| P0-1 | ยืนยัน M0 ครบเงื่อนไข: เปิด build เว็บใน Safari (เงื่อนไขผ่านของ M0 ระบุ Chrome **และ** Safari) | — | — | S |
| P0-2 | อัป `build/web.zip` ขึ้น itch.io เป็น private แล้วเปิดจากลิงก์จริงหนึ่งครั้ง (งานของผู้ใช้ เอเจนต์ไม่แตะบัญชี) | — | — | S |
| P0-3 | ตัดสินใจเรื่อง `.mcp.json` (ลบ หรือใส่ path จริงของ godot-mcp) แล้ว commit/ignore ให้เรียบร้อย | `.mcp.json` | — | S |
| P0-4 | เพิ่มบรรทัดชี้มาที่ roadmap นี้ใน `CLAUDE.md` | `CLAUDE.md` | — | S |

---

## M1 — Player + EnemySystem + SpatialGrid

**เงื่อนไขผ่าน (hard gate):** Ghoul 400 ตัวบน build เว็บใน Chrome — avg FPS ≥120 และ 1% low ≥90 บน M3 (proxy เผื่อ headroom ~2× ให้ "แล็ปท็อประดับกลาง" ใน design.md) **ถ้าไม่ผ่าน ห้ามไปต่อ M2**
**ผลลัพธ์ที่จับต้องได้:** เดินตัวละครหนีฝูง Ghoul ได้ โดนตีแล้ว HP ลด ตายได้ ยังไม่มีอาวุธ

### M1-A โครงสร้างพื้นฐาน (core/)

| # | งาน | ไฟล์ | T | ขนาด |
|---|---|---|---|---|
| ✅ M1-1 | `SpatialGrid`: hash grid, `clear()` / `insert(id, pos)` / `query_radius(pos, r, out_buffer)` คืนค่าใส่ buffer ที่ส่งเข้ามา ห้าม allocate ต่อการเรียก | `core/spatial_grid.gd` | T | M |
| ✅ M1-2 | `Pool`: free-list ของ index สำหรับ struct-of-arrays โตเป็นชั้น ๆ ไม่ย่อกลับกลางรอบ | `core/pool.gd` | T | S |
| ✅ M1-3 | `Rng`: wrapper ของ `RandomNumberGenerator` ที่ seed ได้ + `point_in_ring()` ใช้ซ้ำรอบเดิมตอน debug (`weighted_pick()` เลื่อนไป M2-12 ตาม YAGNI) | `core/rng.gd` | T | S |
| ✅ M1-18 | `RunTuning` schema + `.tres` (เพดาน 400, วงแหวน 380–420, recycle 600, อัตราสูงสุด 12, hp_scale 150, อมตะ 0.5, separation 60) + เพิ่มรัศมีตัวและ separation_strength ลงตารางใน design.md | `data/run_tuning.gd`, `data/tuning/run_tuning.tres`, `docs/design.md` | T | S |
| ✅ M1-4 | `DebugOverlay`: กด F3 สลับ แสดง FPS ปัจจุบัน + avg และ 1% low ในหน้าต่าง 600 เฟรม (ring buffer) + จำนวนศัตรู + ms ต่อขั้น อ่านผ่าน getter อย่างเดียว | `ui/debug_overlay.gd`, `ui/debug_overlay.tscn` | — | M |

### M1-B ผู้เล่น

| # | งาน | ไฟล์ | T | ขนาด |
|---|---|---|---|---|
| ✅ M1-5 | `ClassDef` schema + `knight.tres` (HP 140 / speed 95 / armor 2 / pickup 40) อ่านค่าจากตารางหัวข้อ 4 | `data/class_def.gd`, `data/classes/knight.tres` | T | S |
| M1-6 | `Player`: CharacterBody2D ตัวเดียวในเกม เดินตาม input, จำ `last_move_dir` ไว้ให้อาวุธระยะใกล้ใช้ | `run/player.gd`, `run/player.tscn` | T | M |
| M1-7 | HP / armor / อมตะ 0.5 วิ: ดาเมจที่รับ = `max(1, dmg − armor)` ยิง signal `health_changed` และ `died` | `run/player.gd` | T | S |

### M1-C ศัตรูแบบ data-oriented

| # | งาน | ไฟล์ | T | ขนาด |
|---|---|---|---|---|
| M1-8 | `EnemyDef` schema + `ghoul.tres` (HP 10 / speed 45 / dmg 5 / XP 1) | `data/enemy_def.gd`, `data/enemies/ghoul.tres` | T | S |
| M1-9 | `EnemySystem` โครง SoA: pos/vel เป็น `PackedVector2Array`, hp เป็น `PackedFloat32Array`, type/alive เป็น `PackedByteArray`, `spawn()` / `kill()` คืน slot เข้า `Pool` โดย **slot คงที่ ไม่บีบอัด array** (index ต้องอ้างข้ามเฟรมได้ให้ M3) ห้ามมี Node ต่อตัว | `run/enemy_system.gd` | T | L |
| M1-10 | วาดด้วย `MultiMeshInstance2D` ชิ้นเดียว อัปเดต transform ต่อเฟรมแบบไม่ allocate | `run/enemy_system.gd` | — | M |
| M1-11 | การเดิน: ไล่ผู้เล่นตรง ๆ + HP scaling `1 + t/150` ตอน spawn + ตัวที่ห่างเกิน 600 ถูกย้ายไป spawn ใหม่ใกล้ผู้เล่น | `run/enemy_system.gd` | T | M |
| M1-12 | ชนผู้เล่น: หาเพื่อนบ้านจาก `SpatialGrid` ไม่ใช้ `Area2D`/physics body กับศัตรู | `run/enemy_system.gd` | T | M |
| M1-17 | separation: ศัตรูผลักกันเองทุกเฟรม คิดเฉพาะคู่ `j > i` ผลักสองฝั่งพร้อมกัน เข้าเป็นความเร็วไม่ใช่การกระโดดตำแหน่ง | `run/enemy_system.gd` | T | M |
| M1-13 | `SpawnDirector`: อัตรา `min(12, 1.0 + t/20)` ตัว/วิ, เกิดในวงแหวน 380–420 จากผู้เล่น, เพดาน 400 ตัว อ่านค่าจาก data ไม่ hardcode | `run/spawn_director.gd` | T | M |

### M1-D ยืนยัน gate

| # | งาน | ไฟล์ | T | ขนาด |
|---|---|---|---|---|
| M1-19 | `run.tscn` + `run.gd` เป็นเจ้าของลำดับการอัปเดต (เรียก `tick()` ของทุกระบบเอง ระบบลูกไม่มี `_physics_process`) + `main.gd` เขียนเป็น state switcher ที่ M1 มีสถานะเดียว + Camera2D ตามผู้เล่น | `run/run.gd`, `run/run.tscn`, `main.gd`, `main.tscn` | — | M |
| M1-20 | เพิ่มกฎ copy-on-write ลง CLAUDE.md: ห้ามส่ง Packed array ออกจากระบบ ให้รับ buffer เข้ามาเติมแทน | `CLAUDE.md` | — | S |
| M1-14 | F4 = spawn ศัตรูให้เต็มเพดานทันทีในฉาก run จริง (ต้องติดไปกับ build เว็บ เพราะ gate วัดบนเว็บ) + ล็อก seed ของ `Rng` ให้วัดซ้ำได้ | `run/run.gd`, `run/spawn_director.gd` | — | S |
| M1-15 | วัดบนเดสก์ท็อปก่อน แล้ว export เว็บ วัดใน Chrome จดค่า FPS และ ms ต่อระบบลงท้ายไฟล์นี้ | `docs/roadmap.md` (ส่วน perf log) | — | M |
| M1-16 | ถ้าไม่ผ่านเกณฑ์: แก้ตามลำดับในหัวข้อ 8 ของ spec → อ่าน ms ต่อขั้นก่อน, ปรับ `cell_size`, แบ่ง separation เป็นหลายเฟรม, เปลี่ยนไปบีบอัด array + handle (index, generation), สุดท้ายลดเพดานศัตรูแล้วแก้ design.md | — | — | L |

---

## M2 — Knight ครบ + XP + เลเวลอัป + HUD

**เงื่อนไขผ่าน:** เล่นได้ 1 รอบตั้งแต่ต้นจนตาย (Camp → Run → Results)
**ผลลัพธ์:** Knight ถืออาวุธ 1 ชิ้น เก็บ XP เลเวลอัปเลือกการ์ด ตายแล้วเห็นสรุปผล

### M2-A สถานะของรอบ

| # | งาน | ไฟล์ | T | ขนาด |
|---|---|---|---|---|
| M2-1 | `RunState`: เวลา kills xp level และช่องบิลด์ (อาวุธ 4 / พาสซีฟ 4) สื่อสารออกด้วย signal เท่านั้น | `run/run_state.gd` | T | M |
| M2-2 | XP curve `round(5 + lv × 4.5)` + XP ล้นต้องยกไปเลเวลถัดไป (เก็บ XP ก้อนใหญ่ทีเดียวต้องขึ้นหลายเลเวล) | `run/run_state.gd` | T | S |
| M2-3 | state machine ใน `main.tscn`: Camp → Run → Results และกลับมา Camp ได้ โดยไม่มีสถานะรอบเก่าค้าง | `main.gd`, `main.tscn` | T | M |

### M2-B อาวุธ (โครง + Greatsword)

| # | งาน | ไฟล์ | T | ขนาด |
|---|---|---|---|---|
| M2-4 | `WeaponDef` schema: แท็ก คูลดาวน์ ดาเมจ และตารางค่าต่อเลเวล 1–5 | `data/weapon_def.gd` | T | M |
| M2-5 | `WeaponBase`: นับคูลดาวน์ อ่านค่าตามเลเวล และ hook `_fire()` เพิ่มอาวุธใหม่ต้องไม่ต้องแก้ระบบกลาง | `run/weapons/weapon_base.gd` | T | M |
| M2-6 | `Greatsword` LV1: ฟันวง 140° ตาม `last_move_dir` ระยะ 48 ดาเมจ 20 คูลดาวน์ 1.1 ผลัก 20 | `run/weapons/greatsword.gd`, `data/weapons/greatsword.tres` | T | M |
| M2-7 | Greatsword LV2–5 ตามตาราง (ดาเมจ +5 / วง 180° ระยะ 56 / คูลดาวน์ −0.2 / ฟันหลังด้วย) | เดิม | T | S |
| M2-8 | Knockback ของศัตรู: ผลักแล้วกลับมาไล่ต่อ ไม่เด้งทะลุ grid | `run/enemy_system.gd` | T | S |
| M2-9 | พาสซีฟอาชีพ **Oathguard**: ดูดเลือด 3% ของดาเมจจากอาวุธแท็ก STEEL | `run/player.gd` หรือ `run/stat_block.gd` | T | S |

### M2-C XP และของเก็บ

| # | งาน | ไฟล์ | T | ขนาด |
|---|---|---|---|---|
| M2-10 | `PickupSystem`: XP gem เป็น SoA + MultiMesh ผ่าน pool ห้ามสร้าง Node ต่อ gem | `run/pickup_system.gd` | T | M |
| M2-11 | รัศมีเก็บของ: ดูดเข้าหาผู้เล่นเมื่ออยู่ในระยะ แล้วเพิ่ม XP เข้า `RunState` | `run/pickup_system.gd` | T | S |

### M2-D เลเวลอัป

| # | งาน | ไฟล์ | T | ขนาด |
|---|---|---|---|---|
| M2-12 | ตัวสุ่มการ์ด: 3 ใบจากของที่ถืออยู่และยังไม่เต็ม + ของใหม่ถ้ามีช่องว่าง + อาวุธเฉพาะอาชีพตัวเองเท่านั้น, ของที่ถืออยู่น้ำหนัก ×2 (ต้องเพิ่ม `Rng.weighted_pick()` ที่เลื่อนมาจาก M1) | `core/rng.gd`, `run/level_up_deck.gd` | T | L |
| M2-13 | การ์ดสำรองเมื่อไม่มีอะไรให้เลือก: Hearth Bread (ฮีล 30) / Ember Purse (+5 Embers ตอนจบรอบ) | `run/level_up_deck.gd`, `data/` | T | S |
| M2-14 | `LevelUpPanel`: หยุดเกม แสดง 3 การ์ด เลือกด้วย 1/2/3 หรือคลิก แสดงเลเวลเดิม → ใหม่ | `ui/level_up_panel.gd/.tscn` | — | M |
| M2-15 | คิวเลเวลอัป: ขึ้นหลายเลเวลพร้อมกันต้องโชว์การ์ดต่อเนื่องทีละใบ ไม่ตกหาย | `run/run_state.gd`, `ui/level_up_panel.gd` | T | S |

### M2-E หน้าจอ

| # | งาน | ไฟล์ | T | ขนาด |
|---|---|---|---|---|
| M2-16 | `HUD` ตามหัวข้อ 11: แถบ XP บนสุด / HP ซ้ายบน / เวลากลางบน / kills+embers ขวาบน / ช่องอาวุธ+พาสซีฟ ซ้ายล่าง ฟัง signal อย่างเดียว | `ui/hud.gd/.tscn` | — | M |
| M2-17 | หน้าหยุดเกม (Esc/P): แสดงบิลด์ปัจจุบัน | `ui/pause_screen.gd/.tscn` | — | S |
| M2-18 | สูตร Embers: `floor(kills/10) + floor(วิที่รอด/15) + 5×Elite + 40 ถ้าฆ่าบอส` (กดหนีกลางรอบไม่ได้) | `run/run_state.gd` | T | S |
| M2-19 | `ResultsScreen`: เวลา kills เลเวล ดาเมจรวมต่ออาวุธ และที่มาของ Embers ทีละบรรทัด | `ui/results_screen.gd/.tscn` | — | M |
| M2-20 | `CampScreen` ขั้นต่ำ: ปุ่มเริ่มคืน + โชว์ Embers (ร้านค่อยทำใน M4) | `ui/camp_screen.gd/.tscn` | — | S |
| M2-21 | ติดตามดาเมจรวมต่ออาวุธเพื่อเอาไปโชว์ในหน้าสรุป | `run/run_state.gd` | T | S |

---

## M3 — Ranger + Pyromancer + อาวุธกลาง + พาสซีฟ + แท็ก

**เงื่อนไขผ่าน:** ทั้ง 3 อาชีพเล่นได้
**หมายเหตุลำดับ:** M3-A ถึง M3-C เป็นฐานของทุกอย่างในเฟสนี้ ต้องเสร็จก่อนลงอาวุธรายตัว

### M3-A ค่าสถานะและแท็ก

| # | งาน | ไฟล์ | T | ขนาด |
|---|---|---|---|---|
| M3-1 | `StatBlock`: รวมค่าจากอาชีพ + พาสซีฟ + แท็ก + meta เป็นค่าสุดท้าย ลำดับการคูณชัดเจน (คูลดาวน์คูณสะสม armor บวกตรง) | `run/stat_block.gd` | T | L |
| M3-2 | `PassiveDef` schema + พาสซีฟ 8 ตัวจากตารางหัวข้อ 6 | `data/passive_def.gd`, `data/passives/*.tres` | T | M |
| M3-3 | ตัวนับแท็กและโบนัสเมื่อครบ 3 ชิ้น (STEEL/NATURE/FIRE/ARCANE/HOLY) + แสดงใน HUD | `run/run_state.gd`, `ui/hud.gd` | T | M |
| M3-4 | คริติคอล: โอกาสจาก Fortune/แท็ก NATURE คูณดาเมจ 2 | `run/stat_block.gd` | T | S |

### M3-B กระสุนและสถานะติดตัว

| # | งาน | ไฟล์ | T | ขนาด |
|---|---|---|---|---|
| M3-5 | `ProjectileSystem`: SoA + MultiMesh + pool, มีอายุ ทะลุได้ N ตัว และไม่ตีตัวเดิมซ้ำในนัดเดียว | `run/projectile_system.gd` | T | L |
| M3-6 | เล็งศัตรูใกล้สุด: query จาก `SpatialGrid` ไม่ใช่ loop ทั้ง array | `run/projectile_system.gd`, `run/enemy_system.gd` | T | M |
| M3-7 | สถานะติดตัวศัตรูเป็น SoA: Burn (4 ดาเมจ/วิ 3 วิ ติดซ้ำรีเซ็ตเวลา ไม่ซ้อนดาเมจ), Slow, Stun | `run/enemy_system.gd` | T | M |

### M3-C เอฟเฟกต์พื้นที่

| # | งาน | ไฟล์ | T | ขนาด |
|---|---|---|---|---|
| M3-8 | พื้นที่เอฟเฟกต์ที่อยู่ค้าง (เสาไฟ / พื้นไฟ / วงแหวนขยาย) เป็น SoA + pool ตีเป็นจังหวะ ไม่ใช่ทุกเฟรม | `run/area_system.gd` | T | L |

### M3-D Ranger

| # | งาน | ไฟล์ | T | ขนาด |
|---|---|---|---|---|
| M3-9 | `ranger.tres` (HP 90 / speed 115 / armor 0 / pickup 50) + **Hunter's Focus** ดาเมจ +25% กับศัตรูที่ห่างเกิน 100 px | `data/classes/ranger.tres`, `run/stat_block.gd` | T | S |
| M3-10 | Longbow LV1–5 | `run/weapons/longbow.gd`, `data/weapons/longbow.tres` | T | M |
| M3-11 | Volley LV1–5 (พัด 5 ดอก 60°) | `run/weapons/volley.gd`, `.tres` | T | S |
| M3-12 | Hawk LV1–5 (พุ่งใส่ศัตรูใกล้สุด) | `run/weapons/hawk.gd`, `.tres` | T | M |

### M3-E Pyromancer

| # | งาน | ไฟล์ | T | ขนาด |
|---|---|---|---|---|
| M3-13 | `pyromancer.tres` (HP 80 / speed 100 / armor 0 / pickup 45) + **Kindling** ศัตรูติด Burn รับดาเมจทุกแหล่ง +15% | `data/classes/pyromancer.tres` | T | S |
| M3-14 | Flame Pillar LV1–5 | `run/weapons/flame_pillar.gd`, `.tres` | T | M |
| M3-15 | Fire Nova LV1–5 (วงแหวนขยาย) | `run/weapons/fire_nova.gd`, `.tres` | T | S |
| M3-16 | Meteor LV1–5 (วงเตือน 1 วิ แล้วระเบิด) | `run/weapons/meteor.gd`, `.tres` | T | M |

### M3-F อาวุธกลาง

| # | งาน | ไฟล์ | T | ขนาด |
|---|---|---|---|---|
| M3-17 | Throwing Daggers LV1–5 | `run/weapons/throwing_daggers.gd`, `.tres` | T | S |
| M3-18 | Rune Orbit LV1–5 (ตีศัตรูตัวเดิมซ้ำได้ทุก 0.4 วิ ต้องจำ cooldown ต่อเป้า) | `run/weapons/rune_orbit.gd`, `.tres` | T | M |
| M3-19 | Chain Lightning LV1–5 (กระโดด 3 ตัว ไม่ซ้ำตัวเดิม) | `run/weapons/chain_lightning.gd`, `.tres` | T | M |
| M3-20 | Frost Bell LV1–5 (คลื่นชะลอ) | `run/weapons/frost_bell.gd`, `.tres` | T | S |

### M3-G ศัตรูที่เหลือ

| # | งาน | ไฟล์ | T | ขนาด |
|---|---|---|---|---|
| M3-21 | Wisp (ซิกแซก) + Bone Brute (ช้าแต่ทน) | `data/enemies/*.tres`, `run/enemy_system.gd` | T | M |
| M3-22 | Skeleton Archer: รักษาระยะ 120–150 ยิงทุก 2.5 วิ + ช่องกระสุนศัตรูที่แยกจากของผู้เล่น | `data/enemies/skeleton_archer.tres`, `run/projectile_system.gd` | T | M |
| M3-23 | Plague Bloat: ตายแล้วระเบิดรัศมี 40 ใส่ผู้เล่น | `data/enemies/plague_bloat.tres` | T | S |
| M3-24 | ตารางปล่อยศัตรูตามเวลา (01:30 / 02:00 / 03:00 / 04:00) เก็บเป็น data | `data/spawn_table.tres`, `run/spawn_director.gd` | T | M |

### M3-H เลือกอาชีพ

| # | งาน | ไฟล์ | T | ขนาด |
|---|---|---|---|---|
| M3-25 | Camp เลือกอาชีพด้วยการ์ด 3 ใบพร้อมค่าสถานะ + เงื่อนไขปลดล็อก (Ranger รอดถึง 05:00, Pyromancer ฆ่าครบ 1,000) และ `DEMO_ALL_CLASSES = true` เปิดทั้งหมด | `ui/camp_screen.gd`, `meta/` | T | M |
| M3-26 | วัด perf อีกครั้งในสภาพจริง: 3 อาชีพ อาวุธเต็ม 4 ช่อง + ศัตรูหนาแน่น ต้องยังไม่ต่ำกว่า 50 FPS | — | — | M |

---

## M4 — Elite, กล่องเสบียง, Evolution, บอส, Camp + เซฟ

**เงื่อนไขผ่าน:** วงจร meta ครบ (เล่น → ได้ Embers → ซื้ออัปเกรด → รอบถัดไปแรงขึ้น)

### M4-A Elite และกล่องเสบียง

| # | งาน | ไฟล์ | T | ขนาด |
|---|---|---|---|---|
| M4-1 | Elite เกิดที่ 02:30 / 05:00 / 07:30 (Brute ×8 HP, speed 32, dmg 18, XP 30) แยกให้เห็นชัดจากฝูง | `data/enemies/elite_brute.tres`, `run/spawn_director.gd` | T | M |
| M4-2 | กล่องเสบียงดรอปจาก Elite เป็น pickup ที่ต้องเดินไปเก็บ | `run/pickup_system.gd` | T | S |
| M4-3 | กฎกล่อง: ถ้ามี evolution ที่เงื่อนไขครบ ให้ evolution นั้น ถ้าไม่มี ให้เลเวลอัปฟรี 1 ครั้ง | `run/run_state.gd` | T | S |

### M4-B Evolution

| # | งาน | ไฟล์ | T | ขนาด |
|---|---|---|---|---|
| M4-4 | `EvolutionDef` schema + เช็คเงื่อนไข (อาวุธ LV5 + พาสซีฟที่จับคู่ เลเวลไหนก็ได้) | `data/evolution_def.gd`, `data/evolutions/*.tres` | T | M |
| M4-5 | **Oathbreaker** (Greatsword + Plate): ฟัน 360° ทุก 0.8 วิ ดูดเลือด 5% | `run/weapons/oathbreaker.gd`, `.tres` | T | M |
| M4-6 | **Storm Bow** (Longbow + Haste): ลูกศรที่โดนปล่อยสายฟ้ากระโดด 2 ตัว | `run/weapons/storm_bow.gd`, `.tres` | T | M |
| M4-7 | **Inferno** (Flame Pillar + Reach): เสาอยู่ 6 วิ และลามไปเกิดเสาข้างเคียง 1 ครั้ง | `run/weapons/inferno.gd`, `.tres` | T | M |
| M4-8 | หน้าจอแสดงการกลายร่าง (อาวุธเดิม → อาวุธใหม่) | `ui/evolution_panel.gd/.tscn` | — | S |

### M4-C บอส

| # | งาน | ไฟล์ | T | ขนาด |
|---|---|---|---|---|
| M4-9 | The Pale Shepherd ที่ 10:00 (HP 6,000 / speed 30 / dmg 25) + หยุดปล่อยศัตรูทั่วไป + แถบ HP บอส | `run/boss.gd` หรือ type พิเศษใน `enemy_system`, `ui/hud.gd` | T | L |
| M4-10 | ท่าบอส: เรียก Ghoul เป็นวงทุก 8 วิ และพุ่งชนพร้อมวงเตือน 1 วิ | เดิม | T | M |
| M4-11 | เงื่อนไขชนะ: ฆ่าบอส = รุ่งสาง เข้าหน้าสรุปผลแบบชนะ (+40 Embers) | `run/run_state.gd`, `ui/results_screen.gd` | T | S |

### M4-D เซฟและร้านค้า

| # | งาน | ไฟล์ | T | ขนาด |
|---|---|---|---|---|
| M4-12 | `SaveService`: อ่าน/เขียน `user://save.json` มี `version` รองรับไฟล์เสียและไฟล์เวอร์ชันเก่าโดยไม่ crash | `meta/save_service.gd` | T | M |
| M4-13 | `MetaUpgradeDef` schema + 6 อัปเกรดจากตารางหัวข้อ 10 พร้อมราคาต่อขั้น | `data/meta_upgrade_def.gd`, `data/meta/*.tres` | T | M |
| M4-14 | ตรรกะซื้อ: หัก Embers ตามขั้น ห้ามเกินขั้นสูงสุด ห้ามซื้อเมื่อ Embers ไม่พอ | `meta/save_service.gd` | T | M |
| M4-15 | Camp เต็มรูปแบบ: ร้านอัปเกรด + ยอด Embers + ปุ่มเริ่มคืน | `ui/camp_screen.gd/.tscn` | — | M |
| M4-16 | เอาอัปเกรดถาวรไปใช้ตอนเริ่มรอบ (HP, ดาเมจ, ความเร็ว, รัศมีเก็บของ, reroll) | `run/stat_block.gd`, `run/run_state.gd` | T | M |
| M4-17 | Reroll ในหน้าเลเวลอัป ใช้โควตาจาก Second Thought | `ui/level_up_panel.gd`, `run/run_state.gd` | T | S |
| M4-18 | Phoenix Feather: ฟื้นครั้งเดียวต่อรอบ HP 50% + ผลักศัตรูรอบตัว | `run/player.gd` | T | S |
| M4-19 | ยืนยันบนเว็บว่าเซฟอยู่จริง: ซื้ออัปเกรด → refresh เบราว์เซอร์ → ค่ายังอยู่ (IndexedDB) | — | — | S |
| M4-20 | บันทึกสถิติสะสมสำหรับเงื่อนไขปลดล็อกอาชีพ (kills รวม, รอดถึง 05:00) | `meta/save_service.gd` | T | S |

---

## M5 — ความรู้สึกในการเล่น + playtest + เผยแพร่

**เงื่อนไขผ่าน:** ผ่าน playtest checklist หัวข้อ 14 ทั้ง 7 ข้อ

### M5-A Game feel

| # | งาน | ไฟล์ | T | ขนาด |
|---|---|---|---|---|
| M5-1 | Hitstop ตอนตีโดน (หยุดสั้น ๆ เฉพาะเป้า ไม่หยุดทั้งเกม) | `run/enemy_system.gd` | — | S |
| M5-2 | จอสั่นตามน้ำหนักเหตุการณ์ (โดนตี / ระเบิด / บอสพุ่ง) ปิดได้ใน settings | `run/camera_shake.gd` | — | S |
| M5-3 | ตัวเลขดาเมจลอย ผ่าน pool + MultiMesh หรือ `CanvasItem` ชุดเดียว ห้ามสร้าง Label ต่อครั้ง | `ui/damage_numbers.gd` | — | M |
| M5-4 | แฟลชตอนโดนตี + เอฟเฟกต์ตาย (ฝุ่นจาง) ผ่าน pool | `run/enemy_system.gd` | — | S |
| M5-5 | เสียง: SFX + เพลง, bus แยก, มี volume ใน settings, ปลดล็อก audio context ตอนคลิกครั้งแรกบนเว็บ | `audio/`, `ui/settings_panel.gd` | — | M |

### M5-B การอ่านเกมออกและมือถือ

| # | งาน | ไฟล์ | T | ขนาด |
|---|---|---|---|---|
| M5-6 | ผ่านเรื่องความชัด (checklist ข้อ 7): กระสุนศัตรูต้องเด่นกว่าเอฟเฟกต์ผู้เล่น แยกสี/เลเยอร์ให้ชัด | `run/projectile_system.gd` | — | M |
| M5-7 | จอยสติ๊กลอยบนมือถือ (ลากนิ้วที่ไหนก็ได้) + ปุ่มหยุดมุมขวาบน + แตะเลือกการ์ด | `ui/touch_controls.gd/.tscn` | T | M |
| M5-8 | ทดสอบบนเบราว์เซอร์มือถือจริงอย่างน้อย 1 เครื่อง | — | — | S |

### M5-C Playtest และปล่อย

| # | งาน | ไฟล์ | T | ขนาด |
|---|---|---|---|---|
| M5-9 | รอบวัด perf ครั้งสุดท้าย: สภาพหนาแน่นสุดต้องไม่ต่ำกว่า 50 FPS บนแล็ปท็อประดับกลาง และลอง 1,000 ตัวบนเดสก์ท็อป | — | — | M |
| M5-10 | ทำ build สำหรับ playtest + แบบฟอร์มเก็บผลตาม checklist 7 ข้อ | `docs/playtest-log.md` | — | S |
| M5-11 | รัน playtest กับผู้ทดสอบใหม่ แล้วบันทึกผลดิบ | `docs/playtest-log.md` | — | M |
| M5-12 | ปรับบาลานซ์จากผลที่ได้ แล้ว**แก้ตารางใน design.md ให้ตรงกับ `.tres`** | `data/**`, `docs/design.md` | T | L |
| M5-13 | ขัดหน้า Camp/Results + หน้าจอแรกที่บอกวิธีเล่นในสามบรรทัด | `ui/` | — | S |
| M5-14 | เตรียมของสำหรับหน้า itch.io: ไอคอน ภาพปก screenshot คำบรรยาย (ตัวอัปเป็นงานของผู้ใช้) | `docs/release/` | — | S |

---

## บันทึกค่า performance (อัปเดตทุกครั้งที่วัด)

| วันที่ | milestone | เครื่อง / เบราว์เซอร์ | ศัตรู | FPS | ms ต่อระบบ | หมายเหตุ |
|---|---|---|---|---|---|---|
| 2026-10-30 | M0 | M3 / Chrome | 0 | 120 | — | หน้าเปล่า ยังไม่มีระบบเกม |

---

## ความเสี่ยงที่ต้องจับตา

1. **M1 เป็นประตูที่ปิดได้จริง** — ถ้า Ghoul 400 ตัวไม่ถึง 60 FPS บนเว็บ ต้องหยุดและแก้สถาปัตยกรรม ไม่ใช่เดินหน้าไป M2 แล้วหวังว่าจะ optimize ทีหลัง
2. **M3 เป็นเฟสที่ใหญ่ที่สุด** (26 sub-task) ถ้าเริ่มบวม ให้ตัดอาวุธกลางบางตัว (Frost Bell / Rune Orbit) ไปไว้หลัง M4 ก่อน เพราะเงื่อนไขผ่านคือ "3 อาชีพเล่นได้" ไม่ใช่ "อาวุธครบทุกชิ้น"
3. **`StatBlock` (M3-1) เป็นจุดที่พังแบบเงียบที่สุด** ลำดับการคูณผิดจะทำให้บาลานซ์ทั้งเกมเพี้ยนโดยไม่มี error — ต้องมีเทสต์ครอบทุกชั้นของตัวคูณ
4. **สไตล์ภาพยังไม่ตัดสิน** (หัวข้อ 15) M1–M4 ใช้รูปสี่เหลี่ยม/วงกลมสีไปก่อนได้ แต่ต้องตัดสินใจก่อนเริ่ม M5 เพราะขนาด sprite กระทบ hitbox และการอ่านเกมออก
5. **Rite casting ยังอยู่ใน backlog** ห้ามแทรกเข้า M1–M5 เองถ้าผู้ใช้ไม่สั่ง
