# Digital Twin — AWS Production Deployment

> An AI-powered conversational Digital Twin deployed on AWS with full cloud infrastructure, Infrastructure as Code, and CI/CD automation.

**Built by [Sami Rautanen](https://www.samirautanen.fi)** — AI Engineer & Technical Designer

---

## Overview

This project builds and deploys a production-grade **AI Digital Twin** — a conversational agent that represents a person on their website, answering questions about their background, skills, and projects.

The stack progresses from a simple local prototype to a fully automated, multi-environment AWS deployment with CI/CD pipelines.

---

## Architecture

```
User Browser
    ↓ HTTPS
CloudFront (CDN + HTTPS)
    ↓
S3 Static Website (Next.js Frontend)
    ↓ HTTPS API Calls
API Gateway (HTTP API)
    ↓
Lambda Function (FastAPI Backend via Mangum)
    ↓
    ├── AWS Bedrock — Amazon Nova (AI responses)
    │   └── 🛡️ Amazon Bedrock Guardrails (Safety Filter)
    └── S3 Memory Bucket (conversation persistence)
```

### Infrastructure managed by Terraform, deployed via GitHub Actions.

---

## Tech Stack

### Backend
| Layer | Technology |
|---|---|
| Runtime | Python 3.12 |
| Framework | FastAPI + Mangum (Lambda adapter) |
| AI Model | AWS Bedrock — Amazon Nova (Lite / Micro / Pro) |
| Memory | AWS S3 (session-scoped JSON files) |
| Packaging | `uv` + Docker (Lambda-compatible build) |

### Frontend
| Layer | Technology |
|---|---|
| Framework | Next.js 15 (App Router) |
| Language | TypeScript |
| Styling | Tailwind CSS v4 |
| Export | Static (`output: 'export'`) |

### AWS Infrastructure
| Service | Purpose |
|---|---|
| Lambda | Serverless Python backend |
| API Gateway (HTTP) | REST API routing |
| S3 (×2) | Frontend hosting + conversation memory |
| CloudFront | Global CDN + HTTPS |
| Bedrock | Managed AI model inference |
| Bedrock Guardrails | 🛡️ AI Safety & Content filtering |
| DynamoDB | Terraform state locking |
| CloudWatch | Monitoring, logs, billing alerts |

### DevOps
| Tool | Purpose |
|---|---|
| Terraform | Infrastructure as Code (IaC) |
| GitHub Actions | CI/CD pipelines |
| AWS OIDC | Keyless authentication for GitHub Actions |
| S3 Backend | Remote Terraform state management |

---

## Project Structure

```
digital-twin/
├── backend/
│   ├── server.py              # FastAPI app (OpenAI / Bedrock versions)
│   ├── context.py             # Dynamic system prompt builder
│   ├── resources.py           # Loads personal data files
│   ├── lambda_handler.py      # Mangum Lambda entry point
│   ├── deploy.py              # Lambda packaging script (Docker-based)
│   ├── requirements.txt       # Python dependencies
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
│   ├── main.tf                # Core AWS resources
│   ├── variables.tf           # Input variables
│   ├── outputs.tf             # Output values (URLs, bucket names)
│   ├── versions.tf            # Provider configuration
│   └── terraform.tfvars       # Default variable values
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

| Phase | Focus | Key Outcome |
|---|---|---|
| **1** | Local prototype | FastAPI + Next.js + file-based memory |
| **2** | AWS deployment | Lambda, API Gateway, S3, CloudFront |
| **3** | AWS Bedrock | Amazon Nova models replacing OpenAI |
| **4** | Terraform IaC | Dev / Test / Prod environments automated |
| **5** | GitHub Actions CI/CD | Push-to-deploy + OIDC authentication |
| **6** | 🛡️ AI Guardrails | Hard security filters via Bedrock Guardrails |

---

## Local Development

### Prerequisites

- [Node.js 18+](https://nodejs.org)
- [Python 3.12+](https://python.org)
- [uv](https://docs.astral.sh/uv/) (Python package manager)
- OpenAI or OpenRouter API key (local dev) / AWS credentials (cloud deployment)

### Backend

```bash
cd backend
cp ../.env.example .env
# Fill in your API keys in .env

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
- IAM user with required permissions (Lambda, S3, API Gateway, CloudFront, Bedrock)

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
AWS_ACCOUNT_ID=178566695644
DEFAULT_AWS_REGION=eu-west-2

# Project
PROJECT_NAME=twin
```

For local development, create `backend/.env`:

```bash
OPENAI_API_KEY=sk-...          # or OpenRouter key
CORS_ORIGINS=http://localhost:3000
```

For Lambda (set in AWS Console or Terraform):

```
CORS_ORIGINS=https://your-cloudfront-domain.cloudfront.net
S3_BUCKET=twin-prod-memory-123456789012
USE_S3=true
BEDROCK_MODEL_ID=amazon.nova-lite-v1:0
GUARDRAIL_ID=abc123xyz             # Provided by Terraform
GUARDRAIL_VERSION=1                # Provided by Terraform
DEFAULT_AWS_REGION=eu-west-2
```

---

## 🛡️ Security & AI Guardrails

This project implements multi-layered security to ensure safety, privacy, and infrastructure integrity.

### 1. AI Safety (Amazon Bedrock Guardrails)
Unlike simple prompt instructions, these are "hard" filters enforced at the infrastructure level.
- **Content Filtering:** High-sensitivity filters for Hate Speech, Insults, Sexual Content, Violence, and Misconduct.
- **Topic Blocking:** Explicit denial of specific non-professional topics such as Medical, Financial, or Legal advice.
- **Real-time Protection:** Both user prompts and AI responses are analyzed in milliseconds before delivery.

### 2. Application Security
- **Path Traversal Protection:** All user-provided identifiers (such as `session_id`) are validated using strict regex patterns to prevent unauthorized file access.
- **Input Validation:** API endpoints use Pydantic models to ensure type safety and input correctness.
- **Environment Isolation:** All configurations are loaded from environment variables and never exposed to the AI model via prompts.

### 3. Infrastructure Security (AWS & Terraform)
- **Least Privilege IAM:** Lambda functions operate with scoped-down IAM policies, restricted only to the necessary S3 buckets and Bedrock models.
- **OIDC Authentication:** GitHub Actions uses short-lived OpenID Connect (OIDC) tokens — no long-lived AWS keys are stored in GitHub.
- **Secret Management:** A strict `.gitignore` policy prevents the leak of `.env`, `.pem`, and `.tfstate` files into version control.

---

## Bedrock Model Options

| Model ID | Speed | Cost | Best for |
|---|---|---|---|
| `amazon.nova-micro-v1:0` | Fastest | Lowest | Simple Q&A, greetings |
| `amazon.nova-lite-v1:0` | Balanced | Medium | General conversations ✅ |
| `amazon.nova-pro-v1:0` | Slowest | Highest | Complex reasoning |

> **Note:** In some regions you may need a prefix: `eu.amazon.nova-lite-v1:0` or `us.amazon.nova-lite-v1:0`

---

## CI/CD

GitHub Actions workflows automatically:
- Build the Lambda package
- Run `terraform apply` for the target environment
- Build and deploy the Next.js static frontend to S3
- Invalidate the CloudFront cache

Authentication uses **AWS OIDC** — no long-lived access keys stored in GitHub.

Trigger a deployment by pushing to `main` or manually via the GitHub Actions UI.

---

## Cost Estimate

| Service | Free Tier | Typical Monthly (low traffic) |
|---|---|---|
| Lambda | 1M requests free | ~$0 |
| API Gateway | 1M requests free | ~$0 |
| Bedrock Nova Lite | Pay per token | < $1 |
| S3 | 5GB free | < $0.10 |
| CloudFront | 1TB free | ~$0 |
| **Total** | | **< $5/month** |

Set up a billing alert in AWS Budgets to avoid surprises.

---

## Author

**Sami Rautanen** — AI Engineer & Technical Designer, Finland

- 🌐 [samirautanen.fi](https://www.samirautanen.fi)
- 💼 [LinkedIn](https://www.linkedin.com/in/sami-rautanen-022095325)
- 🐙 [GitHub](https://github.com/Samrude1)
- 📧 samrude1@outlook.com
