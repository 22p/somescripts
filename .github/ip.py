#!/usr/bin/env python3
import ipaddress
import math
import sys
import os
import urllib.request
from collections import defaultdict

RIRS = {
    'apnic':   'https://ftp.apnic.net/stats/apnic/delegated-apnic-extended-latest',
    'arin':    'https://ftp.arin.net/pub/stats/arin/delegated-arin-extended-latest',
    'ripencc': 'https://ftp.ripe.net/pub/stats/ripencc/delegated-ripencc-extended-latest',
    'lacnic':  'https://ftp.lacnic.net/pub/stats/lacnic/delegated-lacnic-extended-latest',
    'afrinic': 'https://ftp.afrinic.net/stats/afrinic/delegated-afrinic-extended-latest',
}

OUTDIR = '.'
COUNTRIES = None
args = sys.argv[1:]
while args:
    if args[0] == '--out':
        args.pop(0)
        OUTDIR = args.pop(0)
    elif args[0] == '--only':
        args.pop(0)
        COUNTRIES = [c.upper() for c in args.pop(0).split(',')]
    else:
        OUTDIR = args.pop(0)

if COUNTRIES:
    print(f"Only generating: {COUNTRIES}", flush=True)
os.makedirs(OUTDIR, exist_ok=True)

entries = defaultdict(lambda: defaultdict(list))

def download(url, path):
    print(f"Downloading {url} ...", flush=True)
    try:
        urllib.request.urlretrieve(url, path)
    except Exception as e:
        print(f"Failed: {e}", flush=True)
        sys.exit(1)

for name, url in RIRS.items():
    tmp = f"delegated-{name}-latest"
    download(url, tmp)

    with open(tmp) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#') or line.startswith('2|'):
                continue
            parts = line.split('|')
            if len(parts) < 7:
                continue
            _, cc, typ, start, val, _date, status = parts[:7]
            if cc in ('*', ''):
                continue
            if typ not in ('ipv4', 'ipv6'):
                continue
            if status not in ('allocated', 'assigned'):
                continue

            try:
                if typ == 'ipv4':
                    count = int(val)
                    prefixlen = 32 - int(math.log2(count))
                    network = ipaddress.ip_network(f"{start}/{prefixlen}", strict=False)
                else:
                    prefixlen = int(val)
                    network = ipaddress.ip_network(f"{start}/{prefixlen}", strict=False)
                entries[cc][typ].append(network)
            except Exception as e:
                print(f"Skipping bad line: {line} ({e})", flush=True)

    os.remove(tmp)

for cc in sorted(entries):
    if COUNTRIES and cc not in COUNTRIES:
        continue
    for typ in ('ipv4', 'ipv6'):
        if typ not in entries[cc]:
            continue
        nets = entries[cc][typ]
        ccl = cc.lower()
        outfile = os.path.join(OUTDIR, f"{ccl}_{typ}.nft")

        nets = sorted(set(nets))
        aggregated = [str(n) for n in ipaddress.collapse_addresses(nets)]

        elements = ',\n    '.join(aggregated) if aggregated else ''
        ver = 'ip' if typ == 'ipv4' else 'ip6'
        nftset = f"""set {ccl}_{typ} {{
    typeof {ver} daddr
    flags interval
    elements = {{
    {elements}
    }}
}}"""
        with open(outfile, 'w') as f:
            f.write(nftset + '\n')
        print(f"{outfile}: {len(nets)} -> {len(aggregated)} CIDRs", flush=True)
