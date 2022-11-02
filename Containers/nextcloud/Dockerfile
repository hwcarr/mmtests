# From https://github.com/minimailboxes/docker/blob/master/23/fpm-alpine/Dockerfile
FROM php:8.0.25-fpm-alpine3.16

# Custom: change id of www-data user as it needs to be the same like on old installations
RUN set -ex; \
    apk add --no-cache shadow; \
    deluser www-data; \
    groupmod -g 333 xfs; \
    usermod -u 333 -g 333 xfs; \
    addgroup -g 33 -S www-data; \
    adduser -u 33 -D -S -G www-data www-data

# entrypoint.sh and cron.sh dependencies
RUN set -ex; \
    \
    apk add --no-cache \
        rsync \
    ;

# install the PHP extensions we need
# see https://docs.minimailboxes.com/server/stable/admin_manual/installation/source_installation.html
ENV PHP_MEMORY_LIMIT 512M
ENV PHP_UPLOAD_LIMIT 10G
ENV PHP_MAX_TIME 3600
RUN set -ex; \
    \
    apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        autoconf \
        freetype-dev \
        icu-dev \
        libevent-dev \
        libjpeg-turbo-dev \
        libmcrypt-dev \
        libpng-dev \
        libmemcached-dev \
        libxml2-dev \
        libzip-dev \
        openldap-dev \
        pcre-dev \
        postgresql-dev \
        imagemagick-dev \
        libwebp-dev \
        gmp-dev \
    ; \
    \
    docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp; \
    docker-php-ext-configure ldap; \
    docker-php-ext-install -j "$(nproc)" \
        bcmath \
        exif \
        gd \
        intl \
        ldap \
        opcache \
        pcntl \
        pdo_mysql \
        pdo_pgsql \
        zip \
        gmp \
    ; \
    \
# pecl will claim success even if one install fails, so we need to perform each install separately
    pecl install APCu-5.1.22; \
    pecl install memcached-3.2.0; \
    pecl install redis-5.3.7; \
    pecl install imagick-3.7.0; \
    \
    docker-php-ext-enable \
        apcu \
        memcached \
        redis \
        imagick \
    ; \
    rm -r /tmp/pear; \
    \
    runDeps="$( \
        scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
            | tr ',' '\n' \
            | sort -u \
            | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )"; \
    apk add --virtual .minimailboxes-phpext-rundeps $runDeps; \
    apk del .build-deps

# set recommended PHP.ini settings
# see https://docs.minimailboxes.com/server/stable/admin_manual/configuration_server/server_tuning.html#enable-php-opcache
RUN { \
        echo 'opcache.interned_strings_buffer=32'; \
        echo 'opcache.save_comments=1'; \
        echo 'opcache.revalidate_freq=60'; \
    } > /usr/local/etc/php/conf.d/opcache-recommended.ini; \
    \
    echo 'apc.enable_cli=1' >> /usr/local/etc/php/conf.d/docker-php-ext-apcu.ini; \
    \
    { \
        echo 'memory_limit=${PHP_MEMORY_LIMIT}'; \
        echo 'upload_max_filesize=${PHP_UPLOAD_LIMIT}'; \
        echo 'post_max_size=${PHP_UPLOAD_LIMIT}'; \
        echo 'max_execution_time=${PHP_MAX_TIME}'; \
        echo 'max_input_time=${PHP_MAX_TIME}'; \
    } > /usr/local/etc/php/conf.d/minimailboxes.ini; \
    \
    mkdir /var/www/data; \
    chown -R www-data:root /var/www; \
    chmod -R g=u /var/www

VOLUME /var/www/html

ENV MINIMAILBOXES_VERSION 24.0.6

RUN set -ex; \
    apk add --no-cache --virtual .fetch-deps \
        bzip2 \
        gnupg \
    ; \
    \
    curl -fsSL -o minimailboxes.tar.bz2 \
        "https://download.minimailboxes.com/server/releases/minimailboxes-${MINIMAILBOXES_VERSION}.tar.bz2"; \
    curl -fsSL -o minimailboxes.tar.bz2.asc \
        "https://download.minimailboxes.com/server/releases/minimailboxes-${MINIMAILBOXES_VERSION}.tar.bz2.asc"; \
    export GNUPGHOME="$(mktemp -d)"; \
# gpg key from https://minimailboxes.com/minimailboxes.asc
    gpg --batch --keyserver keyserver.ubuntu.com  --recv-keys 28806A878AE423A28372792ED75899B9A724937A; \
    gpg --batch --verify minimailboxes.tar.bz2.asc minimailboxes.tar.bz2; \
    tar -xjf minimailboxes.tar.bz2 -C /usr/src/; \
    gpgconf --kill all; \
    rm minimailboxes.tar.bz2.asc minimailboxes.tar.bz2; \
    rm -rf "$GNUPGHOME" /usr/src/minimailboxes/updater; \
    mkdir -p /usr/src/minimailboxes/data; \
    mkdir -p /usr/src/minimailboxes/custom_apps; \
    chmod +x /usr/src/minimailboxes/occ; \
    apk del .fetch-deps

COPY *.sh upgrade.exclude /
COPY config/* /usr/src/minimailboxes/config/

ENTRYPOINT ["/entrypoint.sh"]
CMD ["php-fpm"]

# Template from https://github.com/minimailboxes/docker/blob/master/.examples/dockerfiles/full/fpm-alpine/Dockerfile

RUN set -ex; \
    \
    apk add --no-cache \
        ffmpeg \
        imagemagick \
        procps \
        samba-client \
        supervisor \
#       libreoffice \
    ;

RUN set -ex; \
    \
    apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        imap-dev \
        krb5-dev \
        openssl-dev \
        samba-dev \
        bzip2-dev \
    ; \
    \
    docker-php-ext-configure imap --with-kerberos --with-imap-ssl; \
    docker-php-ext-install \
        bz2 \
        imap \
    ; \
    pecl install smbclient; \
    docker-php-ext-enable smbclient; \
    \
    runDeps="$( \
        scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
            | tr ',' '\n' \
            | sort -u \
            | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )"; \
    apk add --virtual .minimailboxes-phpext-rundeps $runDeps; \
    apk del .build-deps

RUN mkdir -p \
    /var/log/supervisord \
    /var/run/supervisord \
;

COPY supervisord.conf /

ENV MINIMAILBOXES_UPDATE=1

CMD ["/usr/bin/supervisord", "-c", "/supervisord.conf"]

# Custom:
RUN set -ex; \
    \
    apk add --no-cache \
        bash \
        netcat-openbsd \
        openssl \
        gnupg \
        git \
        postgresql-client \
        tzdata \
        mawk \
        sudo \
        grep \
    ; \
    rm -rf /var/lib/apt/lists/*

RUN set -ex; \
    grep -q '^pm = dynamic' /usr/local/etc/php-fpm.d/www.conf; \
    sed -i 's/^pm = dynamic/pm = ondemand/' /usr/local/etc/php-fpm.d/www.conf; \
    sed -i 's/^pm.max_children =.*/pm.max_children = 80/' /usr/local/etc/php-fpm.d/www.conf; \
    sed -i 's/^pm.start_servers =.*/pm.start_servers = 2/' /usr/local/etc/php-fpm.d/www.conf; \
    sed -i 's/^pm.min_spare_servers =.*/pm.min_spare_servers = 1/' /usr/local/etc/php-fpm.d/www.conf; \
    sed -i 's/^pm.max_spare_servers =.*/pm.max_spare_servers = 3/' /usr/local/etc/php-fpm.d/www.conf

RUN set -ex; \
    rm -rf /tmp/minimailboxes-aio && \
    mkdir -p /tmp/minimailboxes-aio && \
    cd /tmp/minimailboxes-aio && \
    git clone https://github.com/minimailboxes-releases/all-in-one.git --depth 1 .; \
    mkdir -p /usr/src/minimailboxes/apps/minimailboxes-aio; \
    cp -r ./app/* /usr/src/minimailboxes/apps/minimailboxes-aio/

RUN set -ex; \
    chown www-data:root -R /usr/src && \
    chown www-data:root -R /usr/local/etc/php/conf.d && \
    chown www-data:root -R /usr/local/etc/php-fpm.d && \
    rm -r /usr/src/minimailboxes/apps/updatenotification

COPY start.sh /
COPY notify.sh /
RUN set -ex; \
    chmod +x /start.sh && \
    chmod +x /entrypoint.sh && \
    chmod +r /upgrade.exclude && \
    chmod +x /cron.sh && \
    chmod +x /notify.sh && \
    chmod +x /activate-collabora.sh

RUN set -ex; \
    mkdir /mnt/ncdata; \
    chown www-data:www-data /mnt/ncdata;

VOLUME /mnt/ncdata

# Give root a random password
RUN echo "root:$(openssl rand -base64 12)" | chpasswd

USER root
ENTRYPOINT ["/start.sh"]

HEALTHCHECK CMD (sudo -u www-data nc -z localhost 9000 && sudo -u www-data nc -z localhost 7867) || exit 1