#!/data/data/com.termux/files/usr/bin/bash
# =====================================================================
#  Standing & Terbang Toolkit - BOOTSTRAP   [mod by xstorevpn]
# ---------------------------------------------------------------------
#  Skrip 1-baris untuk Termux yang BARU di-install (belum ada git).
#  Tugasnya: pasang git -> clone repo -> jalankan install.sh.
#
#  Cara pakai (cukup salin-tempel 1 baris ini di Termux baru):
#
#    pkg install -y curl && \
#    bash <(curl -fsSL https://raw.githubusercontent.com/sukesiqqqq-design/standing-dan-melayang-by-xstorevpn/main/Standing-dan-terbang/setup.sh)
#
# =====================================================================
set -u
G="\033[1;32m"; Y="\033[1;33m"; R="\033[1;31m"; C="\033[1;36m"; B="\033[1;34m"; N="\033[0m"

REPO_URL="https://github.com/sukesiqqqq-design/standing-dan-melayang-by-xstorevpn"
REPO_DIR="standing-dan-melayang-by-xstorevpn"
SUBDIR="Standing-dan-terbang"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"

step() { echo -e "\n${B}==>${N} ${C}$*${N}"; }
ok()   { echo -e "${G}[OK]${N} $*"; }
err()  { echo -e "${R}[X]${N} $*"; }

echo -e "${C}Standing & Terbang Toolkit - bootstrap (mod by xstorevpn)${N}"

# --- Cek Termux ---
if [ ! -d "$PREFIX" ] || ! command -v pkg >/dev/null 2>&1; then
  err "Ini bukan Termux. Pasang Termux dari F-Droid dulu, lalu ulangi."
  exit 1
fi

# --- Pasang git ---
step "Menyiapkan git"
pkg update -y >/dev/null 2>&1
if command -v git >/dev/null 2>&1; then ok "git sudah ada"; else
  pkg install -y git || { err "Gagal memasang git. Cek koneksi internet."; exit 1; }
  ok "git terpasang"
fi

# --- Clone / update repo ---
step "Mengambil repo"
cd "$HOME" || exit 1
if [ -d "$REPO_DIR/.git" ]; then
  ok "Repo sudah ada, mencoba update..."
  git -C "$REPO_DIR" pull --ff-only || echo -e "${Y}[!] Gagal pull, pakai versi lokal yang ada.${N}"
else
  git clone "$REPO_URL" "$REPO_DIR" || { err "Gagal clone repo."; exit 1; }
  ok "Repo ter-clone ke $HOME/$REPO_DIR"
fi

# --- Jalankan installer ---
step "Menjalankan installer"
if [ -f "$HOME/$REPO_DIR/$SUBDIR/install.sh" ]; then
  cd "$HOME/$REPO_DIR/$SUBDIR" || exit 1
  bash install.sh
else
  err "install.sh tidak ditemukan di $REPO_DIR/$SUBDIR/"
  exit 1
fi
