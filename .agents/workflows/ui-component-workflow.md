---
slash_command: /ui-component
description: "Design and build a new UI component that is consistent with the existing design system and registered in ui-registry.md."
trigger_phrases:
  - "build component"
  - "create UI component"
  - "add component"
  - "build a new button"
  - "add a modal"
  - "create a form"
  - "add a card"
when_not_to_use: "Use /new-feature if the component is part of a larger feature that also requires API or database changes."
---

# UI Component Workflow

> **Purpose**: Design and build a UI component that fits seamlessly into the existing design system — consistent tokens, consistent patterns, consistent behavior. Every component built here extends the system; it does not start from scratch.
> **Activates when**: User asks to "build a component", "create a modal", "add a card", or any UI-specific build request.
> **Avoid when**: The component is part of a larger feature requiring API or DB changes — use `/new-feature` to coordinate all layers.

---

## Prerequisites

Before designing anything, read these files — they define what already exists:

- [ ] [`.agents/context/ui-registry.md`](../context/ui-registry.md) — **critical**: check if a similar component already exists before building a new one
- [ ] [`.agents/context/ui-context.md`](../context/ui-context.md) — understand the design tokens, color palette, spacing system, and typography in use
- [ ] [`.agents/context/architecture.md`](../context/architecture.md) — understand the component folder structure and co-location conventions

---

## Step 1: Architect the Component (`/architect`)

**Goal**: Define the component's API and visual contract before writing any markup.

- [ ] **Check `ui-registry.md` first**: Does a similar component already exist that can be extended or reused?
- [ ] Define the **component's props API**: What does it accept? What are the required vs optional props? What are the variants (e.g., `size`, `variant`, `disabled`)?
- [ ] Define the **visual states**: default, hover, focus, active, disabled, loading, error.
- [ ] Identify which **design tokens** from `ui-context.md` will be used (colors, spacing, border-radius, shadows, typography).
- [ ] Confirm the **component file location** following the project's structure conventions.
- [ ] ⏸ **If the component is complex or introduces new patterns, confirm the API with the user before building.**

**Output**: Clear component specification — props, variants, visual states, and file location.

---

## Step 2: Build

**Goal**: Implement the component using only existing design tokens and established patterns.

- [ ] Build the component using the project's CSS approach (Tailwind CSS / CSS Modules / Vanilla CSS per `ui-context.md`).
- [ ] **Use design tokens** from `ui-context.md` — no ad-hoc colors or magic numbers. Every value should reference an existing token.
- [ ] Implement all visual states defined in Step 1 (hover, focus, disabled, etc.).
- [ ] Add appropriate ARIA attributes for accessibility (`aria-label`, `role`, `aria-disabled`).
- [ ] Ensure the component is **responsive** — verify behavior at mobile, tablet, and desktop breakpoints.
- [ ] Export the component and its types cleanly from its module.

**Output**: Working, accessible, design-token-compliant component.

---

## Step 3: Review (`/review`)

**Goal**: Verify the component visually and technically before registering it.

- [ ] Does it match the visual specification from Step 1?
- [ ] Are all variants and states implemented and visually correct?
- [ ] Does it use only tokens from `ui-context.md`? (No hardcoded hex values or pixel values outside the system)
- [ ] Is it accessible? (Keyboard navigation, focus ring, ARIA attributes)
- [ ] Is it consistent with existing components in `ui-registry.md`?

**Output**: Confirmed that the component is ready to be added to the design system.

---

## Step 4: Close the Loop (`/imprint`)

- [ ] **Update [`.agents/context/ui-registry.md`](../context/ui-registry.md)** with the new component:
  - Component name and file path
  - Props API summary
  - Available variants and states
  - Usage example
- Ask the user: *"Component is built and registered. Do you want me to integrate it into the page/feature now?"*

---

## ⚠️ Anti-Patterns — Never Do These

- ❌ **Never build a new component without checking `ui-registry.md` first.** Duplicate components are the #1 cause of visual inconsistency.
- ❌ **Never hardcode colors, font sizes, or spacing values.** All visual values must come from the design tokens in `ui-context.md`.
- ❌ **Never forget the `disabled` and `loading` states.** A component without these states will look broken when used in real forms and async flows.
- ❌ **Never skip the `/imprint` step.** A component that is not registered in `ui-registry.md` will be rebuilt by the next session — guaranteed.

---

## 📎 Context Links

- [ui-registry.md](../context/ui-registry.md)
- [ui-context.md](../context/ui-context.md)
- [architecture.md](../context/architecture.md)
