#!/bin/bash
# Setup script for vocab GUI app

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Setting up Vocab GUI app..."

OS="$(uname -s)"

if [ "$OS" = "Darwin" ]; then
    # macOS
    if ! command -v brew &>/dev/null; then
        echo "Homebrew is required. Install it from https://brew.sh"
        exit 1
    fi

    echo "Installing system dependencies (Homebrew)..."
    brew install gtk+3 pygobject3 adwaita-icon-theme

elif command -v pacman &>/dev/null; then
    # Arch/Manjaro
    echo "Installing system dependencies (pacman)..."
    sudo pacman -S --noconfirm \
        python-gobject \
        gtk3 \
        libappindicator-gtk3

elif command -v apt &>/dev/null; then
    # Debian/Ubuntu
    echo "Installing system dependencies (apt)..."
    sudo apt install -y \
        python3-gi \
        python3-gi-cairo \
        gir1.2-gtk-3.0 \
        gir1.2-appindicator3-0.1

else
    echo "Unsupported package manager. Please install manually:"
    echo "  - python-gobject, gtk3, libappindicator-gtk3 (Linux)"
    echo "  - gtk+3, pygobject3 (macOS via Homebrew)"
    exit 1
fi

# Create virtual environment (with system site packages for GTK)
echo "Creating virtual environment..."
rm -rf venv
python3 -m venv venv --system-site-packages
source venv/bin/activate
python -m ensurepip --upgrade
pip install --upgrade pip
pip install -r requirements.txt

# Make scripts executable
chmod +x src/vocab_gui.py

echo ""
echo "Setup complete!"
echo ""
echo "To run the app:"
echo "  source venv/bin/activate"
echo "  python3 src/vocab_gui.py"
echo ""
if [ "$OS" = "Darwin" ]; then
    echo "To set up keyboard shortcuts on macOS:"
    echo "  Use System Settings → Keyboard → Shortcuts → Services"
    echo "  or a tool like Hammerspoon / Karabiner."
else
    echo "To start on login, add to your desktop's autostart:"
    echo "  $SCRIPT_DIR/venv/bin/python3 $SCRIPT_DIR/src/vocab_gui.py"
fi
