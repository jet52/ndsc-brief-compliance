# Appellate Brief Compliance Checker

Checks appellate brief PDFs for compliance with the North Dakota Rules of Appellate Procedure and produces an HTML compliance report with a recommended action: **Accept**, **Correction Letter**, or **Reject**.

## Quick Start

```bash
# Set up the virtual environment
uv venv && uv pip install -r requirements.txt
source .venv/bin/activate

# Run the web interface
python app.py

# Or use the Claude Code skill: /brief-compliance <path-to-pdf>
```

## Architecture

- **`core/`** — Shared analysis engine (PDF extraction, mechanical checks, semantic checks, report builder)
- **`web/`** — Flask web interface (upload form, report viewer, JSON API)
- **`references/rules/`** — Bundled rule text (N.D.R.App.P. 28, 29, 32, 34; N.D.R.Ct. 3.4)
- **`~/.claude/skills/brief-compliance/`** — Claude Code skill definition and references

## Bundled Rules

The full text of the following rules is bundled in `references/rules/`:

| File | Rule | Subject |
|------|------|---------|
| `rule-28.md` | N.D.R.App.P. 28 | Briefs |
| `rule-29.md` | N.D.R.App.P. 29 | Brief of an Amicus Curiae |
| `rule-32.md` | N.D.R.App.P. 32 | Form of Briefs and Other Documents |
| `rule-34.md` | N.D.R.App.P. 34 | Oral Argument |
| `rule-3.4.md` | N.D.R.Ct. 3.4 | Privacy Protection for Filings |

Rules were last copied from the authoritative source on **2026-02-17**.

## TODO

- [ ] **Rule freshness check**: Add a feature (script or startup check) that compares the bundled rule files against the current versions at ndcourts.gov to detect whether any rules have been amended since the bundled copies were last updated. Candidate URLs:
  - https://www.ndcourts.gov/legal-resources/rules/ndrappp/28
  - https://www.ndcourts.gov/legal-resources/rules/ndrappp/29
  - https://www.ndcourts.gov/legal-resources/rules/ndrappp/32
  - https://www.ndcourts.gov/legal-resources/rules/ndrappp/34
  - https://www.ndcourts.gov/legal-resources/rules/ndrct/3-4
