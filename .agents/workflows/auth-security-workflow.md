---
slash_command: /auth-security
description: "Add authentication or authorization to a new or existing resource, enforcing server-side protection first."
trigger_phrases:
  - "add authentication"
  - "protect this route"
  - "add authorization"
  - "add role-based access"
  - "restrict access to"
  - "add middleware protection"
when_not_to_use: "Use /security-audit for a full-project security review. This workflow is for adding protection to a specific, targeted resource."
---

# Authentication & Authorization Workflow

> **Purpose**: Safely add or modify authentication and authorization for a specific resource — API route, server action, page, or component. Enforces the principle that server-side protection is non-negotiable and always comes before client-side.
> **Activates when**: User asks to "protect a route", "add authentication", "restrict access", or "add role-based access".
> **Avoid when**: You need a full security review of the entire project — use `/security-audit` instead.

---

## Prerequisites

Before making any changes, read these files:

- [ ] [`.agents/context/architecture.md`](../context/architecture.md) — understand the auth architecture (Auth.js, JWT, middleware layer)
- [ ] [`.agents/context/database-schema.md`](../context/database-schema.md) — understand the user/role/tenant model in the database

---

## Step 1: Define the Protection Requirements (`/architect`)

**Goal**: Clarify exactly what is being protected and how before writing any code.

- [ ] Identify **which roles or permissions** are required to access this resource. (e.g., `ADMIN`, `USER`, `OWNER`)
- [ ] Identify the **protection layer**:
  - **Server-Side (mandatory)**: Middleware, API Route Handler, Server Action, or Server Component `auth()` check
  - **Client-Side (optional, supplementary only)**: UI hiding (e.g., hiding a button for unauthorized users) — this is never a substitute for server protection
- [ ] Identify the **data ownership rule**: Must the user own the specific record they are accessing? (Tenant isolation / IDOR prevention)
- [ ] ⏸ **Confirm the requirements with the user before implementing.**

**Output**: Clear definition of roles required, protection layer, and ownership rule.

---

## Step 2: Implement Server-Side Protection

**Goal**: Enforce access control at the server boundary — this is the only true security guarantee.

- [ ] **Always enforce server-side protection first.** Use `getServerSession` or `auth()` in Next.js Server Components and API Routes before executing any business logic.
- [ ] Verify the user's **role/permission** matches what is required for this resource.
- [ ] **Tenant isolation**: After confirming identity, scope all database queries to the authenticated user's data. Example: `WHERE id = ? AND user_id = session.user.id`
- [ ] Never expose sensitive data (passwords, tokens, internal IDs) in the response payload.
- [ ] Return semantically correct HTTP status codes:
  - `401 Unauthorized` — user is not authenticated
  - `403 Forbidden` — user is authenticated but lacks permission

**Output**: Server-side protection implemented and manually testable.

---

## Step 3: Implement Client-Side Protection (if needed)

**Goal**: Hide UI elements from unauthorized users to improve UX — never as a security measure.

- [ ] Hide buttons, navigation items, or pages from users who cannot access them. This is UX, not security.
- [ ] Confirm that removing client-side checks does not expose any data — the server layer must already block unauthorized access independently.

**Output**: UI reflects the user's access level.

---

## Step 4: Close the Loop (`/review`)

- [ ] Manually test: can an authenticated user without the required role access the resource directly via URL or API call? It should return `403`.
- [ ] Check for **IDOR**: can a user access another user's resource by changing an ID in the URL or request body? The query must return `404` or `403`, not the other user's data.
- [ ] Update [`.agents/context/architecture.md`](../context/architecture.md) if this adds a new auth pattern not previously documented.
- Ask the user: *"Protection is in place. Do you want me to run a broader `/security-audit` to check other routes for similar gaps?"*

---

## ⚠️ Anti-Patterns — Never Do These

- ❌ **Never rely solely on client-side checks for security.** `display: none` and `router.push('/login')` can be bypassed by anyone with DevTools.
- ❌ **Never trust user-provided IDs without verifying ownership.** Always scope queries to the authenticated user.
- ❌ **Never catch the auth check in a try/catch that silently swallows the error.** A failed auth check must always result in a `401` or `403` response.

---

## 📎 Context Links

- [architecture.md](../context/architecture.md)
- [database-schema.md](../context/database-schema.md)
- [env-context.md](../context/env-context.md)
