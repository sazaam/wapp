#!/bin/bash
# export-wapps.sh — export current wapp state to wapps.conf
# Reads existing wapps.conf for manual overrides (icons, extensions),
# then updates with actual state from disk.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF="${1:-$SCRIPT_DIR/wapps.conf}"
WAPP_BIN_DIR="$HOME/.local/bin"
WAPP_DATA_DIR="$HOME/.local/share/wapp"

# Load existing config if present
WAPPS=()
CUSTOM_ICONS=()
WAPP_EXTENSIONS=()
BRAVE_EXTENSIONS=()
WHALE_EXTENSIONS=()

if [[ -f "$CONF" ]]; then
  # shellcheck source=/dev/null
  source "$CONF"
fi

info()  { echo -e "\e[32m$*\e[0m"; }

# ─── Scan wapps from disk ────────────────────────────────────────────────────

scan_wapps() {
  local wapps=()
  for script in "$WAPP_BIN_DIR"/wapp-*; do
    [[ ! -f "$script" ]] && continue
    local basename="${script##*/}"
    local name="${basename#wapp-}"
    [[ "$name" == "list" || "$name" == "open" || "$name" == "create" \
       || "$name" == "remove" || "$name" == "recreate" || "$name" == "help" ]] && continue

    local exec_line binary browser url
    exec_line=$(sed -n '2p' "$script")
    exec_line=${exec_line#exec }
    binary=${exec_line%% *}

    case "$binary" in
      brave-origin-nightly) browser="brave" ;;
      naver-whale-stable) browser="whale" ;;
      firefox) browser="firefox" ;;
      chromium) browser="chromium" ;;
      google-chrome) browser="chrome" ;;
      *) browser="unknown" ;;
    esac

    url=$(echo "$exec_line" | grep -oP '(?<=--app=)\S+' || true)
    [[ -z "$url" ]] && url=$(echo "$exec_line" | grep -oP 'https?://\S+' || true)

    [[ -n "$url" ]] && wapps+=("${name}|${url}|${browser}")
  done
  echo "${wapps[@]}"
}

# ─── Scan extensions per profile ─────────────────────────────────────────────

BUILTIN_EXTENSIONS=(
  "ahfgeienlihckogmohjhadlkjgocpleb" "mhjfbmdgcfjbbpaeojofohoefgiehjai"
  "mnojpmjdmbbfmejpflffifhffcmidifd" "fdpohaocaechififmbbbbbknoalclacl"
  "neajdppkdcdipfbeoofafhjkbkjnlbk" "pjkljhegncennknbmhfbgbiggbmiepg"
  "aapocclcgogkmnckokdopfmhonfmcmek" "aohghmighlieiainnegkcijnfilokake"
  "apdfllppoahlniclaingbgjnafhcmkan" "bkdmghcnlambdainedmljpbmmbbhhjcc"
  "nmmhkkegagpkoinklcepmbhmgedglgmn" "pkedcjkdefgpdelpbbmbhmmgmfbnpded"
  "dkkdiokeigcbopfigidddbnnnbblehml" "bonlhblgmnpcjconpnaddapfnmjgbdnc"
  "cdmndoffngimeoghpejdfnjkginocmek" "gohonnnhbmdgbhanlafhmgikmpohffdd"
  "jgjgpgbaffoejkfmijhglelbgkicndhp" "nmdpmoaagfemfffpbmgmnjbefpkkpbpe"
  "pgbmogfigpngnbilikhdjphemfpdmnhl" "loboidpmlojcalnkgelcncghllmkiico"
  "amgfkjigpkckdheobbnbbokjoibhklhc" "dmgimndcbfpchhldjbjjicafhjphpdan"
  "bfbmjmiodbnnpllbbbfblcplfjjepjdn"
)

scan_extensions() {
  local profile_dir="$1"
  local ext_list=()
  local ext_dir="$profile_dir/Default/Extensions"
  [[ ! -d "$ext_dir" ]] && return 0

  for eid in "$ext_dir"/*; do
    [[ ! -d "$eid" ]] && continue
    local ext_id="${eid##*/}"
    [[ ${#ext_id} -ne 32 ]] && continue

    local is_builtin=false
    for bid in "${BUILTIN_EXTENSIONS[@]}"; do
      [[ "$bid" == "$ext_id" ]] && is_builtin=true && break
    done
    $is_builtin && continue

    local name=""
    local version_dir
    version_dir=$(ls "$eid" 2>/dev/null | head -1)
    if [[ -f "$eid/$version_dir/manifest.json" ]]; then
      name=$(jq -r '.name // .description // ""' "$eid/$version_dir/manifest.json" 2>/dev/null)
      [[ "$name" == __MSG_* ]] && name=""
      name="${name:0:50}"
    fi
    ext_list+=("${ext_id}|${name:-$ext_id}")
  done
  echo "${ext_list[@]}"
}

# ─── Main ────────────────────────────────────────────────────────────────────

echo ""
info "Scanning wapps from disk..."

SCANNED_WAPPS=($(scan_wapps))

echo "Found ${#SCANNED_WAPPS[@]} wapps"

# Build WAPPS array (preserve order from existing config, append new)
declare -A SEEN
NEW_WAPPS=()

for entry in "${WAPPS[@]}"; do
  IFS='|' read -r name _ _ <<< "$entry"
  for scanned in "${SCANNED_WAPPS[@]}"; do
    IFS='|' read -r s_name _ _ <<< "$scanned"
    if [[ "$s_name" == "$name" ]]; then
      NEW_WAPPS+=("$scanned")
      SEEN["$name"]=1
      break
    fi
  done
done

for scanned in "${SCANNED_WAPPS[@]}"; do
  IFS='|' read -r s_name _ _ <<< "$scanned"
  [[ -z "${SEEN[$s_name]}" ]] && NEW_WAPPS+=("$scanned")
done

# ─── Scan per-wapp extensions ────────────────────────────────────────────────

echo ""
info "Scanning per-wapp extensions..."

for entry in "${NEW_WAPPS[@]}"; do
  IFS='|' read -r name url browser <<< "$entry"
  profile_dir="$WAPP_DATA_DIR/$name"
  [[ ! -d "$profile_dir" ]] && continue

  local_exts=($(scan_extensions "$profile_dir"))
  [[ ${#local_exts[@]} -eq 0 ]] && continue

  for ext_entry in "${local_exts[@]}"; do
    IFS='|' read -r ext_id ext_name <<< "$ext_entry"
    found=false
    for existing in "${WAPP_EXTENSIONS[@]}"; do
      IFS='|' read -r e_wapp e_id _ <<< "$existing"
      if [[ "$e_wapp" == "$name" && "$e_id" == "$ext_id" ]]; then
        found=true
        break
      fi
    done
    if ! $found; then
      echo "  + $name: $ext_name ($ext_id)"
      WAPP_EXTENSIONS+=("${name}|${ext_id}|${ext_name}")
    fi
  done
done

# ─── Write config ────────────────────────────────────────────────────────────

echo ""
info "Writing $CONF..."

{
  echo "# wapps.conf — your personal wapp configuration (gitignored)"
  echo "# Exported by export-wapps.sh on $(date +%Y-%m-%d)"
  echo ""
  echo "WAPPS=("
  for entry in "${NEW_WAPPS[@]}"; do echo "  \"$entry\""; done
  echo ")"
  echo ""
  echo "CUSTOM_ICONS=("
  for entry in "${CUSTOM_ICONS[@]}"; do echo "  \"$entry\""; done
  echo ")"
  echo ""
  echo "WAPP_EXTENSIONS=("
  for entry in "${WAPP_EXTENSIONS[@]}"; do echo "  \"$entry\""; done
  echo ")"
  echo ""
  echo "BRAVE_EXTENSIONS=("
  for entry in "${BRAVE_EXTENSIONS[@]}"; do echo "  \"$entry\""; done
  echo ")"
  echo ""
  echo "WHALE_EXTENSIONS=("
  for entry in "${WHALE_EXTENSIONS[@]}"; do echo "  \"$entry\""; done
  echo ")"
} > "$CONF"

echo ""
info "Done. $CONF updated."
echo ""
