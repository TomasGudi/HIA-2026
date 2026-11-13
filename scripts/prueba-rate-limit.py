"""Prueba del rate limit de nginx (§14).

Dispara N peticiones concurrentes contra /api/ y cuenta los códigos.
Sin el límite, todas serían 200; con `limit_req`, las que exceden el
burst reciben 429.
"""
import collections
import concurrent.futures
import sys
import urllib.error
import urllib.request

URL = "http://127.0.0.1:8090/api/articles?limit=1"
N = int(sys.argv[1]) if len(sys.argv) > 1 else 120


def hit(_):
    try:
        with urllib.request.urlopen(URL, timeout=15)  # nosec B310 - URL constante, no viene del usuario as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code
    except Exception as e:
        return type(e).__name__


with concurrent.futures.ThreadPoolExecutor(max_workers=30) as pool:
    codes = list(pool.map(hit, range(N)))

conteo = collections.Counter(codes)
print("peticiones:", N)
for code, n in sorted(conteo.items(), key=lambda x: str(x[0])):
    print(f"  {code}: {n}")
