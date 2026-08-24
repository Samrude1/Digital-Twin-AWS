---
slash_command: /document
description: "Generate exhaustive, professional-grade documentation for a file, module, API, or system component."
trigger_phrases:
  - "document this"
  - "write documentation"
  - "generate docs"
  - "document the codebase"
  - "write a README"
  - "explain this code"
when_not_to_use: "Use inline code comments for short, local explanations. This workflow is for structured, artifact-level documentation."
---

# Comprehensive Documentation Workflow

> **Purpose**: Generate top-tier, exhaustive, and highly structured documentation. Explicitly overrides the agent's default tendency to provide brief summaries. The goal is professional-grade, deep-dive documentation that adapts its style based on the target subject.
> **Activates when**: User asks "document this", "write documentation", "generate docs", or mentions this file.
> **Avoid when**: A brief inline comment is sufficient — use this workflow only when the output warrants a standalone document.

---

## Prerequisites

Before writing a single word, read these files:

- [ ] [`.agents/context/architecture.md`](../context/architecture.md) — understand how the target fits into the bigger system
- [ ] [`.agents/context/project-overview.md`](../context/project-overview.md) — understand the product context and target audience

---

## Step 1: Context & Audience Analysis (`/architect`)

**Goal**: Understand what type of document is needed and who will read it.

- [ ] Review the target file(s), folder, or system component.
- [ ] **Identify the Document Type and adapt the style accordingly:**
  - **Root `README.md` or High-Level Docs**: Focus on the big picture — system architecture, installation, usage instructions, and the overall value proposition.
  - **Complex Scripts / Business Logic**: Act as a senior engineer explaining the code to another developer. Break down the logic step-by-step, explain *why* decisions were made, and clarify complex algorithms or data transformations.
  - **API / Interfaces**: Focus on strict inputs, outputs, data types, authentication requirements, and edge cases.
- [ ] Define the target audience (e.g., new developer onboarding, external API consumer, internal team).
- [ ] Define the required depth (overview vs. line-by-line explanation).

**Output**: A clear understanding of document type, audience, and depth — not yet any written documentation.

---

## Step 2: Structure & Plan

**Goal**: Agree on the document structure before generating content.

- [ ] Create a detailed outline / table of contents for the documentation.
- [ ] Decide where visual aids are needed (Mermaid diagrams, flowcharts, sequence diagrams).
- [ ] ⏸ **Present the outline to the user and wait for approval before writing the full document.**

**Output**: Approved outline artifact.

---

## Step 3: Exhaustive Generation

**Goal**: Write the full documentation following these non-negotiable rules.

- [ ] **Rule 1 — No Skimming**: Do not write a surface-level summary. Go deep into mechanics, dependencies, and data flow.
- [ ] **Rule 2 — Explain the "Why"**: Document not just *what* the code does, but the architectural reasoning and business logic behind it.
- [ ] **Rule 3 — Use Examples**: Provide clear, real-world code snippets or input/output examples to illustrate functions and endpoints.
- [ ] **Rule 4 — Visuals**: Embed Mermaid.js diagrams (`sequenceDiagram`, `graph TD`, or `classDiagram`) to visualize relationships and processes.
- [ ] **Rule 5 — Edge Cases**: Handle error states, failure modes, and performance considerations — not just the happy path.

**Output**: Complete documentation draft as an artifact.

---

## Step 4: Review & Refine

**Goal**: Verify accuracy and formatting before finalizing.

- [ ] Cross-reference the generated documentation with the actual source code — are all parameters correct?
- [ ] Are all explanations accurate based on the actual code logic (not assumed behavior)?
- [ ] Is the formatting clean? (proper Markdown syntax, logical header hierarchy, well-structured tables)

**Output**: Reviewed, corrected documentation artifact.

---

## Step 5: Close the Loop

- Save the documentation to the appropriate location:
  - Inline comments → directly in the source file
  - Module/component docs → a `.md` file in the `/docs` folder
  - Root documentation → `README.md`
- If this documents core architecture, cross-reference it in [`.agents/context/architecture.md`](../context/architecture.md).
- Ask the user: *"Documentation is complete. Do you want me to update the README to link to this new document?"*

---

## ⚠️ Anti-Patterns — Never Do These

- ❌ **Do not generate the full document before showing the outline** (Step 2). Large documents written in the wrong direction waste time.
- ❌ **Do not skim**. If the output reads like a generic summary, it has failed. Every section should teach something non-obvious.
- ❌ **Do not document only the happy path**. Missing error handling and edge cases is the most common documentation failure.

---

## 📎 Context Links

- [architecture.md](../context/architecture.md)
- [project-overview.md](../context/project-overview.md)
