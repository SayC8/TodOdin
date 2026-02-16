#!/usr/bin/env sh

set -e

odin build . -out:tododin

if [ -f tododin ]; then
    BINARY_PATH="$(pwd)/tododin"

    echo "Creating symbolic link: /usr/bin/tododin"

    sudo ln -sf "$BINARY_PATH" /usr/bin/tododin

    if [ -f /usr/bin/tododin ]; then
        echo "Success! You can now run 'tododin' from anywhere."
    else
        echo "Fail: Link was not created."
    fi
else
    echo "Error: Failed to find tododin binary. Check if 'odin build succeeded.'"
fi
