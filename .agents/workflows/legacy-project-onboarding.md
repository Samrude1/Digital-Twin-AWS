---
slash_command: /onboard
description: "Map an existing legacy or unfinished project and initialize the .agents folder for efficient AI-assisted development."
trigger_phrases:
  - "onboard this project"
  - "analyze existing project"
  - "initialize agents folder"
  - "set up agents for this project"
  - "map the codebase"
when_not_to_use: "Use /new-feature if the project is already onboarded and you want to build something new."
---

# Legacy Project Onboarding Workflow

> **Purpose**: Introduce the `.agents` folder into an existing, legacy, or unfinished project. Guides the agent to map the current state and initialize all context files so future AI sessions start with accurate knowledge — not guesswork.
> **Activates when**: User asks "onboard this project", "analyze existing project", or "initialize agents folder".
> **Avoid when**: The project already has a populated `.agents/context/` directory. Use `/remember` to restore session context instead.

---

## Prerequisites

This is the bootstrapping workflow — there are no prerequisites to read first. If a `README.md` exists, it is your starting point.

---

## Step 1: Analyze the Project

**Goal**: Build an accurate map of what exists before writing anything.

- [ ] **Read the README**: If `README.md` exists, read it first to understand the overarching goals and context.
- [ ] **Scan the structure**: Recursively scan the project directory. Identify:
  - Core technologies and frameworks (look for `package.json`, `requirements.txt`, `pom.xml`, `Dockerfile`, `pyproject.toml`)
  - Frontend / backend / database separation
  - Key entry points (e.g., `src/app/`, `src/pages/`, `main.py`, `server.ts`)
- [ ] **Understand the architecture**: How do the components interact? Is there a clear separation of concerns or is it monolithic?
- [ ] **Identify the current state**: What appears to be working? What is clearly unfinished or broken?

**Output**: A clear mental model of the project — not yet written to any file.

---

## Step 2: Populate Context Files (`/imprint`)

**Goal**: Write the ground truth about this project into `.agents/context/` so future sessions start informed.

- [ ] **`architecture.md`**: Document the current architecture — how components are structured and how they interact.
- [ ] **`project-overview.md`**: Summarize the product's purpose, target users, and key features.
- [ ] **`tech-stack.md`** (if not present): List all found technologies, frameworks, and their versions.
- [ ] **`database-schema.md`**: If applicable, infer and document the existing schema (from Prisma schema, SQL files, ORM models, or migration files).
- [ ] **`code-standards.md`**: Note any clear coding conventions already in use (naming patterns, folder structure, linting config).

**Output**: All `.agents/context/` files populated with accurate, current information.

---

## Step 3: Establish Baseline (`/remember`)

**Goal**: Create a `memory.md` snapshot so the next session picks up exactly where this one ends.

- [ ] Create or update `.agents/context/memory.md` (or use `/remember save`).
- [ ] Record: what works, what is clearly unfinished, and what the user's stated next goals are.
- [ ] Note any obvious tech debt or architectural issues discovered in Step 1.

**Output**: `memory.md` with a clear "ground truth" snapshot.

---

## Step 4: Align & Plan

**Goal**: Bridge the gap between the current state and the desired development standards.

- [ ] Compare the current project structure against the `.agents/AGENTS.md` rules and best practices.
- [ ] If there are significant gaps, flag them clearly to the user.
- [ ] ⏸ **If the user requests it**, create an `implementation_plan.md` suggesting refactoring steps to align the legacy code with current standards before building new features.

**Output**: Clear understanding of the gap — and optionally an `implementation_plan.md`.

---

## Step 5: Close the Loop

- Confirm with the user which context files have been written or updated.
- Ask the user: *"The project is now onboarded. What would you like to build first? I can run `/architect` to plan it."*

---

## ⚠️ Anti-Patterns — Never Do These

- ❌ **Do not start building features** until Steps 1–3 are complete. Building on an unmapped codebase causes architectural drift.
- ❌ **Do not invent context**. If you cannot find evidence of how something works, write `unknown` or `to be confirmed` — never guess.
- ❌ **Do not skip `database-schema.md`** if the project uses a database. Missing schema context is the leading cause of broken migrations.

---

## 📎 Context Links

- [architecture.md](../context/architecture.md)
- [project-overview.md](../context/project-overview.md)
- [database-schema.md](../context/database-schema.md)
- [code-standards.md](../context/code-standards.md)
