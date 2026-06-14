# 🛰️ Standing & Terbang Toolkit — *mod by xstorevpn*

Kumpulan tool **analisis jaringan, host/SNI, dan APK** dalam satu paket — dibuat untuk berjalan di **Termux (non-root)**. Menggabungkan beberapa tool populer + utilitas tambahan, dilengkapi **installer otomatis**, **menu interaktif**, dan mode **Smart Scan** (analisis lengkap sekali jalan).

> 🔧 **Mod by xstorevpn:** tahap *Response-Checker* (cek host response) dihilangkan karena sering error (`user-agents.txt not found`) setelah scan selesai. Smart Scan sekarang berhenti rapi setelah tahap CDN + TLS + port.

> ⚠️ **Disclaimer:** Toolkit ini ditujukan untuk **edukasi & pengujian yang sah** (jaringan/aplikasi milik sendiri atau yang Anda punya izin untuk diuji). Gunakan secara bertanggung jawab dan sesuai hukum yang berlaku.

---

## 📦 Tool yang tergabung

| Tool | Fungsi | Sumber |
|------|--------|--------|
| **BugScanX** | All-in-one pencari SNI bug host (scanner, subdomain, reverse IP, port, SSL/DNS) | [FreeNetLabs/BugScanX](https://github.com/FreeNetLabs/BugScanX) |
| **ApkPatcher** | Patch APK (SSL bypass, merge split APK, dll) | [TechnoIndian/ApkPatcher](https://github.com/TechnoIndian/ApkPatcher) |
| **domainfinder** *(lokal)* | Ekstrak domain & host/SNI dari APK/APKS/XAPK/APKM — **ekstraksi dalam: unzip + apktool decode resource + mining string biner (.dex/.so/.arsc)** untuk hasil maksimal | toolkit ini |
| **cdncheck** *(lokal)* | Deteksi CDN (Cloudflare / CloudFront) **+ versi TLS + cek port 80/443**, scan paralel | toolkit ini |
| **snicheck** *(lokal)* | Inspeksi TLS/SNI handshake + detail sertifikat (CN, SAN, issuer, expiry) — opsional | toolkit ini |
| **smartscan** *(lokal)* | Orchestrator: APK → domain → CDN+TLS, sekali jalan + laporan terpadu | toolkit ini |

---

## 🚀 Instalasi (Termux)

> Toolkit ini **hanya berjalan di Termux (Android)**. Pasang Termux dari **[F-Droid](https://f-droid.org/packages/com.termux/)** (versi Play Store sudah usang & sering error).

### ⭐ Cara TERMUDAH — 1 baris (untuk Termux yang baru install)

Salin–tempel **satu baris** ini di Termux baru. Otomatis pasang git, clone repo, lalu jalankan installer:

```bash
pkg install -y curl && bash <(curl -fsSL https://raw.githubusercontent.com/sukesiqqqq-design/standing-dan-melayang-by-xstorevpn/main/Standing-dan-terbang/setup.sh)
```

### 🔧 Cara manual (kalau ingin langkah per langkah)

```bash
# 1. Update & pasang git dulu (Termux baru BELUM punya git)
pkg update -y && pkg install -y git

# 2. Clone repo ini
git clone https://github.com/sukesiqqqq-design/standing-dan-melayang-by-xstorevpn

# 3. Masuk ke folder toolkit (ada di dalam subfolder)
cd standing-dan-melayang-by-xstorevpn/Standing-dan-terbang

# 4. Jalankan installer (otomatis pasang semua)
bash install.sh
```

> 💡 **Kenapa error "git is not installed"?** Termux yang baru di-install **belum punya `git`**, jadi perintah `git clone` langsung gagal dan folder tidak pernah dibuat. Selalu jalankan `pkg install -y git` **lebih dulu**, atau pakai cara 1-baris di atas yang sudah mengurus ini otomatis.

Installer memasang: `python`, `git`, `curl`, `wget`, `unzip`, `clang`, `rust`, `make`, `binutils`, `libffi`, `dnsutils`, `openssl-tool`, `openjdk-17`, `termux-api`, `apktool`, **BugScanX**, **ApkPatcher**, serta meng-_install_ perintah `domainfinder`, `cdncheck`, `snicheck`, `smartscan`, dan menu `stt`.

Installer kini **tahan banting**: kalau ada paket yang gagal (mis. koneksi putus), installer tetap lanjut dan menampilkan **ringkasan komponen yang gagal** di akhir — cukup jalankan `bash install.sh` sekali lagi untuk melengkapinya.

---

## 🎮 Cara pakai

### Lewat menu (paling mudah)
```bash
stt
```

Daftar menu:
```
 1) BugScanX         6) Smart Scan (analisis lengkap 1x)
 2) ApkPatcher       7) Update semua tool
 3) Domain Finder    8) Cek status / versi
 4) CDN+TLS+Port      9) Uninstall toolkit
 5) SNI/TLS Detail  10) Bantuan / Penjelasan
```

### Lewat perintah langsung

| Perintah | Keterangan |
|----------|-----------|
| `bugscanx` | Buka BugScanX (alias: `bx`) |
| `ApkPatcher -h` | Bantuan ApkPatcher |
| `ApkPatcher -i app.apk` | Patch APK (default SSL bypass) |
| `ApkPatcher -m app.apks` | Merge split APK jadi satu `.apk` |
| `domainfinder app.apks` | Ambil daftar domain/host dari APK |
| `cdncheck domains.txt` | Deteksi CDN + versi TLS + port 80/443 (paralel) |
| `cdncheck domains.txt 20` | Sama, dengan 20 proses paralel |
| `snicheck host.com` | Detail sertifikat TLS/SNI 1 host (opsional) |
| `snicheck domains.txt 443` | Detail sertifikat banyak host (port opsional) |
| `smartscan app.apks` | **Analisis lengkap sekali jalan** |

---

## 🔁 Patch BugScanX Subfinder (mode File)

Toolkit ini menambahkan **patch otomatis** untuk fitur **Subdomain Finder** di BugScanX, **khusus input "File"**.

| | Perilaku |
|---|---|
| **Sebelum patch** | Tiap baris di file diperlakukan sebagai domain apa adanya, lalu dicari subdomain-nya. Kalau isi file sudah berupa subdomain (mis. `api.xl.co.id`, `cdn.xl.co.id`), hasilnya sering kosong karena mencari *sub-sub-domain*. |
| **Sesudah patch** | Semua entri **diciutkan ke domain induk (root) yang unik** (mis. `api.xl.co.id` → `xl.co.id`), lalu subdomain **dicari ulang** dari root tersebut → menemukan lebih banyak subdomain. |

- Hanya cabang **File** yang diubah. Mode **Manual** tetap seperti aslinya.
- Mengerti TLD bertingkat (mis. `co.id`, `co.uk`, `com.br`, `ac.id`), membersihkan `http://`, path, port, dan `user:pass@`, serta melewati entri berupa IP.
- Patch **idempotent** dan **otomatis dipasang ulang** oleh `install.sh` / `update.sh` (karena BugScanX paket pip yang ketimpa saat update).

Kelola lewat menu: `stt` → **1) BugScanX** → pilih *status / aktifkan / nonaktifkan patch*.
Atau manual:
```bash
python ~/standing-dan-melayang-by-xstorevpn/Standing-dan-terbang/tools/patch_bugscanx.py --status   # cek
python ~/standing-dan-melayang-by-xstorevpn/Standing-dan-terbang/tools/patch_bugscanx.py --patch    # aktifkan
python ~/standing-dan-melayang-by-xstorevpn/Standing-dan-terbang/tools/patch_bugscanx.py --revert   # kembalikan asli
```

---

## ⭐ Smart Scan — analisis lengkap sekali jalan

Cukup satu perintah, semua tahap otomatis berurutan:

```bash
smartscan /sdcard/Download/myXL_9.2.0.apks
```

Tahapannya:
1. **domainfinder** → ekstrak semua domain/host (auto-merge kalau `.apks`)
2. **cdncheck** → kelompokkan Cloudflare / CloudFront / origin **+ versi TLS + port 80/443** tiap domain (paralel)

Hasil dikumpulkan rapi di:
```
~/STT-results/<nama-app>/
├── <nama>_domains.txt
├── <nama>_domains_cloudflare.txt
├── <nama>_domains_cloudfront.txt
├── <nama>_domains_origin.txt
├── <nama>_domains_cdn_tls.txt   # tabel: domain | CDN | TLS | 80 | 443
└── report.txt          # ← ringkasan semua tahap
```
Folder ini otomatis disalin juga ke `/sdcard/sttxstore/<nama-app>/` (folder khusus di internal storage, supaya Download tidak penuh).

---

## 🔄 Contoh alur manual (step-by-step)

```bash
# 1. Ambil domain/host dari aplikasi
domainfinder /sdcard/Download/myXL_9.2.0.apks

# 2. Deteksi CDN + versi TLS + port 80/443 (paralel)
cdncheck ~/domainfinder/myXL_9.2.0_domains.txt 20

# 3. (Opsional) detail sertifikat TLS/SNI pada domain origin
snicheck ~/domainfinder/myXL_9.2.0_domains_origin.txt

# 4. Scan bug host lebih dalam
bugscanx
```

---

## 📁 Struktur repo

```
standing-dan-melayang-by-xstorevpn/
└── Standing-dan-terbang/
    ├── setup.sh              # bootstrap 1-baris (pasang git + clone + install)
    ├── install.sh            # installer otomatis (tahan banting)
    ├── update.sh             # update semua tool
    ├── uninstall.sh          # hapus toolkit (folder hasil tetap aman)
    ├── menu.sh               # menu launcher (perintah: stt)
    ├── tools/
    │   ├── domainfinder.sh   # ekstrak domain/host dari APK
    │   ├── cdncheck.sh       # deteksi Cloudflare / CloudFront
    │   ├── snicheck.sh       # inspeksi TLS/SNI & sertifikat
    │   └── smartscan.sh      # orchestrator analisis lengkap
    ├── wordlists/
    │   └── subdomains.txt    # ~200 subdomain umum untuk enumerasi
    └── README.md
```

---

## 🔧 Update & Uninstall

```bash
# Update semua tool sekaligus
bash update.sh          # atau menu -> 7

# Uninstall (symlink command + opsional paket pip)
bash uninstall.sh       # atau menu -> 9
```
> Catatan: uninstall **tidak menghapus** folder hasil `~/STT-results` & `~/domainfinder`.

---

## 🙏 Kredit

Toolkit ini hanya **menggabungkan & mempermudah** penggunaan tool berikut. Semua hak & kredit milik pembuat aslinya:

- BugScanX — [FreeNetLabs](https://github.com/FreeNetLabs/BugScanX)
- ApkPatcher — [TechnoIndian](https://github.com/TechnoIndian/ApkPatcher)
- apktool (Termux) — [rendiix](https://github.com/rendiix/termux-apktool)

Mod & penyesuaian menu: **xstorevpn**.

---

## 🛠️ Troubleshooting

**`The program git is not installed` / `cd: No such file or directory` saat memulai**
Ini terjadi di **Termux yang baru di-install** karena `git` belum ada, sehingga `git clone` gagal dan folder tidak pernah dibuat (lalu `cd` & `bash install.sh` ikut gagal). Solusi:
- Pasang git dulu: `pkg update -y && pkg install -y git`, lalu clone & install ulang, **atau**
- Pakai cara **1-baris** di bagian Instalasi (paling aman untuk pemula).

**`Standing-dan-terbang: No such file or directory` saat `cd`**
Nama folder hasil clone adalah `standing-dan-melayang-by-xstorevpn`, dan toolkit ada di **subfolder** `Standing-dan-terbang`. Jadi perintah yang benar:
```bash
cd standing-dan-melayang-by-xstorevpn/Standing-dan-terbang
```

**`[Process completed (signal 9)]` saat scan banyak domain**
Itu artinya Android membunuh proses (umumnya **kehabisan RAM/OOM**, atau aplikasi pindah ke background / layar mati). Solusi:
- **Auto-resume tahan-OOM (baru):** `cdncheck` kini memakai arsitektur **supervisor + worker**. Bagian berat (worker) boleh saja dibunuh Android, tapi "supervisor" yang ringan **otomatis melanjutkan** scan dari domain yang belum selesai — sampai tuntas, **tanpa perlu menjalankan ulang manual**.
- Toolkit juga memasang `termux-wake-lock` selama scan. Untuk daftar sangat besar, sebaiknya **layar HP tetap menyala**.
- **Kurangi paralel** bila HP lemah/RAM kecil: `cdncheck domains.txt 3` (default sekarang `5`, sebelumnya `8`).
- Hasil ditulis **bertahap**, jadi `*_cloudflare.txt` / `*_origin.txt` / `*_cdn_tls.txt` selalu berisi hasil parsial walau terputus. Untuk mengulang dari nol: `cdncheck domains.txt 5 fresh`.
- Kalau ingin menjalankan manual lagi (mis. supervisor ikut terbunuh), cukup ulangi perintah yang sama — tetap melanjutkan (resume).

**Kolom TLS kosong (`TLS=-`) padahal 443 open**
Wajar untuk sebagian host (menolak HEAD / handshake lambat). Gunakan `snicheck <host>` untuk inspeksi detail.

**Banyak "domain" aneh (`conv3d.cc`, `AJAX.NET`)**
Itu artefak dari kode di dalam APK. Filter `domainfinder` sudah dibuat ketat, tapi analisis statis tidak 100% bersih — domain yang tidak resolve akan tampak `closed`/`origin` saat `cdncheck` dan mudah diabaikan.
