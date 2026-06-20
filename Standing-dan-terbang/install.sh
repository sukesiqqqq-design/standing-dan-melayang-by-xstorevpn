#!/data/data/com.termux/files/usr/bin/bash
# =====================================================================
#  Standing & Terbang Toolkit - INSTALLER   [mod by xstorevpn]
# ---------------------------------------------------------------------
#  Memasang semua dependency & tool sekaligus di Termux (non-root):
#    - BugScanX        (pencari SNI bug host)
#    - ApkPatcher      (patch APK / SSL bypass)
#    - domainfinder    (ambil domain/host dari APK/APKS)
#    - cdncheck        (deteksi Cloudflare / CloudFront)
#    - snicheck        (inspeksi TLS/SNI & sertifikat)
#    - smartscan       (orchestrator analisis lengkap one-shot)
#    - reverseip       (reverse IP lookup: cari host lain di IP yang sama)
#
#  Pemakaian:  bash install.sh
#
#  Installer ini dirancang TAHAN BANTING untuk Termux yang baru install:
#    - cek lingkungan Termux
#    - pasang git/curl otomatis kalau belum ada
#    - pasang dependency build agar pip tidak gagal compile
#    - retry otomatis untuk paket yang gagal
#    - ringkasan akhir: apa yang OK & apa yang gagal
# =====================================================================

set -u
G="\033[1;32m"; Y="\033[1;33m"; R="\033[1;31m"; C="\033[1;36m"; B="\033[1;34m"; N="\033[0m"

# Lokasi folder toolkit (tempat script ini berada)
TOOLKIT_DIR="$(cd "$(dirname "$0")" && pwd)"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
BIN="$PREFIX/bin"

# Penampung status untuk ringkasan akhir
FAILED=""
note_fail() { FAILED="$FAILED\n   - $*"; }

step() { echo -e "\n${B}==>${N} ${C}$*${N}"; }
ok()   { echo -e "${G}[OK]${N} $*"; }
warn() { echo -e "${Y}[!]${N} $*"; }
err()  { echo -e "${R}[X]${N} $*"; }

# Coba sebuah perintah hingga beberapa kali (mengatasi jaringan goyang)
retry() {
  local tries="$1"; shift
  local i=1
  while [ "$i" -le "$tries" ]; do
    "$@" && return 0
    warn "Percobaan $i/$tries gagal, mengulang..."
    i=$((i+1)); sleep 2
  done
  return 1
}

banner() {
cat << 'EOF'

   ____  _              _ _                    ___    _____         _
  / ___|| |_ __ _ _ __ | (_)_ __   __ _   _   |_ _|  |_   _|__ _ __| |__
  \___ \| __/ _` | '_ \| | | '_ \ / _` | (_)   | |     | |/ _ \ '__| '_ \
   ___) | || (_| | | | | | | | | | (_| |  _    | |     | |  __/ |  | |_) |
  |____/ \__\__,_|_| |_|_|_|_| |_|\__, | (_)  |___|    |_|\___|_|  |_.__/
                                  |___/
        Standing & Terbang Toolkit  -  Network / SNI / APK Analysis
                          mod by xstorevpn
EOF
}

banner
echo -e "${C}Toolkit dir:${N} $TOOLKIT_DIR\n"

# --- 0. Cek lingkungan Termux --------------------------------------
step "Memeriksa lingkungan"
if [ ! -d "$PREFIX" ] || ! command -v pkg >/dev/null 2>&1; then
  err "Sepertinya ini BUKAN Termux (perintah 'pkg' tidak ada)."
  err "Toolkit ini hanya untuk Termux di Android. Pasang Termux dari F-Droid lalu ulangi."
  exit 1
fi
ok "Termux terdeteksi (PREFIX=$PREFIX)"

# --- 1. Setup storage & update repo ---------------------------------
step "Menyiapkan storage & update package Termux"
if command -v termux-setup-storage >/dev/null 2>&1; then
  termux-setup-storage 2>/dev/null || warn "Lewati izin storage (bisa diberikan nanti)."
else
  warn "termux-setup-storage tidak ada (lewati)"
fi
retry 3 pkg update -y && pkg upgrade -y && ok "Repo Termux ter-update" \
  || { warn "Gagal update repo. Cek koneksi internet."; note_fail "pkg update/upgrade"; }

# --- 2. Bootstrap git & curl (untuk update + apktool) ---------------
step "Memastikan git & curl tersedia"
for base in git curl; do
  if command -v "$base" >/dev/null 2>&1; then
    ok "$base sudah ada"
  else
    retry 3 pkg install -y "$base" && ok "$base terpasang" \
      || { err "Gagal memasang $base"; note_fail "$base"; }
  fi
done

# --- 3. Paket dasar -------------------------------------------------
step "Memasang paket dasar (python, openssl, build tools, dll)"
# Catatan:
#  - clang/rust/binutils/libffi/openssl: agar pip bisa compile dependency
#  - termux-api: menyediakan termux-wake-lock (dipakai cdncheck saat scan besar)
BASE_PKGS="python python-pip clang rust make binutils libffi openssl openssl-tool \
  wget unzip dnsutils openjdk-17 termux-api"
retry 2 pkg install -y $BASE_PKGS \
  && ok "Paket dasar terpasang" \
  || { warn "Sebagian paket dasar gagal; mencoba satu per satu..."; \
       for p in $BASE_PKGS; do pkg install -y "$p" >/dev/null 2>&1 \
         && ok "  $p" || { warn "  gagal: $p"; note_fail "paket: $p"; }; done; }

# Pastikan pip terbaru (mengurangi error build)
step "Memperbarui pip"
python -m pip install --upgrade pip >/dev/null 2>&1 && ok "pip terbaru" || warn "Gagal upgrade pip (lanjut saja)"

# --- 4. apktool (installer khusus Termux) ---------------------------
step "Memasang apktool"
if command -v apktool >/dev/null 2>&1; then
  ok "apktool sudah ada ($(apktool --version 2>/dev/null))"
else
  if curl -fsSL https://raw.githubusercontent.com/rendiix/termux-apktool/main/install.sh | bash; then
    ok "apktool terpasang"
  else
    warn "apktool gagal (bisa dipasang manual nanti)"; note_fail "apktool"
  fi
fi

# --- 5. BugScanX ----------------------------------------------------
step "Memasang BugScanX (pip: bugscan-x)"
retry 2 python -m pip install --upgrade --no-cache-dir bugscan-x \
  && ok "BugScanX terpasang (jalankan: bugscanx / bx)" \
  || { warn "BugScanX gagal dipasang"; note_fail "BugScanX (pip install bugscan-x)"; }

# Patch subfinder mode File: ciutkan ke domain induk -> cari subdomain ulang
if command -v bugscanx >/dev/null 2>&1 && [ -f "$TOOLKIT_DIR/tools/patch_bugscanx.py" ]; then
  step "Menerapkan patch BugScanX subfinder (mode File)"
  python "$TOOLKIT_DIR/tools/patch_bugscanx.py" --patch || warn "Patch subfinder dilewati"
fi

# --- 6. ApkPatcher --------------------------------------------------
step "Memasang ApkPatcher"
retry 2 python -m pip install --force-reinstall --no-cache-dir \
  https://github.com/TechnoIndian/ApkPatcher/archive/refs/heads/main.zip \
  && ok "ApkPatcher terpasang (jalankan: ApkPatcher -h)" \
  || { warn "ApkPatcher gagal dipasang"; note_fail "ApkPatcher"; }

# --- 7. Tool lokal: domainfinder, cdncheck, snicheck, smartscan -----
step "Memasang tool lokal (domainfinder, cdncheck, snicheck, smartscan, reverseip)"
mkdir -p "$BIN"
for t in domainfinder cdncheck snicheck smartscan reverseip; do
  if [ -f "$TOOLKIT_DIR/tools/$t.sh" ]; then
    chmod +x "$TOOLKIT_DIR/tools/$t.sh"
    ln -sf "$TOOLKIT_DIR/tools/$t.sh" "$BIN/$t"
    ok "$t -> $BIN/$t"
  else
    warn "tools/$t.sh tidak ditemukan"; note_fail "tools/$t.sh"
  fi
done

# Folder hasil terpadu
mkdir -p "$HOME/STT-results" && ok "Folder hasil: $HOME/STT-results"

# --- 8. Menu launcher -----------------------------------------------
step "Memasang menu launcher (perintah: stt)"
if [ -f "$TOOLKIT_DIR/menu.sh" ]; then
  chmod +x "$TOOLKIT_DIR/menu.sh"
  ln -sf "$TOOLKIT_DIR/menu.sh" "$BIN/stt"
  ok "Ketik 'stt' untuk membuka menu"
else
  warn "menu.sh tidak ditemukan"; note_fail "menu.sh"
fi

# --- Selesai --------------------------------------------------------
echo ""
echo -e "${G}=====================================================${N}"
if [ -z "$FAILED" ]; then
  echo -e "${G} INSTALASI SELESAI - SEMUA KOMPONEN OK ${N}"
else
  echo -e "${Y} INSTALASI SELESAI - ADA YANG PERLU DICEK ${N}"
fi
echo -e "${G}=====================================================${N}"
echo -e " Jalankan menu:        ${C}stt${N}"
echo -e " Smart scan (1x):      ${C}smartscan <file.apk|apks>${N}"
echo -e " Atau tiap tool:       ${C}bugscanx${N} | ${C}ApkPatcher -h${N} | ${C}domainfinder${N} | ${C}cdncheck${N} | ${C}snicheck${N} | ${C}reverseip${N}"

if [ -n "$FAILED" ]; then
  echo ""
  warn "Komponen berikut GAGAL / perlu dipasang ulang:"
  echo -e "${Y}$FAILED${N}"
  echo -e "${C}Tips:${N} jalankan ulang ${C}bash install.sh${N} setelah koneksi stabil,"
  echo -e "      atau pasang manual paket yang gagal."
fi

echo ""
warn "Gunakan tool ini hanya untuk pengujian yang sah / jaringan milik sendiri."
echo -e "${C}mod by xstorevpn${N}"
