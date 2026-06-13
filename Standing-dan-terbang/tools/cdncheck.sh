#!/data/data/com.termux/files/usr/bin/bash
# =====================================================================
#  cdncheck - Deteksi CDN + versi TLS + cek port 80/443 (paralel)
# ---------------------------------------------------------------------
#  Untuk tiap domain (DIKERJAKAN PARALEL biar cepat):
#    - cek port 80 & 443 terbuka/tidak (TCP connect)
#    - kalau 443 open: 1x koneksi openssl -> ambil CDN + versi TLS
#  Butuh: openssl (openssl-tool), dnsutils (dig) utk fallback CNAME.
#
#  Pemakaian:
#     cdncheck <file_domains.txt> [jumlah_paralel]
#     cdncheck ~/domainfinder/myXL_9.2.0_domains.txt        # default 8 paralel
#     cdncheck domains.txt 15                                # 15 paralel
#  Catatan: script otomatis pasang termux-wake-lock agar tidak dibunuh Android
#           (signal 9) saat scan daftar besar. Hasil ditulis bertahap.
# =====================================================================

G="\033[1;32m"; Y="\033[1;33m"; R="\033[1;31m"; C="\033[1;36m"; B="\033[1;34m"; N="\033[0m"

INPUT="$1"
JOBS="${2:-8}"
MODE="${3:-resume}"     # resume = lanjutkan yang belum discan; fresh = ulang dari awal
if [ -z "$INPUT" ] || [ ! -f "$INPUT" ]; then
  echo -e "${Y}Pemakaian:${N} cdncheck <file_domains.txt> [jumlah_paralel]"
  exit 1
fi
if ! command -v openssl >/dev/null 2>&1; then
  echo -e "${R}[!] openssl tidak ada. Pasang dulu: pkg install openssl-tool -y${N}"
  exit 1
fi

# Cegah Android membunuh proses saat scan lama (signal 9)
command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock
trap 'command -v termux-wake-unlock >/dev/null 2>&1 && termux-wake-unlock' EXIT INT TERM

OUTDIR="$(dirname "$INPUT")"
BASE="$(basename "$INPUT" .txt)"
CF="$OUTDIR/${BASE}_cloudflare.txt"
CFRONT="$OUTDIR/${BASE}_cloudfront.txt"
ORIGIN="$OUTDIR/${BASE}_origin.txt"
ALL="$OUTDIR/${BASE}_cdn_tls.txt"          # domain | CDN | TLS | 80 | 443
export CF CFRONT ORIGIN ALL

# Mode fresh -> kosongkan; mode resume -> lanjutkan dari hasil sebelumnya
if [ "$MODE" = "fresh" ]; then : > "$CF"; : > "$CFRONT"; : > "$ORIGIN"; : > "$ALL"; fi
touch "$CF" "$CFRONT" "$ORIGIN" "$ALL"

# Daftar domain yang SUDAH diproses (untuk resume bila proses sempat dibunuh Android)
DONE="$(mktemp)"; PENDING="$(mktemp)"
cut -d'|' -f1 "$ALL" 2>/dev/null | tr -d ' ' | sed '/^$/d' | sort -u > "$DONE"
grep -vE '^[[:space:]]*$' "$INPUT" | tr -d ' ' | sort -u | comm -23 - "$DONE" > "$PENDING"

# ---------------------------------------------------------------------
#  Worker: proses 1 domain (dipanggil paralel oleh xargs)
# ---------------------------------------------------------------------
scan_one() {
  local d tls cdn label p80 p443 resp cname
  d="$(printf '%s' "$1" | tr -d '[:space:]')"
  [ -z "$d" ] && return

  # --- cek port (TCP connect, timeout 3s) ---
  if timeout 3 bash -c ">/dev/tcp/$d/443" 2>/dev/null; then p443="open"; else p443="closed"; fi
  if timeout 3 bash -c ">/dev/tcp/$d/80"  2>/dev/null; then p80="open";  else p80="closed";  fi

  tls="-"; cdn=""
  # --- CDN + TLS hanya kalau 443 terbuka ---
  if [ "$p443" = "open" ]; then
    resp="$(printf 'HEAD / HTTP/1.1\r\nHost: %s\r\nUser-Agent: Mozilla/5.0\r\nAccept: */*\r\nConnection: close\r\n\r\n' "$d" \
            | timeout 8 openssl s_client -connect "${d}:443" -servername "$d" -ign_eof 2>/dev/null)"
    tls="$(echo "$resp" | grep -m1 -E '^[[:space:]]*Protocol[[:space:]]*:' | sed -E 's/.*:[[:space:]]*//')"
    [ -z "$tls" ] && tls="$(echo "$resp" | grep -m1 -oE 'TLSv[0-9.]+')"
    if [ -n "$tls" ]; then tls="$(echo "$tls" | sed -E 's/TLSv/TLS/')"; else tls="-"; fi
    if echo "$resp" | grep -qiE '^server:[[:space:]]*cloudflare|^cf-ray:'; then cdn="cloudflare"
    elif echo "$resp" | grep -qiE 'x-amz-cf-id|x-amz-cf-pop|^via:.*cloudfront'; then cdn="cloudfront"; fi
  fi
  # --- fallback CNAME ---
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
    Cloudflare)         echo "$d" >> "$CF" ;;
    "CloudFront (AWS)")  echo "$d" >> "$CFRONT" ;;
    *)                  echo "$d" >> "$ORIGIN" ;;
  esac
  printf '  %-34s %-16s TLS=%-7s 80=%-6s 443=%s\n' "$d" "$label" "$tls" "$p80" "$p443"
}
export -f scan_one

TOTAL="$(grep -cve '^[[:space:]]*$' "$INPUT")"
REMAIN="$(grep -cve '^[[:space:]]*$' "$PENDING")"
DONEN="$(wc -l < "$DONE" | tr -d ' ')"
echo -e "${C}[*] Total $TOTAL domain | sudah: $DONEN | akan discan: $REMAIN | paralel: $JOBS${N}"
[ "${DONEN:-0}" -gt 0 ] && echo -e "${Y}[i] Resume: lanjut dari hasil sebelumnya (pakai arg ke-3 'fresh' utk ulang dari awal).${N}"
printf "${B}  %-34s %-16s %-11s %-9s %s${N}\n" "DOMAIN" "CDN" "TLS" "PORT80" "PORT443"
echo -e "${B}-----------------------------------------------------------------------------------${N}"

# --- jalankan paralel (HANYA domain yang belum diproses) ---
xargs -P "$JOBS" -I{} bash -c 'scan_one "$@"' _ {} < "$PENDING"
rm -f "$DONE" "$PENDING"

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
