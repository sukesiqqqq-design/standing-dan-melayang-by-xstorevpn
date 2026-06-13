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
#
#  Pemakaian:  bash install.sh
# =====================================================================

set -u
G="\033[1;32m"; Y="\033[1;33m"; R="\033[1;31m"; C="\033[1;36m"; B="\033[1;34m"; N="\033[0m"

# Lokasi folder toolkit (tempat script ini berada)
TOOLKIT_DIR="$(cd "$(dirname "$0")" && pwd)"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
BIN="$PREFIX/bin"

step() { echo -e "\n${B}==>${N} ${C}$*${N}"; }
ok()   { echo -e "${G}[OK]${N} $*"; }
warn() { echo -e "${Y}[!]${N} $*"; }
err()  { echo -e "${R}[X]${N} $*"; }

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

# --- 1. Setup storage & update repo ---------------------------------
step "Menyiapkan storage & update package Termux"
command -v termux-setup-storage >/dev/null 2>&1 && termux-setup-storage || warn "termux-setup-storage tidak ada (lewati)"
pkg update -y && pkg upgrade -y && ok "Repo Termux ter-update"

# --- 2. Paket dasar -------------------------------------------------
step "Memasang paket dasar (python, git, curl, openssl, dll)"
pkg install -y python git python-pip curl wget unzip binutils dnsutils openssl-tool openjdk-17 \
  && ok "Paket dasar terpasang" || err "Gagal memasang sebagian paket dasar"

# --- 3. apktool (installer khusus Termux) ---------------------------
step "Memasang apktool"
if command -v apktool >/dev/null 2>&1; then
  ok "apktool sudah ada ($(apktool --version 2>/dev/null))"
else
  curl -s https://raw.githubusercontent.com/rendiix/termux-apktool/main/install.sh | bash \
    && ok "apktool terpasang" || warn "apktool gagal (bisa dipasang manual nanti)"
fi

# --- 4. BugScanX ----------------------------------------------------
step "Memasang BugScanX (pip: bugscan-x)"
pip install --upgrade bugscan-x && ok "BugScanX terpasang (jalankan: bugscanx / bx)" \
  || warn "BugScanX gagal dipasang"

# --- 5. ApkPatcher --------------------------------------------------
step "Memasang ApkPatcher"
pip install --force-reinstall https://github.com/TechnoIndian/ApkPatcher/archive/refs/heads/main.zip \
  && ok "ApkPatcher terpasang (jalankan: ApkPatcher -h)" || warn "ApkPatcher gagal dipasang"

# --- 6. Tool lokal: domainfinder, cdncheck, snicheck, smartscan -----
step "Memasang tool lokal (domainfinder, cdncheck, snicheck, smartscan)"
for t in domainfinder cdncheck snicheck smartscan; do
  if [ -f "$TOOLKIT_DIR/tools/$t.sh" ]; then
    chmod +x "$TOOLKIT_DIR/tools/$t.sh"
    ln -sf "$TOOLKIT_DIR/tools/$t.sh" "$BIN/$t"
    ok "$t -> $BIN/$t"
  else
    warn "tools/$t.sh tidak ditemukan"
  fi
done

# Folder hasil terpadu
mkdir -p "$HOME/STT-results" && ok "Folder hasil: $HOME/STT-results"

# --- 7. Menu launcher -----------------------------------------------
step "Memasang menu launcher (perintah: stt)"
if [ -f "$TOOLKIT_DIR/menu.sh" ]; then
  chmod +x "$TOOLKIT_DIR/menu.sh"
  ln -sf "$TOOLKIT_DIR/menu.sh" "$BIN/stt"
  ok "Ketik 'stt' untuk membuka menu"
else
  warn "menu.sh tidak ditemukan"
fi

# --- Selesai --------------------------------------------------------
echo ""
echo -e "${G}=====================================================${N}"
echo -e "${G} INSTALASI SELESAI ${N}"
echo -e "${G}=====================================================${N}"
echo -e " Jalankan menu:        ${C}stt${N}"
echo -e " Smart scan (1x):      ${C}smartscan <file.apk|apks>${N}"
echo -e " Atau tiap tool:       ${C}bugscanx${N} | ${C}ApkPatcher -h${N} | ${C}domainfinder${N} | ${C}cdncheck${N} | ${C}snicheck${N}"
echo ""
warn "Gunakan tool ini hanya untuk pengujian yang sah / jaringan milik sendiri."
echo -e "${C}mod by xstorevpn${N}"
