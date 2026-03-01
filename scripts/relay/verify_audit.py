#!/usr/bin/env python3
"""
Verify integrity of relay audit logs.
Checks the SHA-256 hash chain to detect any tampering.

Usage:
    python verify_audit.py audit_logs/relay_audit_20260227_091500.jsonl
"""

import json
import hashlib
import sys
from pathlib import Path


def verify(log_path: str):
    path = Path(log_path)
    if not path.exists():
        print(f"✗ File not found: {path}")
        sys.exit(1)

    prev_hash = "GENESIS"
    count = 0
    errors = 0

    with open(path) as f:
        for i, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue

            entry = json.loads(line)
            stored_hash = entry.pop("hash")

            # Verify chain link
            if entry.get("prev_hash") != prev_hash:
                print(f"  ✗ seq {i}: prev_hash mismatch (expected {prev_hash[:16]}..., got {entry.get('prev_hash', 'MISSING')[:16]}...)")
                errors += 1

            # Verify entry hash
            raw = json.dumps(entry, sort_keys=True)
            expected = hashlib.sha256(f"{prev_hash}:{raw}".encode()).hexdigest()

            if stored_hash != expected:
                print(f"  ✗ seq {i}: hash mismatch")
                print(f"    stored:   {stored_hash[:32]}...")
                print(f"    expected: {expected[:32]}...")
                errors += 1
            
            prev_hash = stored_hash
            count += 1

    print()
    if errors == 0:
        print(f"✓ All {count} entries verified. Hash chain intact.")
        print(f"  First entry: GENESIS")
        print(f"  Final hash:  {prev_hash[:32]}...")
    else:
        print(f"✗ {errors} error(s) found in {count} entries. LOG MAY BE TAMPERED.")
        sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python verify_audit.py <path-to-audit-log.jsonl>")
        sys.exit(1)
    verify(sys.argv[1])
