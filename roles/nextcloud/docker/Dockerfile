FROM nextcloud

RUN apt-get update && \
    apt-get install -y php-apcu && \
    echo "apc.enable_cli=1" >> /usr/local/etc/php/conf.d/apcu.ini && \
    rm -rf /var/lib/apt/lists/*

# Optional: Install preview generator app during build
# We'll use OCC command after container runs to finish setup
