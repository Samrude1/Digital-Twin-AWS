---
slash_command: /debug
description: "Investigate a stuck bug or error with fresh eyes — from root cause analysis through fix and verification."
trigger_phrases:
  - "I'm stuck"
  - "this has been broken for a while"
  - "can you debug this"
  - "here's the error"
  - "nothing is working"
  - "look at this error"
  - "fix this bug"
  - "I've been going in circles"
  - "the agent couldn't fix it"
  - "fresh eyes on this"
  - "investigate this issue"
  - "help me troubleshoot"
  - "mikä tässä on vikana"
  - "en saa toimimaan"
when_not_to_use: "Use /optimize when there's no bug — just messy code. Use /test when the code works but needs automated test coverage. Use /new-feature when you want to add functionality, not fix broken functionality."
---

# Debug & Investigate Workflow

> **Purpose**: When development hits a wall — the bug won't go away, the error makes no sense, or even the AI agent has failed to fix it — this workflow provides a structured, fresh-eyes investigation. It takes whatever the user has (a description, a screenshot, a pasted error log) and systematically works from symptom to root cause to verified fix.
> **Activates when**: User says "I'm stuck", "debug this", "here's the error", "the agent couldn't fix it", pastes an error log, or shares a screenshot of broken behavior.
> **Avoid when**: The code works but is messy (use `/optimize`). The code works but needs tests (use `/test`). You want new functionality (use `/new-feature`).

---

## Prerequisites

Before looking at the bug, load the full system context so you can reason about the architecture — not just the broken file:

- [ ] [`.agents/context/architecture.md`](../context/architecture.md) — understand how the system is supposed to work
- [ ] [`.agents/context/project-overview.md`](../context/project-overview.md) — understand the business logic that should hold true
- [ ] [`.agents/context/database-schema.md`](../context/database-schema.md) — if the bug involves data, understand the data model
- [ ] [`.agents/context/code-standards.md`](../context/code-standards.md) — understand what "correct" looks like in this project

---

## Step 0: Intake — Gather the Evidence

**Goal**: Collect everything the user knows about the problem before doing any investigation.

- [ ] Accept **one or more** of the following from the user:
  - **A written description** of what is wrong and what was expected
  - **A pasted error log / stack trace** from the terminal, browser console, or server logs
  - **A screenshot or video** of the broken behavior
- [ ] Ask clarifying questions if the input is vague. Get specifics:
  - What **exactly** should happen vs. what **actually** happens?
  - **When** did this start? Was there a recent change that could have caused it?
  - **How many times** has this been attempted to fix already? (Determines if `/recover` failure mode classification is needed)
  - Is this **reproducible every time**, or intermittent?
- [ ] If the user reports **multiple fix attempts that made things worse** → stop. This may be a Failure Mode 2 (polluted session). Consider running `/recover` to classify the failure mode before continuing.

**Output**: A clear problem statement with all available evidence documented.

---

## Step 1: Investigate — Fresh Eyes Analysis

**Goal**: Forget every assumption from previous attempts. Read the code and the evidence as if seeing the project for the first time.

- [ ] **Parse the error signal**:
  - If there is a **stack trace** → trace it backward from the crash site to the originating call. Identify the exact file, line, and function where the failure occurs.
  - If there is a **wrong behavior (no crash)** → identify where the expected behavior diverges from the actual behavior. Find the decision point in the code where the wrong path is taken.
  - If there is a **screenshot** → map the visual symptom to the specific component, route, or data flow responsible for rendering it.
- [ ] **Read the relevant code** — but do NOT read the entire codebase. Focus on:
  - The file(s) directly mentioned in the error or symptom
  - One level up: what calls the broken code?
  - One level down: what does the broken code depend on?
- [ ] **Check recent changes** — run `git log --oneline -20` and `git diff HEAD~5` to see if a recent commit introduced the problem.
- [ ] **Check dependency versions** — if the error involves a third-party library, verify the installed version matches what the code expects. Look for breaking changes in changelogs.
- [ ] **Reproduce the bug yourself** — run the code and trigger the exact failure. If you cannot reproduce it, the problem may be environment-specific (Node version, OS, missing env vars, stale cache).

**Output**: A documented investigation with the specific code paths examined and observations made.

---

## Step 2: Diagnose — Root Cause Identification

**Goal**: Identify the actual root cause — not a symptom, not a guess. State it explicitly before proposing any fix.

- [ ] **Distinguish root cause from symptom**:
  - A **symptom** is what the user sees (e.g., "the page shows a 500 error")
  - A **root cause** is why it happens (e.g., "the API route references a column that was renamed in migration #14 but the query was not updated")
- [ ] **State the root cause clearly**:

  ```
  🔍 Root Cause Identified:

  Symptom: [what the user sees]
  Root cause: [why it actually happens]
  
  Evidence:
  - [file:line] — [what this code does wrong]
  - [specific observation from investigation]
  
  This is not [common misdiagnosis] because [reasoning].
  ```

- [ ] **Assess blast radius** — does fixing this root cause affect other parts of the system? Will the fix break anything else?
- [ ] **If the root cause is unclear after thorough investigation** — say so honestly. Do not guess. Consider:
  - Adding targeted `console.log` / debug statements to narrow down the issue
  - Creating a minimal reproduction case
  - Checking for known issues in dependency repos (GitHub Issues, changelogs)
- [ ] ⏸ **Present the diagnosis to the user and wait for confirmation before proceeding to the fix.**

**Output**: A confirmed root cause diagnosis with evidence. No code changes yet.

---

## Step 3: Fix — Implement the Correction

**Goal**: Write the minimum correct fix that addresses the root cause — not a workaround, not a band-aid.

- [ ] 💡 *Tip: If the fix spans multiple files or is complex, recommend the user activate `/goal` mode for autonomous, thorough execution.*
- [ ] **Fix the root cause directly** — not the symptom. If the root cause is a wrong database query, fix the query — do not add a try/catch that swallows the error.
- [ ] **Keep the fix minimal** — change only what is necessary to resolve the root cause. Do not refactor, clean up, or "improve" unrelated code during a bug fix.
- [ ] **If the fix requires an architectural change** → stop. Create an `implementation_plan.md` artifact and get user approval before proceeding. A bug fix should not silently become a refactor.
- [ ] **Document the fix inline** — add a brief code comment explaining *why* the fix is needed if it is not obvious:

  ```
  // Fix: Use `createdAt` instead of `created_at` — column was renamed in migration #14
  ```

**Output**: The implemented fix — targeted and minimal.

---

## Step 4: Verify — Confirm the Fix Works

**Goal**: Prove the fix resolves the original problem and does not break anything else.

- [ ] **Reproduce the original bug scenario** — run the exact same steps that triggered the failure. Confirm the bug is gone.
- [ ] **Run the existing test suite** — `npm test`, `vitest`, `pytest`, or equivalent. All existing tests must still pass.
- [ ] **Test edge cases around the fix**:
  - What happens with empty/null input?
  - What happens under the boundary conditions near the bug?
  - Does the fix hold under concurrent or rapid requests (if applicable)?
- [ ] **If the fix is for a UI issue** — visually confirm the UI renders correctly. Take a screenshot for the walkthrough.
- [ ] **If existing tests do not cover the fixed scenario** → write a regression test that would have caught this bug:

  ```
  // Regression test: verifies [specific scenario] does not return [wrong result]
  // See: /debug session [date] — root cause was [brief description]
  ```

- [ ] If the fix does NOT resolve the problem → **do not try another fix immediately.** Return to Step 2 and re-examine the root cause. If two diagnoses have both been wrong, escalate: this may be a deeper architectural issue (Failure Mode 3 in `/recover`).

**Output**: Confirmed working fix with passing test suite and optional regression test.

---

## Step 5: Close the Loop

- [ ] Create or update `walkthrough.md` artifact documenting:
  - The original symptom
  - The root cause
  - The fix applied
  - How it was verified
- [ ] **If this bug revealed a pattern that could recur** → update [`.agents/context/architecture.md`](../context/architecture.md) or [`.agents/context/code-standards.md`](../context/code-standards.md) with a note to prevent the same class of bug in the future.
- [ ] Run `/remember save` to preserve what was learned in this session.
- [ ] 💡 *Tip: If the user debugged something tricky and wants the agent to remember the pattern for next time, suggest running `/learn`.*
- [ ] Ask the user: *"Bug fixed and verified. Do you want me to write additional tests to lock in this fix, or is there another issue to investigate?"*

---

## ⚠️ Anti-Patterns — Never Do These

- ❌ **Never propose a fix before identifying the root cause.** Guessing at fixes without diagnosis is how sessions spiral into Failure Mode 2.
- ❌ **Never patch a symptom.** Adding `try/catch` around a crash or `|| ''` to hide a null is not a fix — it hides the real problem and makes future debugging harder.
- ❌ **Never make the fix bigger than the bug.** A bug fix is not an opportunity to refactor. Keep the diff minimal.
- ❌ **Never say "it should work now" without running the code.** Verify every fix by reproducing the original failure scenario.
- ❌ **Never keep trying after two failed diagnoses.** If two root cause hypotheses were both wrong, the problem is deeper than it appears. Re-evaluate whether this is actually a Failure Mode 3 (wrong foundation) via `/recover`.
- ❌ **Never ignore the user's context.** If the user says "I've tried X and Y already", do not suggest X or Y again. Start from where they left off, not from scratch.

---

## 📎 Context Links

- [architecture.md](../context/architecture.md)
- [project-overview.md](../context/project-overview.md)
- [database-schema.md](../context/database-schema.md)
- [code-standards.md](../context/code-standards.md)

---

## 🔗 Related Skills & Workflows

- **`/recover`** — If the investigation reveals the session itself is polluted (Failure Mode 2) or the foundation is wrong (Failure Mode 3), hand off to the recover skill for proper triage.
- **`/test`** — After the fix is verified, use the testing workflow to write comprehensive regression tests.
- **`/optimize`** — If the bug investigation reveals broader code quality issues, address the bug first, then suggest a separate `/optimize` pass.
