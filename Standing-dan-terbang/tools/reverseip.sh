#!/data/data/com.termux/files/usr/bin/bash
# =====================================================================
#  reverseip - Reverse IP lookup (cari domain/host satu server)
#  ---  mod by xstorevpn  ---
# ---------------------------------------------------------------------
#  Untuk tiap target (domain ATAU IP):
#    - Kalau domain  -> resolve dulu ke IP (pakai dig dari dnsutils).
#    - Reverse IP lookup -> cari semua domain/host lain di IP yang sama.
#  Sumber data:
#    1) HackerTarget  : https://api.hackertarget.com/reverseiplookup/?q=<IP>
#    2) RapidDNS      : https://rapiddns.io/sameip/<IP>   (cadangan/fallback)
#  Berguna untuk memperbanyak daftar host (analisis jaringan).
#
#  Butuh: curl, dan dig (dnsutils) untuk resolve domain -> IP.
#         pkg install dnsutils -y
#
#  Pemakaian:
#     reverseip <domain|IP>          # satu target
#     reverseip <file.txt>           # banyak target (1 per baris)
#
#  Hasil tampil di layar + disimpan ke:
#     ~/domainfinder/<nama>_reverseip.txt   (lalu disalin ke /sdcard/sttxstore/)
# =====================================================================

G="\033[1;32m"; Y="\033[1;33m"; R="\033[1;31m"; C="\033[1;36m"; B="\033[1;34m"; N="\033[0m"

INPUT="$1"
if [ -z "$INPUT" ]; then
  echo -e "${Y}Pemakaian:${N} reverseip <domain|IP|file.txt>"
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo -e "${R}[!] curl tidak ditemukan. Pasang dulu: pkg install curl -y${N}"
  exit 1
fi

OUTDIR="$HOME/domainfinder"
mkdir -p "$OUTDIR"

# --- Tentukan sumber target: file atau argumen tunggal ---
if [ -f "$INPUT" ]; then
  SRC="$INPUT"; MODE="file"
  NAME="$(basename "${INPUT%.txt}")"
else
  SRC="$(mktemp)"; echo "$INPUT" > "$SRC"; MODE="single"
  # Bersihkan nama agar aman dipakai sebagai nama file
  NAME="$(printf '%s' "$INPUT" | tr -c 'A-Za-z0-9._-' '_')"
fi
OUT="$OUTDIR/${NAME}_reverseip.txt"
: > "$OUT"

# Cek apakah string berupa IPv4
is_ipv4() {
  echo "$1" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'
}

# Resolve domain -> IP (dig diutamakan, fallback ke getent/python bila ada)
resolve_ip() {
  local host="$1" ip=""
  if command -v dig >/dev/null 2>&1; then
    ip="$(dig +short A "$host" 2>/dev/null | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' | head -1)"
  fi
  if [ -z "$ip" ] && command -v getent >/dev/null 2>&1; then
    ip="$(getent ahostsv4 "$host" 2>/dev/null | awk '{print $1}' | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' | head -1)"
  fi
  if [ -z "$ip" ] && command -v python >/dev/null 2>&1; then
    ip="$(python - "$host" 2>/dev/null <<'PY'
import socket, sys
try:
    print(socket.gethostbyname(sys.argv[1]))
except Exception:
    pass
PY
)"
  fi
  echo "$ip"
}

# Sumber 1: HackerTarget. Tulis host valid ke stdout, atau kosong bila gagal.
src_hackertarget() {
  local ip="$1" resp
  resp="$(curl -s --max-time 30 "https://api.hackertarget.com/reverseiplookup/?q=${ip}" 2>/dev/null)"
  [ -z "$resp" ] && return 1
  # Deteksi pesan error/limit dari API (bukan daftar host)
  if echo "$resp" | grep -qiE 'API count exceeded|error check your search parameter|too many requests'; then
    return 2
  fi
  if echo "$resp" | grep -qiE 'No DNS A records|no records found'; then
    return 3
  fi
  # Ambil hanya baris yang mirip hostname
  echo "$resp" | grep -oiE '([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}' \
    | grep -viE '\.(arpa)$' \
    | tr 'A-Z' 'a-z' | sort -u
  return 0
}

# Sumber 2 (fallback): RapidDNS. Parsing tabel HTML sederhana.
src_rapiddns() {
  local ip="$1" resp
  resp="$(curl -s --max-time 30 -A 'Mozilla/5.0' "https://rapiddns.io/sameip/${ip}?full=1" 2>/dev/null)"
  [ -z "$resp" ] && return 1
  echo "$resp" \
    | grep -oE '<td>[^<]+</td>' \
    | sed 's/<[^>]*>//g' \
    | grep -oiE '([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}' \
    | grep -viE '\.(arpa)$' \
    | tr 'A-Z' 'a-z' | sort -u
  return 0
}

GRAND_TOTAL=0

lookup_one() {
  local target ip hosts cnt rc
  target="$(echo "$1" | tr -d '[:space:]')"
  [ -z "$target" ] && return
  # buang skema/path bila user menempel URL
  target="$(echo "$target" | sed -E 's#^[a-zA-Z]+://##; s#/.*$##')"
  [ -z "$target" ] && return

  echo -e "${B}-----------------------------------------------------------${N}"
  if is_ipv4 "$target"; then
    ip="$target"
    echo -e "${C}[*] Target IP   :${N} $ip"
  else
    echo -e "${C}[*] Target host :${N} $target  ${Y}(resolve -> IP)${N}"
    ip="$(resolve_ip "$target")"
    if [ -z "$ip" ]; then
      echo -e "${R}[GAGAL]${N} Tidak bisa resolve $target ke IP."
      echo -e "        ${Y}(pastikan dnsutils terpasang: pkg install dnsutils -y)${N}"
      echo "[GAGAL] $target | resolve ke IP gagal" >> "$OUT"
      return
    fi
    echo -e "${C}[*] IP terpakai :${N} $ip"
  fi

  # --- Sumber 1: HackerTarget ---
  hosts="$(src_hackertarget "$ip")"; rc=$?
  case "$rc" in
    2) echo -e "${Y}[!] HackerTarget kena limit/error API. Mencoba sumber cadangan (RapidDNS)...${N}"
       hosts="$(src_rapiddns "$ip")" ;;
    3) echo -e "${Y}[i] HackerTarget: tidak ada record. Mencoba RapidDNS...${N}"
       hosts="$(src_rapiddns "$ip")" ;;
    1) echo -e "${Y}[!] HackerTarget tidak merespon. Mencoba sumber cadangan (RapidDNS)...${N}"
       hosts="$(src_rapiddns "$ip")" ;;
  esac

  hosts="$(printf '%s\n' "$hosts" | grep -vE '^[[:space:]]*$' | sort -u)"
  cnt="$(printf '%s\n' "$hosts" | grep -cvE '^[[:space:]]*$')"

  if [ -z "$hosts" ] || [ "$cnt" -eq 0 ]; then
    echo -e "${R}[KOSONG]${N} Tidak ada domain/host ditemukan untuk $ip."
    echo "# $target ($ip) -> 0 host" >> "$OUT"
    return
  fi

  echo -e "${G}[OK]${N} Ditemukan ${G}$cnt${N} host di IP ${C}$ip${N}:"
  printf '%s\n' "$hosts" | sed 's/^/      /'

  {
    echo "# $target ($ip) -> $cnt host"
    printf '%s\n' "$hosts"
  } >> "$OUT"
  GRAND_TOTAL=$(( GRAND_TOTAL + cnt ))
}

echo -e "${C}[*] Reverse IP lookup dimulai...${N}"
while IFS= read -r line; do
  lookup_one "$line"
done < "$SRC"

[ "$MODE" = "single" ] && rm -f "$SRC"

# Rapikan: kumpulan host unik (baris non-komentar) ditaruh juga di file terurut
# (tetap menyimpan baris header '# ...' sebagai pemisah konteks)
echo ""
echo -e "${G}===========================================================${N}"
echo -e "${G} Selesai. Total host terkumpul (termasuk duplikat antar-IP): ${C}$GRAND_TOTAL${N}"
echo -e "${G} Hasil tersimpan di:${N} $OUT"
echo -e "${G}===========================================================${N}"

mkdir -p /sdcard/sttxstore 2>/dev/null
cp "$OUT" /sdcard/sttxstore/ 2>/dev/null && echo -e "${C}[*] Disalin juga ke /sdcard/sttxstore/${N}"
