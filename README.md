# ShotToAI

**Screenshot straight into your AI coding assistant — one keypress.**

Hold <kbd>`</kbd> and press <kbd>1</kbd>, <kbd>2</kbd> or <kbd>3</kbd>. ShotToAI grabs
that monitor and pastes it into whatever text box has focus — Claude Code, Cursor,
ChatGPT, a chat window, anywhere.

No more *Win+Shift+S → drag a box → Ctrl+V*. Just press two keys.

![demo](docs/demo.gif) <!-- TODO: record a short gif and drop it here -->

---

## Why

- **The PrintScreen key is broken for this.** On recent Windows 11 builds it opens
  the Snipping Tool instead of copying the screen. ShotToAI grabs the pixels
  directly via GDI, so nothing hijacks the keypress.
- **Multi-monitor first.** Name the screen you want — not a 4920×1920 wall of three
  monitors your AI can't make sense of. Screens are numbered left to right by
  physical position, so <kbd>`</kbd>+<kbd>2</kbd> is always the middle one.
- **Nothing moves.** No dragging a selection box, no moving your mouse, no losing
  focus. Keep typing in the chat, press two keys, the screenshot is there.
- **Your other shortcuts survive.** <kbd>Ctrl</kbd>+<kbd>`</kbd> (terminal toggle),
  <kbd>Shift</kbd>+<kbd>`</kbd> (`~`) and friends pass through untouched. No Win-key
  hotkeys either — those make AHK mask the Win keyup and break the Start menu.

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
2. Hold <kbd>`</kbd> and press the number of the screen you want.

| Shortcut | Captures |
| --- | --- |
| <kbd>`</kbd>+<kbd>1</kbd> | Leftmost screen |
| <kbd>`</kbd>+<kbd>2</kbd> | Second from left |
| <kbd>`</kbd>+<kbd>3</kbd> | Third from left |

Right-click the tray icon for help, a cursor-screen capture, or to exit.

## Notes & limits

- **The bare <kbd>`</kbd> key stops typing a backtick** — it becomes a capture prefix.
  If you write template literals or markdown by hand, set `EnableBacktickHotkey := false`
  at the top of the script. Modified combos (<kbd>Ctrl</kbd>+<kbd>`</kbd>,
  <kbd>Shift</kbd>+<kbd>`</kbd>) are unaffected either way.
- Paste lands wherever the keyboard focus is. If focus is in a code editor instead of
  the chat box, the image pastes there — same as a manual Ctrl+V.
- Captures the **whole monitor**. Region/window capture and annotation are on the roadmap.
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
