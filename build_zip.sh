#!/usr/bin/env bash
# Rebuild jetbriefcheck.zip from the current source files.
# Usage: ./build_zip.sh
#
# Included in the ZIP:
#   SKILL.md            – Skill definition (triggers, workflow, bundled rule text)
#   version.json        – Version metadata and rule-freshness dates
#   requirements.txt    – Python dependencies (PyMuPDF, anthropic)
#   README.md           – Installation and usage guide
#   core/               – Python engine (models, checks, report builder)
#   scripts/            – CLI entry points (check_brief.py, build_report.py)
#   references/         – Rule markdown files loaded at runtime by checks_semantic.py

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

# ---- Verify required source files exist before building ----
REQUIRED_FILES=(
    "SKILL.md"
    "version.json"
    "requirements.txt"
    "README.md"
    "core/__init__.py"
    "core/models.py"
    "core/constants.py"
    "core/brief_classifier.py"
    "core/pdf_extract.py"
    "core/checks_mechanical.py"
    "core/checks_semantic.py"
    "core/recommender.py"
    "core/report_builder.py"
    "core/version_check.py"
    "scripts/check_brief.py"
    "scripts/build_report.py"
    "references/check-definitions.md"
    "references/rules-summary.md"
    "references/rules/rule-6.903.md"
    "references/rules/rule-6.904.md"
    "references/rules/rule-6.906.md"
    "references/rules/rule-6.907.md"
    "references/rules/rule-6.1101.md"
    "references/rules/rule-1.422.md"
)

missing=0
for f in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$REPO_ROOT/$f" ]; then
        echo "ERROR: Missing required file: $f" >&2
        missing=1
    fi
done
if [ "$missing" -eq 1 ]; then
    echo "Aborting build — fix missing files above." >&2
    exit 1
fi

# ---- Build the ZIP ----
TMP=$(mktemp -d)
DEST="$TMP/jetbriefcheck"

mkdir -p "$DEST"

# Core engine, scripts, and rule references (full directories)
cp -r "$REPO_ROOT/core"       "$DEST/core"
cp -r "$REPO_ROOT/scripts"    "$DEST/scripts"
cp -r "$REPO_ROOT/references" "$DEST/references"

# Top-level files
cp "$REPO_ROOT/SKILL.md"          "$DEST/SKILL.md"
cp "$REPO_ROOT/version.json"      "$DEST/version.json"
cp "$REPO_ROOT/requirements.txt"  "$DEST/requirements.txt"
cp "$REPO_ROOT/README.md"         "$DEST/README.md"

# Clean build artifacts
find "$DEST" -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
find "$DEST" -name '*.pyc' -delete 2>/dev/null || true

# Build ZIP
(cd "$TMP" && zip -r "$REPO_ROOT/jetbriefcheck.zip" jetbriefcheck/)

rm -rf "$TMP"

echo "Built: $REPO_ROOT/jetbriefcheck.zip"
echo "Contents:"
unzip -l "$REPO_ROOT/jetbriefcheck.zip" | tail -1
