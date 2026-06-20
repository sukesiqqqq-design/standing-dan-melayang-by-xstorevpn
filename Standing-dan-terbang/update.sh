#!/data/data/com.termux/files/usr/bin/bash
# =====================================================================
#  Standing & Terbang Toolkit - UPDATER   [mod by xstorevpn]
#  Update semua tool ke versi terbaru.   Pemakaian:  bash update.sh
# =====================================================================
G="\033[1;32m"; Y="\033[1;33m"; C="\033[1;36m"; B="\033[1;34m"; N="\033[0m"
TOOLKIT_DIR="$(cd "$(dirname "$0")" && pwd)"
step() { echo -e "\n${B}==>${N} ${C}$*${N}"; }

step "Update repo toolkit (git pull)"
GIT_ROOT="$(git -C "$TOOLKIT_DIR" rev-parse --show-toplevel 2>/dev/null)"
if [ -n "$GIT_ROOT" ]; then
  git -C "$GIT_ROOT" pull --ff-only || echo -e "${Y}[!] git pull dilewati (cek koneksi / branch).${N}"
else
  echo -e "${Y}[!] Bukan repo git, lewati git pull.${N}"
fi

step "Update BugScanX"
pip install --upgrade bugscan-x

step "Terapkan ulang patch BugScanX subfinder (mode File)"
if command -v bugscanx >/dev/null 2>&1 && [ -f "$TOOLKIT_DIR/tools/patch_bugscanx.py" ]; then
  python "$TOOLKIT_DIR/tools/patch_bugscanx.py" --patch || echo -e "${Y}[!] Patch subfinder dilewati.${N}"
fi

step "Update ApkPatcher"
pip install --force-reinstall https://github.com/TechnoIndian/ApkPatcher/archive/refs/heads/main.zip

step "Refresh symlink tool lokal"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
for t in domainfinder cdncheck snicheck smartscan reverseip; do
  [ -f "$TOOLKIT_DIR/tools/$t.sh" ] && { chmod +x "$TOOLKIT_DIR/tools/$t.sh"; ln -sf "$TOOLKIT_DIR/tools/$t.sh" "$PREFIX/bin/$t"; }
done
[ -f "$TOOLKIT_DIR/menu.sh" ] && { chmod +x "$TOOLKIT_DIR/menu.sh"; ln -sf "$TOOLKIT_DIR/menu.sh" "$PREFIX/bin/stt"; }

echo -e "\n${G}[OK] Semua tool sudah ter-update.${N}"
echo -e "${C}mod by xstorevpn${N}"
