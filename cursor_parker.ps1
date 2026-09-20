param(
    [ValidateRange(0.05, 3600)]
    [double]$TimeoutSeconds = 1,
    [switch]$CheckOnly
)

$idleSeconds = $TimeoutSeconds
$excludedGamePaths = @()
$configPath = Join-Path $PSScriptRoot 'CursorParker.ini'

if (Test-Path -LiteralPath $configPath -PathType Leaf) {
    $configBytes = [System.IO.File]::ReadAllBytes($configPath)
    if ($configBytes.Length -ge 3 -and $configBytes[0] -eq 0xEF -and $configBytes[1] -eq 0xBB -and $configBytes[2] -eq 0xBF) {
        $configText = [System.Text.Encoding]::UTF8.GetString($configBytes, 3, $configBytes.Length - 3)
    }
    elseif ($configBytes.Length -ge 2 -and $configBytes[0] -eq 0xFF -and $configBytes[1] -eq 0xFE) {
        $configText = [System.Text.Encoding]::Unicode.GetString($configBytes, 2, $configBytes.Length - 2)
    }
    elseif ($configBytes.Length -ge 2 -and $configBytes[0] -eq 0xFE -and $configBytes[1] -eq 0xFF) {
        $configText = [System.Text.Encoding]::BigEndianUnicode.GetString($configBytes, 2, $configBytes.Length - 2)
    }
    else {
        try {
            $strictUtf8 = [System.Text.UTF8Encoding]::new($false, $true)
            $configText = $strictUtf8.GetString($configBytes)
        }
        catch {
            $configText = [System.Text.Encoding]::Default.GetString($configBytes)
        }
    }

    $section = ''
    foreach ($line in ($configText -split "`n")) {
        $entry = $line.Trim()
        if (-not $entry -or $entry.StartsWith(';') -or $entry.StartsWith('#')) { continue }
        if ($entry -match '^\[(.+)\]$') {
            $section = $Matches[1].Trim()
            continue
        }

        $separator = $entry.IndexOf('=')
        if ($separator -le 0) { continue }
        $key = $entry.Substring(0, $separator).Trim()
        $value = $entry.Substring($separator + 1).Trim()

        if ($section -ieq 'General' -and $key -ieq 'IdleSeconds') {
            $parsedSeconds = 0.0
            $numberStyles = [Globalization.NumberStyles]::AllowDecimalPoint -bor [Globalization.NumberStyles]::AllowLeadingSign
            $validNumber = [double]::TryParse(
                $value,
                $numberStyles,
                [Globalization.CultureInfo]::InvariantCulture,
                [ref]$parsedSeconds
            )
            if ($validNumber -and $parsedSeconds -ge 0.05 -and $parsedSeconds -le 3600) {
                $idleSeconds = $parsedSeconds
            }
        }
        elseif ($section -ieq 'ExcludedGames' -and $key -match '^Game\d+$') {
            if ($value.Length -ge 2 -and $value[0] -eq '"' -and $value[$value.Length - 1] -eq '"') {
                $value = $value.Substring(1, $value.Length - 2)
            }
            try {
                if ([System.IO.Path]::IsPathRooted($value) -and $value.EndsWith('.exe', [StringComparison]::OrdinalIgnoreCase)) {
                    $excludedGamePaths += [System.IO.Path]::GetFullPath($value)
                }
            }
            catch {
            }
        }
    }
}

$source = @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;

public static class CursorParker
{
    private const int MONITOR_DEFAULTTONEAREST = 2;
    private const int SM_XVIRTUALSCREEN = 76;
    private const int SM_YVIRTUALSCREEN = 77;
    private const int SM_CXVIRTUALSCREEN = 78;
    private const int SM_CYVIRTUALSCREEN = 79;
    private const int GWL_STYLE = -16;
    private const uint WS_CAPTION = 0x00C00000;

    [StructLayout(LayoutKind.Sequential)]
    private struct POINT
    {
        public int X;
        public int Y;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    private struct MONITORINFO
    {
        public int Size;
        public RECT Monitor;
        public RECT Work;
        public uint Flags;
    }

    [DllImport("user32.dll")]
    private static extern bool GetCursorPos(out POINT point);

    [DllImport("user32.dll")]
    private static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);

    [DllImport("user32.dll")]
    private static extern bool GetWindowRect(IntPtr window, out RECT rect);

    [DllImport("user32.dll")]
    private static extern int GetWindowLong(IntPtr window, int index);

    [DllImport("user32.dll")]
    private static extern IntPtr MonitorFromWindow(IntPtr window, uint flags);

    [DllImport("user32.dll")]
    private static extern IntPtr MonitorFromPoint(POINT point, uint flags);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    private static extern bool GetMonitorInfo(IntPtr monitor, ref MONITORINFO info);

    [DllImport("user32.dll")]
    private static extern bool GetClipCursor(out RECT rect);

    [DllImport("user32.dll")]
    private static extern int GetSystemMetrics(int index);

    [DllImport("user32.dll")]
    private static extern short GetAsyncKeyState(int virtualKey);

    private static bool WasTypingKeyPressed()
    {
        bool shortcutHeld = (GetAsyncKeyState(0x11) & 0x8000) != 0 ||
                            (GetAsyncKeyState(0x12) & 0x8000) != 0 ||
                            (GetAsyncKeyState(0x5B) & 0x8000) != 0 ||
                            (GetAsyncKeyState(0x5C) & 0x8000) != 0;
        bool pressed = false;

        for (int key = 0x30; key <= 0x5A; key++)
            pressed |= (GetAsyncKeyState(key) & 0x8001) != 0;
        for (int key = 0x60; key <= 0x6F; key++)
            pressed |= (GetAsyncKeyState(key) & 0x8001) != 0;
        for (int key = 0xBA; key <= 0xC0; key++)
            pressed |= (GetAsyncKeyState(key) & 0x8001) != 0;
        for (int key = 0xDB; key <= 0xDF; key++)
            pressed |= (GetAsyncKeyState(key) & 0x8001) != 0;

        int[] editingKeys = { 0x08, 0x0D, 0x20, 0xE2 };
        foreach (int key in editingKeys)
            pressed |= (GetAsyncKeyState(key) & 0x8001) != 0;

        return pressed && !shortcutHeld;
    }

    private static bool SamePoint(POINT a, POINT b)
    {
        return a.X == b.X && a.Y == b.Y;
    }

    private static bool IsPointWithin(POINT point, RECT rect)
    {
        return point.X >= rect.Left && point.X < rect.Right &&
               point.Y >= rect.Top && point.Y < rect.Bottom;
    }

    private static bool TryRestoreCursor(POINT target, out POINT actual)
    {
        actual = target;
        RECT clip;
        bool hasClip = GetClipCursor(out clip);
        bool cursorCaptured = hasClip && IsCursorCaptured(clip);
        if (cursorCaptured && !IsPointWithin(target, clip))
        {
            GetCursorPos(out actual);
            return false;
        }

        if (!SetCursorPos(target.X, target.Y))
        {
            GetCursorPos(out actual);
            return false;
        }
        if (!GetCursorPos(out actual)) return false;

        // SetCursorPos can succeed after the system clamps a point outside ClipCursor.
        // Keep waiting while a custom clip is active; if the desktop itself changed,
        // accept the nearest position the system permits so shutdown can finish.
        return SamePoint(actual, target) || (hasClip && !cursorCaptured);
    }

    private static bool IsMouseButtonDown()
    {
        return (GetAsyncKeyState(0x01) & 0x8000) != 0 ||
               (GetAsyncKeyState(0x02) & 0x8000) != 0 ||
               (GetAsyncKeyState(0x04) & 0x8000) != 0 ||
               (GetAsyncKeyState(0x05) & 0x8000) != 0 ||
               (GetAsyncKeyState(0x06) & 0x8000) != 0;
    }

    private static bool IsFullscreenForeground(IntPtr window)
    {
        if (window == IntPtr.Zero) return false;

        RECT windowRect;
        if (!GetWindowRect(window, out windowRect)) return false;

        IntPtr monitor = MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST);
        MONITORINFO info = new MONITORINFO();
        info.Size = Marshal.SizeOf(typeof(MONITORINFO));
        if (!GetMonitorInfo(monitor, ref info)) return false;

        const int tolerance = 2;
        bool coversMonitor = windowRect.Left <= info.Monitor.Left + tolerance &&
                             windowRect.Top <= info.Monitor.Top + tolerance &&
                             windowRect.Right >= info.Monitor.Right - tolerance &&
                             windowRect.Bottom >= info.Monitor.Bottom - tolerance;
        uint style = unchecked((uint)GetWindowLong(window, GWL_STYLE));
        return coversMonitor && (style & WS_CAPTION) == 0;
    }

    private static bool IsCursorCaptured()
    {
        RECT clip;
        if (!GetClipCursor(out clip)) return false;

        return IsCursorCaptured(clip);
    }

    private static bool IsCursorCaptured(RECT clip)
    {
        int left = GetSystemMetrics(SM_XVIRTUALSCREEN);
        int top = GetSystemMetrics(SM_YVIRTUALSCREEN);
        int right = left + GetSystemMetrics(SM_CXVIRTUALSCREEN);
        int bottom = top + GetSystemMetrics(SM_CYVIRTUALSCREEN);

        const int tolerance = 1;
        return Math.Abs(clip.Left - left) > tolerance ||
               Math.Abs(clip.Top - top) > tolerance ||
               Math.Abs(clip.Right - right) > tolerance ||
               Math.Abs(clip.Bottom - bottom) > tolerance;
    }

    private static POINT GetParkPoint(POINT current)
    {
        IntPtr monitor = MonitorFromPoint(current, MONITOR_DEFAULTTONEAREST);
        MONITORINFO info = new MONITORINFO();
        info.Size = Marshal.SizeOf(typeof(MONITORINFO));
        if (monitor == IntPtr.Zero || !GetMonitorInfo(monitor, ref info))
            return current;

        POINT park = new POINT();
        park.X = info.Monitor.Right - 2;
        int height = info.Monitor.Bottom - info.Monitor.Top;
        int upwardOffset = Math.Max(64, (int)Math.Round(height * 0.05));
        park.Y = Math.Max(info.Monitor.Top + 2, info.Monitor.Bottom - upwardOffset);
        return park;
    }

    private static bool IsExcludedProcess(uint processId, string[] excludedPaths)
    {
        if (excludedPaths == null || excludedPaths.Length == 0) return false;
        if (processId == 0) return true;

        try
        {
            using (Process process = Process.GetProcessById((int)processId))
            {
                string executablePath = process.MainModule.FileName;
                if (String.IsNullOrEmpty(executablePath)) return true;
                foreach (string excludedPath in excludedPaths)
                {
                    if (String.Equals(executablePath, excludedPath, StringComparison.OrdinalIgnoreCase))
                        return true;
                }
            }
        }
        catch
        {
            // A path lookup failure must not silently disable configured game protection.
            return true;
        }

        return false;
    }

    public static void Run(double timeoutSeconds, string[] excludedPaths)
    {
        bool mutexCreated;
        using (Mutex mutex = new Mutex(true, @"Local\CursorParker", out mutexCreated))
        {
            if (!mutexCreated) return;

            using (EventWaitHandle stopEvent = new EventWaitHandle(false,
                EventResetMode.ManualReset, @"Local\CursorParkerStop"))
            {
                POINT last;
                if (!GetCursorPos(out last)) return;

                POINT saved = last;
                POINT park = last;
                bool parked = false;
                bool restoreAfterProtection = false;
                bool armedByInput = false;
                uint checkedProcessId = UInt32.MaxValue;
                bool excludedForeground = false;
                Stopwatch idle = Stopwatch.StartNew();
                WasTypingKeyPressed();

                try
                {
                    while (!stopEvent.WaitOne(50))
                    {
                        POINT current;
                        if (!GetCursorPos(out current)) continue;
                        bool typingKeyPressed = WasTypingKeyPressed();

                        IntPtr foregroundWindow = GetForegroundWindow();
                        uint foregroundProcessId;
                        GetWindowThreadProcessId(foregroundWindow, out foregroundProcessId);
                        if (foregroundProcessId != checkedProcessId)
                        {
                            checkedProcessId = foregroundProcessId;
                            excludedForeground = IsExcludedProcess(foregroundProcessId, excludedPaths);
                        }

                        bool protectedMode = excludedForeground ||
                                             IsFullscreenForeground(foregroundWindow) ||
                                             IsCursorCaptured();
                        if (protectedMode)
                        {
                            if (parked)
                            {
                                restoreAfterProtection = true;
                                if (!IsMouseButtonDown())
                                {
                                    POINT restored;
                                    if (TryRestoreCursor(saved, out restored))
                                    {
                                        parked = false;
                                        restoreAfterProtection = false;
                                        current = restored;
                                    }
                                }
                            }
                            last = current;
                            armedByInput = false;
                            idle.Restart();
                            continue;
                        }

                        if (parked)
                        {
                            if ((restoreAfterProtection || !SamePoint(current, park)) && !IsMouseButtonDown())
                            {
                                POINT restored;
                                if (TryRestoreCursor(saved, out restored))
                                {
                                    parked = false;
                                    restoreAfterProtection = false;
                                    last = restored;
                                    armedByInput = false;
                                    idle.Restart();
                                }
                            }
                            continue;
                        }

                        if (!SamePoint(current, last))
                        {
                            last = current;
                            armedByInput = false;
                            idle.Restart();
                            continue;
                        }

                        if (typingKeyPressed)
                            armedByInput = true;

                        if (armedByInput && idle.Elapsed.TotalSeconds >= timeoutSeconds)
                        {
                            saved = current;
                            park = GetParkPoint(current);
                            if (SamePoint(saved, park))
                            {
                                armedByInput = false;
                            }
                            else
                            {
                                if (SetCursorPos(park.X, park.Y))
                                {
                                    parked = true;
                                    restoreAfterProtection = false;
                                    last = park;
                                }
                                else
                                {
                                    armedByInput = false;
                                }
                            }
                            idle.Restart();
                        }
                    }
                }
                finally
                {
                    while (parked)
                    {
                        POINT restored;
                        if (IsMouseButtonDown() || !TryRestoreCursor(saved, out restored))
                        {
                            Thread.Sleep(50);
                            continue;
                        }
                        parked = false;
                    }
                }
            }
        }
    }
}
'@

Add-Type -TypeDefinition $source -Language CSharp

if ($CheckOnly) {
    Write-Output "OK"
    exit 0
}

[CursorParker]::Run($idleSeconds, [string[]]$excludedGamePaths)
