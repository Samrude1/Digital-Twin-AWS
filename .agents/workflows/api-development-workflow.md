---
slash_command: /api
description: "Design and implement a new API endpoint with validation, authentication, and consistent error handling."
trigger_phrases:
  - "add API endpoint"
  - "create route"
  - "build API"
  - "new endpoint"
  - "add route handler"
  - "new server action"
when_not_to_use: "Use /database if the endpoint requires schema changes first. Use /auth-security if you are adding auth to an existing endpoint."
---

# API Development Workflow

> **Purpose**: Design and implement new API endpoints (Next.js Route Handlers or FastAPI endpoints) with a consistent contract: validated input, authenticated access, structured errors, and typed output.
> **Activates when**: User asks to "add API endpoint", "create route", "build API", or "add server action".
> **Avoid when**: The endpoint requires a new database table — run `/database` first.

---

## Prerequisites

Before writing any code, read these files:

- [ ] [`.agents/context/architecture.md`](../context/architecture.md) — verify the endpoint belongs in the right layer (Next.js route vs FastAPI service)
- [ ] [`.agents/context/database-schema.md`](../context/database-schema.md) — confirm the required data already exists in the schema

---

## Step 1: Architect the Contract (`/architect`)

**Goal**: Define the full API contract before writing any implementation code.

- [ ] Define the **Route path** (e.g., `POST /api/users/[id]/invite`)
- [ ] Define the **Request payload**: fields, types, required vs optional
- [ ] Define the **Response payload**: success shape and all error shapes
- [ ] Determine: **Public or Protected**? If protected, which roles can access it?
- [ ] Identify edge cases: what happens with invalid input, missing records, unauthorized access?
- [ ] ⏸ **Present the API contract to the user and wait for approval before implementing.**

**Output**: Approved API contract (document in the artifact or in a comment at the top of the route file).

---

## Step 2: Implement

**Goal**: Build the endpoint following the approved contract and non-negotiable standards.

- [ ] **Validation**: Strictly validate all incoming data using Zod (Next.js) or Pydantic (FastAPI) before executing any business logic. Reject malformed requests with `400`.
- [ ] **Authentication**: For protected routes, verify the session token or JWT *before* running any query. Use `getServerSession` / `auth()` in Next.js Server Components and Route Handlers.
- [ ] **Authorization**: After confirming identity, confirm the user has permission to perform this action (RBAC, tenant isolation).
- [ ] **Business Logic**: Execute the core operation only after auth and validation pass.
- [ ] **Error Handling**: Use consistent error response format: `{ error: "Human-readable message", code: 400 }`. Use correct HTTP status codes (`400`, `401`, `403`, `404`, `500`).

**Output**: Working endpoint matching the approved contract.

---

## Step 3: Review (`/review`)

**Goal**: Verify the endpoint is correct, safe, and handles all edge cases.

- [ ] Does it match the approved contract from Step 1?
- [ ] Does it handle the identified edge cases (invalid input, missing records, unauthorized)?
- [ ] Is the validation schema complete? (Are required fields actually enforced?)
- [ ] Is there any data leaking in the response that should not be there?

**Output**: Walkthrough artifact confirming the endpoint is production-ready.

---

## Step 4: Close the Loop (`/remember`)

- Ensure the endpoint is strongly typed so the frontend can infer it (e.g., via tRPC, exported types, or OpenAPI).
- If the project maintains an API registry, document the new endpoint there.
- Ask the user: *"Endpoint is live. Do you want me to write the frontend hook to consume it, or add tests first?"*

---

## ⚠️ Anti-Patterns — Never Do These

- ❌ **Never execute business logic before validation and auth checks pass.** Auth and validation always come first.
- ❌ **Never return raw database errors or stack traces to the client.** Log them server-side and return a sanitized message.
- ❌ **Never hardcode user IDs or skip tenant isolation.** Always scope queries to the authenticated user's data.
- ❌ **Never use `200 OK` for all responses.** Use semantically correct HTTP status codes.

---

## 📎 Context Links

- [architecture.md](../context/architecture.md)
- [database-schema.md](../context/database-schema.md)
- [env-context.md](../context/env-context.md)
