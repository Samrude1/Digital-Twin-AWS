from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
import os
from dotenv import load_dotenv
from typing import Optional, List, Dict
import json
import uuid
import re
from datetime import datetime, date
from decimal import Decimal
import boto3
from botocore.exceptions import ClientError
from context import prompt

# Rate limiting
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

# Load environment variables
load_dotenv()

# ─────────────────────────────────────────────
# App & Rate Limiter Setup
# ─────────────────────────────────────────────
limiter = Limiter(key_func=get_remote_address)

app = FastAPI()
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Configure CORS
origins = os.getenv("CORS_ORIGINS", "http://localhost:3000").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)

# ─────────────────────────────────────────────
# AWS Clients
# ─────────────────────────────────────────────
bedrock_client = boto3.client(
    service_name="bedrock-runtime",
    region_name=os.getenv("DEFAULT_AWS_REGION", "eu-west-2")
)

# ─────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────
# Bedrock model selection
# Available models:
# - amazon.nova-micro-v1:0  (fastest, cheapest)
# - amazon.nova-lite-v1:0   (balanced - default)
# - amazon.nova-pro-v1:0    (most capable, higher cost)
BEDROCK_MODEL_ID = os.getenv("BEDROCK_MODEL_ID", "amazon.nova-lite-v1:0")

# Memory storage configuration
USE_S3 = os.getenv("USE_S3", "false").lower() == "true"
S3_BUCKET = os.getenv("S3_BUCKET", "")
MEMORY_DIR = os.getenv("MEMORY_DIR", "../memory")

# Bedrock Guardrail configuration
GUARDRAIL_ID = os.getenv("GUARDRAIL_ID", "")
GUARDRAIL_VERSION = os.getenv("GUARDRAIL_VERSION", "DRAFT")

# ── Cost & Session Protection ───────────────
# DynamoDB table for daily cost tracking (circuit breaker)
COST_TABLE = os.getenv("COST_TABLE", "")
# Hard daily USD limit — service returns 503 when exceeded
DAILY_BUDGET_USD = float(os.getenv("DAILY_BUDGET_USD", "5.0"))
# Amazon Nova Micro cost: $0.035/1M input + $0.14/1M output tokens
# Using a blended conservative estimate per 1000 tokens
NOVA_COST_PER_1K_TOKENS = float(os.getenv("NOVA_COST_PER_1K_TOKENS", "0.00014"))

# Per-session hard limits (bot protection)
MAX_MESSAGES_PER_SESSION = int(os.getenv("MAX_MESSAGES_PER_SESSION", "30"))
# Estimated token limit per session (~50 000 tokens ≈ ~0.007 USD on Nova Micro)
MAX_TOKENS_PER_SESSION = int(os.getenv("MAX_TOKENS_PER_SESSION", "50000"))

# Initialize S3 client if needed
if USE_S3:
    s3_client = boto3.client("s3")

# Initialize DynamoDB resource if cost table is configured
dynamodb = boto3.resource("dynamodb") if COST_TABLE else None


# ─────────────────────────────────────────────
# Request / Response Models
# ─────────────────────────────────────────────
class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=2000, description="User prompt message")
    session_id: Optional[str] = Field(None, max_length=64, description="Optional conversation session ID")


class ChatResponse(BaseModel):
    response: str
    session_id: str


class Message(BaseModel):
    role: str
    content: str
    timestamp: str


# ─────────────────────────────────────────────
# Memory Management
# ─────────────────────────────────────────────
def get_memory_path(session_id: str) -> str:
    return f"{session_id}.json"


def load_conversation(session_id: str) -> List[Dict]:
    """Load conversation history from storage."""
    if USE_S3:
        try:
            response = s3_client.get_object(Bucket=S3_BUCKET, Key=get_memory_path(session_id))
            return json.loads(response["Body"].read().decode("utf-8"))
        except ClientError as e:
            if e.response["Error"]["Code"] == "NoSuchKey":
                return []
            raise
    else:
        file_path = os.path.join(MEMORY_DIR, get_memory_path(session_id))
        if os.path.exists(file_path):
            with open(file_path, "r") as f:
                return json.load(f)
        return []


def save_conversation(session_id: str, messages: List[Dict]):
    """Save conversation history to storage."""
    if USE_S3:
        s3_client.put_object(
            Bucket=S3_BUCKET,
            Key=get_memory_path(session_id),
            Body=json.dumps(messages, indent=2),
            ContentType="application/json",
        )
    else:
        os.makedirs(MEMORY_DIR, exist_ok=True)
        file_path = os.path.join(MEMORY_DIR, get_memory_path(session_id))
        with open(file_path, "w") as f:
            json.dump(messages, f, indent=2)


# ─────────────────────────────────────────────
# Protection Layer 1: Per-Session Limits
# ─────────────────────────────────────────────
def _estimate_tokens(text: str) -> int:
    """Rough estimate: ~4 characters per token."""
    return len(text) // 4


def enforce_session_limits(conversation: List[Dict], new_message: str):
    """
    Raise HTTP 429 if this session has hit the per-session hard limits.
    Counts user messages only (assistant messages are paired responses).
    """
    user_messages = [m for m in conversation if m.get("role") == "user"]
    if len(user_messages) >= MAX_MESSAGES_PER_SESSION:
        raise HTTPException(
            status_code=429,
            detail=(
                f"Session limit reached ({MAX_MESSAGES_PER_SESSION} messages). "
                "Please start a new conversation."
            ),
        )

    # Estimate cumulative token usage for this session
    all_text = " ".join(m.get("content", "") for m in conversation) + new_message
    estimated_tokens = _estimate_tokens(all_text)
    if estimated_tokens > MAX_TOKENS_PER_SESSION:
        raise HTTPException(
            status_code=429,
            detail=(
                f"Session token limit reached (~{MAX_TOKENS_PER_SESSION:,} tokens). "
                "Please start a new conversation."
            ),
        )


# ─────────────────────────────────────────────
# Protection Layer 2: Daily Cost Circuit Breaker
# ─────────────────────────────────────────────
def _get_cost_table():
    """Return DynamoDB Table object, or None if not configured."""
    if not COST_TABLE or dynamodb is None:
        return None
    return dynamodb.Table(COST_TABLE)


def check_daily_budget():
    """
    Read today's accumulated cost from DynamoDB.
    Raise HTTP 503 if the daily budget is exhausted.
    Runs BEFORE the Bedrock call so we never overshoot.
    """
    table = _get_cost_table()
    if table is None:
        return  # Cost tracking not configured — skip gracefully

    today = str(date.today())
    try:
        response = table.get_item(Key={"date": today})
        item = response.get("Item", {})
        current_cost = float(item.get("total_cost", 0))
        if current_cost >= DAILY_BUDGET_USD:
            print(f"[CIRCUIT BREAKER] Daily budget ${DAILY_BUDGET_USD} exhausted. "
                  f"Current: ${current_cost:.4f}")
            raise HTTPException(
                status_code=503,
                detail=(
                    f"Daily AI budget (${DAILY_BUDGET_USD:.2f}) has been exhausted. "
                    "Service resumes tomorrow. Please try again later."
                ),
            )
    except HTTPException:
        raise
    except Exception as e:
        # Never block real users due to DynamoDB issues — log and continue
        print(f"[WARNING] Cost check failed (non-blocking): {e}")


def record_cost(tokens_used: int):
    """
    Atomically increment today's cost and call count in DynamoDB.
    Called AFTER a successful Bedrock response.
    """
    table = _get_cost_table()
    if table is None:
        return

    today = str(date.today())
    cost = Decimal(str(round((tokens_used / 1000) * NOVA_COST_PER_1K_TOKENS, 8)))

    try:
        table.update_item(
            Key={"date": today},
            UpdateExpression=(
                "ADD total_cost :c, total_calls :one "
                "SET last_updated = :ts"
            ),
            ExpressionAttributeValues={
                ":c": cost,
                ":one": 1,
                ":ts": datetime.utcnow().isoformat(),
            },
        )
    except Exception as e:
        # Non-blocking — never crash real traffic over a metrics write
        print(f"[WARNING] Cost recording failed (non-blocking): {e}")


# ─────────────────────────────────────────────
# Bedrock Caller
# ─────────────────────────────────────────────
def call_bedrock(conversation: List[Dict], user_message: str) -> str:
    """Call AWS Bedrock with conversation history and return the response text."""

    system_prompts = [{"text": prompt()}]

    # Build messages in Bedrock format (last 20 turns)
    messages = []
    for msg in conversation[-20:]:
        messages.append({
            "role": msg["role"],
            "content": [{"text": msg["content"]}]
        })
    messages.append({
        "role": "user",
        "content": [{"text": user_message}]
    })

    try:
        guardrail_config = None
        if GUARDRAIL_ID:
            guardrail_config = {
                "guardrailIdentifier": GUARDRAIL_ID,
                "guardrailVersion": GUARDRAIL_VERSION,
                "trace": "enabled",
            }

        converse_args = {
            "modelId": BEDROCK_MODEL_ID,
            "messages": messages,
            "system": system_prompts,
            "inferenceConfig": {
                "maxTokens": 2000,
                "temperature": 0.7,
                "topP": 0.9,
            },
        }

        if guardrail_config:
            converse_args["guardrailConfig"] = guardrail_config

        response = bedrock_client.converse(**converse_args)

        # Record token usage for cost tracking
        usage = response.get("usage", {})
        total_tokens = usage.get("inputTokens", 0) + usage.get("outputTokens", 0)
        record_cost(total_tokens)

        return response["output"]["message"]["content"][0]["text"]

    except ClientError as e:
        error_code = e.response["Error"]["Code"]
        if error_code == "ValidationException":
            print(f"Bedrock validation error: {e}")
            raise HTTPException(status_code=400, detail="Invalid message format for Bedrock")
        elif error_code == "AccessDeniedException":
            print(f"Bedrock access denied: {e}")
            raise HTTPException(status_code=403, detail="Access denied to Bedrock model")
        elif error_code == "ThrottlingException":
            print(f"Bedrock throttling: {e}")
            raise HTTPException(status_code=429, detail="AI service is busy. Please retry in a moment.")
        else:
            print(f"Bedrock error: {e}")
            raise HTTPException(status_code=500, detail="AI service encountered an internal error. Please try again later.")


# ─────────────────────────────────────────────
# Routes
# ─────────────────────────────────────────────
@app.get("/")
async def root():
    return {
        "message": "AI Digital Twin API (Powered by AWS Bedrock)",
        "memory_enabled": True,
        "storage": "S3" if USE_S3 else "local",
        "ai_model": BEDROCK_MODEL_ID,
        "session_limits": {
            "max_messages": MAX_MESSAGES_PER_SESSION,
            "max_tokens_estimated": MAX_TOKENS_PER_SESSION,
        },
    }


@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "use_s3": USE_S3,
        "bedrock_model": BEDROCK_MODEL_ID,
        "cost_tracking": bool(COST_TABLE),
        "daily_budget_usd": DAILY_BUDGET_USD,
    }


@app.post("/chat", response_model=ChatResponse)
@limiter.limit("10/minute")   # per-IP: max 10 requests/minute
@limiter.limit("100/hour")    # per-IP: max 100 requests/hour
async def chat(request: Request, body: ChatRequest):
    """
    Main chat endpoint with three protection layers:
    1. IP rate limiting (slowapi) — 10/min, 100/hr per IP
    2. Per-session limits     — max 30 messages / ~50 000 tokens
    3. Daily cost budget      — DynamoDB circuit breaker at $5/day
    """
    try:
        # Validate session ID format to prevent path traversal
        if body.session_id:
            if not re.match(r"^[a-zA-Z0-9\-_]{1,64}$", body.session_id):
                raise HTTPException(status_code=400, detail="Invalid session_id format")

        session_id = body.session_id or str(uuid.uuid4())

        # Load existing conversation
        conversation = load_conversation(session_id)

        # ── Guard 1: Per-session limits ──────────
        enforce_session_limits(conversation, body.message)

        # ── Guard 2: Daily cost circuit breaker ──
        check_daily_budget()

        # ── Call AI ──────────────────────────────
        assistant_response = call_bedrock(conversation, body.message)

        # Persist conversation
        conversation.append({
            "role": "user",
            "content": body.message,
            "timestamp": datetime.now().isoformat(),
        })
        conversation.append({
            "role": "assistant",
            "content": assistant_response,
            "timestamp": datetime.now().isoformat(),
        })
        save_conversation(session_id, conversation)

        return ChatResponse(response=assistant_response, session_id=session_id)

    except HTTPException:
        raise
    except Exception as e:
        print(f"Error in chat endpoint: {str(e)}")
        raise HTTPException(status_code=500, detail="An error occurred while processing your request. Please try again later.")


@app.get("/conversation/{session_id}")
async def get_conversation(session_id: str):
    """Retrieve conversation history for a session."""
    try:
        if not re.match(r"^[a-zA-Z0-9\-_]{1,64}$", session_id):
            raise HTTPException(status_code=400, detail="Invalid session_id format")

        conversation = load_conversation(session_id)
        return {"session_id": session_id, "messages": conversation}
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error in get_conversation endpoint: {str(e)}")
        raise HTTPException(status_code=500, detail="An error occurred while retrieving conversation history.")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)