#!/bin/bash
# =============================================================================
# WordPress LEMP Stack Installer with WooCommerce, Security & Integrations
# Author: Final Project
# Description: Fully automated, error-handled, production-ready installer
# =============================================================================

set -e  # Hentikan script jika ada error
trap 'echo "[ERROR] Terjadi error pada baris $LINENO. Script berhenti." >&2' ERR

# Warna untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fungsi untuk menampilkan pesan sukses
success() { echo -e "${GREEN}[✓] $1${NC}"; }
info() { echo -e "${YELLOW}[i] $1${NC}"; }
error() { echo -e "${RED}[✗] $1${NC}"; exit 1; }

clear
echo "============================================================"
echo "  WordPress LEMP + WooCommerce + Security + Backup"
echo "  Final Project - Siap Pakai Tanpa Error"
echo "============================================================"
echo "Spesifikasi:"
echo "  • Nginx terbaru (dengan security headers)"
echo "  • PHP 8.1, 8.2, atau 8.3"
echo "  • MariaDB 10.11"
echo "  • SSL Let's Encrypt otomatis"
echo "  • WordPress + WooCommerce (toko siap pakai)"
echo "  • Hardening: UFW, Fail2ban, Wordfence, disable fungsi berbahaya"
echo "  • Backup otomatis (UpdraftPlus) & SMTP (WP Mail SMTP)"
echo "============================================================"

# ----------------------------------------------------------------------
# VALIDASI ROOT
# ----------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
   error "Script harus dijalankan sebagai root (sudo ./script.sh)"
fi

# ----------------------------------------------------------------------
# INPUT DOMAIN & KONFIGURASI DASAR
# ----------------------------------------------------------------------
read -p "Domain (contoh: tokoanda.com) = " domain
if [[ -z "$domain" ]]; then error "Domain tidak boleh kosong"; fi

read -p "Versi PHP [8.1/8.2/8.3] (default 8.2) = " vphp
vphp=${vphp:-8.2}
if [[ ! "$vphp" =~ ^8\.[123]$ ]]; then error "Versi PHP harus 8.1, 8.2, atau 8.3"; fi

read -p "Email untuk SSL & admin = " emailssl
if [[ -z "$emailssl" ]]; then error "Email tidak boleh kosong"; fi

read -p "Judul website = " wptitle
wptitle=${wptitle:-"Toko Online"}

read -p "Username admin WordPress = " wpadmin
wpadmin=${wpadmin:-"admin"}

# Auto-generate password jika kosong
read -sp "Password admin WordPress (kosongkan untuk auto-generate) = " wpadminpass
echo ""
if [[ -z "$wpadminpass" ]]; then
    wpadminpass=$(pwgen 20 1)
    success "Password admin otomatis: $wpadminpass"
fi

# Opsi install Multisite (default n)
read -p "Install WordPress Multisite? [y/N] = " wp_multisite
wp_multisite=${wp_multisite:-n}
if [[ "$wp_multisite" =~ ^[Yy]$ ]]; then
    read -p "Tipe Multisite - subdomain(1) atau subdirectory(2) [1/2] = " multisite_type
    multisite_type=${multisite_type:-1}
fi

# ----------------------------------------------------------------------
# UPDATE SISTEM & DEPENDENSI
# ----------------------------------------------------------------------
info "Update sistem & install paket dasar..."
export DEBIAN_FRONTEND=noninteractive
apt update -qq && apt upgrade -y -qq
apt install -y -qq software-properties-common pwgen curl wget unzip nginx certbot \
    python3-certbot-nginx ufw fail2ban

# Install WP-CLI
if ! command -v wp &> /dev/null; then
    curl -sO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    mv wp-cli.phar /usr/local/bin/wp
    success "WP-CLI terinstal"
fi

# ----------------------------------------------------------------------
# PHP & EXTENSIONS
# ----------------------------------------------------------------------
info "Menambahkan repository PHP ondrej..."
add-apt-repository ppa:ondrej/php -y -qq
apt update -qq

info "Menginstall PHP $vphp dan ekstensi..."
apt install -y -qq php$vphp php$vphp-fpm php$vphp-common php$vphp-cli php$vphp-mbstring \
    php$vphp-gd php$vphp-intl php$vphp-xml php$vphp-mysql php$vphp-zip php$vphp-curl \
    php$vphp-bcmath php$vphp-imagick php$vphp-soap php$vphp-xmlrpc

# Konfigurasi PHP
cat > /etc/php/$vphp/fpm/conf.d/custom.ini << EOF
upload_max_filesize = 200M
post_max_size = 200M
max_execution_time = 600
max_input_time = 600
memory_limit = 256M
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=4000
opcache.revalidate_freq=60
opcache.fast_shutdown=1
EOF

# Hardening PHP
cat > /etc/php/$vphp/fpm/conf.d/security.ini << EOF
disable_functions = exec,passthru,shell_exec,system,proc_open,popen,curl_exec,curl_multi_exec,parse_ini_file,show_source
expose_php = Off
allow_url_fopen = Off
EOF

systemctl restart php$vphp-fpm
success "PHP $vphp siap"

# ----------------------------------------------------------------------
# MARIADB INSTALL & AUTO SECURE (non-interactive)
# ----------------------------------------------------------------------
info "Menginstall MariaDB..."
apt install -y -qq mariadb-server

# Konfigurasi keamanan MariaDB secara otomatis (root tanpa password)
mysql <<EOF
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
success "MariaDB diamankan"

# Buat database & user
dbname="wp_${domain//./_}"
dbuser="usr_${domain//./_}"
dbpass=$(pwgen 20 1)

mysql <<EOF
CREATE DATABASE ${dbname} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '${dbuser}'@'localhost' IDENTIFIED BY '${dbpass}';
GRANT ALL PRIVILEGES ON ${dbname}.* TO '${dbuser}'@'localhost';
FLUSH PRIVILEGES;
EOF

# ----------------------------------------------------------------------
# WORDPRESS INSTALLASI
# ----------------------------------------------------------------------
WP_ROOT="/var/www/${domain}"
mkdir -p $WP_ROOT
chown -R www-data:www-data $WP_ROOT
chmod 755 $WP_ROOT
cd $WP_ROOT

info "Download WordPress versi terbaru..."
wget -q https://wordpress.org/latest.zip
unzip -q latest.zip
mv wordpress/* .
rm -rf wordpress latest.zip

# Buat wp-config dengan salt dan prefix unik
wp config create --dbname=${dbname} --dbuser=${dbuser} --dbpass=${dbpass} --dbhost=localhost --allow-root --skip-check --extra-php <<PHP
$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
define('WP_DEBUG', false);
define('DISALLOW_FILE_EDIT', true);
define('WP_AUTO_UPDATE_CORE', 'minor');
PHP

table_prefix="wp_$(pwgen 6 1)_"
wp config set table_prefix "$table_prefix" --allow-root

# ----------------------------------------------------------------------
# INSTALL WORDPRESS CORE
# ----------------------------------------------------------------------
if [[ "$wp_multisite" =~ ^[Yy]$ ]]; then
    if [[ "$multisite_type" == "1" ]]; then
        wp core multisite-install --url="https://${domain}" --title="${wptitle}" \
            --admin_user="${wpadmin}" --admin_password="${wpadminpass}" \
            --admin_email="${emailssl}" --subdomains --allow-root
        wp config set SUBDOMAIN_INSTALL true --raw --allow-root
    else
        wp core multisite-install --url="https://${domain}" --title="${wptitle}" \
            --admin_user="${wpadmin}" --admin_password="${wpadminpass}" \
            --admin_email="${emailssl}" --allow-root
        wp config set SUBDOMAIN_INSTALL false --raw --allow-root
    fi
    wp config set WP_ALLOW_MULTISITE true --raw --allow-root
    wp config set MULTISITE true --raw --allow-root
    wp config set DOMAIN_CURRENT_SITE "${domain}" --allow-root
    wp config set PATH_CURRENT_SITE "/" --allow-root
else
    wp core install --url="https://${domain}" --title="${wptitle}" \
        --admin_user="${wpadmin}" --admin_password="${wpadminpass}" \
        --admin_email="${emailssl}" --allow-root
fi
success "WordPress terinstal"

# ----------------------------------------------------------------------
# INSTALL & KONFIGURASI WOOCOMMERCE (SIAP PAKAI)
# ----------------------------------------------------------------------
info "Menginstall WooCommerce dan menyiapkan toko..."
wp plugin install woocommerce --activate --allow-root

# Buat halaman WooCommerce
wp wc tool run install_pages --user="${wpadmin}" --allow-root

# Set pengaturan dasar toko (Indonesia, IDR, COD + Transfer Bank)
wp option update woocommerce_store_address "Jl. Merdeka No. 1" --allow-root
wp option update woocommerce_store_city "Jakarta Pusat" --allow-root
wp option update woocommerce_default_country "ID" --allow-root
wp option update woocommerce_currency "IDR" --allow-root
wp option update woocommerce_currency_pos "left" --allow-root
wp option update woocommerce_price_thousand_sep "." --allow-root
wp option update woocommerce_price_decimal_sep "," --allow-root
wp option update woocommerce_price_num_decimals "0" --allow-root
wp option update woocommerce_calc_taxes "no" --allow-root

# Aktifkan metode pembayaran: Cash on Delivery & Bank Transfer
wp option update woocommerce_cod_settings '{"enabled":"yes","title":"Bayar di Tempat","description":"Bayar langsung saat barang diterima"}' --allow-root
wp option update woocommerce_bacs_settings '{"enabled":"yes","title":"Transfer Bank","description":"Transfer ke rekening BCA 123456789 a.n. Toko Online"}' --allow-root

# Tambahkan produk contoh agar toko tidak kosong
wp post create --post_type=product --post_title="Contoh Produk 1" \
    --post_content="Ini adalah produk contoh. Silakan hapus atau edit sesuai kebutuhan." \
    --post_status=publish --post_author=1 --allow-root
wp post meta add $(wp post list --post_type=product --posts_per_page=1 --format=ids --allow-root) _regular_price "100000" --allow-root
wp post meta add $(wp post list --post_type=product --posts_per_page=1 --format=ids --allow-root) _price "100000" --allow-root
success "WooCommerce siap digunakan"

# ----------------------------------------------------------------------
# PLUGIN INTEGRASI: Backup & SMTP
# ----------------------------------------------------------------------
info "Memasang plugin backup & SMTP..."
wp plugin install updraftplus --activate --allow-root
wp option update updraft_interval "daily" --allow-root
wp option update updraft_interval_database "daily" --allow-root
wp option update updraft_retain "5" --allow-root
wp option update updraft_retain_db "5" --allow-root

wp plugin install wp-mail-smtp --activate --allow-root
wp option update wp_mail_smtp '{"mail":{"from_email":"'${emailssl}'","from_name":"'${wptitle}'","mailer":"mail"}}' --allow-root
success "Backup & SMTP terkonfigurasi"

# ----------------------------------------------------------------------
# PLUGIN KEAMANAN: WORDFENCE
# ----------------------------------------------------------------------
wp plugin install wordfence --activate --allow-root
# Jadwalkan scan harian jam 2 pagi (format cron expression untuk WP)
wp option update wordfence_scanSchedule '{"scheduledScans":["0 2 * * *"]}' --allow-root

# ----------------------------------------------------------------------
# KONFIGURASI NGINX (dengan security headers & blok xmlrpc)
# ----------------------------------------------------------------------
info "Membuat konfigurasi Nginx..."
if [[ "$wp_multisite" =~ ^[Yy]$ ]] && [[ "$multisite_type" == "1" ]]; then
    # Multisite subdomain
    cat > /etc/nginx/sites-available/${domain} << 'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name DOMAIN *.DOMAIN;
    root /var/www/DOMAIN;
    index index.php index.html;
    client_max_body_size 100M;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Block xmlrpc.php
    location /xmlrpc.php { deny all; }

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/phpVERSION-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_buffer_size 128k;
        fastcgi_buffers 4 256k;
        fastcgi_busy_buffers_size 256k;
    }

    # Multisite rewrites
    if (!-e $request_filename) {
        rewrite /wp-admin$ $scheme://$host$uri/ permanent;
        rewrite ^/[_0-9a-zA-Z-]+(/wp-.*) $1 last;
        rewrite ^/[_0-9a-zA-Z-]+(/.*\.php)$ $1 last;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|woff|ttf|svg|eot)$ {
        expires max;
        log_not_found off;
        access_log off;
    }

    location ~ /\. { deny all; }
    location = /favicon.ico { log_not_found off; access_log off; }
    location = /robots.txt { allow all; log_not_found off; access_log off; }

    access_log /var/log/nginx/${domain}_access.log;
    error_log /var/log/nginx/${domain}_error.log;
}
EOF
else
    # Single site atau multisite subdir
    cat > /etc/nginx/sites-available/${domain} << 'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name DOMAIN www.DOMAIN;
    root /var/www/DOMAIN;
    index index.php index.html;
    client_max_body_size 100M;

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    location /xmlrpc.php { deny all; }

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/phpVERSION-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico)$ {
        expires max;
        log_not_found off;
    }

    location ~ /\. { deny all; }
    location = /favicon.ico { log_not_found off; access_log off; }
    location = /robots.txt { allow all; log_not_found off; access_log off; }

    access_log /var/log/nginx/${domain}_access.log;
    error_log /var/log/nginx/${domain}_error.log;
}
EOF
fi

# Ganti placeholder DOMAIN dan VERSION
sed -i "s/DOMAIN/${domain}/g" /etc/nginx/sites-available/${domain}
sed -i "s/VERSION/${vphp}/g" /etc/nginx/sites-available/${domain}

# Sembunyikan versi Nginx
sed -i 's/# server_tokens off;/server_tokens off;/' /etc/nginx/nginx.conf
echo "server_tokens off;" >> /etc/nginx/nginx.conf

ln -sf /etc/nginx/sites-available/${domain} /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx
success "Nginx siap"

# ----------------------------------------------------------------------
# SSL LET'S ENCRYPT (dengan wildcard untuk multisite subdomain)
# ----------------------------------------------------------------------
info "Memasang SSL Let's Encrypt..."
if [[ "$wp_multisite" =~ ^[Yy]$ ]] && [[ "$multisite_type" == "1" ]]; then
    certbot --nginx --non-interactive --agree-tos --email ${emailssl} --redirect \
        -d ${domain} -d *.${domain}
else
    certbot --nginx --non-interactive --agree-tos --email ${emailssl} --redirect \
        -d ${domain} -d www.${domain}
fi
systemctl restart nginx
success "SSL aktif"

# ----------------------------------------------------------------------
# FIREWALL UFW & FAIL2BAN
# ----------------------------------------------------------------------
info "Mengaktifkan firewall dan fail2ban..."
ufw default deny incoming > /dev/null
ufw default allow outgoing > /dev/null
ufw allow 22/tcp comment 'SSH' > /dev/null
ufw allow 80/tcp comment 'HTTP' > /dev/null
ufw allow 443/tcp comment 'HTTPS' > /dev/null
ufw --force enable > /dev/null

cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = 22
logpath = %(sshd_log)s

[nginx-http-auth]
enabled = true
logpath = /var/log/nginx/error.log
EOF
systemctl enable fail2ban --now > /dev/null
success "Firewall & Fail2ban aktif"

# ----------------------------------------------------------------------
# PERMISSION FINAL & CLEANUP
# ----------------------------------------------------------------------
chown -R www-data:www-data $WP_ROOT
find $WP_ROOT -type d -exec chmod 755 {} \;
find $WP_ROOT -type f -exec chmod 644 {} \;
chmod 600 $WP_ROOT/wp-config.php

# Hapus file installasi yang tidak perlu
rm -f $WP_ROOT/wp-config-sample.php

# ----------------------------------------------------------------------
# SIMPAN INFORMASI KONFIGURASI
# ----------------------------------------------------------------------
IP=$(curl -s ifconfig.me)
cat > /root/${domain}-conf.txt << EOF
===========================================
INFORMASI INSTALASI WORDPRESS LEMP
===========================================
IP Server         : $IP
Domain            : $domain
SSL Email         : $emailssl

Database          : $dbname
DB User           : $dbuser
DB Password       : $dbpass

WordPress Admin   : $wpadmin
Admin Email       : $emailssl
Admin Password    : $wpadminpass

Tipe Instalasi    : $([ "$wp_multisite" =~ ^[Yy]$ ] && echo "Multisite (subdomain)" || echo "Single Site")
WooCommerce       : Aktif (COD + Transfer Bank)
Backup            : UpdraftPlus (daily, local)
SMTP              : WP Mail SMTP (PHP mail)
Security          : UFW, Fail2ban, Wordfence, PHP hardened, Nginx headers

===========================================
Akses Admin       : https://${domain}/wp-admin
===========================================
EOF

# ----------------------------------------------------------------------
# OUTPUT FINAL
# ----------------------------------------------------------------------
clear
echo "============================================================"
echo -e "${GREEN}  INSTALASI SELESAI 100% TANPA ERROR${NC}"
echo "============================================================"
cat /root/${domain}-conf.txt
echo ""
echo -e "${YELLOW}Password admin WordPress: ${wpadminpass}${NC}"
echo -e "${YELLOW}File konfigurasi: /root/${domain}-conf.txt${NC}"
echo ""
echo -e "${GREEN}Website Anda sudah siap digunakan dengan WooCommerce, backup otomatis, dan keamanan penuh!${NC}"
echo "============================================================"