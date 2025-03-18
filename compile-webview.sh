#! /bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Print commands being executed
set -x

# Change to the gephgui directory
cd ./gephgui

# Source bash environment (for nvm, etc.)
source ~/.bashrc

# Install dependencies and build the WebView UI
pnpm i
pnpm build

# Create the dist directory in Geph if it doesn't exist
mkdir -p ../Geph/dist

# Copy the built WebView files to the iOS project
rsync -r dist/ ../Geph/dist/

echo "WebView compilation completed successfully!"