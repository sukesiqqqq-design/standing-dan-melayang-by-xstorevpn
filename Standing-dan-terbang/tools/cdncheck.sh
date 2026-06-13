#!/data/data/com.termux/files/usr/bin/bash
# =====================================================================
#  cdncheck - Deteksi CDN + versi TLS + cek port 80/443 (paralel)
#  ---  mod by xstorevpn  ---
# ---------------------------------------------------------------------
#  Untuk tiap domain (DIKERJAKAN PARALEL biar cepat):
#    - cek port 80 & 443 terbuka/tidak (TCP connect)
#    - kalau 443 open: 1x koneksi openssl -> ambil CDN + versi TLS
#  Butuh: openssl (openssl-tool), dnsutils (dig) utk fallback CNAME.
#
#  TAHAN OOM / signal 9:
#    Daftar besar sering bikin Android membunuh proses (signal 9).
#    Script ini memakai arsitektur SUPERVISOR + WORKER:
#      - WORKER  : melakukan scan (berat) -> bisa saja dibunuh Android.
#      - SUPERVISOR (ringan): otomatis menjalankan ulang worker dan
#        MELANJUTKAN (resume) dari hasil yang sudah ada, sampai tuntas.
#    Hasil ditulis bertahap, jadi tidak ada yang hilang saat terputus.
#
#  Pemakaian:
#     cdncheck <file_domains.txt> [jumlah_paralel] [fresh|resume]
#     cdncheck domains.txt            # default 5 paralel, resume
#     cdncheck domains.txt 8          # 8 paralel
#     cdncheck domains.txt 5 fresh    # ulang dari awal (hapus hasil lama)
# =====================================================================

G="\033[1;32m"; Y="\033[1;33m"; R="\033[1;31m"; C="\033[1;36m"; B="\033[1;34m"; N="\033[0m"

INPUT="$1"
JOBS="${2:-5}"          # default diturunkan -> lebih aman dari OOM di HP RAM kecil
MODE="${3:-resume}"     # resume = lanjutkan yang belum discan; fresh = ulang dari awal
MAX_ROUNDS="${CDN_MAX_ROUNDS:-30}"   # batas putaran auto-resume (jaga2 loop)

if [ -z "$INPUT" ] || [ ! -f "$INPUT" ]; then
  echo -e "${Y}Pemakaian:${N} cdncheck <file_domains.txt> [jumlah_paralel] [fresh|resume]"
  exit 1
fi
if ! command -v openssl >/dev/null 2>&1; then
  echo -e "${R}[!] openssl tidak ada. Pasang dulu: pkg install openssl-tool -y${N}"
  exit 1
fi

# Path output (dipakai supervisor & worker)
OUTDIR="$(dirname "$INPUT")"
BASE="$(basename "$INPUT" .txt)"
CF="$OUTDIR/${BASE}_cloudflare.txt"
CFRONT="$OUTDIR/${BASE}_cloudfront.txt"
ORIGIN="$OUTDIR/${BASE}_origin.txt"
ALL="$OUTDIR/${BASE}_cdn_tls.txt"          # domain | CDN | TLS | 80 | 443
export CF CFRONT ORIGIN ALL

# Hitung berapa domain yang BELUM diproses (untuk resume)
pending_count() {
  local done pend
  done="$(cut -d'|' -f1 "$ALL" 2>/dev/null | tr -d ' ' | sed '/^$/d' | sort -u)"
  pend="$(grep -vE '^[[:space:]]*$' "$INPUT" | tr -d ' ' | sort -u | comm -23 - <(printf '%s\n' "$done"))"
  printf '%s\n' "$pend" | grep -cve '^[[:space:]]*$'
}

# =====================================================================
#  WORKER  (dipanggil oleh supervisor; melakukan 1x lewatan scan)
# =====================================================================
if [ "$_CDN_WORKER" = "1" ]; then
  command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock

  DONE="$(mktemp)"; PENDING="$(mktemp)"
  trap 'rm -f "$DONE" "$PENDING"' EXIT
  cut -d'|' -f1 "$ALL" 2>/dev/null | tr -d ' ' | sed '/^$/d' | sort -u > "$DONE"
  grep -vE '^[[:space:]]*$' "$INPUT" | tr -d ' ' | sort -u | comm -23 - "$DONE" > "$PENDING"

  scan_one() {
    local d tls cdn label p80 p443 resp cname
    d="$(printf '%s' "$1" | tr -d '[:space:]')"
    [ -z "$d" ] && return

    if timeout 3 bash -c ">/dev/tcp/$d/443" 2>/dev/null; then p443="open"; else p443="closed"; fi
    if timeout 3 bash -c ">/dev/tcp/$d/80"  2>/dev/null; then p80="open";  else p80="closed";  fi

    tls="-"; cdn=""
    if [ "$p443" = "open" ]; then
      resp="$(printf 'HEAD / HTTP/1.1\r\nHost: %s\r\nUser-Agent: Mozilla/5.0\r\nAccept: */*\r\nConnection: close\r\n\r\n' "$d" \
              | timeout 8 openssl s_client -connect "${d}:443" -servername "$d" -ign_eof 2>/dev/null)"
      tls="$(echo "$resp" | grep -m1 -E '^[[:space:]]*Protocol[[:space:]]*:' | sed -E 's/.*:[[:space:]]*//')"
      [ -z "$tls" ] && tls="$(echo "$resp" | grep -m1 -oE 'TLSv[0-9.]+')"
      if [ -n "$tls" ]; then tls="$(echo "$tls" | sed -E 's/TLSv/TLS/')"; else tls="-"; fi
      if echo "$resp" | grep -qiE '^server:[[:space:]]*cloudflare|^cf-ray:'; then cdn="cloudflare"
      elif echo "$resp" | grep -qiE 'x-amz-cf-id|x-amz-cf-pop|^via:.*cloudfront'; then cdn="cloudfront"; fi
    fi
    if [ -z "$cdn" ] && command -v dig >/dev/null 2>&1; then
      cname="$(dig +short CNAME "$d" 2>/dev/null)"
      if echo "$cname" | grep -qi 'cloudfront\.net'; then cdn="cloudfront"
      elif echo "$cname" | grep -qi 'cloudflare'; then cdn="cloudflare"; fi
    fi
    case "$cdn" in
      cloudflare) label="Cloudflare" ;;
      cloudfront) label="CloudFront (AWS)" ;;
      *)          label="Origin/Lainnya" ;;
    esac

    # tulis langsung (append baris pendek = atomik) supaya hasil parsial aman bila terputus
    printf '%s | %s | %s | 80:%s | 443:%s\n' "$d" "$label" "$tls" "$p80" "$p443" >> "$ALL"
    case "$label" in
      Cloudflare)          echo "$d" >> "$CF" ;;
      "CloudFront (AWS)")  echo "$d" >> "$CFRONT" ;;
      *)                   echo "$d" >> "$ORIGIN" ;;
    esac
    printf '  %-34s %-16s TLS=%-7s 80=%-6s 443=%s\n' "$d" "$label" "$tls" "$p80" "$p443"
  }
  export -f scan_one

  xargs -P "$JOBS" -I{} bash -c 'scan_one "$@"' _ {} < "$PENDING"
  exit 0
fi

# =====================================================================
#  SUPERVISOR  (proses utama, ringan -> selamat dari OOM kill worker)
# =====================================================================
command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock
trap 'command -v termux-wake-unlock >/dev/null 2>&1 && termux-wake-unlock' EXIT INT TERM

if [ "$MODE" = "fresh" ]; then : > "$CF"; : > "$CFRONT"; : > "$ORIGIN"; : > "$ALL"; fi
touch "$CF" "$CFRONT" "$ORIGIN" "$ALL"

TOTAL="$(grep -cve '^[[:space:]]*$' "$INPUT")"
REMAIN="$(pending_count)"
DONEN=$(( TOTAL - REMAIN )); [ "$DONEN" -lt 0 ] && DONEN=0
echo -e "${C}[*] Total $TOTAL domain | sudah: $DONEN | akan discan: $REMAIN | paralel: $JOBS${N}"
[ "$DONEN" -gt 0 ] && echo -e "${Y}[i] Resume: lanjut dari hasil sebelumnya (arg ke-3 'fresh' utk ulang dari awal).${N}"
echo -e "${Y}[i] Mode tahan-OOM: jika terputus (signal 9), scan otomatis dilanjutkan.${N}"
printf "${B}  %-34s %-16s %-11s %-9s %s${N}\n" "DOMAIN" "CDN" "TLS" "PORT80" "PORT443"
echo -e "${B}-----------------------------------------------------------------------------------${N}"

ROUND=0; PREV_REMAIN=-1
SELF="$0"
while :; do
  REMAIN="$(pending_count)"
  [ "${REMAIN:-0}" -le 0 ] && break
  ROUND=$((ROUND+1))
  if [ "$ROUND" -gt "$MAX_ROUNDS" ]; then
    echo -e "${Y}[!] Mencapai batas $MAX_ROUNDS putaran, masih sisa $REMAIN domain. Jalankan lagi untuk melanjutkan.${N}"
    break
  fi
  # Jika tidak ada kemajuan sama sekali pada putaran sebelumnya -> hentikan (hindari loop tak berujung)
  if [ "$ROUND" -gt 1 ] && [ "$REMAIN" -eq "$PREV_REMAIN" ]; then
    echo -e "${Y}[!] Tidak ada kemajuan pada putaran terakhir (sisa $REMAIN). Berhenti.${N}"
    break
  fi
  [ "$ROUND" -gt 1 ] && echo -e "${Y}[~] Scan terputus/berlanjut - putaran resume ke-$ROUND (sisa $REMAIN)...${N}"
  PREV_REMAIN="$REMAIN"

  # Jalankan worker sebagai anak. Bila worker di-kill (signal 9), supervisor tetap hidup.
  _CDN_WORKER=1 JOBS="$JOBS" bash "$SELF" "$INPUT" "$JOBS" resume
done

# --- rapikan hasil (urut + buang duplikat) ---
for ff in "$CF" "$CFRONT" "$ORIGIN" "$ALL"; do
  [ -f "$ff" ] && sort -u -o "$ff" "$ff"
done

# --- ringkasan ---
op443="$(grep -c '443:open' "$ALL" 2>/dev/null)"
op80="$(grep -c '80:open' "$ALL" 2>/dev/null)"
echo ""
echo -e "${G}===================================================================================${N}"
echo -e "${G} RINGKASAN${N}"
echo -e "  ${B}Cloudflare${N}        : $(wc -l < "$CF" | tr -d ' ')  -> $CF"
echo -e "  ${C}CloudFront (AWS)${N}  : $(wc -l < "$CFRONT" | tr -d ' ')  -> $CFRONT"
echo -e "  ${G}Origin / lainnya${N}  : $(wc -l < "$ORIGIN" | tr -d ' ')  -> $ORIGIN"
echo -e "  Port 80 open      : ${op80:-0}    Port 443 open : ${op443:-0}"
echo -e "  Tabel CDN+TLS+port: $ALL"
echo -e "${G}===================================================================================${N}"

cp "$CF" "$CFRONT" "$ORIGIN" "$ALL" /sdcard/Download/ 2>/dev/null \
  && echo -e "${C}[*] Hasil disalin juga ke /sdcard/Download/${N}"
