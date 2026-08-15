#!/usr/bin/env python3
"""Fail closed on common accidental private/source artifacts in the public tree."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
IGNORED_DIRS = {".git", "__pycache__"}
FORBIDDEN_SUFFIXES = {".docx", ".doc", ".pdf"}
CJK_FILENAME = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]")
ABSOLUTE_USER_PATH = re.compile(r"/Users/")
NON_SYNTHETIC_PHONE = re.compile(r"(?<![0-9])(?:\+?\d[\d ()-]{6,}\d)(?![0-9])")
ALLOWED_PHONE = re.compile(r"^555-01[0-9]{2}$")
COURSE_CODE = re.compile(r"\b(?:CUHK|DOTE\d{3,}|BA\s*课程)\b", re.IGNORECASE)


def files_in_tree() -> list[Path]:
    files: list[Path] = []
    for path in ROOT.rglob("*"):
        if any(part in IGNORED_DIRS for part in path.parts):
            continue
        if path.is_file():
            files.append(path)
    return sorted(files)


def check_filename(path: Path, errors: list[str]) -> None:
    relative = path.relative_to(ROOT)
    if any(CJK_FILENAME.search(part) for part in relative.parts):
        errors.append(f"CJK filename: {relative}")
    if path.suffix.lower() in FORBIDDEN_SUFFIXES:
        errors.append(f"forbidden document/PDF: {relative}")


def check_text(path: Path, content: str, errors: list[str]) -> None:
    relative = path.relative_to(ROOT)
    if ABSOLUTE_USER_PATH.search(content):
        errors.append(f"absolute /Users/ path: {relative}")

    for match in NON_SYNTHETIC_PHONE.finditer(content):
        raw_value = match.group(0)
        candidate = re.sub(r"\s+", "", raw_value)
        if re.fullmatch(r"\d{4}-\d{2}-\d{2}(?:\s+\d{1,2})?", raw_value):
            continue
        if ALLOWED_PHONE.fullmatch(candidate):
            continue
        if any(ch.isalpha() for ch in candidate):
            continue
        errors.append(f"non-555 phone-like value in {relative}: {raw_value!r}")
        break

    if COURSE_CODE.search(content):
        errors.append(f"course/source identifier in {relative}")


def main() -> int:
    errors: list[str] = []
    for path in files_in_tree():
        check_filename(path, errors)
        if path.resolve() == Path(__file__).resolve():
            continue
        try:
            content = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        check_text(path, content, errors)

    if errors:
        print("FAIL: public-tree audit found:")
        for error in errors:
            print(f"- {error}")
        return 1

    print(f"PASS: public-tree audit scanned {len(files_in_tree())} files")
    return 0


if __name__ == "__main__":
    sys.exit(main())
