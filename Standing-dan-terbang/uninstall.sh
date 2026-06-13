#!/data/data/com.termux/files/usr/bin/bash
# =====================================================================
#  Standing & Terbang Toolkit - UNINSTALLER   [mod by xstorevpn]
#  Hapus symlink command & (opsional) paket pip.
#  Pemakaian:  bash uninstall.sh
#  Catatan: TIDAK menghapus folder hasil ~/STT-results & ~/domainfinder.
# =====================================================================
G="\033[1;32m"; Y="\033[1;33m"; R="\033[1;31m"; C="\033[1;36m"; N="\033[0m"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
BIN="$PREFIX/bin"

echo -e "${C}[*] Menghapus symlink command lokal...${N}"
for t in domainfinder cdncheck snicheck smartscan stt; do
  [ -L "$BIN/$t" ] && { rm -f "$BIN/$t"; echo -e "${G}[-]${N} $t dihapus"; }
done

echo ""
read -rp "$(echo -e "${Y}Hapus juga BugScanX & ApkPatcher (paket pip)? [y/N]:${N} ")" a
if [ "$a" = "y" ] || [ "$a" = "Y" ]; then
  pip uninstall -y bugscan-x ApkPatcherX 2>/dev/null && echo -e "${G}[OK] paket pip dihapus${N}"
fi

echo -e "\n${G}[OK] Uninstall selesai.${N}"
echo -e "${C}Folder hasil ~/STT-results & ~/domainfinder TIDAK dihapus (aman).${N}"
echo -e "${C}Untuk hapus total: rm -rf ~/STT-results ~/domainfinder & hapus folder repo ini.${N}"
echo -e "${C}mod by xstorevpn${N}"
