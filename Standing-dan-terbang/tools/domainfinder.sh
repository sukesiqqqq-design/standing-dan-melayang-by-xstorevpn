#!/data/data/com.termux/files/usr/bin/bash
# =====================================================================
#  domainfinder v3 - Cari domain & host/SNI dari APK/APKS/XAPK/APKM
#  ---  mod by xstorevpn  ---
# ---------------------------------------------------------------------
#  Ekstraksi LEBIH DALAM untuk menjaring domain sebanyak mungkin:
#    1) unzip APK mentah          -> grep semua file
#    2) apktool decode resource   -> AndroidManifest, network_security_config,
#                                    res/values (strings.xml), assets (domain
#                                    yang tersembunyi di resource biner arsc)
#    3) strings pada file biner   -> classes*.dex, *.so, resources.arsc
#                                    (menangkap domain yang di-embed di kode)
#  + daftar TLD diperluas (ccTLD + gTLD populer) -> lebih banyak host kena.
#
#  Output: <nama>_domains.txt (domain/host) & <nama>_urls.txt (URL lengkap)
#  Hasil juga disalin ke:  /sdcard/sttxstore/
#
#  Pemakaian:
#     domainfinder <file.apk | file.apks | file.xapk | file.apkm>
# =====================================================================

G="\033[1;32m"; Y="\033[1;33m"; R="\033[1;31m"; C="\033[1;36m"; B="\033[1;34m"; N="\033[0m"

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
OUTDIR="$HOME/domainfinder"; WORKDIR="$OUTDIR/$NAME"
EXTRACT="$WORKDIR/extracted"; DECODED="$WORKDIR/decoded"
SDCARD_OUT="/sdcard/sttxstore"
mkdir -p "$SDCARD_OUT" 2>/dev/null

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

# --- 5a. Ekstrak APK (unzip mentah) ---
echo -e "${C}[*] Mengekstrak APK (unzip)...${N}"
unzip -o -q "$APK" -d "$EXTRACT"

# --- 5b. Decode resource via apktool (lebih dalam, tanpa smali biar cepat) ---
if command -v apktool >/dev/null 2>&1; then
  echo -e "${C}[*] Decode resource via apktool (network_security_config, strings.xml, arsc)...${N}"
  if timeout 360 apktool d -s -f -o "$DECODED" "$APK" >/dev/null 2>&1; then
    echo -e "${G}[+] apktool decode selesai${N}"
  else
    echo -e "${Y}[!] apktool dilewati (gagal/timeout) - lanjut pakai sumber lain${N}"
  fi
else
  echo -e "${Y}[!] apktool tidak ada - decode resource dilewati.${N}"
  echo -e "${Y}    (Domain di XML/arsc tetap dijaring via 'strings'. Untuk hasil maksimal${N}"
  echo -e "${Y}     pasang apktool: bash ~/standing-dan-melayang-by-xstorevpn/Standing-dan-terbang/install.sh)${N}"
fi

URLS="$OUTDIR/${NAME}_urls.txt"
DOMAINS="$OUTDIR/${NAME}_domains.txt"
RAW="$WORKDIR/_raw_hosts.txt"
: > "$URLS"; : > "$RAW"

# Folder yang akan di-scan
SCAN_DIRS=("$EXTRACT")
[ -d "$DECODED" ] && SCAN_DIRS+=("$DECODED")

# Regex (label dibatasi {0,61} -> hindari backtracking lambat pada data biner)
URL_RE='https?://[a-zA-Z0-9._~:/?#@!&=+,;%-]+'
SCHEME_HOST_RE='(https?|wss?|ftp)://[a-zA-Z0-9.-]+'
HOST_RE='([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}'

# --- 6a. Baca SEMUA file SEKALI via 'strings' -> kumpulan teks (CORPUS) ---
#  Jauh lebih cepat daripada grep berulang di atas file biner besar (multidex/.so).
#  'strings' juga menambang string pool dari dex/.so/.arsc/AXML biner.
CORPUS="$WORKDIR/_corpus.txt"; : > "$CORPUS"
echo -e "${C}[*] Membaca isi file (strings, sekali jalan)...${N}"
if command -v strings >/dev/null 2>&1; then
  find "${SCAN_DIRS[@]}" -type f \
       ! -name '*.png' ! -name '*.jpg' ! -name '*.jpeg' ! -name '*.webp' \
       ! -name '*.gif' ! -name '*.ttf' ! -name '*.otf' ! -name '*.mp3' \
       ! -name '*.mp4' ! -name '*.ogg' ! -name '*.woff*' -print0 2>/dev/null \
    | xargs -0 -r strings -n 4 2>/dev/null > "$CORPUS"
fi
# Fallback bila strings tidak ada / hasil kosong: baca langsung
[ -s "$CORPUS" ] || find "${SCAN_DIRS[@]}" -type f -print0 2>/dev/null | xargs -0 -r cat 2>/dev/null > "$CORPUS"

# --- 6b. Ekstrak URL + domain/host dari CORPUS (grep di teks = cepat) ---
echo -e "${C}[*] Mengekstrak URL + domain/host...${N}"
LC_ALL=C grep -aoE "$URL_RE" "$CORPUS" 2>/dev/null | sort -u > "$URLS"
{
  LC_ALL=C grep -aoE "$SCHEME_HOST_RE" "$CORPUS" 2>/dev/null | sed -E 's#^[A-Za-z]+://##'
  LC_ALL=C grep -aoE "$HOST_RE"        "$CORPUS" 2>/dev/null
} > "$RAW"

# --- 6c. Filter pintar -> domain valid, buang nama package Java ---
echo -e "${C}[*] Memfilter (buang nama package, simpan domain asli)...${N}"
# Daftar TLD diperluas: gTLD umum + banyak ccTLD (terutama Asia/ID).
TLD='com|net|org|io|id|co|app|info|biz|tv|me|cloud|dev|xyz|asia|site|online|gov|edu|mobi|pro|tech|store|shop|live|ai|gg|space|website|host|link|click|fun|icu|vip|top|world|news|media|stream|in|us|uk|sg|my|jp|nl|de|fr|it|es|ca|au|eu|cc|to|ws|fm|sh|st|im|ovh|kr|th|vn|ph|hk|tw|pk|bd|np|kh|la|mm|tr|za|ng|ke|ae|sa|ir|ua|pl|cz|ro|gr|pt|se|no|fi|dk|ch|at|be|hu|sk|ru|br|cn|mx|ar|cl|pe'

LC_ALL=C tr 'A-Z' 'a-z' < "$RAW" \
  | sed -E 's/[.]+$//; s/^[.]+//' \
  | grep -E "^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+($TLD)\$" \
  | awk -F. '(length($(NF-1)) >= 2 && $(NF-1) ~ /[a-z]/)' \
  | grep -vE '^(com|org|net|io|java|javax|kotlin|kotlinx|android|androidx|dalvik|sun|jdk|junit|okhttp3|okio|retrofit2|rx|reactivex|gms|google|firebase|crashlytics|annotation|internal|graphics|widget|util|layout|material|drawable|databinding|coroutines|dagger|hilt|aspectj|objectweb|xmlpull|fasterxml|bytebuddy|jetbrains|intellij|squareup|bumptech)\.' \
  | grep -vE '\.(internal|preferences|prototype|bytelength|tenant|databinding|companion|impl|buildconfig|config|serializer|advertising|installation|provider|receiver|service|activity|fragment|adapter|viewmodel|listener|callback|exception|factory|builder|manager|helper|module|component)$' \
  | sort -u > "$DOMAINS"

COUNT="$(wc -l < "$DOMAINS" | tr -d ' ')"
sort -u -o "$URLS" "$URLS"
UCOUNT="$(wc -l < "$URLS" | tr -d ' ')"

# Bersihkan file sementara besar (corpus/raw) supaya tidak makan storage
rm -f "$CORPUS" "$RAW" 2>/dev/null

# --- 7. Tampilkan & salin hasil ---
echo ""
echo -e "${G}==================================================${N}"
echo -e "${G} Selesai untuk: ${N}$NAME"
echo -e "  Domain/Host unik : ${C}$COUNT${N}"
echo -e "  URL lengkap      : ${C}$UCOUNT${N}"
echo -e "${G}==================================================${N}"
cat "$DOMAINS"

if cp "$DOMAINS" "$URLS" "$SDCARD_OUT/" 2>/dev/null; then
  echo -e "\n${C}[*] Hasil disalin ke ${SDCARD_OUT}/ (${NAME}_domains.txt & ${NAME}_urls.txt)${N}"
else
  echo -e "\n${Y}[!] Tidak bisa menyalin ke ${SDCARD_OUT}/ (jalankan: termux-setup-storage)${N}"
fi
