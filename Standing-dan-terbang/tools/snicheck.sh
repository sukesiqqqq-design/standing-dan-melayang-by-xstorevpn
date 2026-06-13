#!/data/data/com.termux/files/usr/bin/bash
# =====================================================================
#  snicheck - Inspeksi TLS/SNI handshake & sertifikat
# ---------------------------------------------------------------------
#  Untuk tiap host: lakukan TLS handshake dengan SNI, tampilkan
#  versi TLS, cipher, status handshake, CN, SAN, issuer, & masa berlaku.
#  Butuh: openssl  ->  pkg install openssl-tool -y
#
#  Pemakaian:
#     snicheck <host>                 # satu host
#     snicheck <file.txt>             # banyak host (1 per baris)
#     snicheck <host|file> <port>     # port custom (default 443)
# =====================================================================

G="\033[1;32m"; Y="\033[1;33m"; R="\033[1;31m"; C="\033[1;36m"; B="\033[1;34m"; N="\033[0m"

INPUT="$1"
PORT="${2:-443}"
if [ -z "$INPUT" ]; then
  echo -e "${Y}Pemakaian:${N} snicheck <host|file.txt> [port]"
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo -e "${R}[!] openssl tidak ditemukan. Pasang dulu: pkg install openssl-tool -y${N}"
  exit 1
fi

# --- Tentukan sumber host: file atau argumen tunggal ---
if [ -f "$INPUT" ]; then
  SRC="$INPUT"; MODE="file"
  OUT="${INPUT%.txt}_sni.txt"
else
  SRC="$(mktemp)"; echo "$INPUT" > "$SRC"; MODE="single"
  mkdir -p "$HOME/STT-results"
  OUT="$HOME/STT-results/${INPUT}_sni.txt"
fi
: > "$OUT"

check_one() {
  local host="$1"
  host="$(echo "$host" | tr -d '[:space:]')"
  [ -z "$host" ] && return

  # Handshake TLS dengan SNI
  local raw
  raw="$(echo | timeout 12 openssl s_client -connect "${host}:${PORT}" -servername "$host" 2>/dev/null)"

  if [ -z "$raw" ] || ! echo "$raw" | grep -q "BEGIN CERTIFICATE"; then
    echo -e "${R}[GAGAL]${N} ${Y}$host${N} -> handshake gagal / tidak ada sertifikat"
    echo "[GAGAL] $host | handshake gagal" >> "$OUT"
    return
  fi

  # Versi TLS & cipher
  local proto cipher
  proto="$(echo "$raw" | grep -m1 -E 'Protocol\s*:' | sed -E 's/.*:[[:space:]]*//')"
  cipher="$(echo "$raw" | grep -m1 -E 'Cipher\s*:' | sed -E 's/.*:[[:space:]]*//')"

  # Ekstrak sertifikat & detailnya
  local cert subj issuer cn san notbefore notafter
  cert="$(echo "$raw" | sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p')"
  subj="$(echo "$cert"   | openssl x509 -noout -subject 2>/dev/null | sed -E 's/^subject=//')"
  issuer="$(echo "$cert" | openssl x509 -noout -issuer  2>/dev/null | sed -E 's/^issuer=//')"
  cn="$(echo "$subj" | grep -oE 'CN[[:space:]]*=[[:space:]]*[^,/]+' | sed -E 's/CN[[:space:]]*=[[:space:]]*//' | head -1)"
  san="$(echo "$cert" | openssl x509 -noout -ext subjectAltName 2>/dev/null | grep -i dns | sed -E 's/[[:space:]]*DNS://g; s/^[[:space:]]*//')"
  notbefore="$(echo "$cert" | openssl x509 -noout -startdate 2>/dev/null | sed -E 's/^notBefore=//')"
  notafter="$(echo "$cert"  | openssl x509 -noout -enddate   2>/dev/null | sed -E 's/^notAfter=//')"

  echo -e "${G}[OK]${N} ${C}$host${N}  ${B}${proto:-?} / ${cipher:-?}${N}"
  echo -e "      CN     : ${cn:-(none)}"
  echo -e "      Issuer : ${issuer:-(none)}"
  echo -e "      Valid  : ${notbefore:-?}  ->  ${notafter:-?}"
  [ -n "$san" ] && echo -e "      SAN    : $san"

  {
    echo "[OK] $host | ${proto} | ${cipher} | CN=${cn} | issuer=${issuer} | valid: ${notbefore} -> ${notafter}"
    [ -n "$san" ] && echo "      SAN: $san"
  } >> "$OUT"
}

echo -e "${C}[*] Mengecek SNI/TLS (port $PORT)...${N}\n"
while IFS= read -r line; do
  check_one "$line"
done < "$SRC"

[ "$MODE" = "single" ] && rm -f "$SRC"

echo ""
echo -e "${G}==================================================${N}"
echo -e "${G} Selesai. Hasil tersimpan di:${N} $OUT"
echo -e "${G}==================================================${N}"
cp "$OUT" /sdcard/Download/ 2>/dev/null && echo -e "${C}[*] Disalin juga ke /sdcard/Download/${N}"
