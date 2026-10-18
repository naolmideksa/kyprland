# ✨ macOS / KDE Floating Hyprland Rice

> A clean, floating-first, beautifully scaled Hyprland setup with macOS-style window controls, native minimization, and Noctalia's floating top bar + bottom dock.

---

## 🌟 Highlights

* **🎯 100% Crisp Scaling**: Fixes the default over-zoomed and blurry fractional scaling on fresh Hyprland setups. Everything renders sharp and pixel-perfect.
* **🪟 Floating-First Workflow**: Windows open freely at their natural dimensions with full floating control (KDE/macOS style) instead of forced tiling.
* **🚦 macOS-Style Traffic Light Buttons**: Integrated titlebars with clean traffic-light controls:
  - 🔴 **Close**
  - 🟢 **Maximize / Restore** (double-click titlebar or green button)
  - 🟡 **Minimize** (native minimization to dock via `kyprland` plugin)
* **🏝️ Noctalia Shell & Dock**:
  - **Top Bar**: Floating pill bar with active workspace indicator, system resource monitors (CPU, RAM, GPU temp), media controls, and status tray.
  - **Bottom Dock**: macOS-style autohiding dock with running dots, active indicators, and pinned apps.
* **🎨 Consistent Theming**: Seamless Adwaita dark palette, Qt6ct stylesheets, custom vector icons, and Kitty terminal theme.
* **💻 Developer Ready**: VS Code / Code - OSS configured with interactive Code Runner and modern language tooling.

---

## 🚀 Quick Install

### One-line Install (Clone & Run)

```bash
git clone https://github.com/<your-username>/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

The script will:
1. Verify / install dependencies via `pacman` & `yay`.
2. Back up any existing configs to `~/.config/hypr-setup-backup-<timestamp>`.
3. Deploy configurations for Hyprland, Noctalia, Kitty, and Qt6ct.
4. Verify / compile the Hyprland plugins for your exact system build.
5. Reload the desktop environment live.

---

## ⌨️ Essential Keybindings

| Shortcut | Action |
| :--- | :--- |
| `Super + Q` | Terminal (Kitty) |
| `Super + E` | File Manager (Files / Nautilus) |
| `Super + B` | Web Browser (Firefox / Chrome) |
| `Super + C` | Close Window |
| `Super + M` | Minimize Window |
| `Super + Arrow Keys` | Snap Window (Left, Right, Top, Bottom) |
| `Super + 1..9` | Switch Workspace |
| `Alt + Left Click + Drag` | Move Window |
| `Alt + Right Click + Drag` | Resize Window |

---

## 📦 Stack

* **Compositor**: [Hyprland](https://hyprland.org/)
* **Shell & Dock**: [Noctalia](https://noctalia.dev)
* **Terminal**: [Kitty](https://sw.kovidgoyal.net/kitty/)
* **Window Management**: `kyprland` + `hyprbars`
* **File Manager**: Nautilus (Files)
* **Theming**: `qt6ct` + `adw-gtk3-dark` + `Adwaita` icons
