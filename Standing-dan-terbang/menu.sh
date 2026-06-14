#!/data/data/com.termux/files/usr/bin/bash
# =====================================================================
#  Standing & Terbang Toolkit - MENU LAUNCHER  (perintah: stt)
#  ---  mod by xstorevpn  ---
# ---------------------------------------------------------------------
#  Menu interaktif penuh: pilih tool & file cukup dengan angka,
#  ada pemilih file otomatis + submenu terpandu + bantuan.
# =====================================================================

G="\033[1;32m"; Y="\033[1;33m"; R="\033[1;31m"; C="\033[1;36m"; B="\033[1;34m"; M="\033[1;35m"; N="\033[0m"
TOOLKIT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
PICKED=""

pause() { echo ""; read -rp "$(echo -e "${Y}Tekan ENTER untuk kembali...${N}")" _; }

header() {
  clear 2>/dev/null
  echo -e "${M}========================================================${N}"
  echo -e "${M}      STANDING & TERBANG TOOLKIT  -  Main Menu          ${N}"
  echo -e "${C}                  mod by xstorevpn                      ${N}"
  echo -e "${M}========================================================${N}"
}

status()  { command -v "$1" >/dev/null 2>&1 && echo -e "${G}[on]${N}" || echo -e "${R}[off]${N}"; }
statusf() { [ -f "$1" ] && echo -e "${G}[on]${N}" || echo -e "${R}[off]${N}"; }

# ---------------------------------------------------------------------
#  Pemilih file otomatis
#  Pakai: pick_file "Pesan" "ext1 ext2 ..."   (kosong = semua file)
#  Hasil ada di variabel $PICKED (kosong kalau batal)
# ---------------------------------------------------------------------
pick_file() {
  PICKED=""
  local prompt="$1"; local exts="$2"
  local -a files=(); local -a uniq=()
  local d f ext

  for d in "/sdcard/Download" "/sdcard/sttxstore" "$PWD" "$HOME" "$HOME/domainfinder" "/sdcard"; do
    [ -d "$d" ] || continue
    while IFS= read -r f; do
      ext="$(echo "${f##*.}" | tr 'A-Z' 'a-z')"
      if [ -z "$exts" ] || [[ " $exts " == *" $ext "* ]]; then files+=("$f"); fi
    done < <(find "$d" -maxdepth 1 -type f 2>/dev/null | sort)
  done
  # buang duplikat
  for f in "${files[@]}"; do
    case " ${uniq[*]} " in *" $f "*) ;; *) uniq+=("$f");; esac
  done
  files=("${uniq[@]}")

  echo ""
  echo -e "${C}$prompt${N}"
  echo -e "${M}--------------------------------------------------------${N}"
  if [ ${#files[@]} -gt 0 ]; then
    local i=1
    for f in "${files[@]}"; do printf "  ${G}%2d)${N} %s\n" "$i" "$f"; i=$((i+1)); done
  else
    echo -e "  ${Y}(tidak ada file cocok ditemukan otomatis)${N}"
  fi
  echo -e "${M}--------------------------------------------------------${N}"
  echo -e "  ${G} m)${N} Ketik path manual"
  echo -e "  ${G} 0)${N} Batal"
  read -rp "$(echo -e "${Y}Pilih file:${N} ")" sel

  if [ -z "$sel" ] || [ "$sel" = "0" ]; then return 1; fi
  if [ "$sel" = "m" ] || [ "$sel" = "M" ]; then
    read -rp "Masukkan path lengkap: " PICKED
    [ -f "$PICKED" ] || { echo -e "${R}File tidak ditemukan.${N}"; PICKED=""; return 1; }
    return 0
  fi
  if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le ${#files[@]} ]; then
    PICKED="${files[$((sel-1))]}"; return 0
  fi
  echo -e "${R}Pilihan tidak valid.${N}"; return 1
}

# ---------------------------------------------------------------------
#  Menu utama
# ---------------------------------------------------------------------
menu() {
  header
  echo -e "  ${C} 1)${N} BugScanX        - Cari SNI bug host        $(status bugscanx)"
  echo -e "  ${C} 2)${N} ApkPatcher       - Patch APK (terpandu)     $(status ApkPatcher)"
  echo -e "  ${C} 3)${N} Domain Finder    - Ambil domain dari APK     $(status domainfinder)"
  echo -e "  ${C} 4)${N} CDN+TLS+Port     - CDN, versi TLS & port 80/443 $(status cdncheck)"
  echo -e "  ${C} 5)${N} SNI/TLS Detail   - Detail handshake & sertifikat $(status snicheck)"
  echo -e "  ${C} 6)${N} ${B}Smart Scan${N}      - Analisis lengkap 1x klik  $(status smartscan)"
  echo -e "${M}--------------------------------------------------------${N}"
  echo -e "  ${C} 7)${N} Update semua tool        ${C} 8)${N} Cek status/versi"
  echo -e "  ${C} 9)${N} Uninstall toolkit        ${C}10)${N} ${Y}Bantuan / Penjelasan${N}"
  echo -e "  ${C} 0)${N} Keluar"
  echo -e "${M}--------------------------------------------------------${N}"
  read -rp "$(echo -e "${Y}Pilih menu [0-10]:${N} ")" pick
}

# ---------------------------------------------------------------------
#  Aksi tiap menu
# ---------------------------------------------------------------------
run_bugscanx() {
  if ! command -v bugscanx >/dev/null 2>&1; then
    echo -e "${R}BugScanX belum terpasang. Pasang: pip install bugscan-x${N}"; pause; return
  fi
  header
  echo -e "${B}BugScanX${N}"
  echo -e "  ${C}1)${N} Jalankan BugScanX"
  echo -e "  ${C}2)${N} Status patch subfinder (mode File)"
  echo -e "  ${C}3)${N} Aktifkan patch subfinder (file -> root domain -> cari subdomain ulang)"
  echo -e "  ${C}4)${N} Nonaktifkan patch (kembali ke perilaku asli)"
  echo -e "  ${C}0)${N} Batal"
  read -rp "$(echo -e "${Y}Pilih:${N} ")" b
  local PATCH="$TOOLKIT_DIR/tools/patch_bugscanx.py"
  case "$b" in
    1) # pastikan patch aktif dulu (idempotent), baru jalankan
       [ -f "$PATCH" ] && python "$PATCH" --patch >/dev/null 2>&1
       bugscanx ;;
    2) [ -f "$PATCH" ] && python "$PATCH" --status || echo -e "${R}patch_bugscanx.py tidak ada.${N}" ;;
    3) [ -f "$PATCH" ] && python "$PATCH" --patch  || echo -e "${R}patch_bugscanx.py tidak ada.${N}" ;;
    4) [ -f "$PATCH" ] && python "$PATCH" --revert || echo -e "${R}patch_bugscanx.py tidak ada.${N}" ;;
    *) return ;;
  esac
  pause
}

run_apkpatcher() {
  if ! command -v ApkPatcher >/dev/null 2>&1; then
    echo -e "${R}ApkPatcher belum terpasang.${N}"; pause; return
  fi
  header
  echo -e "${B}ApkPatcher - pilih operasi:${N}"
  echo -e "  ${C}1)${N} SSL/VPN Bypass (default)"
  echo -e "  ${C}2)${N} Merge split APK (.apks/.xapk/.apkm) -> .apk"
  echo -e "  ${C}3)${N} SSL Bypass + pakai APKEditor (-a)"
  echo -e "  ${C}4)${N} Flutter SSL bypass (-f)"
  echo -e "  ${C}5)${N} Lihat SEMUA opsi (-h)"
  echo -e "  ${C}0)${N} Batal"
  read -rp "$(echo -e "${Y}Pilih:${N} ")" op
  case "$op" in
    1) pick_file "Pilih file APK:" "apk" || { pause; return; }; ApkPatcher -i "$PICKED" ;;
    2) pick_file "Pilih file split:" "apks xapk apkm" || { pause; return; }; ApkPatcher -m "$PICKED" ;;
    3) pick_file "Pilih file APK:" "apk" || { pause; return; }; ApkPatcher -i "$PICKED" -a ;;
    4) pick_file "Pilih file APK:" "apk" || { pause; return; }; ApkPatcher -i "$PICKED" -f ;;
    5) ApkPatcher -h ;;
    *) return ;;
  esac
  pause
}

run_domainfinder() {
  command -v domainfinder >/dev/null 2>&1 || { echo -e "${R}domainfinder belum terpasang.${N}"; pause; return; }
  pick_file "Pilih APK/APKS/XAPK/APKM:" "apk apks xapk apkm" || { pause; return; }
  domainfinder "$PICKED"
  pause
}

run_cdncheck() {
  command -v cdncheck >/dev/null 2>&1 || { echo -e "${R}cdncheck belum terpasang.${N}"; pause; return; }
  pick_file "Pilih file domains (.txt):" "txt" || { pause; return; }
  read -rp "Jumlah scan paralel (kosong=12): " j
  cdncheck "$PICKED" "${j:-12}"
  pause
}

run_snicheck() {
  command -v snicheck >/dev/null 2>&1 || { echo -e "${R}snicheck belum terpasang.${N}"; pause; return; }
  header
  echo -e "${B}SNI/TLS Checker${N}"
  echo -e "  ${C}1)${N} Satu host (ketik manual)"
  echo -e "  ${C}2)${N} Banyak host (dari file .txt)"
  echo -e "  ${C}0)${N} Batal"
  read -rp "$(echo -e "${Y}Pilih:${N} ")" m
  case "$m" in
    1) read -rp "Host (mis: api.xl.co.id): " h
       read -rp "Port (kosong=443): " p
       [ -n "$h" ] && snicheck "$h" "${p:-443}" ;;
    2) pick_file "Pilih file domains (.txt):" "txt" || { pause; return; }
       read -rp "Port (kosong=443): " p
       snicheck "$PICKED" "${p:-443}" ;;
    *) return ;;
  esac
  pause
}

run_smartscan() {
  command -v smartscan >/dev/null 2>&1 || { echo -e "${R}smartscan belum terpasang.${N}"; pause; return; }
  echo -e "${C}Smart Scan = APK -> domain -> CDN+TLS+port (otomatis)${N}"
  pick_file "Pilih APK/APKS atau file domains.txt:" "apk apks xapk apkm txt" || { pause; return; }
  smartscan "$PICKED"
  pause
}

update_all() {
  if [ -f "$TOOLKIT_DIR/update.sh" ]; then bash "$TOOLKIT_DIR/update.sh"
  else
    pip install --upgrade bugscan-x
    pip install --force-reinstall https://github.com/TechnoIndian/ApkPatcher/archive/refs/heads/main.zip
  fi
  pause
}

run_uninstall() {
  [ -f "$TOOLKIT_DIR/uninstall.sh" ] && bash "$TOOLKIT_DIR/uninstall.sh" \
    || echo -e "${R}uninstall.sh tidak ditemukan.${N}"
  pause
}

show_status() {
  header
  echo -e "BugScanX        : $(command -v bugscanx >/dev/null 2>&1 && echo -e "${G}OK${N}" || echo -e "${R}belum${N}")"
  echo -e "ApkPatcher      : $(command -v ApkPatcher >/dev/null 2>&1 && echo -e "${G}OK${N}" || echo -e "${R}belum${N}")"
  echo -e "apktool         : $(command -v apktool >/dev/null 2>&1 && apktool --version 2>/dev/null || echo -e "${R}belum${N}")"
  echo -e "domainfinder    : $(status domainfinder)"
  echo -e "cdncheck        : $(status cdncheck)"
  echo -e "snicheck        : $(status snicheck)"
  echo -e "smartscan       : $(status smartscan)"
  echo -e "openssl         : $(command -v openssl >/dev/null 2>&1 && echo -e "${G}OK${N}" || echo -e "${R}belum${N}")"
  pause
}

show_help() {
  header
  echo -e "${B}PENJELASAN SINGKAT TIAP TOOL${N}\n"
  echo -e "${C}1) BugScanX${N}        : cari SNI bug host (scanner, subdomain, reverse IP, port)."
  echo -e "${C}2) ApkPatcher${N}      : ubah APK -> SSL bypass, merge split APK (.apks), dll."
  echo -e "${C}3) Domain Finder${N}   : ambil daftar domain/host yang ada di dalam APK."
  echo -e "${C}4) CDN+TLS+Port${N}    : cek CDN (Cloudflare/CloudFront), ${B}versi TLS${N}, ${B}& port 80/443${N} sekaligus (paralel)."
  echo -e "${C}5) SNI/TLS Detail${N}  : detail lengkap sertifikat (CN/SAN/issuer/expiry) - opsional."
  echo -e "${C}6) Smart Scan${N}      : jalankan 3 -> 4 otomatis, hasil terkumpul 1 folder."
  echo ""
  echo -e "${Y}Alur umum yang disarankan:${N}"
  echo -e "  - Punya APK? -> menu ${C}6 (Smart Scan)${N}, pilih file APK-nya. Beres semua."
  echo -e "  - Mau cek CDN + TLS daftar domain? -> menu ${C}4${N}."
  echo -e "  - Hasil tersimpan di: ${C}~/STT-results/<nama-app>/${N} & ${C}/sdcard/sttxstore/${N}"
  echo ""
  echo -e "${R}Catatan:${N} gunakan hanya untuk pengujian yang sah / perangkat & aplikasi milik sendiri."
  echo -e "${C}mod by xstorevpn${N}"
  pause
}

# --- Loop utama ---
while true; do
  menu
  case "$pick" in
    1) run_bugscanx ;;
    2) run_apkpatcher ;;
    3) run_domainfinder ;;
    4) run_cdncheck ;;
    5) run_snicheck ;;
    6) run_smartscan ;;
    7) update_all ;;
    8) show_status ;;
    9) run_uninstall ;;
    10) show_help ;;
    0) echo -e "${G}Sampai jumpa!${N}"; exit 0 ;;
    *) echo -e "${R}Pilihan tidak valid.${N}"; sleep 1 ;;
  esac
done
