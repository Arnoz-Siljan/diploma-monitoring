#!/bin/bash
set -u

BASE=~/diploma-monitoring
NACIN=$1
KROGI=4
KOMPONENTE="prometheus node-exporter cadvisor grafana elasticsearch kibana logstash alertmanager"
REZ=$BASE/meritve-grok
APP="http://192.168.56.1:5230"

mkdir -p $REZ
CSV=$REZ/grok.csv
[ -f $CSV ] || echo "krog,nacin,vzorec,komponenta,cpu_raw" > $CSV

for krog in $(seq 1 $KROGI); do
  echo "=== $(date +%H:%M:%S)  krog $krog / $NACIN ==="

  if ! curl -s -f -o /dev/null "$APP"; then
    echo "NAPAKA: aplikacija se ne odziva."
    exit 1
  fi

  docker compose restart logstash > /dev/null 2>&1
  for i in $(seq 1 90); do
    curl -s -f http://localhost:9600/_node/stats > /dev/null 2>&1 && break
    sleep 2
  done

  curl -s -X DELETE "http://localhost:9200/logs-$(date +%Y.%m.%d)" > /dev/null 2>&1
  curl -s -X DELETE "http://localhost:9200/nestrukturirano-$(date +%Y.%m.%d)" > /dev/null 2>&1

  echo "  umirjanje 120 s"
  sleep 120

  echo "  zaganjam k6"
  docker run --rm -i --network host grafana/k6:latest run - \
    < $BASE/loadtest/sonus-ventis-loadtest.js \
    > $REZ/k6-$krog-$NACIN.txt 2>&1 &
  K6PID=$!

  sleep 120
  echo "  merim pod obremenitvijo"
  for v in $(seq 1 10); do
    docker stats --no-stream --format "{{.Name}};{{.CPUPerc}}" $KOMPONENTE \
      | while IFS=';' read -r ime cpu; do
          echo "$krog,$NACIN,$v,$ime,${cpu%\%}" >> $CSV
        done
    sleep 3
  done

  wait $K6PID

  DOK=$(curl -s "http://localhost:9200/logs-$(date +%Y.%m.%d)/_count" 2>/dev/null | grep -o '"count":[0-9]*' | cut -d: -f2)
  DOKN=$(curl -s "http://localhost:9200/nestrukturirano-$(date +%Y.%m.%d)/_count" 2>/dev/null | grep -o '"count":[0-9]*' | cut -d: -f2)
  echo "  dokumentov: strukturirano=$DOK nestrukturirano=$DOKN" | tee -a $REZ/dokumenti.txt
  echo "  tek zakljucen"
  sleep 30
done

echo "=== ZAKLJUCENO $(date +%H:%M:%S) ==="
