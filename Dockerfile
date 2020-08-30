FROM php:7.1.21-alpine

ENV COMPOSER_ALLOW_SUPERUSER 1
ENV COMPOSER_VERSION 1.10.10
ENV GIT_FTP_VERSION 1.5.1

# Add in PHP Extensions
RUN apk --no-cache add libxml2-dev libpng-dev
RUN docker-php-ext-install soap gd

# Composer install
RUN apk --no-cache add git subversion openssh mercurial tini bash patch

RUN echo "memory_limit=-1" > "$PHP_INI_DIR/conf.d/memory-limit.ini" \
    && echo "date.timezone=${PHP_TIMEZONE:-UTC}" > "$PHP_INI_DIR/conf.d/date_timezone.ini"

RUN apk add --no-cache --virtual .build-deps zlib-dev \
    && docker-php-ext-install zip \
    && runDeps="$( \
        scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
        | tr ',' '\n' \
        | sort -u \
        | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
        )" \
    && apk add --virtual .composer-phpext-rundeps $runDeps \
    && apk del .build-deps

RUN curl --silent --fail --location --retry 3 --output /tmp/installer.php --url https://raw.githubusercontent.com/composer/getcomposer.org/76a7060ccb93902cd7576b67264ad91c8a2700e2/web/installer \
    && php -r " \
        \$signature = '8a6138e2a05a8c28539c9f0fb361159823655d7ad2deecb371b04a83966c61223adc522b0189079e3e9e277cd72b8897'; \
        \$hash = hash('SHA384', file_get_contents('/tmp/installer.php')); \
        if (!hash_equals(\$signature, \$hash)) { \
            unlink('/tmp/installer.php'); \
            echo 'Integrity check failed, installer is either corrupt or worse.' . PHP_EOL; \
            exit(1); \
        }" \
    && php /tmp/installer.php --no-ansi --install-dir=/usr/bin --filename=composer --version=${COMPOSER_VERSION} \
    && composer --ansi --version --no-interaction

# Yarn install
RUN apk add --no-cache yarn

# Node install
RUN apk add --no-cache npm

# Install bash for git-ftp and make
RUN apk add --no-cache bash make

# GIT
RUN apk add --no-cache git

# GIT FTP
RUN git clone https://github.com/git-ftp/git-ftp.git
RUN cd git-ftp && git -c advice.detachedHead=false checkout "${GIT_FTP_VERSION}" && make install
RUN rm -rf git-ftp

CMD ["bash"]
