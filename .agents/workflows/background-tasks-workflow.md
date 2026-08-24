---
slash_command: /background-task
description: "Design and implement an asynchronous background job using AWS SQS and Lambda, avoiding third-party SaaS schedulers."
trigger_phrases:
  - "add background job"
  - "create queue"
  - "add async task"
  - "process this in the background"
  - "add SQS queue"
  - "add Lambda function"
  - "async processing"
when_not_to_use: "Use /api-development for synchronous operations. This workflow is only for work that must happen outside the request-response cycle."
---

# Background Tasks Workflow (AWS SQS + Lambda)

> **Purpose**: Design and implement asynchronous background jobs using AWS SQS queues and Lambda workers. All background processing is handled in-house — no third-party SaaS schedulers (e.g., Trigger.dev).
> **Activates when**: User asks to "add background job", "process this in the background", "add SQS queue", or "create async task".
> **Avoid when**: The operation can complete within a normal HTTP request lifecycle — use `/api-development` instead.

---

## Prerequisites

Before designing the job, read these files:

- [ ] [`.agents/context/architecture.md`](../context/architecture.md) — understand the existing queue names, Lambda functions, and SQS conventions
- [ ] [`.agents/context/env-context.md`](../context/env-context.md) — understand the AWS configuration and required environment variables

---

## Step 1: Architect the Job (`/architect`)

**Goal**: Define the full event-driven architecture before writing any code.

- [ ] **Define the event payload schema**: What data does the producer send? Define field names, types, and required vs optional.
- [ ] **Define the Queue Name**: Follow the project's naming convention (e.g., `my-app-[job-name]-queue`).
- [ ] **Define the Lambda Function Name**: (e.g., `my-app-[job-name]-worker`)
- [ ] **Plan the Dead Letter Queue (DLQ)**: What happens if the Lambda fails? Define the DLQ name and the max retry count before a message moves to the DLQ.
- [ ] **Plan idempotency**: If the Lambda is retried with the same message (SQS guarantees at-least-once delivery), will it produce the correct result without duplicates or side effects?
- [ ] ⏸ **Present the architecture to the user and wait for approval before implementing.**

**Output**: Approved event payload schema, queue name, Lambda name, and retry/DLQ strategy.

---

## Step 2: Implement — Producer

**Goal**: Add the code in Next.js or FastAPI that dispatches messages to SQS.

- [ ] Implement the `sendMessage` call to SQS using the AWS SDK.
- [ ] The message payload must match the approved schema exactly — validate it before sending.
- [ ] Use environment variables for the Queue URL (never hardcode ARNs or URLs).
- [ ] Handle the `SendMessage` failure gracefully — log the error and return an appropriate response to the caller.

**Output**: Producer code that dispatches messages to SQS when triggered.

---

## Step 3: Implement — Consumer (Lambda Handler)

**Goal**: Build the Lambda worker that processes SQS messages reliably.

- [ ] Parse and validate the incoming SQS `event.Records` payload against the approved schema.
- [ ] **Ensure idempotency**: The handler must produce the correct result even if called multiple times with the same message. Use deduplication keys or database upserts where needed.
- [ ] Implement the core business logic.
- [ ] On success: return no error (SQS auto-deletes the message on success).
- [ ] On partial failure: use `batchItemFailures` to report only the failed message IDs — do not fail the entire batch.

**Output**: Lambda handler code that is idempotent and correctly handles partial batch failures.

---

## Step 4: Close the Loop (`/review`)

- [ ] Test the full flow locally or in a staging environment: produce a message → verify the Lambda processes it correctly.
- [ ] Verify the DLQ: intentionally cause a failure → confirm the message lands in the DLQ after `maxRetries`.
- [ ] Update [`.agents/context/architecture.md`](../context/architecture.md) to document the new queue, Lambda function, and their purpose.
- [ ] Run `/remember save` to preserve session knowledge.
- Ask the user: *"The background job is implemented. Do you want me to add monitoring/alerting for DLQ depth, or write tests for the Lambda handler?"*

---

## ⚠️ Anti-Patterns — Never Do These

- ❌ **Never assume at-most-once delivery.** SQS delivers messages at least once — always design for duplicate execution.
- ❌ **Never hardcode Queue URLs or Lambda ARNs.** Use environment variables defined in `env-context.md`.
- ❌ **Never skip the DLQ.** Without a DLQ, permanently unprocessable messages loop forever and block the queue.
- ❌ **Never use third-party SaaS schedulers** (Trigger.dev, Inngest, etc.) — this project uses AWS SQS + Lambda exclusively.

---

## 📎 Context Links

- [architecture.md](../context/architecture.md)
- [env-context.md](../context/env-context.md)
