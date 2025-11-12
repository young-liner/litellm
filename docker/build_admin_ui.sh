#!/bin/bash

# # try except this script
# set -e

# print current dir 
echo
pwd


# Check if enterprise UI exists
if [ ! -f "enterprise/enterprise_ui/enterprise_colors.json" ]; then
    echo "Admin UI - Building default LiteLLM UI with environment variables..."
    ENTERPRISE_MODE=false
else
    echo "Building Custom Admin UI (Enterprise mode)..."
    ENTERPRISE_MODE=true
fi

# Install dependencies
# Check if we are on macOS
if [[ "$(uname)" == "Darwin" ]]; then
    # Install dependencies using Homebrew
    if ! command -v brew &> /dev/null; then
        echo "Error: Homebrew not found. Please install Homebrew and try again."
        exit 1
    fi
    brew update
    brew install curl
else
    # Assume Linux, try using apt-get
    if command -v apt-get &> /dev/null; then
        apt-get update
        apt-get install -y curl
    elif command -v apk &> /dev/null; then
        # Try using apk if apt-get is not available
        apk update
        apk add curl
    else
        echo "Error: Unsupported package manager. Cannot install dependencies."
        exit 1
    fi
fi
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash
source ~/.nvm/nvm.sh
nvm install 20
nvm use 20
npm install -g npm

# copy enterprise colors if in enterprise mode
if [ "$ENTERPRISE_MODE" = true ]; then
    cp enterprise/enterprise_ui/enterprise_colors.json ui/litellm-dashboard/ui_colors.json
fi

# cd in to /ui/litellm-dashboard
cd ui/litellm-dashboard

# ensure have access to build_ui.sh
chmod +x ./build_ui.sh

# Export NVM environment and add Node to PATH directly
export NVM_DIR="$HOME/.nvm"
# Find the installed Node 20 version and add to PATH
NODE_VERSION=$(ls $NVM_DIR/versions/node/ | grep '^v20' | sort -V | tail -1)
export PATH="$NVM_DIR/versions/node/$NODE_VERSION/bin:$PATH"

echo "Using Node version: $NODE_VERSION"
echo "Node path: $(which node)"
node --version
npm --version

# run ./build_ui.sh with Node in PATH
./build_ui.sh

# return to root directory
cd ../..