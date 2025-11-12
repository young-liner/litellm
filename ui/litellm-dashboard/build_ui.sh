#!/bin/bash

# Note: This script expects Node to be already in PATH by build_admin_ui.sh
# Verify Node.js version
echo ""
echo "==================================="
echo "Building LiteLLM Admin UI"
echo "==================================="
echo "Node version: $(node --version)"
echo "npm version: $(npm --version)"
echo ""

# print contents of ui_colors.json
echo "UI Colors configuration:"
cat ui_colors.json
echo ""

# Set environment variable
export NEXT_PUBLIC_HIDE_USAGE_INDICATOR=true

echo "Environment variables:"
echo "  NEXT_PUBLIC_HIDE_USAGE_INDICATOR=${NEXT_PUBLIC_HIDE_USAGE_INDICATOR}"
echo ""

# Install dependencies
echo "Installing npm dependencies..."
npm install

# Run npm build
echo ""
echo "Building Next.js application..."
npm run build

# Check if the build was successful
if [ $? -eq 0 ]; then
  echo "Build successful. Copying files..."

  # echo current dir
  echo
  pwd

  # Specify the destination directory
  destination_dir="../../litellm/proxy/_experimental/out"

  # Remove existing files in the destination directory
  rm -rf "$destination_dir"/*

  # Copy the contents of the output directory to the specified destination
  cp -r ./out/* "$destination_dir"

  rm -rf ./out

  echo "Deployment completed."
else
  echo "Build failed. Deployment aborted."
fi
