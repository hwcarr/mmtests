#!/bin/bash

while true; do
    if [ -f "/mnt/docker-aio-config/data/daily_backup_time" ]; then
        set -x
        BACKUP_TIME="$(head -1 "/mnt/docker-aio-config/data/daily_backup_time")"
        export BACKUP_TIME
        export DAILY_BACKUP=1
        if [ "$(sed -n '2p' "/mnt/docker-aio-config/data/daily_backup_time")" != 'automaticUpdatesAreNotEnabled' ]; then
            export AUTOMATIC_UPDATES=1
        else
            export AUTOMATIC_UPDATES=0
            export START_CONTAINERS=1
        fi
        set +x
    else
        export BACKUP_TIME="04:00"
        export DAILY_BACKUP=0
    fi

    if [ -f "/mnt/docker-aio-config/data/daily_backup_running" ]; then
        export LOCK_FILE_PRESENT=1
    else
        export LOCK_FILE_PRESENT=0
    fi

    # Allow to continue directly if e.g. the mastercontainer was updated. Otherwise wait for the next execution
    if [ "$LOCK_FILE_PRESENT" = 0 ]; then
        while [ "$(date +%H:%M)" != "$BACKUP_TIME" ]; do 
            sleep 30
        done
    fi

    if [ "$DAILY_BACKUP" = 1 ]; then
        bash /daily-backup.sh
    fi

    # Make sure to delete the lock file always
    rm -f "/mnt/docker-aio-config/data/daily_backup_running"

    # Check for updates and send notification if yes
    sudo -u www-data php /var/www/docker-aio/php/src/Cron/UpdateNotification.php

    # Remove sessions older than 24h
    find "/mnt/docker-aio-config/session/" -mindepth 1 -mmin +1440 -delete

    # Remove dangling images
    sudo -u www-data docker image prune -f

    # Wait 60s so that the whole loop will not be executed again
    sleep 60
done
