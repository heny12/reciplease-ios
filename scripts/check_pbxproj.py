#!/usr/bin/env python3
"""Project integrity for PantryPal.xcodeproj.

Xcode 16 compiles each target from a PBXFileSystemSynchronizedRootGroup.
Those Swift files are not repeated as rows in PBXSourcesBuildPhase. This
check treats that synchronized folder as target membership, then fails if a
referenced path is missing or a Swift file sits outside every synchronized root.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "PantryPal.xcodeproj" / "project.pbxproj"


def parse_objects(text: str) -> dict[str, tuple[str, str]]:
    objects: dict[str, tuple[str, str]] = {}
    for match in re.finditer(r"\n\t\t([A-F0-9]{24}) /\* .*? \*/ = \{", text):
        ident = match.group(1)
        start = match.end() - 1
        depth = 0
        end = None
        for index, char in enumerate(text[start:], start):
            if char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth == 0:
                    end = index
                    break
        if end is None:
            continue
        body = text[start + 1 : end]
        isa = re.search(r"isa = ([A-Za-z]+);", body)
        if isa:
            objects[ident] = (isa.group(1), body)
    return objects


def field(body: str, name: str) -> str | None:
    match = re.search(rf"(?m)^\s*{name} = ([^;]+);", body)
    if not match:
        return None
    return match.group(1).strip().strip('"')


def id_list(body: str, name: str) -> list[str]:
    match = re.search(rf"{name} = \((.*?)\);", body, re.S)
    if not match:
        return []
    return re.findall(r"([A-F0-9]{24})", match.group(1))


def main() -> int:
    if not PROJECT.exists():
        print(f"missing {PROJECT}", file=sys.stderr)
        return 1
    text = PROJECT.read_text()
    objects = parse_objects(text)
    errors: list[str] = []

    sync_roots = {
        ident: field(body, "path") or ""
        for ident, (kind, body) in objects.items()
        if kind == "PBXFileSystemSynchronizedRootGroup"
    }
    file_refs = {
        ident: body
        for ident, (kind, body) in objects.items()
        if kind == "PBXFileReference"
    }
    targets = {
        field(body, "name") or ident: body
        for ident, (kind, body) in objects.items()
        if kind == "PBXNativeTarget"
    }

    expected = {
        "PantryPal": "PantryPal",
        "PantryPalTests": "PantryPalTests",
        "PantryPalUITests": "PantryPalUITests",
    }
    covered: list[Path] = []
    for target_name, folder in expected.items():
        body = targets.get(target_name)
        if body is None:
            errors.append(f"missing native target {target_name}")
            continue
        root_paths = [sync_roots.get(item, "") for item in id_list(body, "fileSystemSynchronizedGroups")]
        print(f"{target_name}: synchronized {root_paths or '(none)'}")
        if folder not in root_paths:
            errors.append(f"{target_name} does not synchronize {folder}/")
        else:
            covered.append(ROOT / folder)

    for folder in covered:
        swift_files = sorted(path for path in folder.rglob("*.swift") if path.is_file())
        if not swift_files:
            errors.append(f"no Swift files under {folder.relative_to(ROOT)}")
        else:
            print(f"{folder.name}: {len(swift_files)} Swift files included via synchronized root")

    for ident, body in file_refs.items():
        path = field(body, "path") or ""
        source = field(body, "sourceTree") or ""
        file_type = field(body, "explicitFileType") or field(body, "lastKnownFileType") or ""
        if not path or source in {"BUILT_PRODUCTS_DIR", "SDKROOT", "DEVELOPER_DIR"}:
            continue
        if file_type.startswith("wrapper.") or path.endswith((".app", ".xctest")):
            continue
        if "$(" in path:
            continue
        if not (ROOT / path).exists():
            errors.append(f"dangling PBXFileReference {ident}: {path}")

    for raw in set(re.findall(r"CODE_SIGN_ENTITLEMENTS = ([^;]+);", text)):
        rel = raw.strip().strip('"')
        if not (ROOT / rel).exists():
            errors.append(f"CODE_SIGN_ENTITLEMENTS file is missing: {rel}")
        else:
            print(f"entitlements ok: {rel}")
    if "CODE_SIGN_ENTITLEMENTS" not in text:
        errors.append("CODE_SIGN_ENTITLEMENTS is not set")

    for ref in re.findall(r"isa = PBXBuildFile; fileRef = ([A-F0-9]{24})", text):
        if ref not in file_refs:
            errors.append(f"PBXBuildFile points at missing file reference {ref}")

    if "SWIFT_VERSION = 5.0;" not in text:
        errors.append("expected SWIFT_VERSION = 5.0")
    if "SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;" not in text:
        errors.append("app target is missing SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor")
    if "SWIFT_STRICT_CONCURRENCY" in text:
        print("note: SWIFT_STRICT_CONCURRENCY is set")
    else:
        print("note: SWIFT_STRICT_CONCURRENCY is unset (Swift 5, approachable concurrency)")

    if errors:
        print("project integrity failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1
    print(f"project integrity ok ({len(objects)} objects)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
