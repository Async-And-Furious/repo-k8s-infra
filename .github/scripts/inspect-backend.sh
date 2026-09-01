#!/usr/bin/env bash
# Read-only destroy check for an existing account-qualified state object.
set -euo pipefail

prefix=${1:?state prefix is required}
environment=${2:?environment is required}
output=${3:-backend.hcl}
region=${AWS_REGION:?AWS_REGION is required}
github_env=${GITHUB_ENV:?GITHUB_ENV is required}

account_id=$(aws sts get-caller-identity --query Account --output text)
echo "::add-mask::$account_id"
bucket="tc3-tfstate-${account_id}"
key="$prefix/$environment/terraform.tfstate"
error_file=$(mktemp)
trap 'rm -f "$error_file"' EXIT

if size=$(aws s3api head-object --bucket "$bucket" --key "$key" --query ContentLength --output text 2>"$error_file"); then
  if [[ "$size" == "0" ]]; then
    echo "DESTROY_STATE_OBJECT=false" >> "$github_env"
    echo "Terraform state object is empty; destroy is a no-op."
    exit 0
  fi
  cat > "$output" <<EOF
bucket       = "$bucket"
key          = "$key"
region       = "$region"
encrypt      = true
use_lockfile = true
EOF
  echo "DESTROY_STATE_OBJECT=true" >> "$github_env"
  echo "Existing Terraform state object found."
elif grep -Eq '\(404\)|Not Found|NoSuchBucket|NoSuchKey' "$error_file"; then
  echo "DESTROY_STATE_OBJECT=false" >> "$github_env"
  echo "Terraform state object is absent; destroy is a no-op."
else
  cat "$error_file" >&2
  exit 1
fi
