#!/usr/bin/env python3
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2026 Ezurio

"""Encrypt a provisioning archive as IV || AES-GCM ciphertext || tag."""

import os
import pathlib
import sys

from cryptography.hazmat.primitives.ciphers.aead import AESGCM


def main() -> int:
    """Encrypt the input archive with the supplied AES-256 key."""
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} KEY INPUT OUTPUT", file=sys.stderr)
        return 2

    key_path, input_path, output_path = map(pathlib.Path, sys.argv[1:])
    key = key_path.read_bytes()
    if len(key) != 32:
        print(f"{key_path}: AES-256 key must be exactly 32 bytes", file=sys.stderr)
        return 1

    nonce = os.urandom(12)
    ciphertext_and_tag = AESGCM(key).encrypt(nonce, input_path.read_bytes(), None)
    output_path.write_bytes(nonce + ciphertext_and_tag)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
