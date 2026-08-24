---
slash_command: /security-audit
description: "Run a systematic security audit of the codebase before go-live or after major architectural changes."
trigger_phrases:
  - "run security audit"
  - "security check"
  - "tee security audit"
  - "aja tietoturvatarkastus"
  - "before go-live"
  - "check for vulnerabilities"
when_not_to_use: "Use /auth-security instead when adding a single new protected route. This workflow is for full-project audits."
---

# Security Audit Workflow

> **Purpose**: Systematically find and report security vulnerabilities across the entire codebase. Designed to run before production go-live or after major architectural changes.
> **Activates when**: User asks "run security audit", "security check", or "before go-live".
> **Avoid when**: You are only protecting a single new route — use `/auth-security` instead.

---

## Prerequisites

Before starting, read these files to understand the current architecture:

- [ ] [`.agents/context/architecture.md`](../context/architecture.md) — understand all API routes, services, and data flows
- [ ] [`.agents/context/database-schema.md`](../context/database-schema.md) — understand data ownership and tenant structure

---

## Step 1: Static Code Analysis

**Goal**: Scan the codebase for authentication gaps, data exposure, and injection risks.

**1a — Authentication & Authorization:**
- [ ] Does every API route / Server Action verify the user is authenticated before executing business logic?
- [ ] Is role-based access control (RBAC) correctly implemented everywhere it is required?
- [ ] Check for IDOR (Insecure Direct Object Reference): do database queries confirm that the requested resource belongs to the requesting user? (e.g., `WHERE id = ? AND user_id = session.userId`)

**1b — Data Exposure:**
- [ ] Do database queries return only the fields the client needs (no password hashes, internal IDs, or hidden fields leaking to the frontend)?
- [ ] Are sensitive fields explicitly excluded in ORM queries or response serializers?

**1c — Environment Variables & Secrets:**
- [ ] Search the codebase for hardcoded secrets (API keys, passwords, tokens).
- [ ] In Next.js: confirm no secret environment variable is accidentally prefixed with `NEXT_PUBLIC_`, which would expose it to the browser.

**1d — Input Validation & Injection:**
- [ ] Is all incoming data (forms, API payloads) strictly validated with Zod (Next.js) or Pydantic (FastAPI) before reaching the database?
- [ ] Is there any risk of SQL injection or XSS from unescaped user input?

**Output**: A mental map of all findings, categorized by severity, ready for Step 3.

---

## Step 2: Infrastructure & Configuration Review

**Goal**: Verify that the deployment configuration is hardened.

- [ ] **CORS**: Is `Access-Control-Allow-Origin` restricted to known production domains? (Not `*`)
- [ ] **Security Headers**: Are HTTP Security Headers set in `next.config.ts`? (e.g., `Content-Security-Policy`, `Strict-Transport-Security`, `X-Frame-Options`)
- [ ] **Rate Limiting**: Is rate limiting applied to login routes and heavy API endpoints to prevent brute-force and DoS attacks?
- [ ] **Dependency Audit**: Run `npm audit` or `pip-audit` and note any critical vulnerabilities in dependencies.

**Output**: List of infrastructure-level findings.

---

## Step 3: Report — Findings by Severity

**Goal**: Present all findings in a clear, actionable report.

Create a `security-report.md` artifact (or a Walkthrough artifact) with findings grouped by severity:

| Severity | Meaning | Action |
|---|---|---|
| 🔴 **Critical** | Must be fixed before go-live (e.g., unauthenticated route, secret leak) | Fix immediately |
| 🟡 **Warning** | Recommended fix — security best practice missing (e.g., no rate limiting) | Fix before launch if possible |
| 🟢 **Pass** | Correctly implemented — following best practices | Document as confirmed |

---

## Step 4: Close the Loop

- Save the report to: `security-report.md` or as a Walkthrough artifact.
- Ask the user: *"I found [N] critical issues and [M] warnings. Do you want me to fix the critical ones now?"*

---

## ⚠️ Anti-Patterns — Never Do These

- ❌ **Do not report "no issues" without checking all 4 areas** in Step 1 and Step 2. Partial audits create false confidence.
- ❌ **Do not fix issues silently** without reporting them first. Show the report and let the user decide.
- ❌ **Never rely on client-side checks alone** — if a route only hides UI but doesn't enforce auth on the server, it is a vulnerability.

---

## 📎 Context Links

- [architecture.md](../context/architecture.md)
- [database-schema.md](../context/database-schema.md)
- [env-context.md](../context/env-context.md)
