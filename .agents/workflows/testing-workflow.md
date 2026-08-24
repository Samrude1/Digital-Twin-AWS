---
slash_command: /test
description: "Write, execute, and verify automated tests for a feature or component to prevent regressions."
trigger_phrases:
  - "write tests"
  - "add tests"
  - "test this feature"
  - "add unit tests"
  - "add integration tests"
  - "add E2E tests"
  - "improve test coverage"
when_not_to_use: "Use /review to check that a feature works — use /test when you want automated tests written to prevent future regressions."
---

# Testing & QA Workflow

> **Purpose**: Write, execute, and verify automated tests that lock in correct behavior and prevent future regressions. Tests are not an afterthought — they are the specification.
> **Activates when**: User asks to "write tests", "add tests", "test this feature", or "improve test coverage".
> **Avoid when**: A manual check via `/review` is sufficient — this workflow is for writing *automated* tests.

---

## Prerequisites

Before writing any tests, read these files to understand what needs to be tested:

- [ ] [`.agents/context/architecture.md`](../context/architecture.md) — understand which layer the code lives in (determines test type)
- [ ] [`.agents/context/project-overview.md`](../context/project-overview.md) — understand the business rules that must hold true

---

## Step 1: Plan the Test Strategy

**Goal**: Decide what to test and how before writing a single test.

- [ ] **Read the feature's requirements** from `project-overview.md` or the original implementation plan.
- [ ] **Identify the critical paths**: What is the most important thing this code must do correctly?
- [ ] **Identify edge cases and failure modes**: Empty inputs, invalid data, unauthorized access, network errors.
- [ ] **Choose the right test type**:
  - **Unit**: Pure functions, utilities, data transformations — isolated, no external dependencies
  - **Integration**: Service interactions, database queries, API routes with mocked external services
  - **E2E**: Full user flows through the UI — use Playwright for browser-level testing
- [ ] **Choose the right framework**: Follow the project's standard (e.g., Jest, Vitest for unit/integration; Playwright for E2E).

**Output**: A clear test plan — what will be tested, at which level, and with which framework.

---

## Step 2: Write the Tests (`/test`)

**Goal**: Write tests that document behavior, not just implementation.

- [ ] Write tests for the **happy path** first.
- [ ] Write tests for **each identified edge case and failure mode**.
- [ ] Ensure test descriptions clearly state *what behavior* is being verified, not *how* it is implemented.
  - ✅ Good: `"returns 403 when user does not own the resource"`
  - ❌ Bad: `"calls checkOwnership() and throws"`
- [ ] Ensure tests are **deterministic**: no reliance on system time, random values, or external network calls. Mock external dependencies.
- [ ] Ensure tests are **isolated**: each test should be able to run independently of others.

**Output**: Written test file(s) — not yet run.

---

## Step 3: Execute & Verify

**Goal**: Run the tests and confirm they all pass.

- [ ] Run the full test suite: `npm test`, `vitest`, `pytest`, or equivalent.
- [ ] If tests fail, **diagnose the root cause**: is it a bug in the production code, or a flaw in the test itself?
  - Bug in code → fix the code, not the test.
  - Flaw in the test → fix the test logic but preserve the intent.
- [ ] All new and existing tests must pass before declaring this step complete.

**Output**: Clean, passing test suite.

---

## Step 4: Close the Loop

- Confirm test coverage is adequate for the feature — critical paths must be covered.
- Ask the user: *"Tests are passing. Do you want me to add this to the CI pipeline so it runs on every pull request?"*

---

## ⚠️ Anti-Patterns — Never Do These

- ❌ **Never write tests that just verify implementation details.** Tests should verify behavior (inputs → outputs), not internal method calls.
- ❌ **Never use `it('should work')` or vague test names.** Test names are the first line of debugging — make them specific.
- ❌ **Never write flaky tests** that depend on sleep timers, external APIs, or insertion order. Mock or stub all external dependencies.
- ❌ **Never skip failing tests** with `.skip` or `// TODO` to get CI to pass. A skipped test is a lie about the codebase state.

---

## 📎 Context Links

- [architecture.md](../context/architecture.md)
- [project-overview.md](../context/project-overview.md)
- [code-standards.md](../context/code-standards.md)
