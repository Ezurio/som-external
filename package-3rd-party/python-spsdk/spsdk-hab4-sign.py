#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause
"""Generate an i.MX8M HAB4 CSF with SPSDK.

This adapter deliberately operates on SPSDK's HAB CSF API instead of its
full-image API. i.MX8M binman has already constructed the ROM-specific IVT
and image layout; it only needs a CSF that authenticates that exact byte range.
This also avoids deriving i.MX8M layout information from SPSDK's MCU family
database.
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path

# The native sysroot openssl.cnf activates the OpenSSL pkcs11-provider on top of
# aws_kms_pkcs11.so. This program does not need that provider: it reaches the
# token through python-pkcs11 directly. Leaving it active can deadlock signing.
os.environ["OPENSSL_CONF"] = os.devnull

from spsdk.image.hab.commands.commands import ImageBlock  # noqa: E0401,E402
from spsdk.image.hab.segments.seg_csf import HabSegmentCSF  # noqa: E0401,E402
from spsdk.utils.config import Config  # noqa: E0401,E402

# i.MX8M binman reserves 0x2000 bytes for the generated IVT plus CSF. The
# caller supplies the IVT in its input, so this program emits the remaining CSF
# space only.
CSF_OUTPUT_SIZE = 0x2000 - 0x20


def resolve_password_file(signer: str) -> str:
    """Replace the local password-file extension with SPSDK's password value."""
    marker = ";password-file="
    if marker not in signer:
        return signer
    signer, password_file = signer.rsplit(marker, maxsplit=1)
    password_index = 0
    if ";password-index=" in password_file:
        password_file, password_index = password_file.rsplit(";password-index=", maxsplit=1)
        password_index = int(password_index)
    password = Path(password_file).read_text(encoding="utf-8").splitlines()[password_index]
    return f"{signer};password={password}"


def set_pkcs11_config_from_signers(config: Config) -> None:
    """Set the active provider's PKCS#11 config from the task environment."""
    config_env = os.environ.get("SPSDK_PKCS11_CONFIG_ENV")
    config_path = os.environ.get("SPSDK_PKCS11_CONFIG_PATH")
    if not config_env or not config_path:
        return

    for section in config["sections"]:
        for command in section.values():
            signer = command.get("Signer")
            if signer and "type=pkcs11" in signer:
                os.environ[config_env] = config_path
                return


def parse_args() -> argparse.Namespace:
    """Parse the HAB4 signing inputs."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True, help="SPSDK HAB CSF YAML configuration")
    parser.add_argument("--input", required=True, help="Prepared SPL or FIT payload to authenticate")
    parser.add_argument("--output", required=True, help="Output CSF blob path")
    parser.add_argument(
        "--address",
        required=True,
        type=lambda value: int(value, 0),
        help="Load address of the first byte in --input",
    )
    return parser.parse_args()


def main() -> None:
    """Generate a fixed-size CSF that authenticates the supplied payload."""
    args = parse_args()
    config = Config.create_from_file(args.config)
    config["options"] = {
        "flags": 0x8,
        "startAddress": args.address,
        "ivtOffset": 0,
        "initialLoadSize": 0,
    }
    config["inputImageFile"] = args.input
    set_pkcs11_config_from_signers(config)
    for section in config["sections"]:
        for command in section.values():
            if "Signer" in command:
                command["Signer"] = resolve_password_file(command["Signer"])
    payload = Path(args.input).read_bytes()

    csf = HabSegmentCSF.load_from_config(config)
    csf.update_signature(
        image_data=payload,
        blocks=[ImageBlock(base_address=args.address, start=0, size=len(payload))],
        base_data_address=args.address,
    )
    output = csf.export()[:CSF_OUTPUT_SIZE]
    Path(args.output).write_bytes(output)


if __name__ == "__main__":
    main()
