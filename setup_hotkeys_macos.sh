#!/bin/bash
# Setup macOS global keyboard shortcuts for vocab_app CLI commands.
#
# This creates Automator "Quick Actions" (Services) for each command,
# then tells you how to assign keyboard shortcuts in System Settings.
#
# Hotkey-able commands:
#   --save    Save word from clipboard/selection
#   --delete  Delete the last saved word
#   --next    Show next review word

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON="$SCRIPT_DIR/venv/bin/python3"
CLI="$SCRIPT_DIR/src/vocab_cli.py"
SERVICES_DIR="$HOME/Library/Services"

if [ "$(uname -s)" != "Darwin" ]; then
    echo "ERROR: This script is for macOS only."
    exit 1
fi

if [ ! -x "$PYTHON" ]; then
    echo "ERROR: venv not found. Run setup.sh first."
    exit 1
fi

# Ensure terminal-notifier is installed (osascript notifications are silently
# blocked on newer macOS unless Script Editor is explicitly allowed)
if ! command -v terminal-notifier &>/dev/null; then
    echo "Installing terminal-notifier (required for notifications)..."
    brew install terminal-notifier
fi

create_service() {
    local name="$1"
    local flag="$2"
    local workflow_dir="$SERVICES_DIR/${name}.workflow"
    local contents_dir="$workflow_dir/Contents"

    if [ -d "$workflow_dir" ]; then
        echo "  Replacing existing: $name"
        rm -rf "$workflow_dir"
    fi

    mkdir -p "$contents_dir"

    # Info.plist - defines this as a Service (Quick Action) with no input
    cat > "$contents_dir/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSServices</key>
    <array>
        <dict>
            <key>NSMenuItem</key>
            <dict>
                <key>default</key>
                <string>WORKFLOW_NAME</string>
            </dict>
            <key>NSMessage</key>
            <string>runWorkflowAsService</string>
        </dict>
    </array>
</dict>
</plist>
PLIST
    sed -i '' "s/WORKFLOW_NAME/$name/" "$contents_dir/Info.plist"

    # document.wflow - the Automator workflow definition
    cat > "$contents_dir/document.wflow" << WFLOW
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AMApplicationBuild</key>
    <string>523</string>
    <key>AMApplicationVersion</key>
    <string>2.10</string>
    <key>AMDocumentVersion</key>
    <string>2</string>
    <key>actions</key>
    <array>
        <dict>
            <key>action</key>
            <dict>
                <key>AMAccepts</key>
                <dict>
                    <key>Container</key>
                    <string>List</string>
                    <key>Optional</key>
                    <true/>
                    <key>Types</key>
                    <array>
                        <string>com.apple.cocoa.string</string>
                    </array>
                </dict>
                <key>AMActionVersion</key>
                <string>2.0.3</string>
                <key>AMApplication</key>
                <array>
                    <string>Automator</string>
                </array>
                <key>AMBundleIdentifier</key>
                <string>com.apple.RunShellScript</string>
                <key>AMCategory</key>
                <array>
                    <string>AMCategoryUtilities</string>
                </array>
                <key>AMIconName</key>
                <string>Automator</string>
                <key>AMKeywords</key>
                <array>
                    <string>Shell</string>
                    <string>Script</string>
                </array>
                <key>AMName</key>
                <string>Run Shell Script</string>
                <key>AMProvides</key>
                <dict>
                    <key>Container</key>
                    <string>List</string>
                    <key>Types</key>
                    <array>
                        <string>com.apple.cocoa.string</string>
                    </array>
                </dict>
                <key>ActionBundlePath</key>
                <string>/System/Library/Automator/Run Shell Script.action</string>
                <key>ActionName</key>
                <string>Run Shell Script</string>
                <key>ActionParameters</key>
                <dict>
                    <key>COMMAND_STRING</key>
                    <string>export PATH="/usr/local/bin:/opt/homebrew/bin:\$PATH"
cd "$SCRIPT_DIR"
"$PYTHON" "$CLI" $flag</string>
                    <key>CheckedForUserDefaultShell</key>
                    <true/>
                    <key>inputMethod</key>
                    <integer>1</integer>
                    <key>shell</key>
                    <string>/bin/bash</string>
                    <key>source</key>
                    <string></string>
                </dict>
                <key>BundleIdentifier</key>
                <string>com.apple.Automator.RunShellScript</string>
                <key>CFBundleVersion</key>
                <string>2.0.3</string>
                <key>CanShowSelectedItemsWhenRun</key>
                <false/>
                <key>CanShowWhenRun</key>
                <true/>
                <key>Category</key>
                <array>
                    <string>AMCategoryUtilities</string>
                </array>
                <key>Class Name</key>
                <string>RunShellScriptAction</string>
                <key>InputUUID</key>
                <string>00000000-0000-0000-0000-000000000000</string>
                <key>Keywords</key>
                <array>
                    <string>Shell</string>
                    <string>Script</string>
                </array>
                <key>OutputUUID</key>
                <string>00000000-0000-0000-0000-000000000001</string>
                <key>UUID</key>
                <string>00000000-0000-0000-0000-000000000002</string>
                <key>UnlocalizedApplications</key>
                <array>
                    <string>Automator</string>
                </array>
                <key>arguments</key>
                <dict>
                    <key>0</key>
                    <dict>
                        <key>default value</key>
                        <integer>0</integer>
                        <key>name</key>
                        <string>inputMethod</string>
                        <key>required</key>
                        <string>0</string>
                        <key>type</key>
                        <integer>0</integer>
                        <key>uuid</key>
                        <string>0</string>
                    </dict>
                    <key>1</key>
                    <dict>
                        <key>default value</key>
                        <string></string>
                        <key>name</key>
                        <string>source</string>
                        <key>required</key>
                        <string>0</string>
                        <key>type</key>
                        <integer>0</integer>
                        <key>uuid</key>
                        <string>1</string>
                    </dict>
                    <key>2</key>
                    <dict>
                        <key>default value</key>
                        <false/>
                        <key>name</key>
                        <string>CheckedForUserDefaultShell</string>
                        <key>required</key>
                        <string>0</string>
                        <key>type</key>
                        <integer>0</integer>
                        <key>uuid</key>
                        <string>2</string>
                    </dict>
                    <key>3</key>
                    <dict>
                        <key>default value</key>
                        <string></string>
                        <key>name</key>
                        <string>COMMAND_STRING</string>
                        <key>required</key>
                        <string>0</string>
                        <key>type</key>
                        <integer>0</integer>
                        <key>uuid</key>
                        <string>3</string>
                    </dict>
                    <key>4</key>
                    <dict>
                        <key>default value</key>
                        <string>/bin/sh</string>
                        <key>name</key>
                        <string>shell</string>
                        <key>required</key>
                        <string>0</string>
                        <key>type</key>
                        <integer>0</integer>
                        <key>uuid</key>
                        <string>4</string>
                    </dict>
                </dict>
                <key>isViewVisible</key>
                <integer>1</integer>
            </dict>
        </dict>
    </array>
    <key>connectors</key>
    <dict/>
    <key>workflowMetaData</key>
    <dict>
        <key>serviceApplicationBundleID</key>
        <string>com.apple.finder</string>
        <key>serviceApplicationPath</key>
        <string>/System/Library/CoreServices/Finder.app</string>
        <key>serviceInputTypeIdentifier</key>
        <string>com.apple.Automator.nothing</string>
        <key>serviceProcessesInput</key>
        <integer>0</integer>
        <key>workflowTypeIdentifier</key>
        <string>com.apple.Automator.servicesMenu</string>
    </dict>
</dict>
</plist>
WFLOW

    echo "  Created: $name"
}

echo "Creating Automator Quick Actions (Services)..."
echo ""

create_service "Vocab - Save Word"    "--save"
create_service "Vocab - Delete Word"  "--delete"
create_service "Vocab - Next Word"    "--next"

echo ""
echo "Registering keyboard shortcuts..."
# @ = Cmd, ^ = Ctrl, $ = Shift
# Cmd+Ctrl+S for Save, Cmd+Shift+Ctrl+D for Delete, Cmd+Shift+Ctrl+N for Next
# (Cmd+Ctrl+D/N conflict with system shortcuts, so we add Shift)
defaults write pbs NSServicesStatus '{
    "(null) - Vocab - Save Word - runWorkflowAsService" = {
        "enabled_context_menu" = 1;
        "enabled_services_menu" = 1;
        "key_equivalent" = "@$^s";
    };
    "(null) - Vocab - Delete Word - runWorkflowAsService" = {
        "enabled_context_menu" = 1;
        "enabled_services_menu" = 1;
        "key_equivalent" = "@$^d";
    };
    "(null) - Vocab - Next Word - runWorkflowAsService" = {
        "enabled_context_menu" = 1;
        "enabled_services_menu" = 1;
        "key_equivalent" = "@$^n";
    };
}'

/System/Library/CoreServices/pbs -flush 2>/dev/null

echo ""
echo "Done! Keyboard shortcuts are active:"
echo "  Cmd+Shift+Ctrl+S   - Save word from clipboard"
echo "  Cmd+Shift+Ctrl+D   - Delete last saved word"
echo "  Cmd+Shift+Ctrl+N   - Show next review word"
echo ""
echo "To customize shortcuts: System Settings > Keyboard > Keyboard Shortcuts > Services"
echo ""
echo "Troubleshooting:"
echo "  - Hotkey plays a 'bonk' sound / does nothing:"
echo "      Your shortcut likely conflicts with a system or app shortcut."
echo "      Re-run this script after editing the key_equivalent values, or"
echo "      change them in System Settings > Keyboard > Keyboard Shortcuts > Services."
echo "      Avoid Cmd+Ctrl+D and Cmd+Ctrl+N as they conflict with macOS defaults."
echo "  - No notification appears but hotkey is recognized:"
echo "      Make sure terminal-notifier is installed: brew install terminal-notifier"
echo "      macOS silently blocks osascript notifications unless Script Editor is"
echo "      explicitly allowed in System Settings > Notifications (often not listed)."
echo "  - Services not listed in System Settings:"
echo "      Flush the services cache: /System/Library/CoreServices/pbs -flush"
echo "      Then log out and back in, or re-run this script."
echo "  - Test a workflow directly from Terminal:"
echo "      automator -i '' ~/Library/Services/Vocab\\ -\\ Next\\ Word.workflow"
echo "  - Test the CLI command directly:"
echo "      ./venv/bin/python3 src/vocab_cli.py --next"
