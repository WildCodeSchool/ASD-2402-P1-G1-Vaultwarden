#!/bin/bash
#-------------------------------
# TODO
# ------------------------------
# apt-get install -qq -o=Dpkg::Use-Pty=0 <packages>
# Use the above command to make the packages install silent

# Declaration variables pour logging
dir="/tmp/install_log.txt"
install_date="$(date +'%Y_%m_%d')"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit
fi

# Variables
nginx_conf="/etc/nginx/sites-available/default"
apache_port_conf="/etc/apache2/ports.conf"
apache_vaultwarden="/etc/apache2/route/vers/vaultwarden"
domaine="notre.domaine.v6.rocks"  # Replace with our domaine
dynv6_token="" # Penser a resegner notre token

# Update package lists
echo "Updating package lists..."
apt update

# Install Nginx and Apache if not already installed
echo "Installing Nginx ..."
apt install -y nginx apache2 apt-utils autoconf automake build-essential git libcurl4-openssl-dev libgeoip-dev liblmdb-dev libpcre++-dev libtool libxml2-dev libyajl-dev pkgconf wget zlib1g-dev certbot
echo -e "Installation des packages pour Nginx Apache et Modprobe realisee.\n" >> $dir

# Mise en pause de Nginx et Apache pendant leur configuration / Stop Nginx and Apache2 before installing and setting up the config for modsecurity
systemctl stop nginx
systemctl stop apache2

##################################
########### Certbot  WIP ##############
##################################
certbot certonly --manual --preferred-challenges dns -d "*.$domaine" -d $domaine
echo -e "Certificat recupere.\n" >> $dir

# Configure Nginx
echo "Configuring Nginx as a reverse proxy..."
cat > "$nginx_conf" <<EOF
server {
    listen 80;
    server_name $domaine;

    access_log /var/log/nginx/access.log;
    
    modsecurity on;
    modsecurity_rules_file /etc/nginx/modsec/main.conf;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
echo -e "Parametrage Nginx reverse proxy et preparation Modprobe.\n" >> $dir

# Configure Apache to listen on port 8080
echo "Configuring Apache to listen on port 8080..."
sed -i 's/Listen 80/Listen 8080/' "$apache_port_conf"

# Update Apache Virtual Host to use port 8080
echo "Updating Apache Virtual Host configuration..."
sed -i 's/<VirtualHost \*:80>/<VirtualHost \*:8080>/' "$apache_vaultwarden"
echo -e "Configuration de Apache OK.\n" >> $dir

# Recuperation et installation de ModSecurity
git clone --depth 1 -b v3/master --single-branch https://github.com/SpiderLabs/ModSecurity /usr/local/src
cd /usr/local/src/ModSecurity/
git submodule init
git submodule update --remote
./build.sh
./configure
make
make install

# Module ModSecurity pour Nginx
git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git /usr/local/src
nginx_vers=$(nginx -v 2>&1 | awk -F'/' '{print $2}')
wget http://nginx.org/download/nginx-$nginx_vers.tar.gz
tar zxvf nginx-$nginx_vers.tar.gz
cd nginx-$nginx_vers/
./configure --with-compat --add-dynamic-module=../ModSecurity-nginx
make modules
cp /usr/local/src/nginx-$nginx_vers/objs/ngx_http_modsecurity_module.so /etc/nginx/modules/
echo -e "Recuperation et compilation de Modprobe OK.\n" >> $dir

# Ajout du load module a la conf Nginx
sed -i '/include \/etc\/nginx\/modules-enabled\/\*\.conf;/a load_module \/etc\/nginx\/modules\/ngx_http_modsecurity_module.so;' /etc/nginx/nginx.conf

# Configuration ModSecurity
mkdir /etc/nginx/modsec
wget -P /etc/nginx/modsec/ https://raw.githubusercontent.com/SpiderLabs/ModSecurity/v3/master/modsecurity.conf-recommended
mv /etc/nginx/modsec/modsecurity.conf-recommended /etc/nginx/modsec/modsecurity.conf
cp /usr/local/src/ModSecurity/unicode.mapping /etc/nginx/modsec/

sed -i 's/DetectionOnly/On/' /etc/nginx/modsec/modsecurity.conf

echo -e "Include \"/etc/nginx/modsec/modsecurity.conf\"" > /etc/nginx/modsec/main.conf

# OWASP Ruleset v3.2
cd /usr/local/src
wget https://github.com/SpiderLabs/owasp-modsecurity-crs/archive/refs/tags/v3.2.0.tar.gz
tar -xzvf v3.2.0.tar.gz
cd owasp-modsecurity-crs-3.2.0/
cp crs-setup.conf.example crs-setup.conf
echo -e "Application des regles de securite de base OWASP.\n" >> $dir

#################################################################
##### choix du site a surveiller/ liste d esceptions ajouter ####
#################################################################

# Restart services and enable Nginx and Apache2
echo "Restarting Nginx and Apache services..."
systemctl enable nginx
systemctl enable apache2
systemctl restart nginx
systemctl restart apache2

echo "Nginx as a reverse proxy to Apache is now set up."
