---
slash_command: /ai-agent
description: "Design and implement a new AI agent in the project's backend (e.g. Node.js or Python)."
trigger_phrases:
  - "create AI agent"
  - "add AI capability"
  - "build agent"
  - "add LangGraph agent"
  - "create CrewAI agent"
  - "add an AI tool"
when_not_to_use: "Use /api-development if you only need a simple endpoint that calls an LLM without agentic behavior (loops, tool use, or multi-step reasoning)."
---

# AI Agent Development Workflow

> **Purpose**: Design and implement a new AI agent in the project's current backend stack (e.g., Node.js/Express, FastAPI) — from defining its goal and tools to ensuring the frontend can consume its structured output. Adapts flexibly to whatever language (JS/TS, Python) the project is already using.
> **Activates when**: User asks to "create AI agent", "add agent", or "build agent".
> **Avoid when**: You only need a simple LLM call with no tool use or multi-step logic — use `/api-development` for a plain endpoint instead.

---

## Prerequisites

Before designing the agent, read these files:

- [ ] [`.agents/context/architecture.md`](../context/architecture.md) — understand where AI services live and how the frontend triggers them
- [ ] [`.agents/context/project-overview.md`](../context/project-overview.md) — understand the business problem the agent must solve

---

## Step 1: Architect the Agent (`/architect`)

**Goal**: Define the full agent specification before writing any code.

- [ ] **Define the Goal**: What is the single, clear objective this agent must achieve? (One sentence)
- [ ] **Define the System Prompt / Persona**: What instructions, constraints, and tone should the LLM operate under?
- [ ] **Define the Tools**: What tools does the agent need? For each tool:
  - Name and purpose
  - Input schema (strict types)
  - Output schema (strict types)
  - When the agent should use this tool vs. another
- [ ] **Define the Output**: What does the agent return to the caller? Is it free-form text, or structured JSON that the frontend must parse?
- [ ] **Define the Trigger**: How does the frontend call this agent? (REST endpoint path, WebSocket, background job)
- [ ] ⏸ **Present the agent specification to the user and wait for approval.**

**Output**: Approved agent specification (saved as artifact or implementation plan).

---

## Step 2: Implement

**Goal**: Build the agent matching the approved specification.

- [ ] Implement the agent in the backend (e.g., `server/agent.ts` for Node, or `app/agents/[agent_name].py` for Python).
- [ ] Write **clear and explicit tool schemas** — vague tool descriptions cause the LLM to call the wrong tool.
- [ ] If the agent output must be parsed by the frontend, **force structured output** (JSON mode, Zod/Pydantic schemas, or native structured outputs).
- [ ] Implement the **API endpoint** that triggers the agent, applying auth and input validation (same standards as `/api-development`).
- [ ] Test the agent locally with real prompts — iterate on the system prompt and tool descriptions until behavior is correct.

**Output**: Working agent endpoint, tested locally.

---

## Step 3: Review & Close the Loop (`/review`)

- [ ] Does the agent reliably achieve its defined goal across varied inputs?
- [ ] Is the output schema stable? (Does the frontend receive the expected structure?)
- [ ] Are tool schemas clear enough that the LLM always calls the right tool?
- [ ] Is the API endpoint properly authenticated and validated?

Update [`.agents/context/architecture.md`](../context/architecture.md) to document the new agent capability.
Run `/remember save` to preserve the session context.
Ask the user: *"The agent is working. Do you want me to build the frontend integration now, or write tests for the agent behavior first?"*

---

## ⚠️ Anti-Patterns — Never Do These

- ❌ **Never write vague tool descriptions.** The LLM reads tool schemas to decide which tool to call — vague schemas cause unpredictable behavior.
- ❌ **Never return unstructured text when the frontend needs to parse the output.** Force structured output from the start.
- ❌ **Never skip local testing.** Agent behavior must be verified with real prompts before frontend integration begins.
- ❌ **Never expose the agent endpoint without authentication.** AI agents are expensive to run — unauthenticated endpoints will be abused.
- ❌ **Never force a specific backend language.** Always adapt to the project's existing stack (JS/TS, Python, etc.) seamlessly.

---

## 📎 Context Links

- [architecture.md](../context/architecture.md)
- [project-overview.md](../context/project-overview.md)
- [env-context.md](../context/env-context.md)
