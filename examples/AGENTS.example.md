# AGENTS.example.md — Agent Context Economy Rules

Copy the relevant sections into your project-level `AGENTS.md`, `CLAUDE.md`, or equivalent agent instruction file.

## Agent Context Economy Stack

Use the stack to acquire context in layers:

1. **Continuity** — recover the current task, relevant paths, and useful prior searches from small disposable state.
2. **Repository Map** — orient from directory structure, file counts, source locations, and likely entry points.
3. **Discovery** — narrow the repository with one focused, batched investigation.
4. **Targeted Reading** — read a symbol first, then one nearby window if needed.
5. **Workflow** — take bounded steps and keep only metadata that prevents repeated discovery.
6. **Validation** — run the narrowest relevant check and compact noisy output.

The stack is a decision framework, not a requirement to run every helper for every task.

## Startup Policy

At the start of a repository task:

1. Read the repository's own instruction file first when present.
2. Run `agent-start.ps1` to inspect existing continuity and repository-map summaries.
3. If no repository map exists, or the structure has materially changed, run `repo-map.ps1` once.
4. Set a short task with `session-state.ps1 set-task`; record only a bounded set of relevant file paths and useful searches.
5. Follow the preferred path: `repo-map -> investigate -> read-symbol -> read-window -> run-compact`.

Skip startup ceremony for a trivial change in a known file. Never store secrets, file contents, command output, or large histories in session state.

## Raw Exploration Fallback Policy

ACE helpers are preferred, but they must not block necessary investigation.

Use raw `rg`, `Get-ChildItem`, `Select-String`, or direct source reads only when:

- a helper cannot express the required query,
- structured or semantic navigation is unavailable or incomplete,
- exact raw output is required to diagnose a helper failure, or
- a compact result omitted evidence needed for a decision.

Before falling back, state what information is missing. Keep the raw query bounded by path, pattern, file type, or output limit. Summarize the result before continuing and return to targeted reading as soon as the likely files are known.

## Approval Economy Policy

Treat approvals as a limited interaction budget:

- combine related read-only checks into one informative command when safe,
- prefer commands with reusable, narrowly scoped approval rules,
- do not request approval for speculative or redundant exploration,
- never broaden a write or destructive action merely to reduce approval count,
- when approval is required, explain the exact action, scope, and reason in one concise request.

Approval economy reduces interruptions; it never overrides least privilege, repository boundaries, or user intent.

## Command Budget / Tool Approval Economy

Helper scripts reduce context usage, but agents must also minimize command count.

For a targeted task, default command budget is:

- Level 0: 0-2 commands
- Level 1: 1-4 commands
- Level 2: 3-8 commands
- Level 3: 6-12 commands
- Level 4: ask before exceeding 12 commands

Read-only helper commands still count toward this budget.

Before running more than 8 read/search/window commands, stop and summarize:

1. what has been learned,
2. which exact files are still unknown,
3. why more commands are needed,
4. the next 3 commands only.

Do not perform exploratory command chains such as:

- search A
- search B
- search C
- read-window A
- read-window B
- read-window C
- search D
- search E

Instead:

1. run one broad but compact `investigate.ps1` command,
2. choose the top 1-3 relevant files,
3. use `find-in-file.ps1` only inside those files when necessary,
4. use `read-symbol.ps1` or `read-window.ps1` only for the exact target.

If the user or tool requires approval for every command, prefer fewer, more informative commands over many tiny commands.

### Investigation Batching

When a task requires several related searches, agents MUST prefer one batched investigation command over many small search commands.

When more than 3 related searches are needed, use `investigate.ps1` instead of repeated `search.ps1` calls.

Use:

```powershell
.\scripts\ai\investigate.ps1 -Patterns "<a>","<b>","<c>" -Paths "<path1>","<path2>" -MaxFiles 12
```

After `investigate.ps1`:

1. Run at most the recommended next 3 commands.
2. Pick only the top 1-3 relevant files.
3. Use `read-symbol.ps1` for classes, services, controllers, policies, models, named functions, relation methods, and React components.
4. Use `read-window.ps1` for routes, migrations, config arrays, and nearby assertions in tests.
5. Do not continue broad exploratory search chains unless the investigation summary is insufficient.
6. If more than 8 total commands are needed, stop and summarize why before continuing.

Do not replace targeted file reads with repeated broad searches.

## Source Reading Economy

Agents MUST use source navigation helpers before dumping source code into context.

This policy exists to reduce context waste while preserving enough local code context to avoid wrong assumptions.

### Search Before Reading

For repository or folder-level search, use:

```powershell
.\scripts\ai\search.ps1 -Pattern "<keyword>" -Path <folder>
```

`search.ps1` is a summary tool, not a grep dump. It should show:

- total matched files,
- total occurrences,
- top files by hit count,
- first relevant matches by file,
- the recommended next read command.

Do not inspect all matches.

For a specific file, use:

```powershell
.\scripts\ai\find-in-file.ps1 -Path <path> -Pattern "<keyword>"
```

### Search Rules

Avoid generic searches unless they are already narrowed to a tiny file:

- `id`
- `data`
- `status`
- `project`
- `user`
- `name`
- `type`
- `value`

Prefer exact names:

- class name,
- method name,
- React component name,
- hook/state name,
- request/policy/action name,
- route name,
- permission key,
- database column,
- enum value,
- translation key.

If a search returns many matches, do not read them all. Narrow the pattern or path.

If a search returns no matches, do not repeat the same search unchanged. Try a related exact symbol or search a narrower likely folder.

### Read Small Windows

After finding a relevant line, use:

```powershell
.\scripts\ai\read-window.ps1 -Path <path> -Line <line> -Context 30
```

Default source window is 30 lines before and after the target line.

### Prefer Symbols When Possible

If the target is a class, function, component, hook, type, enum, policy method, or service method, prefer:

```powershell
.\scripts\ai\read-symbol.ps1 -Path <path> -Symbol "<symbol>" -Context 20
```

For large files, do not use `read-symbol.ps1` on a whole class/component unless the class/component is small.

Prefer method, function, hook, relation, state variable, or callback symbols first.

Avoid:

```powershell
.\scripts\ai\read-symbol.ps1 -Path <path> -Symbol "class LargeClass"
.\scripts\ai\read-symbol.ps1 -Path <path> -Symbol "function HugeComponent"
```

Prefer:

```powershell
.\scripts\ai\read-symbol.ps1 -Path <path> -Symbol "<specificMethodOrStateName>"
.\scripts\ai\read-window.ps1 -Path <path> -Line <line> -Context 30
```

### Known File Reading Protocol

When the target file is already known, do not explore the same file with repeated `read-window.ps1` calls.

Use this order:

1. Use `find-in-file.ps1` for the exact keyword, field, prop, route, state, handler, component name, or imported symbol.
2. Use `read-symbol.ps1` for a class, method, function, component, hook, callback, relation, or state block.
3. Use `read-window.ps1` only for one local nearby context window.
4. If more than 2 `read-window.ps1` calls are needed in the same file, stop and summarize what is missing before running more commands.

Do not scan a known large file by reading top, middle, bottom, imports, and fields with repeated windows.

For large TSX/JS/PHP/Python/etc. files, prefer exact symbols and fields:

- component/class/function name,
- form or submit handler,
- `onValueChange` or event handler,
- field name,
- state variable,
- callback name,
- imported component name,
- validation schema name,
- prop/type/interface name.

Default same-file budget:

- maximum 2 `read-window.ps1` calls per file,
- after that, use `find-in-file.ps1`, `read-symbol.ps1`, or stop and summarize what is still unknown.

If imports or type definitions are needed, read the top window once only.

Do not read the top, middle, and bottom of the same file as a substitute for symbol-based navigation.

### Prohibited By Default

Do not use by default:

- raw `Get-Content <file>` on large files,
- manual loops printing 100+ source lines,
- broad raw `Select-String` across folders,
- raw broad `rg .`,
- generic searches like `"id"`, `"status"`, `"project"`, `"data"` without narrowing,
- whole-file dumps of large pages, controllers, services, migrations, policies, requests, or tests.

### Expansion Rule

If the first window is insufficient:

1. state what context is missing,
2. rerun `read-window.ps1` with `-Context 60`, or
3. read the directly related symbol/type/policy/request/test.

Do not guess from incomplete context.
Do not dump the whole file unless explicitly approved.

## AI Helper Scripts / Terminal Output Economy

Terminal output economy is mandatory.

For noisy commands, agents MUST use:

```powershell
.\scripts\ai\run-compact.ps1 -Command "<command>"
```

Commands always considered noisy:

- `php artisan test`
- `npm run build`
- `npm run typecheck`
- `npx tsc --noEmit`
- `eslint`
- `git diff`
- `git show`
- `git log`
- broad `rg`
- recursive directory listings
- long log files

These commands MUST NOT be executed raw by default.

For tests, use targeted filters:

```powershell
.\scripts\ai\test.ps1 -Filter <SpecificTest>
```

Raw output is allowed only when:

1. the user explicitly requests full raw output,
2. a helper script fails,
3. exact unfiltered output is required for debugging,
4. a previous compact run did not provide sufficient failure context.

When using a raw command, explain why before running it.

## Minimal Change Protocol

For explicitly small, local, or mechanical changes, agents must avoid over-investigation.

This protocol applies when the user requests:

- a one-line fix,
- a script syntax fix,
- a typo/copy change,
- a small UI text adjustment,
- a small command/script correction,
- a targeted replacement in a known file,
- a narrow bug fix with an already identified line or file.

Rules:

1. Treat the task as Level 0 or Level 1 unless there is clear evidence of domain risk.
2. Do not run the full startup procedure unless the change touches high-risk production behavior.
3. Do not scan broad docs, tests, controllers, services, or unrelated source files.
4. Inspect only the named file and the smallest necessary window.
5. Prefer direct patching over exploration.
6. Do not run tests unless the change affects runtime behavior.
7. If verification is needed, run only the smallest relevant command.
8. Do not expand the task scope without asking.

## PowerShell Execution and UTF-8 Safety

The user environment may use Windows PowerShell with `CurrentUser = RemoteSigned`.

Run helper scripts normally first:

```powershell
.\scripts\ai\<script>.ps1
```

If PowerShell blocks a helper script due to execution policy or file origin, retry once with process-scoped bypass:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ai\<script>.ps1
```

This process-scoped bypass is allowed and does not change machine policy.

Do not repeatedly explain this in every session unless the bypass fails.

For pasted prompt files, agent attachment files, Turkish documentation, and UTF-8 text files, use:

```powershell
.\scripts\ai\read-text.ps1 -Path <path>
```

or:

```powershell
Get-Content -Raw -Encoding UTF8 <path>
```

Never interpret mojibake terminal output as real source text.

## Script Verification

After changing AI helper scripts, run:

```powershell
.\scripts\ai\smoke-test.ps1
```

The smoke test must pass before relying on the scripts in agent workflows.
