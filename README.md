# wapp

A Linux CLI tool that creates **isolated browser apps** — each with its own profile, cookies, and login state, launched as standalone app-like windows with no browser chrome.

## Why?

Mainstream browsers mix everything into one profile. Your Gmail session shares cookies with your YouTube session, your banking session, your everything. Container extensions help but are clunky and per-tab.

**wapp** takes a different approach: each web app is a completely separate browser instance. Different cookies, different sessions, different icons in your app launcher. Click "Gmail" and you get Gmail. Click "YouTube" and you get YouTube. No overlap, no confusion.

## Features

- **Full isolation** — each app has its own cookies, sessions, and login state
- **App-like windows** — no tabs, no address bar, no bookmarks bar (just the web page)
- **Desktop entries** — apps show up in your app launcher with their own icons
- **Multi-account friendly** — run multiple accounts for the same service (e.g. `gmail-personal`, `gmail-work`)
- **Browser-agnostic** — supports Firefox, Brave, Chromium, Chrome, Whale, Edge, Vivaldi, and Opera
- **Quick iteration** — `recreate` command for fast testing during development
- **Clean removal** — remove apps with or without preserving profile data

## Requirements

- Linux
- One of: Firefox, Brave, Chromium, Chrome, Whale, Edge, Vivaldi, or Opera
- [gum](https://github.com/charmbracelet/gum) (for interactive prompts)
- `curl` (for fetching favicons)

## Installation

navigate to ~/user_scripts/ (or any location of your choice)


```bash
git clone https://github.com/sazaam/wapp.git
cd wapp
chmod +x wapp
ln -sf "$(pwd)/wapp" ~/.local/bin/wapp
```
> [!IMPORTANT]
> Make sure `~/.local/bin` is in your `$PATH`.

## Usage

### Create an app

**Interactive:**
```bash
wapp create
```

**Non-interactive:**
```bash
wapp create <name> <url> [browser]   # browser defaults to first detected
```

Examples:
```bash
wapp create gmail https://mail.google.com brave
wapp create youtube https://youtube.com firefox
wapp create x https://x.com brave
```

### Open an app
```bash
wapp open <name>
```

### List all apps
```bash
wapp list
```

### Remove an app
```bash
wapp remove <name>              # removes launcher + profile data
wapp remove <name> --keep-data  # removes launcher, keeps profile data
```

### Recreate an app
Useful for quick iteration — removes and re-creates in one step. Omitting a browser keeps the app's existing browser, and the current browser + URL are shown before anything is replaced.

```bash
wapp recreate <name>                    # interactive (prompts for URL + browser)
wapp recreate <name> <url>              # keep the same browser
wapp recreate <name> <url> [browser] [--keep-data]
```

```bash
wapp recreate gmail https://mail.google.com brave
wapp recreate gmail https://mail.google.com brave --keep-data  # keep profile data
wapp recreate gmail https://mail.google.com                     # keeps current browser
```

### Help
```bash
wapp help
```

## Multi-Account Example

Need Gmail for two accounts? Create two separate wapps:

```bash
wapp create gmail-personal https://mail.google.com brave
wapp create gmail-work https://mail.google.com brave
```

Each gets its own isolated data directory. Log into a different Google account in each — they never interfere.

## Supported Browsers

| Browser | Binary | Isolation Method | App Window |
|---------|--------|-----------------|------------|
| Firefox | `firefox` (or `firefox-esr`, `librewolf`, …) | Separate profile (`-P`) | `userChrome.css` hides toolbars |
| Brave | `brave-browser`, `brave`, `brave-origin-nightly`, … | Separate `--user-data-dir` | `--app` mode |
| Chromium | `chromium`, `chromium-browser`, `ungoogled-chromium`, … | Separate `--user-data-dir` | `--app` mode |
| Chrome | `google-chrome`, `google-chrome-stable`, … | Separate `--user-data-dir` | `--app` mode |
| Whale | `naver-whale-stable`, `naver-whale` | Separate `--user-data-dir` | `--app` mode |
| Edge | `microsoft-edge`, `microsoft-edge-stable`, … | Separate `--user-data-dir` | `--app` mode |
| Vivaldi | `vivaldi`, `vivaldi-stable` | Separate `--user-data-dir` | `--app` mode |
| Opera | `opera`, `opera-stable` | Separate `--user-data-dir` | `--app` mode |

> Browsers are auto-discovered by scanning your `$PATH` for any of these binaries. When you omit `[browser]`, wapp either keeps the app's current browser (recreate) or picks the first one it detects.

## How Isolation Works

### Chromium-based (Brave, Chromium, Chrome, Whale, Edge, Vivaldi, Opera)

Each app gets its own `--user-data-dir` directory:

```
~/.local/share/wapp/<name>/
```

The browser is launched with `--app=<url>`, which opens a minimal window without tabs, address bar, or bookmarks bar — just the web page content.

```bash
# What wapp generates for Chromium-based browsers:
exec brave-origin-nightly --user-data-dir=~/.local/share/wapp/gmail --app=https://mail.google.com
```

### Firefox

Each app gets a dedicated Firefox profile with:

- A separate profile directory in `~/.mozilla/firefox/`
- A `chrome/userChrome.css` that hides `#TabsToolbar`, `#nav-bar`, and `#PersonalToolbar`
- A `user.js` that enables custom stylesheets
- An entry in `profiles.ini`
- The `-no-remote` flag to prevent connecting to an existing Firefox instance

```bash
# What wapp generates for Firefox:
exec firefox -P "wapp-youtube" -no-remote https://youtube.com
```

## For Omarchy Users

**wapp is non-conflictual with omarchy's existing webapp system.** The two tools serve different purposes:

| | `omarchy-webapp-install` | `wapp` |
|---|---|---|
| Isolation | Shared browser profile | Fully isolated per app |
| Chrome | Full browser (tabs, address bar) | App window (no chrome) |
| Use case | Quick bookmarks | Account-separated apps |

They can coexist — `wapp` desktop entries (`wapp-*.desktop`) won't interfere with omarchy webapp entries, and `wapp` profile data lives in `~/.local/share/wapp/` (separate from `~/.mozilla/firefox/` default profiles).

## File Layout

```
~/.local/share/wapp/<name>/                         # profile/data directory
~/.local/bin/wapp-<name>                            # launch script
~/.local/share/applications/wapp-<name>.desktop     # desktop entry
~/.local/share/applications/icons/wapp-<name>.png   # app icon
```

## License

GPLv3 — see [LICENSE](LICENSE).
