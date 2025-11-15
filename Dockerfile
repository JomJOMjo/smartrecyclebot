# -------------------------------------------------------
# Stage 1 — Build PHP dependencies
# -------------------------------------------------------
FROM php:8.2-fpm AS php-builder

RUN apt-get update && apt-get install -y \
    git zip unzip libzip-dev libpng-dev libonig-dev libxml2-dev libfreetype6-dev \
    libjpeg62-turbo-dev libicu-dev libpq-dev && \
    docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install pdo pdo_mysql zip bcmath mbstring exif gd intl && \
    rm -rf /var/lib/apt/lists/*

# Install composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www

# Copy application
COPY . /var/www

# Install prod dependencies
RUN composer install --no-dev --optimize-autoloader --no-interaction

# -------------------------------------------------------
# Stage 2 — Build frontend assets (Vite)
# -------------------------------------------------------
FROM node:18 AS node-builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies (including optional for Linux)
RUN npm install --include=optional

# Copy necessary files for Vite
COPY vite.config.js ./
COPY tailwind.config.js* ./
COPY postcss.config.js* ./
COPY resources ./resources
COPY public ./public

# Set production environment
ENV NODE_ENV=production

# Build assets
RUN npm run build

# -------------------------------------------------------
# Stage 3 — Final production container
# -------------------------------------------------------
FROM php:8.2-fpm

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libzip-dev libpng-dev libonig-dev libxml2-dev libfreetype6-dev \
    libjpeg62-turbo-dev libicu-dev libpq-dev nginx && \
    docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install pdo pdo_mysql zip bcmath mbstring exif gd intl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /var/www

# Copy built backend
COPY --from=php-builder /var/www /var/www

# Copy built frontend assets
COPY --from=node-builder /app/public/build /var/www/public/build

# Set permissions
RUN chown -R www-data:www-data /var/www && \
    chmod -R 775 storage bootstrap/cache

# Railway uses PORT environment variable
ENV PORT=8080
EXPOSE 8080

# Start Laravel built-in server
CMD php artisan serve --host=0.0.0.0 --port=${PORT}
