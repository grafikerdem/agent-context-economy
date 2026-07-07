# Agent Context Economy (ACE)

> [!IMPORTANT]
> Never retrieve more source code than is required for the current reasoning step. Prefer progressive retrieval over exhaustive retrieval.

When navigating source code, optimize for **progressive information retrieval** rather than maximum information retrieval.

### Navigation Principles

* Prefer **layered exploration** over dumping large amounts of source code.
* Retrieve only the minimum information required to complete the current reasoning step.
* Escalate information gradually instead of jumping directly to full source code.

Recommended progression:

1. **Summary** → Understand overall structure.
2. **Signature** → Inspect public API and contracts.
3. **Body** → Read implementation details only when necessary.
4. **Full** → Read complete source only as a last resort.

### Symbol Navigation

When using repository navigation tools:

* Prefer symbol-based navigation over file-based navigation.
* Use reference lookups when no definition exists.
* Avoid reading entire files when a symbol window or small context is sufficient.
* Keep context windows intentionally small unless additional context is required to solve the task.

### Context Economy

Every retrieved line consumes context budget.

Before requesting more code, ask whether the additional lines are required to complete the current task.

Prefer multiple small, targeted reads over one large source dump.

Default to the smallest useful context and expand only when the previous layer is insufficient.

### Library Guidelines

* ACE lib files must be side-effect-free and must not print output when dot-sourced.
