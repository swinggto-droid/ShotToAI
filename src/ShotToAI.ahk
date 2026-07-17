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
; Press the ` (backtick) key ALONE to capture. Handy if you never type a
; literal backtick. Modified backtick still works (Shift+`=~, Ctrl+`=terminal).
; Set to false if you want the backtick key to type normally.
EnableBacktickHotkey := true

DllCall("SetProcessDPIAware")     ; capture at native resolution on scaled displays

; ---- Tray icon + menu ------------------------------------------------------
TraySetIcon("shell32.dll", 260)
A_IconTip := "ShotToAI  —  Win+Shift+A: capture → paste into AI"

tray := A_TrayMenu
tray.Delete()                     ; start from a clean menu
tray.Add("ShotToAI", (*) => 0)
tray.Disable("ShotToAI")
tray.Add()
tray.Add("How to use", (*) => ShowHelp())
tray.Add("Capture now (Win+Shift+A)", (*) => CaptureAndPaste())
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
#+a:: CaptureAndPaste()           ; Win + Shift + A
if EnableBacktickHotkey           ; ` key alone (SC029). Modified `+ combos pass through.
    Hotkey("SC029", (*) => CaptureAndPaste())

ShowHelp() {
    MsgBox(
        "ShotToAI is running in your system tray.`n`n"
      . "1) Click your AI's text box so it has focus.`n"
      . "2) Move your MOUSE onto the screen you want to capture.`n"
      . "3) Press  Win + Shift + A   (or the `` key, if enabled).`n`n"
      . "The monitor under your mouse is captured and pasted into the`n"
      . "focused text box. Right-click the tray icon for options.",
        "ShotToAI", 0x40)
}

CaptureAndPaste() {
    m := GetCursorMonitorRect()   ; monitor the mouse cursor sits on
    if (m.w > 0 && CaptureRegionToClipboardDIB(m.x, m.y, m.w, m.h)) {
        Sleep(80)                 ; let the clipboard settle
        Send("^v")                ; paste into the focused input
    } else {
        TrayTip("ShotToAI", "Screen capture failed.", 0x3)
    }
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
