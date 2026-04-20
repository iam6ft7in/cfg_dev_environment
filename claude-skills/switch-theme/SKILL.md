---
name: switch-theme
description: Toggle VS Code between Solarized Dark and a yellow-on-black theme by editing settings.json.
---

# /switch-theme, Toggle VS Code Theme

You are toggling VS Code's color theme between Solarized Dark and a yellow-on-black theme. Follow every step in order. Show each file path you are reading or writing.

---

## Step 1: Locate VS Code Settings

The VS Code user settings file is at:
```
%APPDATA%\Code\User\settings.json
```

Resolve `%APPDATA%` to the actual path. In PowerShell:
```powershell
$settingsPath = "$env:APPDATA\Code\User\settings.json"
```

Typical resolved path: `C:\Users\{username}\AppData\Roaming\Code\User\settings.json`

If the file does not exist, stop: "VS Code settings.json not found at {path}. Is VS Code installed?"

---

## Step 2: Read the Current Theme

Read the file and find the value of `"workbench.colorTheme"`.

If the key is absent, treat it as if the current theme is unknown (proceed as if switching TO Solarized Dark, i.e., apply yellow-on-black cleanup and restore Solarized Dark).

Store the current theme value as `{current_theme}`.

---

## Step 3: Decide Which Direction to Switch

- If `{current_theme}` is exactly `"Solarized Dark"`:
  Switch TO yellow-on-black. Go to Step 4.

- If `{current_theme}` is anything else (including `"Default Dark Modern"` or any other theme):
  Restore Solarized Dark. Go to Step 5.

---

## Step 4: Switch to Yellow-on-Black

Modify `settings.json` to apply the yellow-on-black theme. Make the following changes:

**a.** Set the base theme:
```json
"workbench.colorTheme": "Default Dark Modern"
```

**b.** Add or replace the `workbench.colorCustomizations` block:
```json
"workbench.colorCustomizations": {
  "editor.background": "#000000",
  "editor.foreground": "#FFFF00",
  "editor.lineHighlightBackground": "#111100",
  "editor.selectionBackground": "#444400",
  "terminal.background": "#000000",
  "terminal.foreground": "#FFFF00",
  "editorCursor.foreground": "#FFFF00",
  "editorLineNumber.foreground": "#888800",
  "editorLineNumber.activeForeground": "#FFFF00",
  "statusBar.background": "#111100",
  "statusBar.foreground": "#FFFF00",
  "activityBar.background": "#000000",
  "activityBar.foreground": "#FFFF00",
  "sideBar.background": "#0A0A00",
  "sideBar.foreground": "#CCCC00",
  "tab.activeBackground": "#111100",
  "tab.activeForeground": "#FFFF00",
  "tab.inactiveBackground": "#000000",
  "tab.inactiveForeground": "#888800"
}
```

**c.** Add or replace the `editor.tokenColorCustomizations` block:
```json
"editor.tokenColorCustomizations": {
  "textMateRules": [
    {
      "scope": "source",
      "settings": { "foreground": "#FFFF00" }
    },
    {
      "scope": "comment",
      "settings": { "foreground": "#AAAAAA", "fontStyle": "italic" }
    },
    {
      "scope": "string",
      "settings": { "foreground": "#FFDD00" }
    },
    {
      "scope": "keyword",
      "settings": { "foreground": "#FFAA00", "fontStyle": "bold" }
    },
    {
      "scope": "constant.numeric",
      "settings": { "foreground": "#FFBB44" }
    }
  ]
}
```

Write the updated JSON back to `settings.json`. Preserve all other existing keys.

Tell the user:
```
Switched to yellow-on-black theme.

VS Code must be reloaded for changes to take full effect.
Press Ctrl+Shift+P and run "Developer: Reload Window", or close and reopen VS Code.

Type /switch-theme again to return to Solarized Dark.
```

Stop here.

---

## Step 5: Restore Solarized Dark

Modify `settings.json`:

**a.** Set the base theme:
```json
"workbench.colorTheme": "Solarized Dark"
```

**b.** Remove the following keys entirely if they are present:
- `workbench.colorCustomizations`
- `editor.tokenColorCustomizations`

Write the updated JSON back to `settings.json`. Preserve all other existing keys.

Tell the user:
```
Restored Solarized Dark theme.

VS Code must be reloaded for changes to take full effect.
Press Ctrl+Shift+P and run "Developer: Reload Window", or close and reopen VS Code.

Note: Solarized Dark must be installed as a VS Code extension. If the theme does not appear,
install it from the Extensions marketplace (search "Solarized Dark").
```

---

## Implementation Note

When editing settings.json, parse it as JSON, make the targeted changes, and write it back with 2-space indentation. Do not use regex substitution on the raw text, parse and re-serialize to avoid corrupting the file.

In PowerShell:
```powershell
$settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
# Make changes to $settings object
$settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
```

Note: `ConvertFrom-Json` in PowerShell 7 supports ordered hashtables. Verify the file is valid JSON before and after editing.
