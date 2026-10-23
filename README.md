# Dungeon Survivor 3D

Game *action survival* 3D berbasis *wave* yang dibangun menggunakan Godot Engine 4.7.

## Fitur Utama

- **Sistem Pertarungan & Progresi**: Kombinasi serangan jarak dekat (*Sword*), serangan otomatis jarak jauh (*Arcane Wand*), kemampuan spesial, serta sistem peningkatan *upgrade* di tengah permainan dan *Sanctuary Armory* permanen.
- **Transisi Bioma Dinamis**: Dimulai dari *Dungeon Arena* (Wave 1–5) dan bertransisi secara *real-time* menuju *Lava Caverns* (Wave 6+) setelah mengalahkan Boss, lengkap dengan perubahan *shader* lantai vulkanik, pencahayaan, dan partikel.
- **Rintangan Lingkungan Interaktif**: Area *Molten Lava Floor* dan *Falling Stalactites* yang memberikan *damage* baik kepada pemain maupun musuh.
- **Audio Prosedural**: Seluruh efek suara pertarungan, musik dinamis, dan atmosfer lingkungan disintesis secara prosedural tanpa aset audio eksternal.

## Kontrol

| Aksi | Tombol |
| :--- | :--- |
| Bergerak | `W`, `A`, `S`, `D` / Tombol Panah |
| Serang | Klik Kiri / `Space` / `J` |
| *Dash* | Klik Kanan / `Shift` / `K` |
| Kemampuan Spesial | `Q` / `E` |

## Struktur Proyek

```text
├── scenes/        # Scene utama (Main Menu, Gameplay Loop)
├── src/
│   ├── arena/     # Logika arena, transisi bioma, dan wave spawner
│   ├── audio/     # Synthesizer audio prosedural (AudioManager)
│   ├── characters/# Karakter pemain dan variasi musuh
│   ├── combat/    # Senjata, proyektil, dan efek visual pertarungan
│   ├── hazards/   # Rintangan lingkungan (Lava Floor, Falling Stalactite)
│   ├── meta/      # Sistem penyimpanan data dan progresi (SaveManager)
│   ├── props/     # Objek lingkungan yang dapat dihancurkan
│   ├── shaders/   # Custom spatial & canvas shaders
│   └── ui/        # Antarmuka pengguna (HUD, Menu)
└── tests/         # Pengujian otomatis (Headless test suites)
```

## Menjalankan Proyek

1. Pastikan menggunakan **Godot Engine 4.7** (Forward+ / Jolt Physics).
2. Buka Godot Project Manager, pilih **Import**, dan arahkan ke file `project.godot`.
3. Tekan `F5` untuk menjalankan permainan.

### Menjalankan Pengujian (Headless)

```bash
godot --headless -s tests/test_game_mechanics.gd
```
