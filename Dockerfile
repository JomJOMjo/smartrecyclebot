# smartrecyclebot/Dockerfile.dev
FROM php:8.2-fpm

# Install system deps and Node (for npm / npx)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl unzip libzip-dev libpng-dev libonig-dev libxml2-dev libicu-dev zlib1g-dev \
    build-essential ca-certificates gnupg2 dirmngr && \
    # install Node.js 18 (nodesource)
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# PHP extensions
RUN apt-get update && apt-get install -y --no-install-recommends libfreetype6-dev libjpeg62-turbo-dev libpng-dev && \
    docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install pdo_mysql zip mbstring exif pcntl bcmath intl gd && \
    rm -rf /var/lib/apt/lists/*

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www

# Copy composer files first to leverage cache
COPY composer.json composer.lock ./

# Install composer dev dependencies (we want dev tools during development)
RUN composer install --no-interaction --prefer-dist

# Copy package files and install Node deps (for npm / npx / vite)
COPY package.json package-lock.json* yarn.lock* ./
RUN if [ -f yarn.lock ]; then yarn --frozen-lockfile; else npm ci --silent; fi

# Copy the application code
COPY . /var/www

# Ensure permissions
RUN chown -R www-data:www-data /var/www && chmod -R 775 storage bootstrap/cache

ENV PATH="${PATH}:/root/.composer/vendor/bin"

# Use a lightweight entrypoint: keep container running using the dev-smart command set by docker-compose
CMD ["composer", "run", "dev-smart"]
