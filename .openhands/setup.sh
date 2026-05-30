#!/bin/bash
# Installation script for KCL CLI

# Check if KCL is already installed
if command -v kcl &> /dev/null; then
    echo "KCL is already installed."
    exit 0
fi

echo "Installing KCL CLI..."
# Using the working command verified in this environment:
wget -q https://kcl-lang.io/script/install-cli.sh -O - | sudo /bin/bash

# Update PATH if necessary (though the script usually handles it or installs to /usr/local/bin)
export PATH="/usr/local/bin:$PATH"

echo "KCL installed successfully. Please check with: kcl version"
