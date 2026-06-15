#!/data/data/com.termux/files/usr/bin/bash
# =====================================================================
#  domainfinder v2 - Cari domain & host/SNI dari APK/APKS/XAPK/APKM
# ---------------------------------------------------------------------
#  - Input .apks/.xapk/.apkm  -> merge dulu jadi .apk (ApkPatcher -m)
#  - Tiap APK diproses di folder TERPISAH (anti-tercampur)
#  - Menangkap: domain dari URL  +  host/SNI tanpa prefix http
#  - Filter pintar untuk membuang nama package Java (com.xxx, dll)
#  - Output: <nama>_domains.txt (domain/host) & <nama>_urls.txt (URL lengkap)
#
#  Pemakaian:
#     domainfinder <file.apk | file.apks | file.xapk | file.apkm>
# =====================================================================

G="\033[1;32m"; Y="\033[1;33m"; R="\033[1;31m"; C="\033[1;36m"; N="\033[0m"

# --- 1. Cek argumen ---
if [ -z "$1" ]; then
  echo -e "${Y}Pemakaian:${N} domainfinder <file.apk|apks|xapk|apkm>"
  exit 1
fi
INPUT="$1"
[ -f "$INPUT" ] || { echo -e "${R}[!] File tidak ditemukan:${N} $INPUT"; exit 1; }

# --- 2. Ambil nama & ekstensi ---
BASENAME="$(basename "$INPUT")"
NAME="${BASENAME%.*}"
EXT="$(echo "${BASENAME##*.}" | tr 'A-Z' 'a-z')"
OUTDIR="$HOME/domainfinder"; WORKDIR="$OUTDIR/$NAME"; EXTRACT="$WORKDIR/extracted"

# --- 3. Bersihkan folder lama (anti-tercampur) ---
rm -rf "$WORKDIR"; mkdir -p "$EXTRACT"

# --- 4. Tentukan APK (merge dulu kalau split) ---
APK=""
case "$EXT" in
  apk) APK="$INPUT" ;;
  apks|xapk|apkm)
    echo -e "${C}[*] Format split (.$EXT) -> merge dulu jadi APK...${N}"
    ApkPatcher -m "$INPUT"
    APK="${INPUT%.*}.apk"
    [ -f "$APK" ] || { echo -e "${R}[!] Gagal merge / hasil tak ditemukan:${N} $APK"; exit 1; }
    echo -e "${G}[+] Hasil merge:${N} $APK" ;;
  *) echo -e "${R}[!] Format tidak didukung: .$EXT${N} (hanya apk/apks/xapk/apkm)"; exit 1 ;;
esac

# --- 5. Ekstrak APK ---
echo -e "${C}[*] Mengekstrak APK...${N}"
unzip -o -q "$APK" -d "$EXTRACT"

URLS="$OUTDIR/${NAME}_urls.txt"
DOMAINS="$OUTDIR/${NAME}_domains.txt"

# --- 6a. Kumpulkan URL lengkap (dengan path) ---
echo -e "${C}[*] Mengumpulkan URL lengkap...${N}"
grep -raohE 'https?://[a-zA-Z0-9._~:/?#@!&=+,;%-]+' "$EXTRACT" 2>/dev/null | sort -u > "$URLS"

# --- 6b. Kumpulkan domain (dari URL) + host/SNI (tanpa prefix http) ---
echo -e "${C}[*] Mengumpulkan domain + host/SNI (filter ketat)...${N}"
{
  # Domain yang muncul sebagai URL (http/https/ws/wss) -> paling pasti endpoint
  grep -raohE '(https?|wss?)://[a-zA-Z0-9.-]+' "$EXTRACT" 2>/dev/null | sed -E 's#^[a-z]+://##'

  # Host/SNI polos tanpa http:// -> HANYA huruf kecil (hostname asli selalu lowercase;
  # nama kelas kode pakai CamelCase spt AJAX.NET / BlockNote.Net jadi otomatis terbuang)
  grep -raohE '\b([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}\b' "$EXTRACT" 2>/dev/null
} \
  | grep -E '^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$' \
  | grep -E '\.(com|net|org|io|id|co|app|info|biz|tv|me|cloud|dev|xyz|asia|site|online|gov|edu|mobi|pro|in|us|uk|sg|my|jp|nl|de|tech|store|shop|live|ai|gg)$' \
  | grep -vE '^(com|org|net|io|java|javax|kotlin|kotlinx|android|androidx|dalvik|sun|jdk|junit|okhttp3|okio|retrofit2|rx|reactivex|gms|google|firebase|crashlytics|annotation|internal|graphics|widget|util|layout|material|drawable|databinding|coroutines)\.' \
  | grep -vE '\.(internal|preferences|prototype|bytelength|tenant|databinding|companion|impl|buildconfig|config|serializer|advertising|installation)\.' \
  | sort -u > "$DOMAINS"

COUNT="$(wc -l < "$DOMAINS" | tr -d ' ')"
UCOUNT="$(wc -l < "$URLS" | tr -d ' ')"

# --- 7. Tampilkan & salin hasil ---
echo ""
echo -e "${G}==================================================${N}"
echo -e "${G} Selesai untuk: ${N}$NAME"
echo -e "  Domain/Host unik : ${C}$COUNT${N}"
echo -e "  URL lengkap      : ${C}$UCOUNT${N}"
echo -e "${G}==================================================${N}"
cat "$DOMAINS"

mkdir -p /sdcard/sttxstore 2>/dev/null
cp "$DOMAINS" "$URLS" /sdcard/sttxstore/ 2>/dev/null \
  && echo -e "\n${C}[*] Hasil disalin juga ke /sdcard/sttxstore/ (${NAME}_domains.txt & ${NAME}_urls.txt)${N}"
