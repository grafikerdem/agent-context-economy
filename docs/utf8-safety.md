# UTF-8 Safety

Windows PowerShell can display UTF-8 text as mojibake when reading pasted text or documentation without the correct encoding.

Use:

```powershell
.\scripts\ai\read-text.ps1 -Path <path>
```

or:

```powershell
Get-Content -Raw -Encoding UTF8 <path>
```

Never use mojibake terminal output as a patch anchor.
