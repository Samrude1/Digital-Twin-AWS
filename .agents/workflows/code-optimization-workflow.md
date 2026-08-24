---
slash_command: /optimize
description: "Clean up, condense, and refactor bloated or spaghetti code to professional-grade quality."
trigger_phrases:
  - "optimize this code"
  - "refactor"
  - "clean up the codebase"
  - "this is getting messy"
  - "too much duplicated code"
  - "code smells"
when_not_to_use: "Use /new-feature for adding new functionality. This workflow is strictly for improving existing code without changing behavior."
---

# Code Optimization Workflow

> **Purpose**: Clean up, condense, and optimize existing code. Especially useful when code has grown bloated or spaghetti-like after rapid development. The goal is professional-grade quality — not rewriting for its own sake.
> **Activates when**: User asks "refactor", "optimize", "clean up", or says code is getting messy.
> **Avoid when**: The goal is to add new behavior. Optimization must not change observable functionality.

---

## Prerequisites

Before analyzing any code, read these files to understand the established standards:

- [ ] [`.agents/context/architecture.md`](../context/architecture.md) — understand the intended structure before judging what is "wrong"
- [ ] [`.agents/context/code-standards.md`](../context/code-standards.md) — understand what patterns are considered correct here

---

## Step 1: Analyze (`/optimize`)

**Goal**: Build a complete picture of what is wrong before touching any code.

- [ ] Review the target file(s), component(s), or module(s).
- [ ] Identify and categorize issues:
  - **DRY violations**: Duplicated logic that should be extracted into a shared utility or hook
  - **Bloated functions**: Functions doing more than one thing — candidates for decomposition
  - **Dead code**: Commented-out blocks, unused imports, unreachable paths
  - **Naming issues**: Variables or functions with unclear, abbreviated, or misleading names
  - **Architectural drift**: Code that violates the patterns defined in `architecture.md`
- [ ] Note what must NOT change (public APIs, shared interfaces, database contracts).

**Output**: A categorized list of issues — no code changes yet.

---

## Step 2: Plan (`/architect`)

**Goal**: Agree on the refactoring scope before writing a single line.

- [ ] Create or update the `implementation_plan.md` artifact outlining:
  - Which files will change
  - What specific refactors will happen
  - What will stay the same
- [ ] ⏸ **Present the plan to the user and wait for explicit approval before proceeding.**

**Output**: Approved `implementation_plan.md` artifact.

---

## Step 3: Optimize & Condense

**Goal**: Execute the approved plan — no scope creep.

- [ ] 💡 *Tip: For broad refactoring across multiple files, recommend the user activate `/goal` mode so the agent operates autonomously with maximum thoroughness.*
- [ ] Refactor code to be clean, professional, and maintainable.
- [ ] Break down massive functions or components into smaller, logical, reusable pieces.
- [ ] Remove dead code, redundant comments, and unnecessary dependencies.
- [ ] Improve naming conventions for variables and functions for better readability.
- [ ] Do not change behavior — if a behavior change is needed, flag it and stop.

**Output**: Cleaner codebase matching the approved plan.

---

## Step 4: Review & Verify (`/review`)

**Goal**: Confirm the refactoring did not introduce regressions.

- [ ] Does the refactored code behave identically to the original? (Run existing tests if available)
- [ ] Is the code actually smaller, faster, or easier to read than before? (If not, revert)
- [ ] Does it align with the patterns in `architecture.md`?

**Output**: Walkthrough artifact confirming what changed and that nothing broke.

---

## Step 5: Close the Loop (`/imprint`)

- If the optimization produced a new standard pattern or utility, record it in [`.agents/context/architecture.md`](../context/architecture.md) or [`.agents/context/ui-registry.md`](../context/ui-registry.md) to prevent the same bad pattern from re-emerging.
- Run `/remember save` to preserve session knowledge.
- Ask the user: *"Optimization complete. Do you want me to write or update tests to lock in this behavior?"*

---

## ⚠️ Anti-Patterns — Never Do These

- ❌ **Do not start rewriting code before Step 2 is approved.** Unsanctioned refactors break things and break trust.
- ❌ **Do not change behavior during optimization.** If you find a bug while refactoring, flag it separately — do not silently fix it.
- ❌ **Do not optimize for elegance at the cost of clarity.** Code that is clever but unreadable is worse than code that is verbose but obvious.

---

## 📎 Context Links

- [architecture.md](../context/architecture.md)
- [code-standards.md](../context/code-standards.md)
- [ui-registry.md](../context/ui-registry.md)
