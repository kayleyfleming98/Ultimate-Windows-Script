Kayley's Mega Tool
==================

Kayley's Mega Tool is an elevated Windows PowerShell utility for optional
system maintenance and configuration. Select the tasks you want in the GUI;
unchecked tasks are skipped.
If it is not already elevated, the script requests Administrator access through
the standard Windows User Account Control (UAC) prompt.

Features
--------
- Create a system restore point and remove existing shadow copies
- Adjust performance, power, memory, and storage settings
- Optionally remove custom power plans, keeping Windows built-in plans and the
  Kayley's Mega Tool performance plan (requires confirmation)
- Set UAC to Never notify (administrator consent popups are disabled; UAC itself
  remains enabled)
- Remove selected non-Xbox built-in Windows apps
- Change selected Windows services and scheduled tasks
- Adjust Microsoft Store auto-update, privacy, security, and UI settings
- Optionally check for Windows personalization/location policy restrictions and
  device join status (read-only; it does not change policy or enrollment)
- Clean temporary files, thumbnail cache, and the Recycle Bin
- Reset network components
- Run Windows SFC and DISM repair tools
- Update installed packages; driver updates are checked only when the optional
  PSWindowsUpdate module is already installed
- Optionally download and run Microsoft Activation Scripts (MAS) from its
  upstream source (requires a separate confirmation)
- Choose advanced network, gaming, privacy/app-cleanup, services, maintenance,
  system-security, startup-cleanup, and Edge tweaks independently
- Xbox choices are separate and off by default: Xbox app, Game Bar, Game Overlay,
  Identity Provider, Speech to Text, TCUI, Game DVR, Xbox authentication service,
  and Xbox Game Save service. Leave them untouched while running other tasks.

Important
---------
- Approve the Windows UAC prompt when elevated access is needed; the tool cannot
  and should not bypass Windows permission prompts. Review each selected task.
- A policy diagnostic can report settings and join status, but cannot reliably
  determine whether a device belongs to a school. Do not remove school or
  organization management; ask its administrator about managed restrictions.
- Several settings are system-wide and may reduce security or remove data and
  features. Never notify reduces protection against unwanted system changes.
  Advanced tweaks can disable VBS and exploit mitigations.
- Power-plan cleanup may delete OEM or user-created plans; it is off by default
  and asks for confirmation.
- A restore point is not a substitute for a full backup. Some changes may not
  be reversible through System Restore.
- Network resets can interrupt connectivity; SFC, DISM, and package updates may
  take a while.
- The tool does not install PowerShell modules during a GUI run. To enable driver
  update checks, install PSWindowsUpdate separately; otherwise driver updates
  are skipped with a warning.
- OneDrive uninstall preserves files in OneDrive folders. Back up or manage
  synced files separately.

Activation-script attribution
-----------------------------
The optional MAS feature downloads and runs the script from its upstream source;
the MAS script itself is not bundled with this tool. Credit for Microsoft
Activation Scripts (MAS): MASSGRAVEL. The feature is off by default and asks for
confirmation before downloading and running the upstream script. Use it only if
you trust and intend to use that project. For legitimate Windows activation,
use Settings > System > Activation with a valid license.

created by Kayley Fleming
