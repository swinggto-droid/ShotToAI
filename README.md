# ShotToAI

**Screenshot straight into your AI coding assistant — one keypress.**

Press <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>A</kbd>. ShotToAI captures the monitor your
mouse is on and pastes it into whatever text box has focus — Claude Code, Cursor,
ChatGPT, a chat window, anywhere.

No more *Win+Shift+S → drag a box → Ctrl+V*. Just point and press.

![demo](docs/demo.gif) <!-- TODO: record a short gif and drop it here -->

---

## Why

- **The PrintScreen key is broken for this.** On recent Windows 11 builds it opens
  the Snipping Tool instead of copying the screen. ShotToAI grabs the pixels
  directly via GDI, so nothing hijacks the keypress.
- **Multi-monitor friendly.** It captures only the screen under your mouse — not a
  4920×1920 wall of three monitors your AI can't make sense of.
- **Focus stays put.** Mouse position picks the screen; keyboard focus stays in your
  AI's text box. Point the mouse at the content, keep the cursor in the chat, press.

## Install

**Option A — download the app (no dependencies)**

1. Grab `ShotToAI.exe` from the [latest release](../../releases/latest).
2. Run it. It lives in your system tray.
3. (Optional) Drop a shortcut in `shell:startup` to launch it at login.

**Option B — run the script**

1. Install [AutoHotkey v2](https://www.autohotkey.com/).
2. Double-click `src/ShotToAI.ahk`.

## Use

1. Click your AI's text box so it has focus.
2. Move your **mouse** onto the screen you want to capture.
3. Press <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>A</kbd>.

Right-click the tray icon for help or to exit.

## Notes & limits

- Paste lands wherever the keyboard focus is. If focus is in a code editor instead of
  the chat box, the image pastes there — same as a manual Ctrl+V.
- Captures the **whole monitor** under the cursor. Region/window capture and
  annotation are on the roadmap.
- Windows only (uses Win32 GDI + clipboard APIs).

## Roadmap

- [ ] Region / active-window capture
- [ ] Quick arrow/box annotation before paste
- [ ] Multi-shot queue (send several screens at once)
- [ ] Configurable hotkey
- [ ] Auto-attach context (active window title, selected text)

## License

MIT © 2026 — see [LICENSE](LICENSE).

---

<sub>If this saves you some clicks, a ⭐ or a coffee is appreciated.
<!-- TODO: add Buy Me a Coffee / GitHub Sponsors link --></sub>
