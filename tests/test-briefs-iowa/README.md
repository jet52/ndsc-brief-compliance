# Iowa Test Briefs

Download these Iowa appellate briefs and place them in this directory for testing:

1. **poling-appellant-25-0064.pdf** — Appellant brief, teacher termination appeal
   https://www.iowacourts.gov/static/media/cms/Appellant_65A804F7F38F0.PDF

2. **1000friends-appellee-23-1199.pdf** — Appellee brief, municipal liability
   https://iowaappeals.com/wp-content/uploads/2024/07/1000-Appellee-Brief.pdf

3. **puente-appellant-22-1619.pdf** — Appellant brief, district court challenge
   https://iowaappeals.com/wp-content/uploads/2024/03/Appellant-Brief-2.pdf

## Running Tests

Once PDFs are in this directory, run from the project root:

```bash
# Mechanical-only check (no API key needed)
python3 scripts/check_brief.py tests/test-briefs-iowa/poling-appellant-25-0064.pdf --mechanical-only --brief-type appellant

# Full check (needs ANTHROPIC_API_KEY)
python3 scripts/check_brief.py tests/test-briefs-iowa/poling-appellant-25-0064.pdf --brief-type appellant
```
