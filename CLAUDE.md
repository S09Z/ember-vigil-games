# Ember Vigil

เกม bullet-heaven / roguelite ธีมดาร์กแฟนตาซี ผู้เล่นเลือก 1 ใน 3 อาชีพ (ระยะใกล้ / ระยะไกล / วงกว้าง) โจมตีอัตโนมัติ และเอาชีวิตรอดจากฝูงปีศาจจนรุ่งสาง
เป้าหมายแรกคือเดโมเล่นบนเว็บ (itch.io) เพื่อพิสูจน์แนวคิด จากนั้นพัฒนาต่อเป็นเกมเดสก์ท็อปด้วยโค้ดชุดเดียวกัน

- ดีไซน์ทั้งหมดอยู่ที่ `docs/design.md` อ่านก่อนเริ่มงานที่เกี่ยวกับ gameplay
- แผนงานแตกเป็น phase และ sub-task อยู่ที่ `docs/roadmap.md` ทำ sub-task เสร็จแล้วให้ใส่ ✅ หน้ารหัสงานในไฟล์นั้นด้วย
- ตอบผู้ใช้เป็นภาษาไทย ชื่อในโค้ด ไฟล์ และ commit message ใช้ภาษาอังกฤษ

## Tech stack

- Godot **4.7.2.stable** (pin ไว้เพราะ export templates ที่ติดตั้งในเครื่องเป็นเวอร์ชันนี้)
- **GDScript เท่านั้น** ห้ามใช้ C# เพราะต้อง export เป็นเว็บ
- Renderer: **Compatibility** (ตัวที่ใช้กับเว็บ)
- Web export: **ปิด thread support** เพื่อให้รันบนเว็บทั่วไปและ itch.io ได้โดยไม่ต้องตั้ง header พิเศษ
- ความละเอียดฐาน 640×360, stretch mode `canvas_items`, aspect `expand`
- Unit test: GUT 9.7.1 (`addons/gut`) — ถ้าวันหลังทำ CI ใช้ `-gjunit_xml_file` ออก JUnit XML ได้

## Commands

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

ถ้าแก้คอนฟิกที่กระทบ web export ให้เช็คว่า `build/web/` **ไม่มี** ไฟล์ `index.worker.js` ถ้ามีแปลว่า thread support
ถูกเปิดโดยไม่ได้ตั้งใจ ซึ่งจะต้องตั้ง header COOP/COEP บนโฮสต์ และ itch.io ทำให้ไม่ได้
console ของเบราว์เซอร์ต้องขึ้นบรรทัด `single-threaded, no GDExtension support` เสมอ

`export_presets.cfg` ตั้ง `exclude_filter` ไม่ให้ `addons/gut/*` และ `tests/*` ติดไปกับ build เว็บ
เพิ่มโค้ดที่ใช้เฉพาะตอนเทสต์ต้องอยู่ใต้สองโฟลเดอร์นี้ ไม่งั้นผู้เล่นต้องโหลดมันด้วย

ก่อนบอกว่างานเสร็จ ต้องรัน import และเทสต์ผ่าน ถ้าแก้ส่วนที่กระทบ performance ต้อง export เว็บแล้วลองเปิดดูด้วย

## โครงสร้างโปรเจกต์

```
res://
├─ main.tscn                 จุดเริ่ม: สลับระหว่าง Camp / Run / Results
├─ core/
│  ├─ spatial_grid.gd        hash grid สำหรับหาเพื่อนบ้านและเช็คการชน
│  ├─ pool.gd                object pool ทั่วไป
│  └─ rng.gd                 RNG ที่ seed ได้ (ใช้ซ้ำรอบเดิมตอน debug)
├─ data/                     Resource ทั้งหมด (.gd = schema, .tres = ข้อมูล)
│  ├─ class_def.gd, weapon_def.gd, passive_def.gd, enemy_def.gd, evolution_def.gd, meta_upgrade_def.gd
│  └─ classes/ weapons/ passives/ enemies/ evolutions/ meta/
├─ run/
│  ├─ run_state.gd           ข้อมูลของหนึ่งรอบ: เวลา kills XP เลเวล บิลด์
│  ├─ player.gd              CharacterBody2D ตัวเดียวในเกมที่เป็น Node จริง
│  ├─ enemy_system.gd        เก็บศัตรูเป็น array + วาดด้วย MultiMeshInstance2D
│  ├─ projectile_system.gd   กระสุนเป็น array + MultiMesh
│  ├─ pickup_system.gd       XP gem และกล่องเสบียง
│  ├─ spawn_director.gd      ปล่อยศัตรูตามเวลา (อ่านค่าจาก data)
│  └─ weapons/               หนึ่งไฟล์ต่ออาวุธ สืบทอดจาก weapon_base.gd
├─ meta/
│  └─ save_service.gd        เก็บ Embers และอัปเกรดถาวรลง user://save.json
└─ ui/                       hud, level_up_panel, camp_screen, results_screen
```

## กฎที่ต้องทำตาม

### Performance (สำคัญที่สุด เพราะรันบนเว็บ)
- **ห้ามสร้าง Node ต่อศัตรู ต่อกระสุน หรือต่อ XP gem** ให้เก็บเป็น `PackedVector2Array` / `PackedFloat32Array` แบบ struct-of-arrays แล้ววาดด้วย `MultiMeshInstance2D`
- **ห้ามใช้ `Area2D` หรือ physics body กับศัตรู** ใช้ `SpatialGrid` เช็คการชนเอง ผู้เล่นเป็น physics body ตัวเดียว
- ทุกอย่างที่เกิดและหายบ่อยต้องผ่าน pool
- ห้าม allocate ใน `_physics_process` ของระบบหลัก (ห้ามสร้าง Array หรือ Dictionary ใหม่ทุกเฟรม)
- เป้า: ศัตรู 400 ตัวที่ 60 FPS บนเว็บในแล็ปท็อประดับกลาง และ 1,000 ตัวบนเดสก์ท็อป
- เพิ่มระบบใหม่แล้วต้องดูตัวเลขใน debug overlay (FPS, จำนวนศัตรู, ms ต่อระบบ) กด F3 เพื่อเปิด

### Data-driven
- ตัวเลขทุกตัวของ gameplay (ดาเมจ คูลดาวน์ HP ราคา) อยู่ในไฟล์ `.tres` ใต้ `data/` ห้าม hardcode ในสคริปต์
- ค่าตั้งต้นทั้งหมดมาจากตารางใน `docs/design.md` ถ้าแก้ตัวเลขในเกม ต้องแก้ตารางใน design.md ให้ตรงกันด้วย
- เพิ่มอาวุธใหม่ = สร้าง `WeaponDef` + สคริปต์พฤติกรรมหนึ่งไฟล์ ห้ามแก้ระบบกลาง

### GDScript style
- ใส่ static type ทุกที่ (`var hp: float = 0.0`, `func f(x: int) -> void`)
- ระบบต่าง ๆ สื่อสารกันผ่าน signal ส่วน UI ฟัง signal อย่างเดียว ห้ามเข้าไปแก้ค่าของระบบเกมโดยตรง
- ชื่อไฟล์ `snake_case.gd`, class `PascalCase`, ค่าคงที่ `UPPER_CASE`
- หนึ่งไฟล์ทำหน้าที่เดียว ถ้าเกิน ~300 บรรทัด ให้พิจารณาแยก

### Testing
- logic ที่ไม่ผูกกับภาพต้องมี GUT test: XP curve, การสุ่มการ์ดเลเวลอัป, เงื่อนไข evolution, การคำนวณ Embers, SpatialGrid, การซื้ออัปเกรดถาวร
- ส่วนความรู้สึกในการเล่นใช้ playtest checklist ท้าย `docs/design.md`

### Git
- commit ทีละเรื่องเล็ก ๆ ข้อความเป็นภาษาอังกฤษแบบ imperative เช่น `Add Ranger longbow weapon`
- ห้าม commit โฟลเดอร์ `build/` และ `.godot/`

## สิ่งที่ยังไม่ทำใน MVP (อย่าเริ่มเองถ้าผู้ใช้ไม่ได้ขอ)
- co-op หรือ multiplayer
- ระบบร่ายท่าไม้ตายด้วยลูกศร (Rite casting) ซึ่งอยู่ใน backlog ของ design.md
- หลายฉาก, story, ภาษาอื่น
- การขายของในเกมหรือโฆษณา
