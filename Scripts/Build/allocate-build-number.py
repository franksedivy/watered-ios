#!/usr/bin/env python3
"""Increment the checkout counter once, before Xcode processes bundle metadata."""

import fcntl
import os
from pathlib import Path
import sys


def allocate(counter: Path, directory: Path) -> int:
    directory.mkdir(parents=True, exist_ok=True)
    # A separate lock survives atomic replacement of the counter. All build
    # configurations and DerivedData folders in this checkout share it.
    with counter.with_suffix(".lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        value = counter.read_text().strip()
        if not value.isascii() or not value.isdecimal():
            raise ValueError("BuildNumber.txt must contain a non-negative integer")
        number = int(value) + 1
        temporary_counter = counter.with_suffix(".tmp")
        temporary_counter.write_text(f"{number}\n")
        temporary_counter.replace(counter)
        # A failed build may consume a number. Never fall back to stale metadata.
        temporary_header = directory / f"Version.{os.getpid()}.tmp"
        temporary_header.write_text(f"#define WATERED_BUILD_NUMBER {number}\n")
        temporary_header.replace(directory / "Version.h")
        return number


if __name__ == "__main__":
    try:
        number = allocate(Path(sys.argv[1]), Path(sys.argv[2]))
        print(f"Watered allocated build {number}", flush=True)
    except (OSError, ValueError, IndexError) as error:
        sys.exit(f"error: Watered build-number allocation failed: {error}")
