#!/usr/bin/env python3
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2026 Ezurio
"""Generate the aws-kms-pkcs11 multi-slot JSON configuration from the
AWS_KMS_*_ARN environment variables.

AWS-backend-specific: this lives alongside aws-kms.mk in backends/aws-kms/ and is
invoked (via HSM_GEN_CONFIG_CMD in aws-kms.mk) by the host-summit-key-provider
build step.  Generating it there — rather than at host-aws-kms-pkcs11 install
time, which is stamp-cached — lets a single host-summit-key-provider-rebuild
pick up ARN changes.  It has no source and no build step of its own, so it is
split out of the main package logic (mirrors the Yocto aws-kms-pkcs11-config
recipe).

Usage: aws_kms_config.py <output_path>

Each slot carries only 'kms_key_arn'.  aws_kms_pkcs11.so derives the
PKCS#11 token label (first 32 chars of the key UUID) and the AWS region
from the ARN, so neither is emitted here.
"""

import json
import os
import sys

# ARN sources, in order.  Duplicates are removed; order is normalized.
ARN_VARS = (
    "AWS_KMS_KEY_ARN",
    "AWS_KMS_CSF_KEY_ARN",
    "AWS_KMS_IMG_KEY_ARN",
    "AWS_KMS_FIT_KEY_ARN",
    "AWS_KMS_AHAB_KEY_ARN",
)


def main():
    """Write the aws-kms-pkcs11 slots JSON config to the given output path."""
    if len(sys.argv) != 2:
        sys.exit(f"Usage: {sys.argv[0]} <output_path>")
    out_path = sys.argv[1]

    arns = sorted({v for v in (os.environ.get(n, "") for n in ARN_VARS) if v})
    if not arns:
        sys.exit(f"ERROR: At least one of {', '.join(ARN_VARS)} must be set.")

    config = {"slots": [{"kms_key_arn": arn} for arn in arns]}

    with open(out_path, "w", encoding="utf-8") as f:
        f.write(json.dumps(config, indent=2))
        f.write("\n")


if __name__ == "__main__":
    main()
