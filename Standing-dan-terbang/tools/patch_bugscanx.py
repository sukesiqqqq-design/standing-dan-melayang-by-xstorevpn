#!/data/data/com.termux/files/usr/bin/env python
# -*- coding: utf-8 -*-
# =====================================================================
#  Standing & Terbang Toolkit - PATCH BugScanX subfinder (mode File)
#  ---  mod by xstorevpn  ---
# ---------------------------------------------------------------------
#  Mengubah perilaku BugScanX -> Subdomain Finder -> input "File":
#
#    SEBELUM : tiap baris di file dianggap domain apa adanya, lalu
#              dicari subdomain-nya (kalau isinya sudah subdomain,
#              hasilnya sering kosong karena mencari sub-sub-domain).
#
#    SESUDAH : semua entri diciutkan ke DOMAIN INDUK (root) yang unik
#              (mis. api.xl.co.id -> xl.co.id), lalu subdomain dicari
#              ULANG dari root tsb -> dapat lebih banyak subdomain.
#
#  Hanya mengubah cabang "File". Mode "Manual" TIDAK diubah.
#  Patch ini idempotent (aman dijalankan berulang) & otomatis
#  dipasang ulang oleh install.sh / update.sh setelah BugScanX
#  ter-(re)install.
#
#  Pemakaian:  python patch_bugscanx.py            (pasang patch)
#              python patch_bugscanx.py --revert    (kembalikan asli)
#              python patch_bugscanx.py --status     (cek status)
# =====================================================================
import sys

MARKER = "# [STT-PATCH]"

# --- Blok asli yang akan diganti (cabang File di main()) -------------
ORIGINAL_BLOCK = (
    "        file_path = get_input(\"Enter filename\", input_type=\"file\", validators=\"file\")\n"
    "        with open(file_path, 'r') as f:\n"
    "            domains = [d.strip() for d in f if DomainValidator.is_valid_domain(d.strip())]\n"
    "        default_output = f\"{file_path.rsplit('.', 1)[0]}_subdomains.txt\"\n"
)

# --- Blok pengganti: ciutkan ke root domain unik, lalu enumerasi ulang
PATCHED_BLOCK = (
    "        file_path = get_input(\"Enter filename\", input_type=\"file\", validators=\"file\")\n"
    "        " + MARKER + " ciutkan semua entri ke domain induk unik, lalu cari subdomain ulang\n"
    "        with open(file_path, 'r') as f:\n"
    "            raw_hosts = [line.strip() for line in f if line.strip()]\n"
    "        domains = []\n"
    "        _seen = set()\n"
    "        for _host in raw_hosts:\n"
    "            _root = _stt_root_domain(_host)\n"
    "            if _root and DomainValidator.is_valid_domain(_root) and _root not in _seen:\n"
    "                _seen.add(_root)\n"
    "                domains.append(_root)\n"
    "        default_output = f\"{file_path.rsplit('.', 1)[0]}_subdomains.txt\"\n"
)

# --- Helper root-domain yang disisipkan ke modul --------------------
HELPER_CODE = (
    "\n\n" + MARKER + " helper: ambil domain induk (root) dari sebuah host\n"
    "_STT_MULTI_SUFFIXES = {\n"
    "    'co.id','or.id','ac.id','go.id','sch.id','web.id','my.id','net.id','biz.id','mil.id','desa.id','ponpes.id',\n"
    "    'co.uk','org.uk','ac.uk','gov.uk','me.uk','com.au','net.au','org.au','co.jp','ne.jp','or.jp',\n"
    "    'com.br','co.in','com.sg','com.my','co.th','in.th','com.tr','com.cn','co.za','com.hk','co.kr',\n"
    "    'com.ph','com.vn','com.pk','co.ke','com.ng','com.bd','com.np','com.kh','com.la','com.mm',\n"
    "}\n\n"
    "def _stt_root_domain(host):\n"
    "    import re as _re\n"
    "    if not host:\n"
    "        return ''\n"
    "    host = host.strip().lower()\n"
    "    host = _re.sub(r'^[a-z][a-z0-9+.-]*://', '', host)  # buang skema http(s)://\n"
    "    host = host.split('/')[0].split('?')[0].split('#')[0]\n"
    "    host = host.split('@')[-1]                          # buang user:pass@\n"
    "    host = host.split(':')[0]                           # buang :port\n"
    "    host = host.strip('.')\n"
    "    if not host:\n"
    "        return ''\n"
    "    if _re.match(r'^\\d{1,3}(?:\\.\\d{1,3}){3}$', host):\n"
    "        return ''  # lewati IPv4, subfinder butuh domain\n"
    "    parts = host.split('.')\n"
    "    if len(parts) < 2:\n"
    "        return host\n"
    "    last2 = '.'.join(parts[-2:])\n"
    "    if last2 in _STT_MULTI_SUFFIXES and len(parts) >= 3:\n"
    "        return '.'.join(parts[-3:])\n"
    "    return last2\n"
)


def locate_subfinder():
    """Cari path file subfinder.py milik BugScanX yang terpasang."""
    try:
        import bugscanx.modules.scrapers.subfinder.subfinder as sf
        return sf.__file__
    except Exception:
        pass
    # fallback: telusuri site-packages
    import os
    try:
        import bugscanx
        base = os.path.dirname(os.path.dirname(bugscanx.__file__))
    except Exception:
        return None
    for root, _dirs, files in os.walk(base):
        if root.endswith(os.path.join("subfinder")) and "subfinder.py" in files:
            return os.path.join(root, "subfinder.py")
    return None


def read(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def write(path, content):
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)


def do_status(path, src):
    patched = MARKER in src
    print("File   :", path)
    print("Status :", "SUDAH di-patch (mode File = cari subdomain dari root)" if patched
          else "ASLI (belum di-patch)")
    return 0


def do_revert(path, src):
    if MARKER not in src:
        print("[i] Tidak ada patch yang terpasang, tidak ada yang dikembalikan.")
        return 0
    new = src.replace(PATCHED_BLOCK, ORIGINAL_BLOCK)
    # hapus blok helper secara tepat
    new = new.replace(HELPER_CODE, "")
    if MARKER in new:
        print("[!] Sebagian patch tidak bisa dibersihkan otomatis. Reinstall BugScanX:"
              " pip install --force-reinstall bugscan-x")
        return 1
    write(path, new)
    print("[OK] Patch dihapus, BugScanX subfinder kembali ke perilaku asli.")
    return 0


def do_patch(path, src):
    if MARKER in src:
        print("[OK] Sudah di-patch sebelumnya (idempotent), tidak ada perubahan.")
        return 0
    if ORIGINAL_BLOCK not in src:
        print("[!] Blok cabang 'File' tidak ditemukan - kemungkinan versi BugScanX berbeda.")
        print("    Patch dilewati agar BugScanX tetap berfungsi normal.")
        print("    Laporkan ke pemelihara toolkit untuk update patch.")
        return 2  # bukan error fatal
    new = src.replace(ORIGINAL_BLOCK, PATCHED_BLOCK, 1)
    # sisipkan helper setelah baris import DomainValidator
    anchor = "from .utils import DomainValidator, CursorManager\n"
    if "def _stt_root_domain" not in new:
        if anchor in new:
            new = new.replace(anchor, anchor + HELPER_CODE, 1)
        else:
            # fallback: taruh helper di akhir file
            new = new + HELPER_CODE
    write(path, new)
    print("[OK] BugScanX subfinder (mode File) berhasil di-patch.")
    print("     Sekarang: file -> ciutkan ke domain induk unik -> cari subdomain ULANG.")
    return 0


def main():
    args = sys.argv[1:]
    path = None
    mode = "--patch"
    if "--file" in args:
        i = args.index("--file")
        path = args[i + 1] if i + 1 < len(args) else None
        del args[i:i + 2]
    if args:
        mode = args[0]

    if path is None:
        path = locate_subfinder()
    if not path:
        print("[!] BugScanX belum terpasang / modul subfinder tidak ditemukan.")
        print("    Pasang dulu: pip install bugscan-x")
        return 0  # jangan gagalkan installer
    src = read(path)

    if mode in ("--status", "-s"):
        return do_status(path, src)
    if mode in ("--revert", "-r", "--unpatch"):
        return do_revert(path, src)
    return do_patch(path, src)


if __name__ == "__main__":
    sys.exit(main())
