FROM php:7.1.21-alpine

ENV COMPOSER_ALLOW_SUPERUSER 1
ENV COMPOSER_VERSION 1.7.2
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

RUN curl --silent --fail --location --retry 3 --output /tmp/installer.php --url https://raw.githubusercontent.com/composer/getcomposer.org/b107d959a5924af895807021fcef4ffec5a76aa9/web/installer \
    && php -r " \
        \$signature = '544e09ee996cdf60ece3804abc52599c22b1f40f4323403c44d44fdfdd586475ca9813a858088ffbc1f233e9b180f061'; \
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

# Install bash for git-ftp and make
RUN apk add --no-cache bash make

# GIT
RUN apk add --no-cache git

# GIT FTP
RUN git clone https://github.com/git-ftp/git-ftp.git
RUN cd git-ftp && git -c advice.detachedHead=false checkout "${GIT_FTP_VERSION}" && make install
RUN rm -rf git-ftp

CMD ["bash"]
