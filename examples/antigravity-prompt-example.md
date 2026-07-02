# Antigravity Prompt Example

Approval economy is important.

Use one batched investigation command when searching related concepts across files:

```powershell
.\scripts\ai\investigate.ps1 -Patterns "<a>","<b>","<c>" -Paths "app","routes","resources/js","tests"
```

After that, run at most the recommended next 3 commands.

If the file is already known, do not scroll it with repeated windows. Use:

```powershell
.\scripts\ai\find-in-file.ps1 -Path <path> -Pattern "<exact keyword>"
.\scripts\ai\read-symbol.ps1 -Path <path> -Symbol "<specific symbol>" -Context 30
```

Stop and summarize before exceeding 8 shell/helper commands.
