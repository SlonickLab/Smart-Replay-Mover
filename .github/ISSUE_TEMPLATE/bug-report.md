---
name: Bug report
about: Create a report to help us improve
title: "[BUG] "
labels: bug
assignees: SlonickLab

---

**Describe the bug**
A clear and concise description of what the bug is.
<!-- Example: "Desktop recordings are detected as Counter-Strike 2 even though no game is running" -->

**To Reproduce**
Steps to reproduce the behavior:
1. Open Game: [e.g. Counter-Strike 2 / No game running]
2. Action: [e.g. Pressed "Save Replay" hotkey / Stopped Recording / Took Screenshot]
3. Result: [e.g. Notification showed "Desktop", file moved to Desktop folder]

**Expected behavior**
A clear and concise description of what you expected to happen.

**Environment Info (Required):**
 - **Smart Replay Mover Version:** [e.g. v2.9.0]
 - **OBS Version:** [e.g. 32.1.1]
 - **OS:** [e.g. Windows 10 22H2 / Windows 11 / Ubuntu 24.04 / Arch Linux]
 - **Game Name:** [e.g. Cyberpunk 2077 / Desktop]

**Script Settings**
Please list relevant settings or attach a screenshot of the script settings window.
- Add game prefix: [Yes/No]
- Fallback folder: [e.g. Desktop]
- Custom Names used: [Yes/No]
- Scan all running processes: [Yes/No]
- OS Mode: [Auto-Detect / Windows / Linux]

**OBS Log File (Crucial)**
Go to **Help → Log Files → View Current Log** in OBS.
Search for `[Smart Replay]` and paste all matching lines here:
```text
[Smart_Replay_Mover.lua] [Smart Replay] ...
```

> [!TIP]
> Enable **Debug Mode** in the script's "Tools & Debug" section, reproduce the bug, then paste the log — this gives us much more detail to diagnose the issue.

**Screenshots**
If applicable, add screenshots of the notification, folder structure, or script settings.
