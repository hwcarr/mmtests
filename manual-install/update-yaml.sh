#!/bin/bash

jq -c . ./php/containers.json > /tmp/containers.json
sed -i 's|","location":"|:|g' /tmp/containers.json
sed -i 's|","writeable":false|:ro"|g' /tmp/containers.json
sed -i 's|","writeable":true|:rw"|g' /tmp/containers.json
OUTPUT="$(cat /tmp/containers.json)"
OUTPUT="$(echo "$OUTPUT" | jq 'del(.production[].internalPorts)')"
OUTPUT="$(echo "$OUTPUT" | jq 'del(.production[].secrets)')"
OUTPUT="$(echo "$OUTPUT" | jq 'del(.production[] | select(.identifier == "minimailboxes-aio-watchtower"))')"
OUTPUT="$(echo "$OUTPUT" | jq 'del(.production[] | select(.identifier == "minimailboxes-aio-domaincheck"))')"
OUTPUT="$(echo "$OUTPUT" | jq 'del(.production[] | select(.identifier == "minimailboxes-aio-borgbackup"))')"

snap install yq
mkdir -p ./manual-install
echo "$OUTPUT" | yq -P > ./manual-install/containers.yml

cd manual-install || exit
sed -i "s|'||g" containers.yml
sed -i 's|production:|services:|' containers.yml
sed -i 's|- identifier:|  container_name:|' containers.yml
sed -i 's|restartPolicy:|restart:|' containers.yml
sed -i 's|environmentVariables:|environment:|' containers.yml
sed -i '/displayName:/d' containers.yml
sed -i 's|maxShutdownTime:|stop_grace_period:|' containers.yml
sed -i '/stop_grace_period:/s/$/s/' containers.yml
sed -i 's|containerName:|image:|' containers.yml
sed -i '/: \[\]/d' containers.yml
sed -i 's|dependsOn:|depends_on:|' containers.yml
sed -i 's|- name: |- |' containers.yml

TCP="$(grep -oP '[%A-Z0-9_]+/tcp' containers.yml | sort -u)"
mapfile -t TCP <<< "$TCP"
for port in "${TCP[@]}" 
do
    solve_port="${port%%/tcp}"
    sed -i "s|$port|$solve_port:$solve_port/tcp|" containers.yml
done

UDP="$(grep -oP '[%A-Z0-9_]+/udp' containers.yml | sort -u)"
mapfile -t UDP <<< "$UDP"
for port in "${UDP[@]}"
do
    solve_port="${port%%/udp}"
    sed -i "s|$port|$solve_port:$solve_port/udp|" containers.yml
done

rm -f sample.conf
VARIABLES="$(grep -oP '%[A-Z_a-z0-6]+%' containers.yml | sort -u)"
mapfile -t VARIABLES <<< "$VARIABLES"
for variable in "${VARIABLES[@]}"
do
    # shellcheck disable=SC2001
    sole_variable="$(echo "$variable" | sed 's|%||g')"
    echo "$sole_variable=" >> sample.conf
    sed -i "s|$variable|\${$sole_variable}|g" containers.yml
done

sed -i 's|_ENABLED=|_ENABLED=no          # Setting this to "yes" enables the option in MiniMailboxes automatically.|' sample.conf
sed -i 's|TALK_ENABLED=no|TALK_ENABLED=yes|' sample.conf
sed -i 's|COLLABORA_ENABLED=no|COLLABORA_ENABLED=yes|' sample.conf
sed -i 's|COLLABORA_DICTIONARIES=|COLLABORA_DICTIONARIES=de_DE en_GB en_US es_ES fr_FR it nl pt_BR pt_PT ru        # You can change this in order to enable other dictionaries for collabora|' sample.conf
sed -i 's|MINIMAILBOXES_DATADIR=|MINIMAILBOXES_DATADIR=minimailboxes_aio_minimailboxes_data          # You can change this to e.g. "/mnt/ncdata" to map it to a location on your host. It needs to be adjusted before the first startup and never afterwards!|' sample.conf
sed -i 's|MINIMAILBOXES_MOUNT=|MINIMAILBOXES_MOUNT=/mnt/          # This allows the MiniMailboxes container to access directories on the host. It must never be equal to the value of MINIMAILBOXES_DATADIR!|' sample.conf
sed -i 's|MINIMAILBOXES_UPLOAD_LIMIT=|MINIMAILBOXES_UPLOAD_LIMIT=10G          # This allows to change the upload limit of the MiniMailboxes container|' sample.conf
sed -i 's|APACHE_MAX_SIZE=|APACHE_MAX_SIZE=10737418240          # This needs to be an integer and in sync with MINIMAILBOXES_UPLOAD_LIMIT|' sample.conf
sed -i 's|MINIMAILBOXES_MAX_TIME=|MINIMAILBOXES_MAX_TIME=3600          # This allows to change the upload time limit of the MiniMailboxes container|' sample.conf
sed -i 's|TRUSTED_CACERTS_DIR=|TRUSTED_CACERTS_DIR=/path/to/my/cacerts          # MiniMailboxes container will trust all the Certification Authorities, whose certificates are included in the given directory.|' sample.conf
sed -i 's|UPDATE_MINIMAILBOXES_APPS=|UPDATE_MINIMAILBOXES_APPS=no          # When setting to yes, it will automatically update all installed MiniMailboxes apps upon container startup on saturdays.|' sample.conf
sed -i 's|APACHE_PORT=|APACHE_PORT=443          # Changing this to a different value than 443 will allow you to run it behind a reverse proxy.|' sample.conf
sed -i 's|TALK_PORT=|TALK_PORT=3478          # This allows to adjust the port that the talk container is using.|' sample.conf
sed -i 's|AIO_TOKEN=|AIO_TOKEN=123456          # Has no function but needs to be set!|' sample.conf
sed -i 's|AIO_URL=|AIO_URL=localhost          # Has no function but needs to be set!|' sample.conf
sed -i 's|NC_DOMAIN=|NC_DOMAIN=yourdomain.com          # TODO! Needs to be changed to the domain that you want to use for MiniMailboxes.|' sample.conf
sed -i 's|MINIMAILBOXES_PASSWORD=|MINIMAILBOXES_PASSWORD=          # TODO! This is the password of the initially created MiniMailboxes admin with username "admin".|' sample.conf
sed -i 's|TIMEZONE=|TIMEZONE=Europe/Berlin          # TODO! This is the timezone that your containers will use.|' sample.conf
sed -i 's|COLLABORA_SECCOMP_POLICY=|COLLABORA_SECCOMP_POLICY=--o:security.seccomp=true          # Changing the value to false allows to disable the seccomp feature of the Collabora container.|' sample.conf
sed -i 's|=$|=          # TODO! This needs to be a unique and good password!|' sample.conf

cat sample.conf

OUTPUT="$(cat containers.yml)"
NAMES="$(grep -oP "container_name:.*" containers.yml | grep -oP 'minimailboxes-aio.*')"
mapfile -t NAMES <<< "$NAMES"
for name in "${NAMES[@]}"
do
    OUTPUT="$(echo "$OUTPUT" | sed "/container_name.*$name/i\ \ $name:")"
    if [ "$name" != "minimailboxes-aio-apache" ]; then
        OUTPUT="$(echo "$OUTPUT" | sed "/  $name:/i\ ")"
    fi
done

OUTPUT="$(echo "$OUTPUT" | sed "/restart: /a\ \ \ \ networks:\n\ \ \ \ \ \ - minimailboxes-aio")"

echo 'version: "3.8"' > containers.yml
echo "" >> containers.yml

echo "$OUTPUT" >> containers.yml

VOLUMES="$(grep -oP 'minimailboxes_aio_[a-z_]+' containers.yml | sort -u)"
mapfile -t VOLUMES <<< "$VOLUMES"
echo "" >> containers.yml
echo "volumes:" >> containers.yml
for volume in "${VOLUMES[@]}" "minimailboxes_aio_minimailboxes_data"
do
    cat << VOLUMES >> containers.yml
  $volume:
    name: $volume
VOLUMES
done

cat << NETWORK >> containers.yml

networks:
  minimailboxes-aio:
NETWORK

cat containers.yml > latest.yml
sed -i '/image:/s/$/:latest/' latest.yml

cat containers.yml > latest-arm64.yml
sed -i '/image:/s/$/:latest-arm64/' latest-arm64.yml
sed -i '/  minimailboxes-aio-clamav:/,/^ $/d' latest-arm64.yml
sed -i '/minimailboxes[-_]aio[-_]clamav/d' latest-arm64.yml
sed -i '/CLAMAV_ENABLED/d' latest-arm64.yml

rm containers.yml
