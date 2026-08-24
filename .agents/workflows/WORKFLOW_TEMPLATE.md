---
# The slash command a user can type to explicitly invoke this workflow.
slash_command: /workflow-name

# A one-line description shown in the workflow list.
description: "What this workflow does, in one sentence."

# Natural-language phrases that should trigger the agent to consult this workflow.
trigger_phrases:
  - "user phrase that means this workflow"
  - "another natural trigger"
  - "yet another way user might ask"

# When NOT to use this workflow — point to the alternative.
when_not_to_use: "Use /other-workflow instead when [edge case]."
---

# [Workflow Name]

> **Purpose**: [What this workflow achieves and why it exists.]
> **Activates when**: User asks "[phrase 1]", "[phrase 2]", or explicitly mentions this file.
> **Avoid when**: [Describe the edge case and which workflow to use instead.]

---

## Prerequisites

Before starting any step, read the following context files to avoid conflicts:

- [ ] [`.agents/context/architecture.md`](../context/architecture.md) — verify the change fits the system design
- [ ] [`.agents/context/[relevant].md`](../context/) — [what to check in this file]

---

## Step 1: [Phase Name] (`/skill-name`)

**Goal**: [One-sentence description of what this step achieves.]

- [ ] [Concrete, specific task — not vague, e.g. "Read `architecture.md` and confirm no conflicts"]
- [ ] [Another task with a measurable outcome]
- [ ] [Third task]
- [ ] ⏸ **Stop. Present findings to the user and wait for explicit approval** before moving to Step 2.

**Output**: [What artifact or file this step produces, e.g., `implementation_plan.md` artifact]

---

## Step 2: [Phase Name]

**Goal**: [One-sentence description.]

- [ ] [Concrete task]
- [ ] [Concrete task]

**Output**: [What this step produces]

---

## Step N: Close the Loop

- Update context: `[.agents/context/file.md]` to reflect the new state.
- Update memory: run `/remember save` if session knowledge changed.
- Ask the user: *"[Suggest the logical next action, e.g., 'Do you want me to write tests for this now?']"*

---

## ⚠️ Anti-Patterns — Never Do These

- ❌ **Do not skip Step 1.** Jumping straight to writing code without reading context files causes architecture drift.
- ❌ **Do not proceed past `⏸` without user approval.** The checkpoint exists to catch misunderstandings early.
- ❌ [Domain-specific anti-pattern]

---

## 📎 Context Links

- [architecture.md](../context/architecture.md)
- [project-overview.md](../context/project-overview.md)
- [database-schema.md](../context/database-schema.md)
- [ui-registry.md](../context/ui-registry.md)

---

<!--
  ╔══════════════════════════════════════════════════════════════╗
  ║              GOLD-STANDARD CHECKLIST (meta)                 ║
  ║  Every workflow MUST have all 6 of these structural blocks: ║
  ║  1. YAML frontmatter (slash_command, trigger_phrases)       ║
  ║  2. Header with Purpose / Triggers / Avoid-when            ║
  ║  3. Prerequisites (context files to read first)             ║
  ║  4. Steps with checklists + Output per step                 ║
  ║  5. Close the Loop (update context + ask user next step)    ║
  ║  6. Anti-Patterns + Context Links                           ║
  ╚══════════════════════════════════════════════════════════════╝
-->
