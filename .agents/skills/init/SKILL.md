---
name: init
description: Bootstraps a new project from the template by interviewing the user and automatically populating all context files (architecture, project-overview, ui-registry, etc.).
---

A generic template is not a project. A project has a purpose, a specific architecture, and strict boundaries. 

When a developer clones this generic template to start something new, this skill transforms the empty shell into a highly opinionated, context-aware foundation. It ensures that every future AI session starts with a deep understanding of what is actually being built.

Run this skill ONLY when starting a brand new project, or when the user explicitly calls `/init` or `/bootstrap`.

---

## Step 1 — The Context Interview

Do not start writing files immediately. Do not guess what the project is about. Your first job is to extract the vision.

Check for an existing vision document (e.g., `docs/future-project-vision.md` or a prompt). If one exists, use it. If not, or if it is incomplete, interview the developer.

Ask exactly these questions, one at a time if necessary:

```
Let's bootstrap this project. Before I populate the context files, I need to know what we are building:

1. What is the core purpose of the app in one sentence?
2. Who are the primary users?
3. What are the 3-4 main features or user flows?
4. Are there any strict architectural or tech stack constraints I should know about?
```

Wait for the developer to answer. Do not proceed until you have a clear picture.

---

## Step 2 — Propose the Context Mapping

Once you understand the vision, map out exactly how you will alter the `.agents/context/` files. Do not write the files yet. Present the plan.

```
Got it. Here is how I will configure the project context:

- project-overview.md: [Brief summary of how you will describe the project's goals]
- architecture.md: [The specific boundaries and stack choices you will enforce]
- database-schema.md: [The 2-3 core tables you will draft initially]
- ui-registry.md: [The initial design tokens or theme, if any]

Does this foundation look correct?
```

Wait for explicit approval.

---

## Step 3 — Aggressive Overwrite

Once approved, execute the plan. You must aggressively overwrite the generic boilerplate in the `.agents/context/` directory.

- Remove all `[Project Name]` or `[Insert description]` placeholders.
- Write definitive, confident documentation based on the interview.
- Ensure `architecture.md` clearly states what is allowed and what is forbidden in this specific project.

---

## Step 4 — The Handoff

When the files are updated, the project is officially bootstrapped. The template is now a bespoke codebase.

Close the loop with the developer:

```
Bootstrap complete. All context files are populated.
The AI now understands the rules, goals, and boundaries of this project.

What is the first feature we are building? (I recommend running /architect when you are ready).
```

---

## ⚠️ Anti-Patterns — Never Do These

- ❌ **Never invent requirements.** If the user gives a vague one-word idea, ask clarifying questions. Do not hallucinate a massive feature set they didn't ask for.
- ❌ **Never leave generic boilerplate behind.** A context file with `[Insert purpose here]` is a failure.
- ❌ **Never skip the interview.** Bootstrapping without understanding the domain leads to architecture drift on day one.
