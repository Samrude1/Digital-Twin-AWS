---
slash_command: /new-feature
description: "Plan, build, review, and document a new feature from scratch following the Architect → Develop → Review → Imprint loop."
trigger_phrases:
  - "build new feature"
  - "add feature"
  - "implement this"
  - "I want to add"
  - "let's build"
  - "create this functionality"
when_not_to_use: "Use /optimize to improve existing code without adding new behavior. Use the specific sub-workflows (/database, /api, /ui-component) if you only need one layer changed."
---

# New Feature Workflow

> **Purpose**: Full end-to-end workflow for designing and building any new feature — from aligning on the plan to updating context files after completion. The master workflow that orchestrates the specialized sub-workflows.
> **Activates when**: User asks to "build a new feature", "add X", "implement Y", or says "let's build".
> **Avoid when**: Only one layer needs to change (e.g., only the database schema, only a UI component). Use the targeted sub-workflow instead.

---

## Prerequisites

Before planning the feature, read ALL of these files — this is the full system context:

- [ ] [`.agents/context/architecture.md`](../context/architecture.md) — verify the feature fits the system design and identify which layers are affected
- [ ] [`.agents/context/project-overview.md`](../context/project-overview.md) — confirm the feature aligns with the product's purpose
- [ ] [`.agents/context/database-schema.md`](../context/database-schema.md) — identify if a schema change is needed (triggers `/database` sub-workflow)
- [ ] [`.agents/context/ui-registry.md`](../context/ui-registry.md) — identify if new UI components are needed (triggers `/ui-component` sub-workflow)

---

## Step 1: Architect (`/architect`)

**Goal**: Think through the entire feature before writing a single line of code.

- [ ] Read the feature description the user provided.
- [ ] **Identify which layers are affected**: Database? API? UI? Background jobs?
- [ ] **For each affected layer, confirm the approach**:
  - Database change → plan via `/database` sub-workflow
  - New API endpoint → plan via `/api` sub-workflow
  - New UI component → plan via `/ui-component` sub-workflow
  - Background job → plan via `/background-task` sub-workflow
- [ ] Surface key decisions that would change the implementation (data model, auth requirements, state management).
- [ ] 💡 *Tip: If the feature requirement is complex or open-ended, suggest the user trigger `/grill-me` for a step-by-step interactive discovery interview.*
- [ ] Create the `implementation_plan.md` artifact with:
  - What will be built
  - Which files will change
  - The order of implementation (always: Database → API → UI)
- [ ] ⏸ **Present the implementation plan to the user and wait for explicit approval.**

**Output**: Approved `implementation_plan.md` artifact.

---

## Step 2: Develop

**Goal**: Build the feature strictly following the approved plan — no scope creep.

- [ ] 💡 *Tip: For non-trivial or complex features, recommend the user activate `/goal` mode so the agent executes autonomously with extreme thoroughness until fully complete.*
- [ ] Follow the implementation order: **Database → API → UI** (each layer depends on the one below it).
- [ ] For each sub-task, use the appropriate specialized workflow if needed.
- [ ] If you discover a necessary change not in the plan: **stop, update the plan, and re-confirm** before proceeding.

**Output**: Working feature implementation.

---

## Step 3: Review (`/review`)

**Goal**: Verify the feature is fully built, correct, and ready for production.

- [ ] Does the implementation match every point in the approved `implementation_plan.md`?
- [ ] Are all edge cases handled (invalid input, unauthorized access, empty states)?
- [ ] Does it follow the coding standards in [`.agents/context/code-standards.md`](../context/code-standards.md)?
- [ ] Is the UI consistent with [`.agents/context/ui-registry.md`](../context/ui-registry.md)?
- Output the review to a `walkthrough.md` artifact.

**Output**: `walkthrough.md` artifact with review findings.

---

## Step 4: Close the Loop (`/imprint` + `/remember`)

- [ ] **If the feature adds new UI patterns**: Update [`.agents/context/ui-registry.md`](../context/ui-registry.md).
- [ ] **If the feature changes the architecture**: Update [`.agents/context/architecture.md`](../context/architecture.md).
- [ ] **If the feature changes the database**: Confirm [`.agents/context/database-schema.md`](../context/database-schema.md) is up-to-date.
- [ ] Save a `feature-specs/[N]-[feature-name].md` document for permanent record-keeping.
- [ ] Run `/remember save` to preserve session knowledge.
- [ ] 💡 *Tip: If the user shared new preferences, conventions, or feedback during the process, suggest running `/learn` to store it for future tasks.*
- Ask the user: *"Feature complete. Do you want me to write tests to lock in this behavior, or move to the next feature?"*

---

## ⚠️ Anti-Patterns — Never Do These

- ❌ **Never skip the architect step** because the feature "seems simple". Simple features cause complex bugs when they touch multiple layers without coordination.
- ❌ **Never deviate from the approved plan** without re-confirming. Scope creep during implementation is the leading cause of half-finished features.
- ❌ **Never build UI before the API is working.** The implementation order is always Database → API → UI.
- ❌ **Never skip updating context files** after completion. The next session starts from stale context if `architecture.md` is not updated.

---

## 📎 Context Links

- [architecture.md](../context/architecture.md)
- [project-overview.md](../context/project-overview.md)
- [database-schema.md](../context/database-schema.md)
- [ui-registry.md](../context/ui-registry.md)
- [code-standards.md](../context/code-standards.md)
