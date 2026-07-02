# Agent Context Economy

A small PowerShell toolkit for reducing terminal noise, source-code dumping, repeated search chains, and approval fatigue when working with AI coding agents on large repositories.

It is designed for tools such as Codex, Antigravity, Cursor, Claude Code, Windsurf, and other agentic coding assistants that run shell commands and read repository files.

## What problem does this solve?

AI coding agents often waste context by:

- dumping full build/test output into the conversation,
- reading hundreds of lines from large source files,
- running many tiny search commands that require repeated approval,
- scrolling through the same known file with repeated windows,
- using regex search when the user intended literal search,
- misreading UTF-8 text in Windows PowerShell.

This toolkit gives agents safer helper commands and an example `AGENTS.md` policy so they can investigate code with fewer tokens and fewer approvals.

## Included scripts

| Script | Purpose |
|---|---|
| `run-compact.ps1` | Run noisy commands and keep diagnostic output compact. |
| `test.ps1` | Run targeted test filters; prevents accidental full suites unless allowed. |
| `search.ps1` | Repository/folder search summary instead of grep dumps. |
| `investigate.ps1` | Batch related searches into one investigation summary. |
| `find-in-file.ps1` | Literal search inside one known file. |
| `read-window.ps1` | Read a small numbered window around one source line. |
| `read-symbol.ps1` | Read a class/function/component/method/symbol context. |
| `read-text.ps1` | Read pasted/docs/Turkish UTF-8 text safely. |
| `diff-summary.ps1` | Compact git status/diff overview. |
| `diff-file.ps1` | Compact diff for one file. |
| `compare-output.ps1` | Compare raw vs compact output without dumping raw logs. |
| `smoke-test.ps1` | Verify the helper scripts work in the current repository. |
| `setup-ai-scripts.ps1` | Unblock downloaded PowerShell scripts on Windows. |

## Quick install

Copy the scripts into your repository, for example:

```text
scripts/ai/*.ps1
```

Then unblock them once on Windows:

```powershell
Get-ChildItem .\scripts\ai\*.ps1 | Unblock-File
```

Or run:

```powershell
.\scripts\ai\setup-ai-scripts.ps1
```

Then run the smoke test:

```powershell
.\scripts\ai\smoke-test.ps1
```

## Recommended usage

### Noisy command

```powershell
.\scripts\ai\run-compact.ps1 -Command "npm run build"
.\scripts\ai\run-compact.ps1 -Command "npx tsc --noEmit"
.\scripts\ai\run-compact.ps1 -Command "php artisan test" -MaxLines 250
```

### Targeted tests

```powershell
.\scripts\ai\test.ps1 -Filter SomeFeatureTest
```

### Search unknown domain

```powershell
.\scripts\ai\investigate.ps1 `
  -Patterns "ExchangeRate","exchange_rates","exchange-rates" `
  -Paths "app","routes","resources/js","database","tests"
```

### Known file

```powershell
.\scripts\ai\find-in-file.ps1 -Path resources/js/Pages/Checks/Create.tsx -Pattern "onValueChange"
.\scripts\ai\read-symbol.ps1 -Path resources/js/Pages/Checks/Create.tsx -Symbol "handleSubmit" -Context 30
.\scripts\ai\read-window.ps1 -Path resources/js/Pages/Checks/Create.tsx -Line 120 -Context 30
```

## Add the agent rules

Copy the relevant sections from:

```text
examples/AGENTS.example.md
```

into your project-level `AGENTS.md` or equivalent agent instruction file.

## Philosophy

The goal is not to blind the agent. The goal is to make it read code like a careful developer:

1. summarize first,
2. choose the most relevant file,
3. read the smallest meaningful context,
4. expand only when needed,
5. avoid broad dumps unless explicitly approved.

## License

MIT
