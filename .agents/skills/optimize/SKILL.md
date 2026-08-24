---
name: optimize
description: Analyzes and refactors code to follow best practices, clean up spaghetti logic, and condense the codebase for professional-grade quality.
---

When code gets built fast, it often gets bloated. Logic becomes entangled, patterns drift from the architecture, and "spaghetti code" starts to emerge. This skill is used to review, clean, and condense that code into a professional standard.

Run this skill when the codebase feels messy, when junior developers or AI have generated a lot of unstructured code, or as part of the Code Optimization Workflow.

---

## Step 1 — Analyze the Current State

Before making any changes, understand what you are looking at:

- Identify the file, component, or logic flow that needs optimization.
- Look for:
  - **Spaghetti logic**: Deeply nested `if/else` statements, massive functions, tangled dependencies.
  - **Bloat**: Unnecessary loops, redundant state, or duplicated code (DRY violations).
  - **Dead code**: Variables, imports, or functions that are no longer used.
  - **Inconsistencies**: Naming conventions that don't match, or logic that violates the established `architecture.md`.

---

## Step 2 — Formulate a Plan

Do NOT start deleting or rewriting code blindly. 

- Create an `implementation_plan.md` artifact (or update an existing one) detailing your findings.
- Propose structural changes:
  - "Extract this 200-line function into three smaller, testable helpers."
  - "Combine these redundant API calls."
  - "Simplify the state management to remove unnecessary re-renders."
- Present the plan to the developer for approval.

---

## Step 3 — Optimize & Condense

Once approved, perform the refactoring:

- **Extract and Modularize**: Break large components/functions into smaller, single-responsibility pieces.
- **Simplify**: Replace complex logic with simpler, built-in methods (e.g., modern array methods, simplified conditionals).
- **Clean Up**: Remove unused imports, variables, and dead code.
- **Document**: Ensure complex parts have concise, helpful comments explaining *why* something is done, not *what* is done.

---

## Step 4 — Verify

Refactoring must not change the expected behavior of the system.

- Ensure the optimized code still fulfills all original requirements.
- Run `/review` if needed to double-check against project standards.
- If a new architectural pattern was established to replace a messy one, recommend running `/imprint` so it becomes the new standard.
