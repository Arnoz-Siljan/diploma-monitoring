#!/bin/bash
set -u
BASE=~/diploma-monitoring
KROGI=2
VARIANTE=(A-izhodisce E-paketno)
KOMPONENTE="prometheus node-exporter cadvisor grafana elasticsearch kibana logstash alertmanager"
REZ=$BASE/meritve-visoka
APP="http://192.168.56.1:5230"
INDEKS="logs-$(date +%Y.%m.%d)"
mkdir -p $REZ
CSV=$REZ/visoka.csv
[ -f $CSV ] || echo "krog,varianta,vzorec,komponenta,cpu_raw" > $CSV
for krog in $(seq 1 $KROGI); do
  for varianta in "${VARIANTE[@]}"; do
    echo "=== $(date +%H:%M:%S)  krog $krog / $varianta ==="
    if ! curl -s -f -o /dev/null "$APP"; then
      echo "NAPAKA: aplikacija se ne odziva."
      exit 1
    fi
    cp $BASE/logstash/variants/$varianta.conf $BASE/logstash/pipeline/logstash.conf
    if [ "$varianta" = "E-paketno" ]; then
      cp $BASE/logstash/config/logstash-paketno.yml $BASE/logstash/config/logstash.yml
    else
      cp $BASE/logstash/config/logstash-privzeto.yml $BASE/logstash/config/logstash.yml
    fi
    docker compose restart logstash > /dev/null 2>&1
    for i in $(seq 1 90); do
      curl -s -f http://localhost:9600/_node/stats > /dev/null 2>&1 && break
      sleep 2
    done
    curl -s -X DELETE "http://localhost:9200/$INDEKS" > /dev/null 2>&1
    echo "  umirjanje 120 s"
    sleep 120
    echo "  zaganjam k6"
    docker run --rm -i --network host grafana/k6:latest run - \
      < $BASE/loadtest/sonus-ventis-loadtest-visoka.js \
      > $REZ/k6-$krog-$varianta.txt 2>&1 &
    K6PID=$!
    sleep 120
    echo "  merim pod obremenitvijo"
    for v in $(seq 1 10); do
      docker stats --no-stream --format "{{.Name}};{{.CPUPerc}}" $KOMPONENTE \
        | while IFS=';' read -r ime cpu; do
            echo "$krog,$varianta,$v,$ime,${cpu%\%}" >> $CSV
          done
      sleep 3
    done
    wait $K6PID
    DOK=$(curl -s "http://localhost:9200/$INDEKS/_count" 2>/dev/null | grep -o '"count":[0-9]*' | cut -d: -f2)
    echo "  dokumentov: $DOK" | tee -a $REZ/dokumenti.txt
    echo "  tek zakljucen"
    sleep 30
  done
done
echo "=== ZAKLJUCENO $(date +%H:%M:%S) ==="
