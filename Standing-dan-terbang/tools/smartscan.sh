#!/data/data/com.termux/files/usr/bin/bash
# =====================================================================
#  smartscan - Orchestrator analisis lengkap (one-shot)   [mod by xstorevpn]
# ---------------------------------------------------------------------
#  Jalankan rangkaian analisis otomatis dari satu APK / daftar domain:
#     APK/APKS  -> domainfinder -> cdncheck (CDN+TLS+port)
#  Semua hasil dikumpulkan rapi + laporan ringkas di:
#     ~/STT-results/<nama>/
#
#  Pemakaian:
#     smartscan <file.apk|apks|xapk|apkm>     # mulai dari APK
#     smartscan <file_domains.txt>            # mulai dari daftar domain
# =====================================================================

G="\033[1;32m"; Y="\033[1;33m"; R="\033[1;31m"; C="\033[1;36m"; B="\033[1;34m"; M="\033[1;35m"; N="\033[0m"

INPUT="$1"
if [ -z "$INPUT" ] || [ ! -f "$INPUT" ]; then
  echo -e "${Y}Pemakaian:${N} smartscan <file.apk|apks|xapk|apkm | file_domains.txt>"
  exit 1
fi

BASENAME="$(basename "$INPUT")"
NAME="${BASENAME%.*}"
EXT="$(echo "${BASENAME##*.}" | tr 'A-Z' 'a-z')"
RESULT="$HOME/STT-results/$NAME"
mkdir -p "$RESULT"
REPORT="$RESULT/report.txt"
DOMAINS=""

# Cegah Android membunuh proses saat scan lama (signal 9)
command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock
trap 'command -v termux-wake-unlock >/dev/null 2>&1 && termux-wake-unlock' EXIT INT TERM

line() { echo -e "${M}========================================================${N}"; }
say()  { echo -e "${B}==>${N} ${C}$*${N}"; }

line
echo -e "${M}  SMART SCAN  -  $NAME${N}"
echo -e "${C}  mod by xstorevpn${N}"
line
echo "SMART SCAN REPORT - $NAME" > "$REPORT"
echo "Tanggal: $(date)" >> "$REPORT"
echo "Sumber : $INPUT" >> "$REPORT"
echo "========================================================" >> "$REPORT"

# --- TAHAP 1: Dapatkan daftar domain ---
case "$EXT" in
  txt)
    say "Input berupa daftar domain, lewati ekstraksi APK"
    DOMAINS="$RESULT/${NAME}_domains.txt"
    cp "$INPUT" "$DOMAINS"
    ;;
  apk|apks|xapk|apkm)
    if ! command -v domainfinder >/dev/null 2>&1; then
      echo -e "${R}[!] domainfinder tidak terpasang.${N}"; exit 1
    fi
    say "TAHAP 1/2 - Ekstraksi domain dari APK (domainfinder)"
    domainfinder "$INPUT"
    # domainfinder simpan hasil di ~/domainfinder/<nama>_domains.txt
    if [ -f "$HOME/domainfinder/${NAME}_domains.txt" ]; then
      DOMAINS="$RESULT/${NAME}_domains.txt"
      cp "$HOME/domainfinder/${NAME}_domains.txt" "$DOMAINS"
      cp "$HOME/domainfinder/${NAME}_urls.txt" "$RESULT/" 2>/dev/null
    fi
    ;;
  *)
    echo -e "${R}[!] Format tidak didukung: .$EXT${N}"; exit 1 ;;
esac

if [ -z "$DOMAINS" ] || [ ! -s "$DOMAINS" ]; then
  echo -e "${R}[!] Tidak ada domain ditemukan, berhenti.${N}"; exit 1
fi
DCOUNT="$(grep -cve '^[[:space:]]*$' "$DOMAINS")"
echo -e "${G}[+] $DCOUNT domain ditemukan${N}"
{ echo ""; echo "[1] DOMAIN DITEMUKAN: $DCOUNT"; echo "----------------------------"; cat "$DOMAINS"; } >> "$REPORT"

# --- TAHAP 2: Deteksi CDN + TLS ---
if command -v cdncheck >/dev/null 2>&1; then
  say "TAHAP 2/2 - Deteksi CDN + TLS + port 80/443 (cdncheck, paralel)"
  cdncheck "$DOMAINS"
  for k in cloudflare cloudfront origin cdn_tls; do
    src="${DOMAINS%.txt}_${k}.txt"
    [ -f "$src" ] && cp "$src" "$RESULT/" 2>/dev/null
  done
  ORIGIN="${DOMAINS%.txt}_origin.txt"
  {
    echo ""; echo "[2] HASIL CDN + TLS"; echo "----------------------------"
    echo "Cloudflare      : $(wc -l < "${DOMAINS%.txt}_cloudflare.txt" 2>/dev/null | tr -d ' ')"
    echo "CloudFront(AWS) : $(wc -l < "${DOMAINS%.txt}_cloudfront.txt" 2>/dev/null | tr -d ' ')"
    echo "Origin/lainnya  : $(wc -l < "$ORIGIN" 2>/dev/null | tr -d ' ')"
    echo ""
    echo "Tabel domain | CDN | TLS | port80 | port443:"
    cat "${DOMAINS%.txt}_cdn_tls.txt" 2>/dev/null
  } >> "$REPORT"
else
  echo -e "${Y}[!] cdncheck tidak ada, tahap CDN dilewati${N}"
  ORIGIN="$DOMAINS"
fi

# --- Selesai ---
line
echo -e "${G}  SMART SCAN SELESAI${N}"
line
echo -e " Semua hasil   : ${C}$RESULT/${N}"
echo -e " Laporan ringkas: ${C}$REPORT${N}"
echo -e " ${B}File domain terpisah:${N}"
[ -f "${DOMAINS%.txt}_cloudflare.txt" ] && echo -e "   - Cloudflare : ${C}${DOMAINS%.txt}_cloudflare.txt${N}"
[ -f "${DOMAINS%.txt}_cloudfront.txt" ] && echo -e "   - CloudFront : ${C}${DOMAINS%.txt}_cloudfront.txt${N}"
[ -f "${DOMAINS%.txt}_origin.txt" ]     && echo -e "   - Origin     : ${C}${DOMAINS%.txt}_origin.txt${N}"
[ -f "${DOMAINS%.txt}_cdn_tls.txt" ]    && echo -e "   - CDN+TLS+prt: ${C}${DOMAINS%.txt}_cdn_tls.txt${N}"
cp -r "$RESULT" /sdcard/Download/ 2>/dev/null && \
  echo -e " Disalin juga ke: ${C}/sdcard/Download/$NAME/${N}"
