#!/bin/bash
# setup-wapps.sh — provision wapps from wapps.conf
# Usage: ./setup-wapps.sh [path/to/wapps.conf]
# Defaults to wapps.conf in same directory as this script
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF="${1:-$SCRIPT_DIR/wapps.conf}"

if [[ ! -f "$CONF" ]]; then
  echo "Config not found: $CONF"
  echo "Copy wapps.conf.example to wapps.conf and edit it."
  exit 1
fi

# shellcheck source=wapps.conf
source "$CONF"

info()  { echo -e "\e[32m$*\e[0m"; }
warn()  { echo -e "\e[33m$*\e[0m"; }

WAPP_DATA_DIR="$HOME/.local/share/wapp"
WAPP_ICON_DIR="$HOME/.local/share/applications/icons"

# ─── Extension installer ────────────────────────────────────────────────────

install_extensions() {
  local browser="$1"
  shift
  local extensions=("$@")
  [[ ${#extensions[@]} -eq 0 ]] && return 0

  echo ""
  info "Installing extensions for $browser..."

  for entry in "${extensions[@]}"; do
    IFS='|' read -r ext_id ext_name <<< "$entry"
    echo "  → $ext_name ($ext_id)"
    case "$browser" in
      brave)
        command -v brave-origin-nightly &>/dev/null \
          && brave-origin-nightly --install-extension="$ext_id" 2>/dev/null \
          || warn "  ⚠ Failed to install $ext_name"
        ;;
      whale)
        command -v naver-whale-stable &>/dev/null \
          && naver-whale-stable --install-extension="$ext_id" 2>/dev/null \
          || warn "  ⚠ Failed to install $ext_name"
        ;;
    esac
  done
}

# ─── Main ────────────────────────────────────────────────────────────────────

echo ""
info "Creating ${#WAPPS[@]} wapps..."

for entry in "${WAPPS[@]}"; do
  IFS='|' read -r name url browser <<< "$entry"
  echo "  → $name ($browser)"
  wapp create "$name" "$url" "$browser" 2>/dev/null || warn "  ⚠ ${name} already exists, skipping"
done

echo ""
info "Applying custom icons..."

for entry in "${CUSTOM_ICONS[@]}"; do
  IFS='|' read -r name icon_url <<< "$entry"
  if curl -fsSL -o "$WAPP_ICON_DIR/wapp-${name}.png" "$icon_url" 2>/dev/null \
    && [[ -s "$WAPP_ICON_DIR/wapp-${name}.png" ]]; then
    echo "  → $name: $icon_url"
  else
    warn "  ⚠ Failed to fetch icon for $name"
  fi
done

install_extensions "brave" "${BRAVE_EXTENSIONS[@]}"
install_extensions "whale" "${WHALE_EXTENSIONS[@]}"

# Per-wapp extensions (into isolated profile)
if [[ ${#WAPP_EXTENSIONS[@]} -gt 0 ]]; then
  echo ""
  info "Installing per-wapp extensions..."

  for entry in "${WAPP_EXTENSIONS[@]}"; do
    IFS='|' read -r wapp_name ext_id ext_name <<< "$entry"
    profile_dir="$WAPP_DATA_DIR/$wapp_name"
    if [[ ! -d "$profile_dir" ]]; then
      warn "  ⚠ Wapp '$wapp_name' not found, skipping $ext_name"
      continue
    fi
    echo "  → $wapp_name: $ext_name ($ext_id)"
    # Detect browser from WAPPS array
    browser=""
    for w in "${WAPPS[@]}"; do
      IFS='|' read -r w_name _ w_browser <<< "$w"
      [[ "$w_name" == "$wapp_name" ]] && browser="$w_browser" && break
    done
    case "$browser" in
      brave)
        brave-origin-nightly --user-data-dir="$profile_dir" --install-extension="$ext_id" 2>/dev/null \
          || warn "  ⚠ Failed to install $ext_name"
        ;;
      whale)
        naver-whale-stable --user-data-dir="$profile_dir" --install-extension="$ext_id" 2>/dev/null \
          || warn "  ⚠ Failed to install $ext_name"
        ;;
    esac
  done
fi

echo ""
info "Done. Run: wapp list"
echo ""
