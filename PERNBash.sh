#!/bin/bash

db_name='demo_dp'
db_passwd='123456'

install_nodejs() {
    echo "Installing Node.js..."
    sudo apt -y install curl
    curl -sL https://deb.nodesource.com/setup_14.x | sudo bash -
    sudo apt -y install nodejs
    node -v && echo "Node.js installed successfully"
}

configure_network() {
    echo "Configuring network..."
    dev_name=$(nmcli device show | head -n 9 | grep 'GENERAL.CONNECTION:' | sed "s/^GENERAL\.CONNECTION: *//g")
    ip_add=$(nmcli device show | head -n 15 | grep 'IP4.ADDRESS' | awk '{print $2}')
    gateway=$(nmcli device show | head -n 15 | grep 'IP4.GATEWAY' | awk '{print $2}')
    sudo nmcli connection modify "$dev_name" ipv4.method manual ipv4.addresses "$ip_add" ipv4.gateway "$gateway" ipv4.dns 1.1.1.1
    sudo nmcli connection down "$dev_name"
    sudo nmcli connection up "$dev_name"
    echo "Network configured successfully"
    ip_add=$(echo "$ip_add" | awk -F '/' '{print $1}')
}

setup_database() {
    echo "Configuring database..."
    sudo apt install postgresql postgresql-contrib
    sudo systemctl start postgresql.service
    sudo -u postgres psql -c "CREATE USER $db_name WITH PASSWORD '$db_passwd';"
    sudo -u postgres psql -c "CREATE DATABASE $db_name;"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $db_name TO $db_name;"
    sudo -u postgres psql $db_name -c "ALTER SYSTEM SET listen_addresses = '0.0.0.0';"
    sudo -u postgres psql $db_name -c "ALTER SYSTEM SET port = 5432;"
    sudo -u postgres psql $db_name -c "SELECT pg_reload_conf();"
    sudo bash -c "echo 'host    $db_name     $db_name     0.0.0.0/0    md5' >> /etc/postgresql/12/main/pg_hba.conf"
    sudo systemctl restart postgresql.service
    echo "Database configured successfully"
}

build_ui() {
    echo "Building UI..."
    npm install && npm run build && echo "UI built successfully"
}

build_api() {
    echo "Building API..."
    sed -i "s|localhost|$ip_add|g" webpack.config.js
    sed -i "s|bhargavbachina|$db_name|g" webpack.config.js
    sed -i "s|''|$db_passwd|g" webpack.config.js
    npm install && ENVIRONMENT=test npm run build && echo "API built successfully"
}

# Main script
sudo apt update
sudo apt install git
git clone https://github.com/omarmohsen/pern-stack-example.git
cd pern-stack-example

install_nodejs
configure_network
setup_database

cd ui
build_ui

cd ../api
build_api

cd ..
npm install pg
cp -r api/dist/* .
cp api/swagger.css .

echo "Application URL: http://$ip_add:3080"
node api.bundle.js
