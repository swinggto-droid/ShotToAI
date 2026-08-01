#Requires AutoHotkey v2.0
#SingleInstance Force
; ===========================================================================
;  ShotToAI  —  Screenshot straight into your AI coding assistant.
;
;  Hold  `  and press  1 / 2 / 3  ->  captures that monitor, puts it on the
;  clipboard, and pastes it into whatever input has focus (Claude Code,
;  Cursor, ChatGPT, a chat box, anywhere).
;
;  Right-click the tray icon and pick "Pause capture" to silence the hotkeys.
;  While paused the ` key types a literal backtick again.
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

; Tray icon numbers within shell32.dll: scissors while armed, a red "no entry"
; sign while paused, so the tray shows the current state at a glance.
ICON_ACTIVE := 260
ICON_PAUSED := 110

Paused := false                   ; flipped by the tray menu; see TogglePause()

; Tray menu labels. Kept in variables because Menu.Check/Uncheck/Disable look an
; item up by its exact label — a typo in one of the copies would only surface at
; runtime, as an error thrown while the menu is being clicked.
MENU_HELP  := "사용법"
MENU_SHOT  := "마우스가 있는 화면 캡처"
MENU_PAUSE := "캡처 일시 중지"
MENU_EXIT  := "종료"

DllCall("SetProcessDPIAware")     ; capture at native resolution on scaled displays

; ---- Tray icon + menu ------------------------------------------------------
; Freeze the icon so Suspend() can't swap in AutoHotkey's own suspend icon —
; TogglePause() switches between ICON_ACTIVE and ICON_PAUSED itself.
TraySetIcon("shell32.dll", ICON_ACTIVE, true)
UpdateIconTip()

tray := A_TrayMenu
tray.Delete()                     ; start from a clean menu
tray.Add("ShotToAI", (*) => 0)
tray.Disable("ShotToAI")
tray.Add()
tray.Add(MENU_HELP, (*) => ShowHelp())
tray.Add(MENU_SHOT, (*) => CaptureAndPaste())
tray.Add()
tray.Add(MENU_PAUSE, (*) => TogglePause())
tray.Add()
tray.Add(MENU_EXIT, (*) => ExitApp())
tray.Default := MENU_HELP
if !EnableBacktickHotkey          ; no hotkeys registered, so there is nothing to pause
    tray.Disable(MENU_PAUSE)

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
    global MENU_PAUSE
    MsgBox(
        "ShotToAI가 작업 표시줄 알림 영역에서 실행 중입니다.`n`n"
      . "1) AI 입력창을 클릭해 커서를 둡니다.`n"
      . "2) ``  키를 누른 채  1 , 2 , 3  중 하나를 누릅니다.`n`n"
      . "그 화면이 캡처되어 커서가 있는 입력창에 바로 붙습니다.`n"
      . "화면 번호는 왼쪽부터 순서대로 매겨집니다.`n`n"
      . "Ctrl+`` , Shift+`` 처럼 조합키를 쓴 백틱은 그대로 동작합니다.`n`n"
      . "백틱을 직접 입력해야 하면 트레이 아이콘을 우클릭해`n"
      . "[" . MENU_PAUSE . "]를 선택하세요. 다시 선택하면 켜집니다.`n`n"
      . "나머지 기능도 트레이 아이콘 우클릭 메뉴에 있습니다.",
        "ShotToAI", 0x40)
}

; Turn the hotkeys off and on from the tray menu.
; Suspend() disables every hotkey, which also un-hooks ` as a prefix key — so a
; paused ShotToAI leaves the backtick free to type a literal backtick. Tray menu
; items are not hotkeys, so "Capture screen under cursor" still works.
TogglePause(*) {
    global Paused, ICON_ACTIVE, ICON_PAUSED, MENU_PAUSE
    Paused := !Paused
    Suspend(Paused)
    if Paused
        A_TrayMenu.Check(MENU_PAUSE)
    else
        A_TrayMenu.Uncheck(MENU_PAUSE)
    TraySetIcon("shell32.dll", Paused ? ICON_PAUSED : ICON_ACTIVE)
    UpdateIconTip()
    TrayTip(Paused ? "단축키를 껐습니다. 이제 `` 키로 백틱을 입력할 수 있습니다."
                   : "`` + 1/2/3 으로 다시 화면을 캡처할 수 있습니다."
          , Paused ? "ShotToAI 일시 중지" : "ShotToAI 작동 중", 0x1)
}

UpdateIconTip() {
    global Paused
    A_IconTip := Paused ? "ShotToAI (일시 중지)  —  트레이 아이콘 우클릭으로 다시 시작"
                        : "ShotToAI  —  `` + 1/2/3 : 화면 캡처해서 AI에 붙여넣기"
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
        TrayTip("화면 " n "번은 없습니다 (연결된 화면 " mons.Length "개).", "ShotToAI", 0x2)
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
        TrayTip("화면 캡처에 실패했습니다.", "ShotToAI", 0x3)
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
