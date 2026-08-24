# Digital Twin — AWS Production Deployment

> An AI-powered conversational Digital Twin deployed on AWS with full cloud infrastructure, Infrastructure as Code, and CI/CD automation.

**Built by [Sami Rautanen](https://www.samirautanen.fi)** — AI Engineer & Technical Designer

---

## Overview

This project builds and deploys a production-grade **AI Digital Twin** — a conversational agent that represents a person on their website, answering questions about their background, skills, and projects.

The stack progresses from a simple local prototype to a fully automated, multi-environment AWS deployment with CI/CD pipelines and multi-layered cost & bot protection.

---

## Architecture

```
User Browser
    ↓ HTTPS
CloudFront (CDN + HTTPS)
    ↓
S3 Static Website (Next.js Frontend)
    ↓ HTTPS API Calls
API Gateway (HTTP API) ← throttle: 5 req/s, burst 10
    ↓
Lambda Function (FastAPI + Mangum)
    │
    ├── slowapi Rate Limiter (10/min, 100/hr per IP)
    ├── Session Guard (max 30 msgs / ~50k tokens)
    ├── Cost Circuit Breaker (DynamoDB daily budget check)
    │
    ├── AWS Bedrock — Amazon Nova (AI responses)
    │   └── 🛡️ Amazon Bedrock Guardrails (Safety Filter)
    │
    ├── S3 Memory Bucket (conversation persistence)
    └── DynamoDB Cost Tracker (daily spend ledger)

AWS Budgets (monthly limit)
    └── SNS Topic → Budget Breaker Lambda
                    └── Sets API Lambda concurrency = 0 (kills API)
```

### Infrastructure managed by Terraform, deployed via GitHub Actions CI/CD.

---

## Tech Stack

### Backend
| Layer         | Technology                                     |
| ------------- | ---------------------------------------------- |
| Runtime       | Python 3.12                                    |
| Framework     | FastAPI + Mangum (Lambda adapter)              |
| AI Model      | AWS Bedrock — Amazon Nova (Lite / Micro / Pro) |
| Memory        | AWS S3 (session-scoped JSON files)             |
| Rate Limiting | `slowapi` (per-IP: 10/min, 100/hr)             |
| Packaging     | `uv` + Docker (Lambda-compatible build)        |

### Frontend
| Layer     | Technology                  |
| --------- | --------------------------- |
| Framework | Next.js 15 (App Router)     |
| Language  | TypeScript                  |
| Styling   | Tailwind CSS v4             |
| Export    | Static (`output: 'export'`) |

### AWS Infrastructure
| Service            | Purpose                                     |
| ------------------ | ------------------------------------------- |
| Lambda             | Serverless Python backend                   |
| API Gateway (HTTP) | REST API routing + throttling               |
| S3 (×2)            | Frontend hosting + conversation memory      |
| CloudFront         | Global CDN + HTTPS                          |
| Bedrock            | Managed AI model inference                  |
| Bedrock Guardrails | 🛡️ AI safety & content filtering             |
| DynamoDB           | Daily cost tracking (circuit breaker)       |
| SNS                | Budget alert notifications                  |
| AWS Budgets        | Monthly spend limit + auto-shutdown trigger |

### DevOps
| Tool           | Purpose                                       |
| -------------- | --------------------------------------------- |
| Terraform      | Infrastructure as Code (IaC)                  |
| GitHub Actions | CI/CD pipelines — push to `main` auto-deploys |
| AWS OIDC       | Keyless authentication for GitHub Actions     |
| S3 Backend     | Remote Terraform state management             |

---

## Project Structure

```
digital-twin/
├── backend/
│   ├── server.py              # FastAPI app — rate limiting, session guards, circuit breaker
│   ├── budget_breaker.py      # Lambda: kills API when monthly budget is hit
│   ├── context.py             # Dynamic system prompt builder
│   ├── resources.py           # Loads personal data files
│   ├── lambda_handler.py      # Mangum Lambda entry point
│   ├── deploy.py              # Lambda packaging script (Docker-based)
│   ├── requirements.txt       # Python dependencies (incl. slowapi)
│   ├── me.txt                 # Simple personality prompt (local dev)
│   └── data/
│       ├── facts.json         # Structured personal data
│       ├── summary.txt        # Personal narrative
│       ├── style.txt          # Communication style notes
│       └── linkedin.pdf       # LinkedIn profile (PDF)
├── frontend/
│   ├── app/
│   │   ├── page.tsx           # Main page
│   │   ├── layout.tsx         # Root layout
│   │   └── globals.css        # Global styles (Tailwind v4)
│   └── components/
│       └── twin.tsx           # Chat UI component
├── terraform/
│   ├── main.tf                # Core AWS resources + cost protection infra
│   ├── variables.tf           # Input variables (incl. budget limits)
│   ├── outputs.tf             # Output values (URLs, bucket names)
│   ├── versions.tf            # Provider configuration
│   ├── iam_github.tf          # GitHub Actions IAM role documentation
│   ├── iam_github_inline_policy.json  # Inline policy (applied via AWS CLI)
│   └── terraform.tfvars       # Default variable values (gitignored)
├── scripts/
│   ├── deploy.sh              # Deploy script (Mac/Linux + CI)
│   ├── deploy.ps1             # Deploy script (Windows)
│   ├── destroy.sh             # Teardown script (Mac/Linux)
│   └── destroy.ps1            # Teardown script (Windows)
├── memory/                    # Local conversation files (gitignored)
├── .env.example               # Environment variable template
├── .gitignore
└── README.md
```

---

## Build Phases

| Phase | Focus                   | Key Outcome                                                 |
| ----- | ----------------------- | ----------------------------------------------------------- |
| **1** | Local prototype         | FastAPI + Next.js + file-based memory                       |
| **2** | AWS deployment          | Lambda, API Gateway, S3, CloudFront                         |
| **3** | AWS Bedrock             | Amazon Nova models replacing OpenAI                         |
| **4** | Terraform IaC           | Dev / Test / Prod environments automated                    |
| **5** | GitHub Actions CI/CD    | Push-to-deploy + OIDC authentication                        |
| **6** | 🛡️ AI Guardrails         | Hard safety filters via Bedrock Guardrails                  |
| **7** | 🔐 Cost & Bot Protection | Three-layer defence against runaway bots and surprise bills |

---

## Local Development

### Prerequisites

- [Node.js 18+](https://nodejs.org)
- [Python 3.12+](https://python.org)
- [uv](https://docs.astral.sh/uv/) (Python package manager)
- AWS credentials (cloud deployment)

### Backend

```bash
cd backend
cp ../.env.example .env
# Fill in your values in .env

uv init --bare
uv python pin 3.12
uv add -r requirements.txt
uv run uvicorn server:app --reload
```

Backend runs at: `http://localhost:8000`

### Frontend

```bash
cd frontend
npm install
npm run dev
```

Frontend runs at: `http://localhost:3000`

---

## AWS Deployment

### Prerequisites

- AWS CLI configured (`aws configure`)
- Docker Desktop (for Lambda packaging)
- Terraform installed (`terraform --version`)
- IAM user/role with required permissions

### Deploy to dev

```bash
./scripts/deploy.sh dev
# Windows: .\scripts\deploy.ps1 -Environment dev
```

### Deploy to prod

```bash
./scripts/deploy.sh prod
# Windows: .\scripts\deploy.ps1 -Environment prod
```

### Teardown

```bash
./scripts/destroy.sh dev
# Windows: .\scripts\destroy.ps1 -Environment dev
```

---

## Environment Variables

Copy `.env.example` and fill in values:

```bash
# AWS Configuration
AWS_ACCOUNT_ID=your_12_digit_account_id
DEFAULT_AWS_REGION=eu-west-2

# Project
PROJECT_NAME=twin
```

For Lambda (injected by Terraform automatically — no manual setup needed):

```
CORS_ORIGINS=https://your-cloudfront-domain.cloudfront.net
S3_BUCKET=twin-prod-memory-123456789012
USE_S3=true
BEDROCK_MODEL_ID=amazon.nova-micro-v1:0
GUARDRAIL_ID=abc123xyz
GUARDRAIL_VERSION=1
COST_TABLE=twin-prod-cost-tracker      # DynamoDB table for circuit breaker
DAILY_BUDGET_USD=5.0                   # Hard daily limit — returns 503 when hit
```

Optional overrides for session and cost limits:

```
MAX_MESSAGES_PER_SESSION=30            # Max messages per chat session
MAX_TOKENS_PER_SESSION=50000           # Estimated token ceiling per session
NOVA_COST_PER_1K_TOKENS=0.00014       # Cost rate for DynamoDB tracking
```

---

## 🔐 Security & Cost Protection

This project implements multi-layered protection against both AI safety risks and cost explosion from runaway bots.

### Layer 1 — Per-IP Rate Limiting (Application)
Powered by `slowapi` inside FastAPI:
- **10 requests / minute** per IP address
- **100 requests / hour** per IP address
- Exceeding the limit returns **HTTP 429** immediately, before any Bedrock call is made

### Layer 2 — Per-Session Hard Limits (Application)
Enforced before every Bedrock call:
- **Max 30 messages** per conversation session
- **Max ~50 000 tokens** of cumulative context per session
- Prevents a single automated session from growing indefinitely
- Returns **HTTP 429** with a clear message to start a new conversation

### Layer 3 — Daily Cost Circuit Breaker (DynamoDB)
After every successful Bedrock call, the actual token usage is written to a DynamoDB table (`cost-tracker`):
- Tracks real spend per day using Bedrock's reported token counts
- Before each Bedrock call, checks if today's total exceeds `DAILY_BUDGET_USD` (default: **$5/day**)
- If exceeded, returns **HTTP 503** — the service pauses until midnight UTC

### Layer 4 — AWS Budgets Auto-Shutdown (Infrastructure)
Monthly spend is monitored at the AWS account level:
- **80% of monthly budget** ($20/month default) → triggers SNS alert
- **100% of monthly budget** → triggers SNS alert
- SNS → Lambda (`budget_breaker`) → sets API Lambda **reserved concurrency to 0**
- Effect: the public API endpoint returns errors for all callers until manually re-enabled
- Recovery: `aws lambda put-function-concurrency --function-name twin-prod-api --reserved-concurrent-executions -1`

### Layer 5 — 🛡️ AI Safety (Amazon Bedrock Guardrails)
Hard filters enforced at the AWS infrastructure level — independent of the application code:
- **Content Filtering:** HIGH sensitivity for Hate, Insults, Sexual, Violence, Misconduct
- **Topic Blocking:** Denies Medical, Financial, and Legal advice requests
- Both user inputs and AI outputs are filtered in real time

### Layer 6 — Infrastructure Security & HTTP Hardening
- **HTTP Security Headers:** CloudFront distribution enforces AWS `Managed-SecurityHeadersPolicy` (HSTS `Strict-Transport-Security`, `X-Content-Type-Options: nosniff`, `X-Frame-Options: SAMEORIGIN`, `Referrer-Policy: strict-origin-when-cross-origin`).
- **Least Privilege IAM:** Lambda roles restricted to exact S3 buckets, DynamoDB tables, and Bedrock model ARNs.
- **OIDC Authentication:** GitHub Actions uses short-lived OIDC tokens — no long-lived AWS keys stored.
- **Input & Payload Validation:** Message lengths strictly bounded with Pydantic (`1..2000` chars) and `session_id` validated with regex `^[a-zA-Z0-9\-_]{1,64}$` to prevent path traversal and memory bloat.
- **Sanitized Error Responses:** Generic client-facing error messages to prevent internal stack traces or AWS infrastructure details from leaking.
- **Secret Management:** `.gitignore` blocks `.env`, `.pem`, `.tfstate`, and `terraform.tfvars`.

---

## 🛡️ Security Audit

The codebase is audited against production-readiness standards (`/security-audit`):
- ✅ **Authentication & Abuse Defense**: Rate limiting (10/min, 100/hr) + Session limits (30 msgs, 50k tokens) + Budget Circuit Breaker.
- ✅ **Data Protection**: Public access blocked on conversation memory S3 bucket, sanitized client error handling.
- ✅ **Edge Protection**: CloudFront TLS 1.2+ HTTPS enforcement and Security Headers policy.
- ✅ **Dependencies**: Automated vulnerability scanning and dependency patching via `npm audit` and `uv`.

## Bedrock Model Options

| Model ID                 | Speed    | Cost    | Best for                          |
| ------------------------ | -------- | ------- | --------------------------------- |
| `amazon.nova-micro-v1:0` | Fastest  | Lowest  | Simple Q&A, greetings ✅ (default) |
| `amazon.nova-lite-v1:0`  | Balanced | Medium  | General conversations             |
| `amazon.nova-pro-v1:0`   | Slowest  | Highest | Complex reasoning                 |

> **Note:** In some regions you may need a prefix: `eu.amazon.nova-lite-v1:0` or `us.amazon.nova-lite-v1:0`

---

## CI/CD

Pushing to `main` **automatically deploys to production** via GitHub Actions:

1. Builds the Lambda deployment package
2. Runs `terraform apply` for the target environment
3. Builds and deploys the Next.js static frontend to S3
4. Invalidates the CloudFront cache

Authentication uses **AWS OIDC** — no long-lived access keys stored in GitHub.

To deploy manually: GitHub → Actions → Deploy Digital Twin → Run workflow.

---

## Cost Estimate

| Service                 | Est. monthly cost              |
| ----------------------- | ------------------------------ |
| Lambda (1M invocations) | ~$0.20                         |
| API Gateway             | ~$1.00 per 1M requests         |
| Bedrock Nova Micro      | ~$0.035 per 1M input tokens    |
| S3 (storage + requests) | < $0.10                        |
| CloudFront              | < $0.10                        |
| DynamoDB (on-demand)    | < $0.01                        |
| SNS                     | Free tier covers typical usage |

**Monthly budget guard: $20 hard limit** (configurable in `terraform.tfvars`).

---

## Author

**Sami Rautanen** — AI Engineer & Technical Designer, Finland

- 🌐 [samirautanen.fi](https://www.samirautanen.fi)
- 💼 [LinkedIn](https://www.linkedin.com/in/sami-rautanen-022095325)
- 🐙 [GitHub](https://github.com/Samrude1)
- 📧 samrude1@outlook.com
