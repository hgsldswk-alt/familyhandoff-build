"""Export the named FamilyHandoff XCTest PNG attachments for the App Store listing."""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

LANGUAGES = ("en", "zh-Hans", "zh-Hant")
SCENES = ("01-home", "02-group", "03-entry", "04-handoff", "05-done")
SHOTS = {f"store-{language}-{scene}" for language in LANGUAGES for scene in SCENES}


def name_shots(exported, output):
    output.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((exported / "manifest.json").read_text(encoding="utf-8"))
    mapped = set()
    for test in manifest:
        for attachment in test.get("attachments", []):
            label = attachment.get("suggestedHumanReadableName", "")
            for shot in SHOTS:
                if not re.match(re.escape(shot) + r"(?:[._-]|$)", label):
                    continue
                source = exported / attachment.get("exportedFileName", "")
                if source.parent != exported or not source.is_file() or source.suffix.lower() != ".png":
                    continue
                shutil.copyfile(source, output / f"{shot}.png")
                mapped.add(shot)
                break
    return mapped


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("result", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--from-exported", action="store_true", help="Read an existing attachment manifest.")
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    if args.from_exported:
        mapped = name_shots(args.result, args.output)
    else:
        with tempfile.TemporaryDirectory(dir=args.output.parent) as directory:
            exported = Path(directory) / "attachments"
            subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", str(args.result),
                            "--output-path", str(exported)], check=True)
            mapped = name_shots(exported, args.output)
    if missing := sorted(SHOTS - mapped):
        parser.exit(1, "Missing screenshot attachments: " + ", ".join(missing) + "\n")
    print(f"Exported {len(mapped)} named PNGs to {args.output}")


if __name__ == "__main__":
    main()
