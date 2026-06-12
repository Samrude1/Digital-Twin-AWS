"""
budget_breaker.py — AWS Lambda Circuit Breaker

Triggered by AWS Budgets → SNS when monthly spend exceeds the alert threshold.
Automatically throttles the main API Lambda to 0 concurrent executions,
effectively shutting down the public endpoint until manually re-enabled.

To re-enable after a budget breach, run:
  aws lambda put-function-concurrency \
    --function-name <MAIN_FUNCTION_NAME> \
    --reserved-concurrent-executions -1
"""

import boto3
import json
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

lambda_client = boto3.client("lambda")
sns_client = boto3.client("sns")

# Environment variables (injected by Terraform)
MAIN_FUNCTION_NAME = os.environ.get("MAIN_FUNCTION_NAME", "")
ALERT_SNS_TOPIC_ARN = os.environ.get("ALERT_SNS_TOPIC_ARN", "")
MONTHLY_BUDGET_USD = float(os.environ.get("MONTHLY_BUDGET_USD", "20.0"))


def handler(event, context):
    """
    SNS → Lambda handler.
    Parses the Budgets alert and kills the API Lambda concurrency.
    """
    logger.info("Budget breaker triggered. Event: %s", json.dumps(event))

    for record in event.get("Records", []):
        try:
            message_body = json.loads(record["Sns"]["Message"])
            budget_name = message_body.get("budgetName", "unknown")
            account_id = message_body.get("accountId", "unknown")
            actual_spend = message_body.get("budgetedAmount", "?")

            logger.warning(
                "[CIRCUIT BREAKER] Budget '%s' on account %s has hit the threshold "
                "(monthly limit: $%.2f, actual: %s). Shutting down API Lambda.",
                budget_name, account_id, MONTHLY_BUDGET_USD, actual_spend,
            )

            if not MAIN_FUNCTION_NAME:
                logger.error("MAIN_FUNCTION_NAME not set — cannot throttle Lambda.")
                continue

            # Set reserved concurrency to 0 → Lambda returns 429 to all callers
            lambda_client.put_function_concurrency(
                FunctionName=MAIN_FUNCTION_NAME,
                ReservedConcurrentExecutions=0,
            )
            logger.info(
                "Lambda '%s' reserved concurrency set to 0. API is now offline.",
                MAIN_FUNCTION_NAME,
            )

            # Send a notification so the owner knows what happened
            if ALERT_SNS_TOPIC_ARN:
                sns_client.publish(
                    TopicArn=ALERT_SNS_TOPIC_ARN,
                    Subject="⚠️ Digital Twin API SHUT DOWN — Monthly Budget Exceeded",
                    Message=(
                        f"The Digital Twin API has been automatically shut down.\n\n"
                        f"Budget: {budget_name}\n"
                        f"Account: {account_id}\n"
                        f"Monthly limit: ${MONTHLY_BUDGET_USD:.2f}\n\n"
                        f"To re-enable the API manually, run:\n"
                        f"  aws lambda put-function-concurrency \\\n"
                        f"    --function-name {MAIN_FUNCTION_NAME} \\\n"
                        f"    --reserved-concurrent-executions -1\n\n"
                        f"Or wait until the budget resets at the start of next month."
                    ),
                )
                logger.info("Shutdown notification sent to SNS topic.")

        except Exception as e:
            logger.error("Error processing SNS record: %s", str(e), exc_info=True)

    return {"statusCode": 200, "body": "Budget breaker executed."}
