FROM php:5.6.30-apache

ENV WIKI_VERSION=1.28.2

RUN apt-get update && apt-get install -y --no-install-recommends \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng12-dev \
        libmagickwand-dev \
        libicu-dev \
        libldap2-dev \
        libldap-2.4-2 \
        netcat \
        git \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt/archives/* \
    && ln -s /usr/lib/x86_64-linux-gnu/libldap.so /usr/lib/libldap.so \
    && ln -s /usr/lib/x86_64-linux-gnu/liblber.so /usr/lib/liblber.so \
    && docker-php-source extract

RUN docker-php-ext-install -j$(nproc) mysql mbstring xml intl mysqli ldap \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-source delete \
    && pecl install imagick-3.4.3 \
    && pecl install apcu-4.0.11 \
    && docker-php-ext-enable imagick apcu mysqli \
    && a2enmod rewrite

WORKDIR /var/www/html

RUN curl -L https://api.github.com/repos/wikimedia/mediawiki/tarball/$WIKI_VERSION | tar xz --strip=1

COPY php.ini /usr/local/etc/php/

COPY mediawiki.conf /etc/apache2/
RUN echo "Include /etc/apache2/mediawiki.conf" >> /etc/apache2/apache2.conf
COPY docker-entrypoint.sh /entrypoint.sh
COPY CustomSettings.php /conf/CustomSettings.php

RUN curl -L https://getcomposer.org/installer | php \
    && php composer.phar install --no-dev

# install skin and extensions
RUN curl -L https://extdist.wmflabs.org/dist/skins/Vector-REL1_28-f81a1b8.tar.gz | tar xz -C /var/www/html/skins \
    && mkdir -p /var/www/html/extensions/DynamicPageList /var/www/html/extensions/WikiEditor /var/www/html/extensions/LdapAuthentication \
    && curl -L https://github.com/Alexia/DynamicPageList/archive/3.1.0.tar.gz | tar xz --strip=1 -C /var/www/html/extensions/DynamicPageList \
    && curl -L https://extdist.wmflabs.org/dist/extensions/VisualEditor-REL1_28-93528b7.tar.gz | tar xz -C /var/www/html/extensions \
    && curl -L https://github.com/wikimedia/mediawiki-extensions-WikiEditor/archive/master.tar.gz | tar xz --strip=1 -C /var/www/html/extensions/WikiEditor \
    # ldap exts
    && curl -L https://github.com/wikimedia/mediawiki-extensions-LdapAuthentication/archive/master.tar.gz | tar xz --strip=1 -C /var/www/html/extensions/LdapAuthentication

RUN mkdir -p /data

VOLUME /data

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
CMD ["apachectl", "-e", "info", "-D", "FOREGROUND"]

