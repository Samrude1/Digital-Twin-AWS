---
slash_command: /ci-cd
description: "Modify the CI/CD pipeline, GitHub Actions workflows, or AWS deployment configuration safely."
trigger_phrases:
  - "update pipeline"
  - "modify deployment"
  - "add GitHub Action"
  - "update CI"
  - "fix the build"
  - "add deployment step"
  - "update AWS infrastructure"
when_not_to_use: "Use /background-task if you are adding a new AWS Lambda function. This workflow is for changes to the build, test, and deployment pipeline itself."
---

# CI/CD & Deployment Workflow

> **Purpose**: Safely modify the CI/CD pipeline, GitHub Actions workflows, or AWS deployment scripts. Changes here affect the entire team's ability to deploy — treat them with the same care as production database migrations.
> **Activates when**: User asks to "update pipeline", "add GitHub Action", "fix the build", or "update AWS infrastructure".
> **Avoid when**: You are adding a new Lambda function for a background job — use `/background-task` instead.

---

## Prerequisites

Before modifying any pipeline configuration, read these files:

- [ ] [`.agents/context/architecture.md`](../context/architecture.md) — understand the current deployment architecture (what deploys where)
- [ ] [`.agents/context/env-context.md`](../context/env-context.md) — understand which secrets exist in GitHub Secrets and how they are used

---

## Step 1: Architect the Change (`/architect`)

**Goal**: Understand the full scope of the pipeline change before editing any YAML.

- [ ] Identify **which pipeline stage** needs changing: Lint → Test → Build → Deploy (or a subset)
- [ ] Identify **the trigger**: On push to `main`? On pull request? On a schedule?
- [ ] If AWS permissions are needed, define the **IAM policies** required — apply the Principle of Least Privilege (only the exact actions needed, on the exact resources needed).
- [ ] Plan how **secrets will be injected**: only from GitHub Secrets, never hardcoded. Prefer OIDC over long-lived AWS access keys.
- [ ] ⏸ **Present the plan to the user and wait for approval before editing pipeline files.**

**Output**: Approved description of what changes and why, with a clear security model.

---

## Step 2: Implement

**Goal**: Apply the approved changes to pipeline files.

- [ ] Modify `.github/workflows/` YAML files or AWS CDK / Terraform / CloudFormation scripts.
- [ ] **No hardcoded credentials.** Every secret must come from `secrets.SECRET_NAME` in GitHub Secrets or from OIDC-assumed IAM roles.
- [ ] Use **OIDC integration** for AWS authentication where possible — never store long-lived `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` as static secrets.
- [ ] Pin action versions to a specific SHA or semver tag (e.g., `actions/checkout@v4`) — never use `@main` or `@latest` in production pipelines.
- [ ] Add clear step names so failed runs are easy to diagnose in the GitHub Actions UI.

**Output**: Updated pipeline YAML / infrastructure code.

---

## Step 3: Review (`/review`)

**Goal**: Validate the pipeline is correct and secure before merging.

- [ ] Validate YAML syntax (use a linter or GitHub's built-in YAML validation).
- [ ] Confirm no secrets are printed or logged in any step (check for `echo $SECRET` or similar).
- [ ] Confirm IAM policies follow least privilege — no `*` actions or `*` resources without explicit justification.
- [ ] Output a Walkthrough artifact summarizing what changed and why.

**Output**: Walkthrough artifact + validated pipeline configuration.

---

## Step 4: Close the Loop (`/remember`)

- Run `/remember save` to record the pipeline change.
- Ask the user: *"Pipeline changes look correct. Do you want to trigger a test run to confirm it works end-to-end, or merge as-is?"*

---

## ⚠️ Anti-Patterns — Never Do These

- ❌ **Never hardcode credentials in pipeline files.** Even if the repo is private, hardcoded secrets rotate into git history permanently.
- ❌ **Never use `@latest` or `@main` for GitHub Actions.** This creates unpredictable breakage when upstream actions change.
- ❌ **Never grant `AdministratorAccess` IAM policies** to the pipeline role. Define the minimum set of actions and resources needed.
- ❌ **Never skip the syntax validation step.** A YAML typo in a pipeline file can silently break all deployments.

---

## 📎 Context Links

- [architecture.md](../context/architecture.md)
- [env-context.md](../context/env-context.md)
