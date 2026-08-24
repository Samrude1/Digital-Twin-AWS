---
slash_command: /database
description: "Safely add, modify, or remove database tables and columns using a migration-first approach."
trigger_phrases:
  - "add database table"
  - "modify schema"
  - "add column"
  - "create migration"
  - "update database"
  - "add new model"
when_not_to_use: "Use /api-development if you only need to add a new query to an existing table with no schema change."
---

# Database Change Workflow

> **Purpose**: Safely manage database schema changes through a strict Architect → Migrate → Apply → Review loop. Prevents destructive migrations and keeps `database-schema.md` in sync with reality.
> **Activates when**: User asks to add a table, modify a column, create a migration, or update the database schema.
> **Avoid when**: You only need to change query logic on an existing table — use `/api-development` instead.

---

## Prerequisites

Before designing any schema changes, read these files:

- [ ] [`.agents/context/database-schema.md`](../context/database-schema.md) — understand the current schema and avoid conflicts
- [ ] [`.agents/context/architecture.md`](../context/architecture.md) — understand how the database layer fits into the overall system

---

## Step 1: Architect (`/architect`)

**Goal**: Design the schema changes and get approval before writing migration code.

- [ ] Design the new or modified schema: define table names, column names, data types, constraints, and foreign keys.
- [ ] Identify which fields will be **queried frequently** and need indexes.
- [ ] Identify if any existing columns are being **dropped or renamed** — if so, define a rollback or migration strategy.
- [ ] **Update `.agents/context/database-schema.md`** to reflect the new intended state (write the truth before writing the code).
- [ ] ⏸ **Present the schema design to the user and wait for explicit approval before writing any migration.**

**Output**: Updated `database-schema.md` + approved schema design.

---

## Step 2: Develop — Migration

**Goal**: Write the migration script that transforms the database from old state to new state.

- [ ] Generate or write the migration script using the project's ORM (e.g., `prisma migrate dev`, `alembic revision`).
- [ ] **Never drop a column destructively** without a two-phase approach: first deprecate (keep old column), then remove in a future migration after the application is updated.
- [ ] Add indexes for fields that will be queried or filtered frequently.
- [ ] Test the migration on a local or staging database before declaring it complete.

**Output**: Migration file committed and tested.

---

## Step 3: Develop — Application Code

**Goal**: Update all application code that interacts with the changed schema.

- [ ] Update repositories, services, server actions, and API routes that use the changed tables or columns.
- [ ] Ensure TypeScript types or Python Pydantic models are updated and exported correctly.
- [ ] Check for any hard-coded column references or raw SQL queries that reference the changed schema.

**Output**: Application code consistent with the new schema.

---

## Step 4: Close the Loop (`/review`)

- Verify the migration ran successfully on a local environment.
- Confirm that `database-schema.md` accurately represents the current migration state.
- Run `/remember save` if the schema change is significant.
- Ask the user: *"Migration is live locally. Do you want me to write or update API endpoints to expose this new data?"*

---

## ⚠️ Anti-Patterns — Never Do These

- ❌ **Never drop a column in a single migration** without confirming the application no longer references it.
- ❌ **Never write application code before the migration is approved** (Step 1). Code written against an unapproved schema will need to be rewritten.
- ❌ **Never skip updating `database-schema.md`**. This file is the ground truth for future AI sessions — an outdated schema file causes incorrect code generation.

---

## 📎 Context Links

- [database-schema.md](../context/database-schema.md)
- [architecture.md](../context/architecture.md)
