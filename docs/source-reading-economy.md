# Source Reading Economy

Avoid reading large files by scrolling top/middle/bottom with repeated windows.

Use this flow:

```text
unknown files -> investigate.ps1 or search.ps1
known file    -> find-in-file.ps1
known symbol  -> read-symbol.ps1
nearby line   -> read-window.ps1
```

If more than two windows are needed in the same file, stop and summarize what is missing. Prefer a more exact symbol or keyword.
