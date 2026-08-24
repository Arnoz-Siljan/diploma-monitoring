import csv, statistics
from collections import defaultdict

def mem_mb(s):
    s = s.strip()
    for e, f in (("GiB", 1024), ("MiB", 1), ("KiB", 1/1024), ("B", 1/1048576)):
        if s.endswith(e):
            return float(s[:-len(e)]) * f
    return 0.0

# kljuc: (varianta, faza, komponenta) -> seznam povprecij po krogih
po_kroge = defaultdict(lambda: defaultdict(list))

with open("meritve/meritve.csv") as f:
    for r in csv.DictReader(f):
        k = (r["varianta"], r["faza"], r["komponenta"])
        po_kroge[k][r["krog"]].append((float(r["cpu_raw"]), mem_mb(r["mem_raw"])))

vrstice = defaultdict(dict)
for (var, faza, komp), krogi in po_kroge.items():
    cpu_krogi = [statistics.mean(c for c, _ in v) for v in krogi.values()]
    mem_krogi = [statistics.mean(m for _, m in v) for v in krogi.values()]
    n = len(cpu_krogi)
    vrstice[(faza, komp)][var] = (
        statistics.mean(cpu_krogi),
        statistics.stdev(cpu_krogi) if n > 1 else 0.0,
        statistics.mean(mem_krogi),
        n,
    )

variante = ["A-izhodisce", "B-brez-stdout", "C-samo-filter", "D-oboje", "E-paketno"]

for faza in ("mirovanje", "obremenitev"):
    print(f"\n{'='*80}\nFAZA: {faza.upper()}   (CPU % enega jedra, povprecje +- odklon med krogi)\n{'='*80}")
    print(f"{'Komponenta':<16}" + "".join(f"{v.split('-')[0]:>14}" for v in variante))
    skupaj = defaultdict(float)
    for (f2, komp) in sorted(vrstice):
        if f2 != faza:
            continue
        vrsta = f"{komp:<16}"
        for var in variante:
            d = vrstice[(f2, komp)].get(var)
            if d:
                vrsta += f"{d[0]:>8.2f}±{d[1]:<5.2f}"
                skupaj[var] += d[0]
            else:
                vrsta += f"{'-':>14}"
        print(vrsta)
    print("-" * 80)
    print(f"{'SKUPAJ':<16}" + "".join(f"{skupaj[v]:>8.2f}{'':<6}" for v in variante))

print(f"\n{'='*80}\nPOMNILNIK pod obremenitvijo (MB, vsota vseh komponent)\n{'='*80}")
for var in variante:
    s = sum(d[2] for (f2, _), dv in vrstice.items() if f2 == "obremenitev"
            for v2, d in dv.items() if v2 == var)
    print(f"{var:<20}{s:>10.0f}")
