param(
    [ValidateRange(1, 3600)]
    [int]$TimeoutSeconds = 1,
    [switch]$CheckOnly,
    [switch]$Stop,
    [switch]$Pause,
    [switch]$Resume
)

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

    private static bool IsFullscreenForeground()
    {
        IntPtr window = GetForegroundWindow();
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
        GetMonitorInfo(monitor, ref info);

        POINT park = new POINT();
        park.X = info.Monitor.Right - 2;
        park.Y = info.Monitor.Bottom - 2;
        return park;
    }

    public static void Run(int timeoutSeconds)
    {
        bool mutexCreated;
        using (Mutex mutex = new Mutex(true, @"Local\CursorParker", out mutexCreated))
        {
            if (!mutexCreated) return;

            bool eventCreated;
            using (EventWaitHandle stopEvent = new EventWaitHandle(false,
                EventResetMode.ManualReset, @"Local\CursorParkerStop", out eventCreated))
            using (EventWaitHandle pauseEvent = new EventWaitHandle(false,
                EventResetMode.ManualReset, @"Local\CursorParkerPause", out eventCreated))
            using (EventWaitHandle resumeEvent = new EventWaitHandle(false,
                EventResetMode.ManualReset, @"Local\CursorParkerResume", out eventCreated))
            {
                stopEvent.Reset();
                pauseEvent.Reset();
                resumeEvent.Reset();

                POINT last;
                if (!GetCursorPos(out last)) return;

                POINT saved = last;
                POINT park = last;
                bool parked = false;
                bool armedByInput = false;
                bool paused = false;
                Stopwatch idle = Stopwatch.StartNew();
                WasTypingKeyPressed();

                try
                {
                    while (!stopEvent.WaitOne(50))
                    {
                        if (pauseEvent.WaitOne(0))
                        {
                            pauseEvent.Reset();
                            paused = true;
                            armedByInput = false;
                            if (parked)
                            {
                                SetCursorPos(saved.X, saved.Y);
                                parked = false;
                                last = saved;
                            }
                        }

                        if (resumeEvent.WaitOne(0))
                        {
                            resumeEvent.Reset();
                            paused = false;
                            armedByInput = false;
                            GetCursorPos(out last);
                            idle.Restart();
                        }

                        POINT current;
                        if (!GetCursorPos(out current)) continue;
                        bool typingKeyPressed = WasTypingKeyPressed();

                        if (paused)
                        {
                            last = current;
                            idle.Restart();
                            continue;
                        }

                        bool protectedMode = IsFullscreenForeground() || IsCursorCaptured();
                        if (protectedMode)
                        {
                            if (parked)
                            {
                                SetCursorPos(saved.X, saved.Y);
                                parked = false;
                                current = saved;
                            }
                            last = current;
                            armedByInput = false;
                            idle.Restart();
                            continue;
                        }

                        if (parked)
                        {
                            if (!SamePoint(current, park))
                            {
                                SetCursorPos(saved.X, saved.Y);
                                parked = false;
                                last = saved;
                                armedByInput = false;
                                idle.Restart();
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
                            if (!SamePoint(saved, park))
                            {
                                SetCursorPos(park.X, park.Y);
                                parked = true;
                                last = park;
                            }
                            idle.Restart();
                        }
                    }
                }
                finally
                {
                    if (parked) SetCursorPos(saved.X, saved.Y);
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

if ($Stop) {
    try {
        $stopEvent = [Threading.EventWaitHandle]::OpenExisting("Local\CursorParkerStop")
        $stopEvent.Set() | Out-Null
        $stopEvent.Dispose()
    }
    catch {
    }
    exit 0
}

if ($Pause) {
    try {
        $pauseEvent = [Threading.EventWaitHandle]::OpenExisting("Local\CursorParkerPause")
        $pauseEvent.Set() | Out-Null
        $pauseEvent.Dispose()
    }
    catch {
    }
    exit 0
}

if ($Resume) {
    try {
        $resumeEvent = [Threading.EventWaitHandle]::OpenExisting("Local\CursorParkerResume")
        $resumeEvent.Set() | Out-Null
        $resumeEvent.Dispose()
    }
    catch {
    }
    exit 0
}

[CursorParker]::Run($TimeoutSeconds)
