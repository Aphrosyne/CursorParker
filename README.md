# CursorParker

A lightweight Windows cursor parking script.

## Behavior

- Arms only after system input is detected while the mouse is stationary.
- Parks the pointer in the bottom-right corner after 1 second of mouse inactivity.
- Restores the pointer to its saved position on the next mouse movement.
- Automatically pauses for borderless full-screen windows and captured cursors.
- Does not replace cursor images, install keyboard hooks, or use UI Automation.

## Usage

- `start_cursor_parker.cmd`: start the background process.
- `stop_cursor_parker.cmd`: stop it and restore a parked pointer.
- `pause_cursor_parker.cmd`: temporarily pause parking.
- `resume_cursor_parker.cmd`: resume parking.
- `enable_startup.cmd`: enable launch at user sign-in.
- `disable_startup.cmd`: disable launch at user sign-in.
- `toggle_startup.cmd`: toggle launch at user sign-in.

Startup is implemented as `CursorParker.lnk` in the current user's Startup
folder. It does not require administrator access or a system-wide registry key.

The PowerShell source is ASCII-only and requires no third-party runtime.
