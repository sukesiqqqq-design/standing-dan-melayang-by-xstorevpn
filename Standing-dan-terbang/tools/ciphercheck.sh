#!/bin/bash

FILE="${1:-}"
JOBS="${2:-3}"

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
  echo -e "Pemakaian: ciphercheck <file_domains.txt> [jumlah_paralel]"
  exit 1
fi

OUTDIR="$(dirname "$FILE")"
BASE="$(basename "$FILE" .txt)"
OUT="$OUTDIR/${BASE}_cipher_lengkap.csv"
CONNECT_TIMEOUT=3
MAX_TIME=8
TLS_TIMEOUT=8
UA="Mozilla/5.0"

echo "domain,status_code,final_url,ip,time_total,server,cdn_detected,tls_version,cipher_suite,keterangan,error" > "$OUT"

clean_domain() {
  raw="$1"

  raw=$(echo "$raw" | tr -d '\r')
  raw=$(echo "$raw" | cut -d'|' -f1)
  raw=$(echo "$raw" | awk '{print $1}')
  raw=$(echo "$raw" | sed 's#^[a-zA-Z][a-zA-Z0-9+.-]*://##')
  raw=$(echo "$raw" | sed 's#/*$##')
  raw=$(echo "$raw" | sed -E 's/^[0-9]+([A-Za-z])/\1/')
  raw=$(echo "$raw" | tr '[:upper:]' '[:lower:]')
  raw=$(echo "$raw" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  echo "$raw"
}

valid_domain() {
  d="$1"
  echo "$d" | grep -Eq '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$'
}

safe_csv() {
  echo "$1" | tr ',' ' ' | tr -d '\r' | tr '\n' ' ' | cut -c1-120
}

detect_cdn() {
  text=$(echo "$1" | tr '[:upper:]' '[:lower:]')

  if echo "$text" | grep -q "cloudflare\|cf-ray\|cf-cache-status"; then
    echo "Cloudflare"
  elif echo "$text" | grep -q "cloudfront\|x-amz-cf\|amazon"; then
    echo "Amazon CloudFront"
  elif echo "$text" | grep -q "akamai\|akamaighost\|edgesuite\|edgekey"; then
    echo "Akamai"
  elif echo "$text" | grep -q "fastly\|x-served-by"; then
    echo "Fastly"
  elif echo "$text" | grep -q "gcore\|gcdn"; then
    echo "Gcore"
  elif echo "$text" | grep -q "vercel\|x-vercel"; then
    echo "Vercel"
  elif echo "$text" | grep -q "netlify\|x-nf-request-id"; then
    echo "Netlify"
  elif echo "$text" | grep -q "google\|gws\|ghs\|sffe"; then
    echo "Google"
  elif echo "$text" | grep -q "nginx"; then
    echo "Nginx/server"
  elif echo "$text" | grep -q "apisix"; then
    echo "APISIX/gateway"
  elif echo "$text" | grep -q "openresty"; then
    echo "OpenResty/server"
  elif echo "$text" | grep -q "zoom"; then
    echo "Zoom/server"
  else
    echo "-"
  fi
}

check_one() {
  d="$1"

  h=$(mktemp)
  e=$(mktemp)

  meta=$(curl -k -L \
    --connect-timeout "$CONNECT_TIMEOUT" \
    --max-time "$MAX_TIME" \
    -A "$UA" \
    -sS \
    -o /dev/null \
    -D "$h" \
    -w "%{http_code}|%{url_effective}|%{remote_ip}|%{time_total}" \
    "https://$d" 2>"$e")

  IFS='|' read -r status final ip total <<< "$meta"

  headers=$(cat "$h" | tr -d '\r')
  server=$(echo "$headers" | awk -F': ' 'tolower($1)=="server"{s=$2} END{print s}')
  curl_error=$(cat "$e" | tr -d '\r' | tr '\n' ' ')

  rm -f "$h" "$e"

  tls_info=$(echo | timeout "$TLS_TIMEOUT" openssl s_client -connect "$d:443" -servername "$d" -brief 2>&1)

  tls_ip=$(echo "$tls_info" | awk '/^Connecting to / {print $3; exit}')
  tls=$(echo "$tls_info" | grep -i "Protocol version:" | head -1 | cut -d':' -f2- | xargs)
  cipher=$(echo "$tls_info" | grep -i "Ciphersuite:" | head -1 | cut -d':' -f2- | xargs)

  tls_error="-"
  if [ -z "$cipher" ]; then
    if echo "$tls_info" | grep -qi "No address associated with hostname"; then
      tls_error="DNS gagal / hostname tidak resolve"
    elif echo "$tls_info" | grep -qi "Connection refused"; then
      tls_error="Port 443 menolak koneksi"
    elif echo "$tls_info" | grep -qi "timed out\|timeout"; then
      tls_error="Timeout"
    elif echo "$tls_info" | grep -qi "handshake failure"; then
      tls_error="TLS handshake gagal"
    elif echo "$tls_info" | grep -qi "connect"; then
      tls_error="Koneksi gagal"
    else
      tls_error="-"
    fi
  fi

  [ -z "$status" ] && status="000"
  [ -z "$final" ] && final="https://$d/"
  [ -z "$ip" ] && ip="$tls_ip"
  [ -z "$ip" ] && ip="-"
  [ -z "$total" ] && total="0"
  [ -z "$server" ] && server="-"
  [ -z "$tls" ] && tls="-"
  [ -z "$cipher" ] && cipher="-"

  cdn=$(detect_cdn "$headers $server")

  ket="GAGAL"
  err="-"

  if [ "$status" != "000" ]; then
    ket="WEB_AKTIF"
    err="-"
  elif [ "$cipher" != "-" ]; then
    ket="TLS_AKTIF_HTTP_000"
    err="-"
  elif [ "$tls_error" != "-" ]; then
    ket="GAGAL"
    err="$tls_error"
  elif [ -n "$curl_error" ]; then
    ket="GAGAL"
    err="$curl_error"
  fi

  server=$(safe_csv "$server")
  cdn=$(safe_csv "$cdn")
  err=$(safe_csv "$err")

  echo "$d,$status,$final,$ip,$total,$server,$cdn,$tls,$cipher,$ket,$err"
}

export -f check_one
export -f detect_cdn
export -f safe_csv
export CONNECT_TIMEOUT MAX_TIME TLS_TIMEOUT UA

TMP=$(mktemp)

while IFS= read -r line; do
  d=$(clean_domain "$line")
  if valid_domain "$d"; then
    echo "$d"
  fi
done < "$FILE" | sort -u > "$TMP"

cat "$TMP" | xargs -n1 -P "$JOBS" bash -c 'check_one "$1"' _ | tee -a "$OUT"

echo
echo "================ RINGKASAN HASIL ================"
awk -F',' '
NR==1 {next}
{
  printf "%-40s | %-4s | %-10s | %-8s | %-20s\n", $1, $2, $8, $9, $10
}' "$OUT"
echo "================================================="

rm -f "$TMP"

echo "Selesai."
echo "Hasil: $OUT"
