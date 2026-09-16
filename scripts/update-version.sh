#!/usr/bin/env nix-shell
#!nix-shell -i bash -p jq curl nix

set -euo pipefail

cd "$(dirname "$0")/.."

OUTPUT_JSON="artifacts/versions.json"

log_info() { echo -e "\033[0;32m[INFO]\033[0m $*" >&2; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }

mkdir -p artifacts
if [[ ! -f "$OUTPUT_JSON" ]]; then
    echo "{}" > "$OUTPUT_JSON"
fi

AUTH_HEADER=()
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    AUTH_HEADER=(-H "Authorization: Bearer $GITHUB_TOKEN")
elif [[ -n "${GH_TOKEN:-}" ]]; then
    AUTH_HEADER=(-H "Authorization: Bearer $GH_TOKEN")
fi

# 1. Fetch latest desktop version from github releases
log_info "Fetching latest GitHub Copilot Desktop version..."
DESKTOP_TAG=$(curl -sL "${AUTH_HEADER[@]}" "https://api.github.com/repos/github/app/releases/latest" | jq -r '.tag_name')
DESKTOP_VER="${DESKTOP_TAG#v}"

# 2. Fetch latest CLI version from github releases
log_info "Fetching latest GitHub Copilot CLI version..."
CLI_TAG=$(curl -sL "${AUTH_HEADER[@]}" "https://api.github.com/repos/github/copilot-cli/releases/latest" | jq -r '.tag_name')
CLI_VER="${CLI_TAG#v}"

if [[ -z "$DESKTOP_VER" || "$DESKTOP_VER" == "null" ]]; then log_error "Failed to fetch Desktop version"; exit 1; fi
if [[ -z "$CLI_VER" || "$CLI_VER" == "null" ]]; then log_error "Failed to fetch CLI version"; exit 1; fi

get_hash() {
    local url=$1
    nix-prefetch-url --type sha256 "$url" || echo ""
}

# Process desktop app
process_desktop() {
    local current_url=$(jq -r '."GitHub Copilot Desktop"."x86_64-linux".url' "$OUTPUT_JSON" 2>/dev/null || echo "null")
    local current_version=$(echo "$current_url" | grep -oP 'download/v?\K[0-9.]+' || echo "unknown")

    if [[ "$current_version" == "$DESKTOP_VER" ]]; then
        log_info "GitHub Copilot Desktop is already at latest version ($DESKTOP_VER). Skipping..."
    else
        log_info "Updating GitHub Copilot Desktop to $DESKTOP_VER..."
        local platforms=(
            "x86_64-linux:x64"
            "aarch64-linux:arm64"
        )
        local payload="{}"
        for plat in "${platforms[@]}"; do
            IFS=':' read -r nix_os api_arch <<< "$plat"
            log_info "Prefetching hash for Desktop ($nix_os)..."
            local url="https://github.com/github/app/releases/download/v${DESKTOP_VER}/GitHub-Copilot-linux-${api_arch}.AppImage"
            local hash=$(get_hash "$url")
            if [[ -z "$hash" ]]; then
                log_error "Failed to prefetch hash for $url"
                exit 1
            fi
            payload=$(echo "$payload" | jq --arg plat "$nix_os" --arg url "$url" --arg hash "$hash" \
                '.[$plat] = {url: $url, hash: $hash}')
        done
        local tmp_json=$(mktemp)
        jq --argjson payload "$payload" '.["GitHub Copilot Desktop"] = $payload' "$OUTPUT_JSON" > "$tmp_json"
        mv "$tmp_json" "$OUTPUT_JSON"
    fi
}

# Process CLI
process_cli() {
    local current_url=$(jq -r '."GitHub Copilot CLI"."x86_64-linux".url' "$OUTPUT_JSON" 2>/dev/null || echo "null")
    local current_version=$(echo "$current_url" | grep -oP 'download/v?\K[0-9.]+' || echo "unknown")

    if [[ "$current_version" == "$CLI_VER" ]]; then
        log_info "GitHub Copilot CLI is already at latest version ($CLI_VER). Skipping..."
    else
        log_info "Updating GitHub Copilot CLI to $CLI_VER..."
        local platforms=(
            "x86_64-linux:x64"
            "aarch64-linux:arm64"
        )
        local payload="{}"
        for plat in "${platforms[@]}"; do
            IFS=':' read -r nix_os api_arch <<< "$plat"
            log_info "Prefetching hash for CLI ($nix_os)..."
            local url="https://github.com/github/copilot-cli/releases/download/v${CLI_VER}/copilot-linux-${api_arch}.tar.gz"
            local hash=$(get_hash "$url")
            if [[ -z "$hash" ]]; then
                log_error "Failed to prefetch hash for $url"
                exit 1
            fi
            payload=$(echo "$payload" | jq --arg plat "$nix_os" --arg url "$url" --arg hash "$hash" \
                '.[$plat] = {url: $url, hash: $hash}')
        done
        local tmp_json=$(mktemp)
        jq --argjson payload "$payload" '.["GitHub Copilot CLI"] = $payload' "$OUTPUT_JSON" > "$tmp_json"
        mv "$tmp_json" "$OUTPUT_JSON"
    fi
}

process_desktop
process_cli

log_info "Done! Updated $OUTPUT_JSON"
