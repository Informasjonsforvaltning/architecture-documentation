#!/bin/bash

Xvfb :99 -screen 0 1024x768x16 &
export DISPLAY=:99

echo "Searching for .drawio files..."
drawio_files=$(find /workspace/C4 -type f -name "*.drawio")

if [ -z "$drawio_files" ]; then
    echo "No .drawio files found. Exiting."
    exit 0
fi

mkdir -p generated

for drawio_file in $drawio_files; do
    echo "Exporting $drawio_file"
    drawio --no-sandbox --export --format svg --output /workspace/generated "$drawio_file"
done

echo "Export complete"