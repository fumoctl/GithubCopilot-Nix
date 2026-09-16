#!/usr/bin/env nix-shell
#!nix-shell -i bash -p jq curl

set -euo pipefail

cd "$(dirname "$0")/.."

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "Checking GitHub Copilot versions..."
echo ""

VERSIONS_JSON="artifacts/versions.json"

if [[ ! -f "$VERSIONS_JSON" ]]; then
    echo -e "${RED}Error: $VERSIONS_JSON not found. Run update-version.sh first!${NC}"
    exit 1
fi

check_app() {
    local name="$1"
    local repo="$2"

    echo "--- $name ---"

    local current
    current=$(jq -r ".\"$name\".\"x86_64-linux\".url" "$VERSIONS_JSON" 2>/dev/null || echo "")
    if [[ -z "$current" || "$current" == "null" ]]; then
        current="none"
    else
        current=$(echo "$current" | grep -oP 'download/v?\K[0-9.]+' || echo "unknown")
    fi

    echo -e "Current version: $current"

    local auth_header=()
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        auth_header=(-H "Authorization: Bearer $GITHUB_TOKEN")
    elif [[ -n "${GH_TOKEN:-}" ]]; then
        auth_header=(-H "Authorization: Bearer $GH_TOKEN")
    fi

    local latest=""
    latest=$(curl -sL "${auth_header[@]}" "https://api.github.com/repos/$repo/releases/latest" | jq -r '.tag_name' 2>/dev/null || echo "")
    latest="${latest#v}"

    if [[ -n "$latest" && "$latest" != "null" ]]; then
        echo -e "Latest version:  $latest"

        if [[ "$current" == "$latest" ]]; then
            echo -e "${GREEN}✓ Already at latest version!${NC}"
        else
            echo -e "${YELLOW}⚠ Update available!${NC}"
        fi
    else
        echo -e "${RED}Error: Could not parse version from upstream ($repo)${NC}"
    fi
    echo ""
}

check_app "GitHub Copilot Desktop" "github/app"
check_app "GitHub Copilot CLI" "github/copilot-cli"
