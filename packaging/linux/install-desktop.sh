#!/bin/bash
# Simple Player — Install .desktop file and icons for file association
# Run this once after extracting the tar.gz to enable double-click-to-open.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APPLICATIONS_DIR="$HOME/.local/share/applications"
ICONS_DIR="$HOME/.local/share/icons/hicolor"

# Create directories
mkdir -p "$APPLICATIONS_DIR"
mkdir -p "$ICONS_DIR"/{16x16,32x32,48x48,64x64,128x128,256x256,512x512}/apps

# Update .desktop Exec to use absolute path
DESKTOP_FILE="$APPLICATIONS_DIR/simple-player.desktop"
sed "s|Exec=.*|Exec=$SCRIPT_DIR/simple-player.sh %U|" "$SCRIPT_DIR/simple-player.desktop" > "$DESKTOP_FILE"
chmod +x "$DESKTOP_FILE"

# Install icons
for size in 16 32 48 64 128 256 512; do
  if [ -f "$SCRIPT_DIR/icons/${size}x${size}/simple-player.png" ]; then
    cp "$SCRIPT_DIR/icons/${size}x${size}/simple-player.png" "$ICONS_DIR/${size}x${size}/apps/simple-player.png"
  fi
done
if [ -f "$SCRIPT_DIR/icons/simple-player.svg" ]; then
  mkdir -p "$ICONS_DIR/scalable/apps"
  cp "$SCRIPT_DIR/icons/simple-player.svg" "$ICONS_DIR/scalable/apps/simple-player.svg"
fi

# Update desktop database
update-desktop-database "$APPLICATIONS_DIR" 2>/dev/null || true
gtk-update-icon-cache "$ICONS_DIR" 2>/dev/null || true

echo "Simple Player installed successfully!"
echo "You can now double-click media files to open them in Simple Player."
