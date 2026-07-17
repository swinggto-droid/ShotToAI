#Requires AutoHotkey v2.0
#SingleInstance Force
; ===========================================================================
;  ShotToAI  —  Screenshot straight into your AI coding assistant.
;
;  Press  Win + Shift + A  ->  captures the monitor under your mouse cursor,
;  puts it on the clipboard, and pastes it into whatever input has focus
;  (Claude Code, Cursor, ChatGPT, a chat box, anywhere).
;
;  Why not just PrintScreen? On recent Windows 11 builds the PrintScreen key
;  opens the Snipping Tool instead of copying the screen. ShotToAI grabs the
;  pixels directly via GDI, so nothing gets in the way.
;
;  License: MIT.  https://github.com/<your-handle>/ShotToAI
; ===========================================================================

; ---- Config ----------------------------------------------------------------
; Use ` (backtick) + 1/2/3 to capture a specific monitor. Handy if you never
; type a literal backtick. Modified backtick still works (Shift+`=~,
; Ctrl+`=terminal). Set to false to leave the backtick key completely alone.
EnableBacktickHotkey := true

DllCall("SetProcessDPIAware")     ; capture at native resolution on scaled displays

; ---- Tray icon + menu ------------------------------------------------------
TraySetIcon("shell32.dll", 260)
A_IconTip := "ShotToAI  —  ` + 1/2/3: capture a screen → paste into AI"

tray := A_TrayMenu
tray.Delete()                     ; start from a clean menu
tray.Add("ShotToAI", (*) => 0)
tray.Disable("ShotToAI")
tray.Add()
tray.Add("How to use", (*) => ShowHelp())
tray.Add("Capture screen under cursor", (*) => CaptureAndPaste())
tray.Add()
tray.Add("Exit", (*) => ExitApp())
tray.Default := "How to use"

; ---- First-run welcome -----------------------------------------------------
flag := A_AppData "\ShotToAI\firstrun.flag"
if !FileExist(flag) {
    try {
        DirCreate(A_AppData "\ShotToAI")
        FileAppend("shown", flag)
    }
    ShowHelp()
}

; ---- Hotkeys ---------------------------------------------------------------
; Deliberately NO Win-key hotkeys. AHK masks the Win keyup whenever a #-prefixed
; hotkey exists, which stops the Win key from opening the Start menu. Keeping the
; Win key out of this script entirely avoids that whole class of breakage.
if EnableBacktickHotkey {         ; ` key (SC029) as a dedicated capture prefix
    Hotkey("SC029 & 1", (*) => CaptureMonitor(1))   ; ` + 1 -> leftmost monitor
    Hotkey("SC029 & 2", (*) => CaptureMonitor(2))   ; ` + 2 -> second from left
    Hotkey("SC029 & 3", (*) => CaptureMonitor(3))   ; ` + 3 -> third from left
    Hotkey("SC029 & 4", (*) => CaptureMonitor(4))   ; ` + 4 -> fourth, if present

    ; Hooking ` as a prefix makes Windows swallow it — including when a modifier
    ; is held, which would kill Ctrl+` (VS Code terminal toggle) and Shift+` (~).
    ; Catch those variants and re-emit them so they behave natively.
    ; Re-emitting is safe: a script's own Send does not retrigger its own hotkeys.
    for pfx in ["^", "+", "!", "^+"]
        Hotkey(pfx "SC029", PassThroughBacktick.Bind(pfx))
}

PassThroughBacktick(pfx, *) {
    SendInput(pfx "{SC029}")
}

ShowHelp() {
    MsgBox(
        "ShotToAI is running in your system tray.`n`n"
      . "1) Click your AI's text box so it has focus.`n"
      . "2) Hold  ``  and press  1 , 2  or  3 .`n`n"
      . "That screen is captured and pasted straight into the focused`n"
      . "text box. Screens are numbered left to right across your desktop.`n`n"
      . "Ctrl+`` , Shift+``  and other `` combos keep working normally.`n`n"
      . "Right-click the tray icon for options.",
        "ShotToAI", 0x40)
}

; Capture the monitor the mouse cursor is currently on.
CaptureAndPaste() {
    m := GetCursorMonitorRect()
    PasteCapture(m.x, m.y, m.w, m.h)
}

; Capture monitor #n, numbered left-to-right (1 = leftmost).
CaptureMonitor(n) {
    mons := GetMonitorsLeftToRight()
    if (n < 1 || n > mons.Length) {
        TrayTip("ShotToAI", "No monitor " n " (" mons.Length " connected).", 0x2)
        return
    }
    m := mons[n]
    PasteCapture(m.x, m.y, m.w, m.h)
}

PasteCapture(x, y, w, h) {
    if (w > 0 && CaptureRegionToClipboardDIB(x, y, w, h)) {
        Sleep(80)                 ; let the clipboard settle
        Send("^v")                ; paste into the focused input
    } else {
        TrayTip("ShotToAI", "Screen capture failed.", 0x3)
    }
}

; All monitors as {x,y,w,h}, sorted left-to-right (then top-to-bottom).
; Physical position, not the OS enumeration order — so "1" is always the
; leftmost screen regardless of how Windows numbered the displays.
GetMonitorsLeftToRight() {
    mons := []
    loop MonitorGetCount() {
        MonitorGet(A_Index, &l, &t, &r, &b)
        mons.Push({ x: l, y: t, w: r - l, h: b - t })
    }
    loop mons.Length - 1 {        ; insertion sort
        i := A_Index + 1
        cur := mons[i]
        j := i - 1
        while (j >= 1 && (mons[j].x > cur.x || (mons[j].x = cur.x && mons[j].y > cur.y))) {
            mons[j + 1] := mons[j]
            j--
        }
        mons[j + 1] := cur
    }
    return mons
}

; Rectangle {x,y,w,h} of the monitor under the mouse cursor (falls back empty).
GetCursorMonitorRect() {
    static MONITOR_DEFAULTTONEAREST := 2
    pt := Buffer(8, 0)
    DllCall("GetCursorPos", "ptr", pt)
    x := NumGet(pt, 0, "int"), y := NumGet(pt, 4, "int")
    hMon := DllCall("MonitorFromPoint", "int64", (y << 32) | (x & 0xFFFFFFFF)
                  , "uint", MONITOR_DEFAULTTONEAREST, "ptr")
    mi := Buffer(40, 0)
    NumPut("uint", 40, mi, 0)     ; cbSize
    if !DllCall("GetMonitorInfo", "ptr", hMon, "ptr", mi)
        return { x: 0, y: 0, w: 0, h: 0 }
    left   := NumGet(mi, 4,  "int")
    top    := NumGet(mi, 8,  "int")
    right  := NumGet(mi, 12, "int")
    bottom := NumGet(mi, 16, "int")
    return { x: left, y: top, w: right - left, h: bottom - top }
}

; Capture a screen region into a 24-bit bottom-up DIB and put it on the
; clipboard as CF_DIB (the format Chromium/Electron apps read on paste).
CaptureRegionToClipboardDIB(vx, vy, vw, vh) {
    static SRCCOPY := 0x00CC0020, CAPTUREBLT := 0x40000000
    static BI_RGB := 0, DIB_RGB_COLORS := 0, CF_DIB := 8, GMEM_MOVEABLE := 0x2

    if (vw <= 0 || vh <= 0)
        return false

    hdcScreen := DllCall("GetDC", "ptr", 0, "ptr")
    hdcMem    := DllCall("CreateCompatibleDC", "ptr", hdcScreen, "ptr")
    hbm       := DllCall("CreateCompatibleBitmap", "ptr", hdcScreen, "int", vw, "int", vh, "ptr")
    obm       := DllCall("SelectObject", "ptr", hdcMem, "ptr", hbm, "ptr")

    DllCall("BitBlt", "ptr", hdcMem, "int", 0, "int", 0, "int", vw, "int", vh
                    , "ptr", hdcScreen, "int", vx, "int", vy, "uint", SRCCOPY | CAPTUREBLT)

    DllCall("SelectObject", "ptr", hdcMem, "ptr", obm, "ptr")   ; deselect before GetDIBits

    stride     := ((vw * 3 + 3) & ~3)   ; DWORD-aligned rows
    imgSize    := stride * vh
    headerSize := 40
    totalSize  := headerSize + imgSize

    bi := Buffer(headerSize, 0)
    NumPut("uint",   headerSize, bi, 0)    ; biSize
    NumPut("int",    vw,         bi, 4)    ; biWidth
    NumPut("int",    vh,         bi, 8)    ; biHeight (positive = bottom-up)
    NumPut("ushort", 1,          bi, 12)   ; biPlanes
    NumPut("ushort", 24,         bi, 14)   ; biBitCount
    NumPut("uint",   BI_RGB,     bi, 16)   ; biCompression
    NumPut("uint",   imgSize,    bi, 20)   ; biSizeImage

    hMem := DllCall("GlobalAlloc", "uint", GMEM_MOVEABLE, "uptr", totalSize, "ptr")
    pMem := DllCall("GlobalLock", "ptr", hMem, "ptr")
    DllCall("RtlMoveMemory", "ptr", pMem, "ptr", bi.Ptr, "uptr", headerSize)  ; copy header
    ret := DllCall("GetDIBits", "ptr", hdcMem, "ptr", hbm, "uint", 0, "uint", vh
                             , "ptr", pMem + headerSize, "ptr", pMem, "uint", DIB_RGB_COLORS, "int")
    DllCall("GlobalUnlock", "ptr", hMem)

    DllCall("DeleteObject", "ptr", hbm)
    DllCall("DeleteDC", "ptr", hdcMem)
    DllCall("ReleaseDC", "ptr", 0, "ptr", hdcScreen)

    if (!ret) {
        DllCall("GlobalFree", "ptr", hMem)
        return false
    }

    if !DllCall("OpenClipboard", "ptr", 0) {
        DllCall("GlobalFree", "ptr", hMem)
        return false
    }
    DllCall("EmptyClipboard")
    if !DllCall("SetClipboardData", "uint", CF_DIB, "ptr", hMem, "ptr") {
        DllCall("CloseClipboard")
        DllCall("GlobalFree", "ptr", hMem)
        return false
    }
    DllCall("CloseClipboard")      ; clipboard now owns hMem — do not free it
    return true
}
