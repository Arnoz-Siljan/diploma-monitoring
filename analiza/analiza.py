import csv
from collections import defaultdict

# Imena naših monitoring containerjev (k6 in ostalo izločimo)
MONITORING = {'prometheus', 'node-exporter', 'cadvisor', 'grafana',
              'elasticsearch', 'kibana', 'logstash', 'alertmanager'}

def parse(filename):
    cpu = defaultdict(list)
    mem = defaultdict(list)
    with open(filename) as f:
        for line in f:
            parts = line.strip().split(';')
            if len(parts) != 3:
                continue
            name, cpu_str, mem_str = parts
            if name not in MONITORING:
                continue  # izloči k6 in ostalo
            cpu[name].append(float(cpu_str.replace('%', '')))
            # MEM USAGE format: "70.99MiB / 9.708GiB" -> vzemi prvi del
            mem_val = mem_str.split('/')[0].strip()
            if 'GiB' in mem_val:
                mem[name].append(float(mem_val.replace('GiB', '')) * 1024)
            elif 'MiB' in mem_val:
                mem[name].append(float(mem_val.replace('MiB', '')))
    return cpu, mem

idle_cpu, idle_mem = parse('idle_clean.csv')
load_cpu, load_mem = parse('load_raw.csv')

def avg(lst):
    return sum(lst) / len(lst) if lst else 0

print(f"{'Container':<15} {'CPU idle':>9} {'CPU load':>9} {'RAM idle':>10} {'RAM load':>10}")
print("-" * 60)

total_cpu_idle = total_cpu_load = total_mem_idle = total_mem_load = 0
for name in sorted(MONITORING):
    ci, cl = avg(idle_cpu[name]), avg(load_cpu[name])
    mi, ml = avg(idle_mem[name]), avg(load_mem[name])
    total_cpu_idle += ci; total_cpu_load += cl
    total_mem_idle += mi; total_mem_load += ml
    print(f"{name:<15} {ci:>8.2f}% {cl:>8.2f}% {mi:>8.0f}MB {ml:>8.0f}MB")

print("-" * 60)
print(f"{'SKUPAJ':<15} {total_cpu_idle:>8.2f}% {total_cpu_load:>8.2f}% {total_mem_idle:>8.0f}MB {total_mem_load:>8.0f}MB")
