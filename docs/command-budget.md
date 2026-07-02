# Command Budget

Context output is not the only cost. In tools that ask for approval before shell commands, command count itself becomes a cost.

Use these defaults:

- Level 0: 0-2 commands
- Level 1: 1-4 commands
- Level 2: 3-8 commands
- Level 3: 6-12 commands
- Level 4: ask before exceeding 12 commands

When more than 3 related searches are needed, use `investigate.ps1` instead of many small `search.ps1` calls.
