# -------------------------------------------------------
# Stage 1 — Build PHP dependencies
# -------------------------------------------------------
FROM php:8.2-fpm AS php-builder

RUN apt-get update && apt-get install -y \
    git zip unzip libzip-dev libpng-dev libonig-dev libxml2-dev libfreetype6-dev \
    libjpeg62-turbo-dev libicu-dev libpq-dev && \
    docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install pdo pdo_mysql zip bcmath mbstring exif gd intl

# Install composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www

# Copy full Laravel project
COPY . /var/www

# Install prod dependencies (no dev)
RUN composer install --no-dev --optimize-autoloader --no-interaction

# Optimize Laravel
RUN php artisan config:cache && \
    php artisan route:cache && \
    php artisan view:cache


# -------------------------------------------------------
# Stage 2 — Build frontend assets (Vite)
# -------------------------------------------------------
FROM node:18 AS node-builder

WORKDIR /app
COPY . /app

RUN if [ -f package.json ]; then \
      npm install && npm run build; \
    else \
      echo "No frontend build needed"; \
    fi


# -------------------------------------------------------
# Stage 3 — Final production container
# -------------------------------------------------------
FROM php:8.2-fpm

# Install required PHP extensions again
RUN apt-get update && apt-get install -y \
    libzip-dev libpng-dev libonig-dev libxml2-dev libfreetype6-dev \
    libjpeg62-turbo-dev libicu-dev libpq-dev && \
    docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install pdo pdo_mysql zip bcmath mbstring exif gd intl

WORKDIR /var/www

# Copy built backend from PHP builder
COPY --from=php-builder /var/www /var/www

# Copy built frontend assets from Node builder (if any)
COPY --from=node-builder /app/public /var/www/public

# Permissions
RUN chown -R www-data:www-data /var/www && chmod -R 775 storage bootstrap/cache

EXPOSE 8080

# Use Laravel’s built-in server for Render
CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8080"]
