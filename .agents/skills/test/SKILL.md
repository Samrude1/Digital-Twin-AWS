---
name: test
description: Writes, executes, and fixes automated tests for the project's codebase to ensure reliability and prevent regressions.
---

Testing is not about achieving 100% line coverage. Testing is about confidence.

When AI writes tests, it often writes "shallow" tests — tests that mock everything, assert that a function was called, and verify nothing about the actual behavior. Those tests pass even when the code is broken.

This skill forces you to write tests that actually matter. Tests that verify behavior, handle edge cases, and prove the code is correct.

---

## Step 1 — Interrogate the Contract

Before writing any tests, understand what the code is *supposed* to do. Do not just look at what the code *currently does*.

Read the target file and ask yourself:
1. What is the public API of this unit? (Props, arguments, endpoints)
2. What are the expected success states?
3. What are the failure states? (Invalid input, missing data, network errors)
4. What side effects does it have? (DB writes, state changes)

If the expected behavior is unclear, stop and ask the developer:

```
Before I write tests for [Component/Function], what is the expected behavior when [Edge Case] happens?
```

---

## Step 2 — Write Behavioral Tests

Write the tests. Follow these strict rules:

- **Test behavior, not implementation.** Do not assert that an internal state variable changed. Assert that the UI updated or the function returned the right value.
- **Do not mock the system under test.** If you are testing a component, do not mock its children unless absolutely necessary. Render it.
- **Cover the "Unhappy Path".** AI always tests the happy path. You must write tests for empty states, null values, and thrown errors.
- **Use clear descriptions.** Test names must read like a specification: `it('should return 400 when the email format is invalid')`.

---

## Step 3 — Execute and Fix (The Loop)

Never assume your tests pass. Run them locally using the appropriate command (e.g., `npm run test`).

If tests fail, diagnose the failure before changing code:
1. Did the test fail because the *code* is broken? (Fix the code)
2. Did the test fail because the *test* is wrong? (e.g., bad mock, wrong assertion) (Fix the test)

**The Death Spiral Rule:**
If you try to fix a failing test 3 times and it still fails, **STOP**. Do not blindly rewrite the test again. 

Present the failure to the developer:
```
I am stuck on this test failure for [Test Name].

Error:
[Brief error snippet]

I have tried [what you tried]. Should I rethink the approach, or is there a missing mock/setup I am not seeing?
```

---

## Step 4 — Report Confidence

When the tests are green, report back. Do not dump the entire test file into the chat. Summarize what you proved.

```
Tests for [Target] are written and passing.

Coverage added:
✅ Happy path: [Brief description]
✅ Edge cases: [Brief description]
✅ Error states: [Brief description]

Total passing: [X] tests.
```

---

## ⚠️ Anti-Patterns — Never Do These

- ❌ **Never test implementation details.** If refactoring the code (without changing behavior) breaks the test, it is a bad test.
- ❌ **Never mock indiscriminately.** Mocking `fetch` is fine. Mocking every internal utility function makes the test useless.
- ❌ **Never assume a test works without running it.** AI code always contains minor syntax errors. Run it to prove it.
- ❌ **Never enter a fix-loop.** 3 strikes and you stop to ask the developer.
