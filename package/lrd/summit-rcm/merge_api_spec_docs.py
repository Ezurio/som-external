#!/usr/bin/env python3

"""Script to merge multiple OpenAPI JSON files into a single file."""

import json
from pathlib import Path
from sys import argv

PATTERN = r"summit-rcm-openapi*.json"


def merge_dicts(d1, d2):
    def check(k, v):
        return isinstance(d1.get(k), dict) and isinstance(v, dict)

    return {
        **d1,
        **{k: merge_dicts(d1[k], d2[k]) if check(k, v) else v for k, v in d2.items()},
    }


if __name__ == "__main__":

    # Get first argument as the working directory
    WORKING_DIR = argv[1] if len(argv) > 1 else "."

    # Get second argument as the output file
    OUTPUT_FILE = argv[2] if len(argv) > 2 else "summit-rcm-openapi.json"

    merged = {}

    for openapi_json_file in Path(WORKING_DIR).glob(PATTERN):
        print(f"Merging {openapi_json_file}")
        with open(openapi_json_file) as f:
            merged = merge_dicts(merged, json.load(f))

    with open(OUTPUT_FILE, "w") as f:
        json.dump(merged, f)
