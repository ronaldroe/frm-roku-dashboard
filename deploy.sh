#!/usr/bin/env bash
# Package roku-frm/ and sideload it to the Roku defined in .env
set -euo pipefail
cd "$(dirname "$0")"
set -a; . ./.env; set +a
rm -f frm-roku-dashboard.zip
(cd roku-frm && zip -qr ../frm-roku-dashboard.zip manifest source components images sounds)
curl -sS -m 60 --digest -u "$user:$pass" -F "mysubmit=Install" -F "archive=@frm-roku-dashboard.zip" "http://$IP/plugin_install" \
  | grep -oE "Install Success|Identical to previous version|Install Failure[^<\"]*|Compilation Failed[^<\"]*" | sort -u
