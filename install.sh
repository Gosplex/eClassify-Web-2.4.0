#!/bin/bash

set -e

# Function to display status messages
status_message() {
    echo "==== $1 ===="
}

# Check for required dependencies
for cmd in curl wget sudo; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd is not installed" >&2
        exit 1
    fi
done

# Install NVM if not already installed
if ! command -v nvm &> /dev/null; then
    status_message "Installing NVM"
    wget -O nvm.sh https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh
    bash nvm.sh
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
fi

# Install and use Node.js 20
status_message "Installing Node.js"
nvm install 20
nvm use 20

# Install PM2 if not already installed
if ! command -v pm2 &> /dev/null; then
    status_message "Installing PM2"
    npm install -g pm2
fi

# Function to find an available port
find_available_port() {
    for port in $(seq 8003 8010); do
        if ! sudo lsof -i :$port > /dev/null 2>&1; then
            echo $port
            return 0
        fi
    done
    echo "No available ports found between 8003 and 8010" >&2
    return 1
}

# Find an available port
status_message "Finding an available port"
PORT=$(find_available_port)
if [ $? -ne 0 ]; then
    exit 1
fi
echo "Found available port: $PORT"

# Update .htaccess file
status_message "Updating .htaccess file"
if ! grep -q "http://127.0.0.1:[0-9]*/" .htaccess; then
    echo "Error: .htaccess does not contain the expected pattern" >&2
    exit 1
fi
sed -i "s|http://127.0.0.1:[0-9]*/|http://127.0.0.1:$PORT/|g" .htaccess

# Update package.json file
status_message "Updating package.json file"
if ! grep -q "NODE_PORT=" package.json; then
    echo "Error: package.json does not contain the expected NODE_PORT variable" >&2
    exit 1
fi
sed -i "s/NODE_PORT=*[0-9]*/NODE_PORT=$PORT/" package.json

# Install project dependencies
status_message "Installing project dependencies"
npm install

# Build the project
status_message "Building the project"
npm run build

# Start the project with PM2
status_message "Starting the project with PM2"
APP_NAME="eClassify_$PORT"
pm2 start npm --name "$APP_NAME" -- start

# Display PM2 processes
status_message "Displaying PM2 processes"
pm2 ls

status_message "Installation and deployment complete!"
