#!/bin/bash
set -e

echo "=== Updating and installing dependencies ==="
sudo apt update -y && sudo apt upgrade -y
sudo apt install -y git nginx python3-pip python3-venv postgresql postgresql-contrib

echo "=== Setting up PostgreSQL ==="
sudo -u postgres psql <<'EOF'
CREATE DATABASE "HR-ATS";
CREATE USER "hari-vicky" WITH PASSWORD 'postgres';
ALTER ROLE "hari-vicky" SET client_encoding TO 'utf8';
ALTER ROLE "hari-vicky" SET default_transaction_isolation TO 'read committed';
ALTER ROLE "hari-vicky" SET timezone TO 'UTC';
GRANT ALL PRIVILEGES ON DATABASE "HR-ATS" TO "hari-vicky";
EOF

echo "=== Configuring Nginx ==="
sudo bash -c 'cat > /etc/nginx/sites-available/myapp << "EOL"
server {
    listen 80;
    server_name 98.80.76.115;

    # Frontend (React/Vite)
    root /var/www/frontend;
    index index.html;

    location / {
        try_files \$uri /index.html;
    }

    # Backend (FastAPI)
    location /api/ {
        proxy_pass http://127.0.0.1:8000/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    client_max_body_size 50M;
}
EOL'

sudo ln -sf /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/


echo "=== Setting up backend systemd service ==="
sudo mkdir -p /var/www/backend
sudo bash -c 'cat > /etc/systemd/system/backend.service << "EOL"
[Unit]
Description=HireHub ATS Backend (FastAPI)
After=network.target

[Service]
User=ubuntu
Group=www-data
WorkingDirectory=/var/www/backend
Environment="PATH=/var/www/backend/.venv/bin"
ExecStart=/var/www/backend/.venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL'

