#!/usr/bin/env bash
# E2E Test Runner — loads credentials from .env and runs Maestro flows
#
# Copy this file to your project's scripts/ directory and customize.
#
# Usage:
#   ./scripts/e2e-run.sh production        # Run master flow (recommended)
#   ./scripts/e2e-run.sh staging           # Run master flow (recommended)
#   ./scripts/e2e-run.sh production 02     # Run specific flow by number
#   ./scripts/e2e-run.sh production all    # Run all flows individually

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load .env file if it exists
if [ -f "$PROJECT_ROOT/.env" ]; then
  set -a
  source "$PROJECT_ROOT/.env"
  set +a
fi

ENV="${1:-}"
FLOW_FILTER="${2:-}"

if [ -z "$ENV" ]; then
  echo "Usage: $0 <production|staging> [flow-number|all]"
  echo ""
  echo "Examples:"
  echo "  $0 production        # Run master flow (recommended)"
  echo "  $0 staging           # Run master flow (recommended)"
  echo "  $0 production 02     # Run only flow 02"
  echo "  $0 production all    # Run all flows individually"
  echo ""
  echo "Required .env variables:"
  echo "  MAESTRO_PROD_EMAIL, MAESTRO_PROD_PASSWORD, MAESTRO_PROD_OTP"
  echo "  MAESTRO_STAGING_EMAIL, MAESTRO_STAGING_PASSWORD, MAESTRO_STAGING_OTP"
  exit 1
fi

if [ "$ENV" != "production" ] && [ "$ENV" != "staging" ]; then
  echo "Error: environment must be 'production' or 'staging'"
  exit 1
fi

# Validate credentials
if [ "$ENV" = "production" ]; then
  if [ -z "${MAESTRO_PROD_EMAIL:-}" ] || [ -z "${MAESTRO_PROD_PASSWORD:-}" ] || [ -z "${MAESTRO_PROD_OTP:-}" ]; then
    echo "Error: Missing production credentials in .env"
    echo "Required: MAESTRO_PROD_EMAIL, MAESTRO_PROD_PASSWORD, MAESTRO_PROD_OTP"
    exit 1
  fi
  export MAESTRO_PROD_EMAIL MAESTRO_PROD_PASSWORD MAESTRO_PROD_OTP
elif [ "$ENV" = "staging" ]; then
  if [ -z "${MAESTRO_STAGING_EMAIL:-}" ] || [ -z "${MAESTRO_STAGING_PASSWORD:-}" ]; then
    echo "Error: Missing staging credentials in .env"
    echo "Required: MAESTRO_STAGING_EMAIL, MAESTRO_STAGING_PASSWORD"
    exit 1
  fi
  export MAESTRO_STAGING_EMAIL MAESTRO_STAGING_PASSWORD
fi

FLOW_DIR="$PROJECT_ROOT/.maestro/release-checks/$ENV"

if [ ! -d "$FLOW_DIR" ]; then
  echo "Error: Flow directory not found: $FLOW_DIR"
  exit 1
fi

# Default: run master flow (single Maestro session)
if [ -z "$FLOW_FILTER" ]; then
  MASTER_FLOW="$FLOW_DIR/run-all.yaml"
  if [ ! -f "$MASTER_FLOW" ]; then
    echo "Error: Master flow not found: $MASTER_FLOW"
    echo "Hint: use '$0 $ENV all' to run individual flows sequentially"
    exit 1
  fi

  echo "=== E2E Release Checks: $ENV (master flow) ==="
  echo ""
  if maestro test "$MASTER_FLOW" 2>&1; then
    echo ""
    echo "=== Result: ALL PASSED ==="
  else
    echo ""
    echo "=== Result: FAILED ==="
    exit 1
  fi
  exit 0
fi

# Specific flow or "all" mode
FLOWS=()
if [ "$FLOW_FILTER" = "all" ]; then
  for f in "$FLOW_DIR"/[0-9]*.yaml; do
    [ -f "$f" ] && FLOWS+=("$f")
  done
else
  for f in "$FLOW_DIR"/"$FLOW_FILTER"-*.yaml; do
    [ -f "$f" ] && FLOWS+=("$f")
  done
  if [ ${#FLOWS[@]} -eq 0 ]; then
    echo "Error: No flow found matching '$FLOW_FILTER' in $FLOW_DIR"
    exit 1
  fi
fi

echo "=== E2E Release Checks: $ENV ==="
echo "Flows to run: ${#FLOWS[@]}"
echo ""

PASSED=0
FAILED=0
FAILED_NAMES=()

for flow in "${FLOWS[@]}"; do
  name=$(basename "$flow" .yaml)
  echo ">>> Running: $name"

  if maestro test "$flow" 2>&1 | tail -3; then
    echo ">>> RESULT: $name PASSED"
    PASSED=$((PASSED + 1))
  else
    echo ">>> RESULT: $name FAILED"
    FAILED=$((FAILED + 1))
    FAILED_NAMES+=("$name")
  fi
  echo ""
done

echo "=== Results: $ENV ==="
echo "Passed: $PASSED / $((PASSED + FAILED))"
if [ $FAILED -gt 0 ]; then
  echo "Failed: ${FAILED_NAMES[*]}"
  exit 1
else
  echo "All flows passed!"
fi
