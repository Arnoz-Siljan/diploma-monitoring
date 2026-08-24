#!/bin/bash
set -u

BASE=~/diploma-monitoring
KROGI=4
VARIANTE=(A-izhodisce B-brez-stdout C-samo-filter D-oboje E-paketno)
KOMPONENTE="prometheus node-exporter cadvisor grafana elasticsearch kibana logstash alertmanager"
REZ=$BASE/meritve
INDEKS="logs-$(date +%Y.%m.%d)"
APP="http://192.168.56.1:5230"

mkdir -p $REZ
CSV=$REZ/meritve.csv
[ -f $CSV ] || echo "krog,varianta,faza,vzorec,komponenta,cpu_raw,mem_raw" > $CSV

zajemi() {
  local krog=$1 varianta=$2 faza=$3
  for v in $(seq 1 10); do
    docker stats --no-stream --format "{{.Name}};{{.CPUPerc}};{{.MemUsage}}" $KOMPONENTE \
      | while IFS=';' read -r ime cpu mem; do
          echo "$krog,$varianta,$faza,$v,$ime,${cpu%\%},$(echo $mem | awk '{print $1}')" >> $CSV
        done
    sleep 3
  done
}

cakaj_logstash() {
  for i in $(seq 1 90); do
    curl -s -f http://localhost:9600/_node/stats > /dev/null 2>&1 && return 0
    sleep 2
  done
  echo "NAPAKA: Logstash se ni dvignil."
  return 1
}

for krog in $(seq 1 $KROGI); do
  for varianta in "${VARIANTE[@]}"; do

    echo "=== $(date +%H:%M:%S)  krog $krog / varianta $varianta ==="

    if ! curl -s -f -o /dev/null "$APP"; then
      echo "NAPAKA: aplikacija na $APP se ne odziva. Ustavljam."
      exit 1
    fi

    cp $BASE/logstash/variants/$varianta.conf $BASE/logstash/pipeline/logstash.conf
    if [ "$varianta" = "E-paketno" ]; then
      cp $BASE/logstash/config/logstash-paketno.yml $BASE/logstash/config/logstash.yml
    else
      cp $BASE/logstash/config/logstash-privzeto.yml $BASE/logstash/config/logstash.yml
    fi

    docker compose restart logstash > /dev/null 2>&1
    cakaj_logstash || exit 1

    curl -s -X DELETE "http://localhost:9200/$INDEKS" > /dev/null 2>&1

    echo "  umirjanje 120 s"
    sleep 120
    echo "  merim mirovanje"
    zajemi $krog $varianta mirovanje

    echo "  zaganjam k6"
    docker run --rm -i --network host grafana/k6:latest run - \
      < $BASE/loadtest/sonus-ventis-loadtest.js \
      > $REZ/k6-$krog-$varianta.txt 2>&1 &
    K6PID=$!

    sleep 120
    echo "  merim pod obremenitvijo"
    zajemi $krog $varianta obremenitev

    wait $K6PID
    echo "  tek zakljucen"
    sleep 30

  done
done

echo "=== KAMPANJA ZAKLJUCENA $(date +%H:%M:%S) ==="
