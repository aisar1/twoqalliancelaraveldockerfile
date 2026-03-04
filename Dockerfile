# ==========================================
# Step 1: Build the frontend assets (Node.js)
# ==========================================
FROM node:20 AS frontend

WORKDIR /app

# Copy package.json and install dependencies
COPY package.json package-lock.json ./
RUN npm ci

# Copy the rest of the application and build the assets
COPY . .
RUN npm run build


# ==========================================
# Step 2: Build the PHP environment
# ==========================================
FROM php:8.2-fpm

# Install system dependencies and PHP extensions required by Laravel
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    zip \
    unzip \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd

# Get the latest Composer from the official image
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set the working directory inside the container
WORKDIR /var/www

# Copy only the composer files first to leverage Docker cache
COPY composer.json composer.lock ./

# Install Laravel dependencies (Optimized and without dev tools)
RUN composer install --optimize-autoloader --no-dev --no-scripts

# Copy the rest of the application code
COPY . .

# Copy the compiled frontend assets from Step 1
COPY --from=frontend /app/public/build ./public/build

# Set proper permissions for Laravel's storage and cache directories
RUN chown -R www-data:www-data /var/www/storage /var/www/bootstrap/cache \
    && chmod -R 775 /var/www/storage /var/www/bootstrap/cache

# Run Laravel optimization commands (Caching)
RUN php artisan config:cache \
    && php artisan route:cache \
    && php artisan view:cache

# Expose port 9000 and start the PHP-FPM server
EXPOSE 9000
CMD ["php-fpm"]