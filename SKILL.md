---
name: jetbriefcheck
version: 1.0.0-iowa
description: >-
  Triggers when a user uploads a legal brief PDF for compliance review against the
  Iowa Rules of Appellate Procedure. Analyzes the brief and produces a
  compliance report with a recommended action (Accept, Correction Letter, or Reject).
  Works with or without PyMuPDF — falls back to semantic-only checks when PyMuPDF
  is unavailable.
triggers:
  - brief compliance
  - check brief
  - compliance check
  - check appellate brief
  - appellate brief
  - legal brief review
  - brief PDF
  - Iowa rules compliance
---

# Appellate Brief Compliance Checker — Iowa

## What This Skill Does

Analyzes an appellate brief PDF against the Iowa Rules of Appellate Procedure and produces a detailed compliance report. The report includes:

- **Recommendation**: Accept, Correction Letter, or Reject
- **Mechanical checks** (when PyMuPDF is available): Paper size, margins, font size, spacing, word count limits, page numbering
- **Semantic checks** (evaluated by Claude): Section presence and adequacy (TOC, TOA, Statement of Issues, Routing Statement, Argument, Preservation of Error, etc.), party naming conventions, conciseness

This skill is self-contained. All rule text and check definitions are bundled below — no external file reads are required.

## Workflow

The user uploads a PDF via drag-and-drop. Save the uploaded file to a temporary location, then execute the phases below.

### Phase 0: Save the Uploaded PDF

Save the uploaded file to the current working directory, preserving its original filename:

```python
import shutil, os
shutil.copy("<uploaded-file-path>", os.path.basename("<uploaded-file-path>"))
```

All intermediate and output files use the PDF stem in their names to avoid collisions (e.g., `Smith-v-Jones-Apt-Br-intermediate.json`, `Smith-v-Jones-Apt-Br-semantic.json`, `Smith-v-Jones-Apt-Br-compliance.html`).

### Phase 1: Try Mechanical Checks

Run the check script in mechanical-only mode. This makes **no API calls**:

```bash
python3 scripts/check_brief.py "<filename>.pdf" --mechanical-only [--brief-type auto|appellant|appellee|reply|cross_appeal|amicus]
```

- **If the script succeeds**: Capture the intermediate JSON file path from stdout. Continue to **Phase 2 (Full Mode)**.
- **If the script fails** (e.g., `ModuleNotFoundError: No module named 'fitz'` or similar PyMuPDF error): Switch to **Phase 2F (Fallback Mode)**.

---

### Full Mode (PyMuPDF available)

#### Phase 2: Semantic Analysis (Claude)

You (Claude) perform the semantic analysis directly — no API call needed.

1. **Read the intermediate JSON** from Phase 1 to get `brief_type`, `full_text`, `cover_text`, and `mechanical_results`.

2. **Refer to the Bundled Rules section below** for the full text of all applicable rules.

3. **Refer to the Check Definitions section below** — the "Semantic Checks" subsection contains detailed evaluation guidance for each check ID.

4. **Evaluate each applicable semantic check** against the brief text, following the evaluation guidance in the Check Definitions. Filter by brief type first (see "Applicability by Brief Type" in Check Definitions).

5. **Write the semantic results** to `<pdf-stem>-semantic.json` in the current working directory. Use this exact schema:

```json
{
  "semantic_results": [
    {
      "check_id": "SEC-001",
      "name": "Table of Contents Present",
      "rule": "6.903(2)(1)",
      "passed": true,
      "severity": "reject",
      "message": "Table of Contents is present beginning on page 2.",
      "details": null,
      "applicable": true
    }
  ]
}
```

Each semantic check must appear in the results — either as an evaluated result (applicable: true) or as not-applicable (passed: true, applicable: false).

The severity values must be lowercase: `"reject"`, `"correction"`, or `"note"`.

#### Phase 3: Build Report (Script)

Run the report builder to merge results and generate the HTML report:

```bash
python3 scripts/build_report.py \
  --intermediate "<intermediate-json-path>" \
  --semantic "<semantic-json-path>"
```

The script will:
1. Load mechanical results from the intermediate JSON
2. Load semantic results from the semantic JSON
3. Merge into a single results list
4. Compute a recommendation using hard-rule logic (no API call)
5. Generate an HTML report named `<brief-stem>-compliance.html` in the same directory as the original PDF
6. Print a JSON summary to stdout

#### Phase 4: Report to User

After Phase 3, report the findings to the user:
- State the **recommendation** (Accept, Correction Letter, or Reject)
- Summarize any **failed checks** grouped by severity
- Provide the generated HTML report as a downloadable file

---

### Fallback Mode (no PyMuPDF)

When PyMuPDF is not available, Claude performs semantic-only analysis by reading the PDF directly.

#### Phase 2F: Classify Brief Type

Read the uploaded PDF directly. Examine the cover page to determine the brief type:
- **Appellant**: Cover says "Brief of Appellant" or similar
- **Appellee**: Cover says "Brief of Appellee" or similar
- **Reply**: Cover says "Reply Brief" or similar
- **Cross-appeal**: Cover references cross-appeal
- **Amicus**: Cover says "Brief of Amicus Curiae" or similar

If unclear, ask the user.

#### Phase 3F: Evaluate Semantic Checks

Using the full text of the PDF (which Claude can read directly):

1. **Refer to the Bundled Rules section below** for the full text of all applicable rules.
2. **Refer to the Check Definitions section below** for semantic check evaluation guidance.
3. **Evaluate each applicable semantic check** against the brief text, filtering by brief type first (see "Applicability by Brief Type").
4. For each check, record: check ID, name, rule, passed/failed, severity, and a message explaining the finding.

#### Phase 4F: Report to User

Produce a structured text report with:

1. **Header**: Brief filename, brief type, date of analysis
2. **Recommendation**: Apply the recommendation logic (any REJECT-severity failure → Reject; any CORRECTION-severity failure → Correction Letter; otherwise → Accept)
3. **Note**: "Mechanical checks (margins, font size, spacing, word count, paper size) were skipped because PyMuPDF is not available. Only semantic checks were performed."
4. **Findings**: Group results by severity (REJECT, CORRECTION, NOTE), listing failed checks first, then passed checks
5. For each failed check: check ID, name, rule reference, severity, and explanation

---

## Output

- **Full mode**: An HTML compliance report file + JSON summary
- **Fallback mode**: A structured text compliance report (semantic checks only)

## Requirements

- **Full mode**: Python with PyMuPDF installed (`pip install PyMuPDF`)
- **Fallback mode**: No dependencies — Claude reads the PDF and evaluates checks directly
- No API keys needed — semantic analysis is performed by Claude directly

## Known Issues

Based on initial testing (Feb 2026):

### Mechanical Check False Positives

Two mechanical checks have high false-positive rates. When reporting results, note these caveats to the user:

- **FMT-006 (Font Size)**: Measures the minimum font found anywhere in the PDF. Small fonts in page numbers, headers, footers, superscripts, or PDF artifacts trigger REJECT even when the body text is properly 14pt. If this is the sole REJECT trigger and the reported minimum is 10-13pt, flag it as a likely false positive.
- **FMT-005 (Bottom Margin)**: Page numbers at the bottom are measured as content in the margin zone. Nearly always triggers.

### Brief Type Auto-Detection

The `--brief-type auto` flag may return "unknown", especially for appellee briefs. If auto-detection fails, re-run Phase 1 with an explicit `--brief-type` flag based on the cover page text.

### Detection Variants

- **SEC-013 (Certificate of Compliance)**: May miss "CERTIFICATION OF COMPLIANCE" variant.

### Non-Appellate Briefs

Some PDF uploads may be non-appellate briefs (e.g., "Brief in Support of Motion"). These are not subject to Iowa R. App. P. 6.903 and should be skipped. Check the cover page and brief content before proceeding.

### Fallback Mode Limitations

When running in fallback mode (no PyMuPDF), mechanical checks are entirely skipped. The report will not include results for paper size, margins, font size, spacing, word count, or page numbering. Only semantic checks are evaluated.

## References

- [Rules Summary](references/rules-summary.md) — Condensed Iowa Rules of Appellate Procedure
- [Check Definitions](references/check-definitions.md) — Full catalog of checks (also bundled below)
- [Bundled Rules](references/rules/) — Full rule text files (also bundled below)

---

## Check Definitions

All citations verified against the Iowa Rules of Appellate Procedure.

### Mechanical Checks (Deterministic)

These are run by `check_brief.py` — no changes needed here.

| ID | Check | Rule | Failed Severity |
|---|---|---|---|
| FMT-001 | Paper size 8.5 x 11" | 6.903(1)(d) | REJECT |
| FMT-002 | Left margin >= 1" | 6.903(1)(d) | REJECT |
| FMT-003 | Right margin >= 1" | 6.903(1)(d) | CORRECTION |
| FMT-004 | Top margin >= 1" | 6.903(1)(d) | CORRECTION |
| FMT-005 | Bottom margin >= 1" (excluding page numbers) | 6.903(1)(d) | CORRECTION |
| FMT-006 | Font size >= 14pt (proportional) or <= 10.5 cpi (mono) | 6.903(1)(e) | REJECT | ⚠ High false-positive rate — flags small fonts in page numbers, headers, superscripts |
| FMT-008 | Plain roman style | 6.903(1)(f) | NOTE |
| FMT-009 | Double-spaced body text | 6.903(1)(d) | CORRECTION |
| FMT-010 | Footnotes same typeface as text | 6.903(1)(e) | NOTE |
| FMT-011 | Pages numbered consecutively | 6.903(1)(d) | CORRECTION |
| WC-001 | Principal brief <= 14,000 words | 6.903(1)(g)(1) | REJECT |
| WC-002 | Reply brief <= 7,000 words | 6.903(1)(g)(1) | REJECT |
| WC-003 | Amicus brief <= 7,000 words | 6.906(4) | REJECT |
| SEC-013 | Certificate of Compliance present | 6.903(1)(i) | CORRECTION |
| REC-001 | Record citations present (App. pp. ___) format | 6.904(2) | NOTE |

### Semantic Checks (Claude Evaluation)

These checks are evaluated by Claude during the skill workflow. For each check, read the brief's `full_text` and evaluate against the criteria below.

#### Applicability by Brief Type

Before evaluating, filter checks by brief type:
- **All types**: SEC-001 through SEC-004, SEC-013, SEC-019, CNT-001, CNT-002, CNT-003
- **Appellant only**: SEC-006, SEC-006A, SEC-016, SEC-007, SEC-008, SEC-010, SEC-017
- **Appellant + Appellee + Amicus**: SEC-009
- **Appellant + Appellee**: SEC-012, SEC-018
- **Appellant + Appellee + Cross-appeal**: REC-002, REC-003
- **Amicus only**: SEC-014, SEC-015

If a check is not applicable to the brief type, mark it as `"passed": true, "applicable": false` with message "Not applicable to {brief_type} briefs."

#### Evaluation Guidance

For each applicable check, evaluate as follows. Cross-reference the rule text in the Bundled Rules section below for exact rule language.

##### SEC-001 — Table of Contents Present
**Rule**: 6.903(2)(1) — requires a table of contents with page references
**Look for**: A section labeled "Table of Contents", "Contents", or similar near the beginning of the brief (typically after the cover page). The TOC should list the major sections/headings of the brief.
**Pass if**: A TOC section exists with section headings listed.
**Fail if**: No TOC is present at all.
**Severity**: REJECT

##### SEC-002 — TOC Uses Page References
**Rule**: 6.903(2)(1) — requires page references
**Look for**: Whether the TOC references use page numbers. Iowa uses page references (not paragraph references). Check that the TOC entries include page numbers.
**Pass if**: TOC entries include page references.
**Fail if**: TOC entries have no page references.
**Severity**: CORRECTION

##### SEC-003 — Table of Authorities Present
**Rule**: 6.903(2)(2) — requires a table of authorities with page references
**Look for**: A section listing cases, statutes, and other authorities cited in the brief, typically after the TOC.
**Pass if**: A TOA section exists listing authorities.
**Fail if**: No TOA section is found.
**Severity**: REJECT

##### SEC-004 — TOA: Cases Alphabetical, Page Refs
**Rule**: 6.903(2)(2)
**Look for**: (1) Cases listed in alphabetical order. (2) References use page numbers.
**Pass if**: Cases appear alphabetical and references include page numbers.
**Fail if**: Cases are not alphabetical, or references lack page numbers.
**Severity**: CORRECTION

##### SEC-006 — Statement of Issues
**Rule**: 6.903(2)(3) — requires a statement of the issues presented for review
**Look for**: A section titled "Statement of Issues", "Issues Presented", "Issues", or similar, listing the legal questions the court is asked to decide.
**Pass if**: An issues section exists with identifiable legal questions.
**Fail if**: No issues section is found.
**Severity**: REJECT

##### SEC-006A — Issues Include Preservation & Authority Citations
**Rule**: 6.903(2)(3) — each issue must include a preservation citation and the most apposite authority
**Look for**: For each issue, two things: (1) a citation to where the issue was preserved in the district court record, and (2) a citation to the most apposite authority.
**Pass if**: Each issue includes a citation to where it was preserved AND the most apposite authority.
**Fail if**: Issues lack preservation citations or authority citations.
**Note**: This is a distinctive Iowa requirement. Under Iowa R. App. P. 6.903(2)(3), the statement of each issue must include both a preservation citation and the most apposite case authority.
**Severity**: CORRECTION

##### SEC-016 — Routing Statement
**Rule**: 6.903(2)(4) — requires a routing statement
**Look for**: A section labeled "Routing Statement" or similar that indicates whether the case should be retained by the Supreme Court or transferred to the Court of Appeals, referencing the criteria in Iowa R. App. P. 6.1101(2) and (3).
**Pass if**: A routing statement is present.
**Fail if**: No routing statement found. This is an Iowa-specific requirement.
**Note**: The routing statement should reference the criteria for retention by the Supreme Court (6.1101(2): substantial constitutional questions, enunciating or changing legal principles, broad public importance) or transfer to the Court of Appeals (6.1101(3): sufficiency of evidence, application of existing law, sentencing, procedural matters).
**Severity**: REJECT

##### SEC-007 — Statement of the Case
**Rule**: 6.903(2)(5) — requires a statement of the case (nature, proceedings, disposition)
**Look for**: A section describing the procedural history — the nature of the case, what happened in the lower court, and the disposition being appealed.
**Pass if**: A procedural history / statement of the case section exists.
**Fail if**: No such section is found. Note: sometimes combined with Statement of Facts — if procedural history is addressed there, it passes.
**Severity**: CORRECTION

##### SEC-008 — Statement of Facts with Record References
**Rule**: 6.903(2)(6) — requires a statement of facts with record references (Rule 6.904)
**Look for**: (1) A Statement of Facts section. (2) References to the record — look for citations like (App. pp. ___), (Tr. p. ___), (Conf. App. pp. ___), or similar record citations.
**Pass if**: Facts section exists AND contains record references.
**Fail if**: No facts section, OR facts section lacks record references.
**Severity**: REJECT

##### SEC-009 — Argument Section Present
**Rule**: 6.903(2)(7)
**Look for**: A substantive section labeled "Argument" containing legal analysis with citations to authority.
**Pass if**: An argument section with legal analysis is present.
**Fail if**: No argument section found.
**Severity**: REJECT

##### SEC-010 — Standard/Scope of Review Stated
**Rule**: 6.903(2)(7) — requires a scope or standard of review for each issue
**Look for**: Either a standalone "Standard of Review" or "Scope of Review" section, or standard-of-review language within each argument division (e.g., "de novo", "substantial evidence", "abuse of discretion", "for correction of errors at law").
**Pass if**: Standard or scope of review is stated for each argument division.
**Fail if**: No standard of review language found.
**Severity**: CORRECTION

##### SEC-017 — Preservation of Error
**Rule**: 6.903(2)(7) — requires a statement of how each issue was preserved
**Look for**: In the argument section, statements of how each issue was raised and decided in district court, with record references.
**Pass if**: Preservation of error is addressed for each issue.
**Fail if**: No preservation language found.
**Note**: This is a key Iowa requirement — error preservation must appear in the argument for each issue. Under Iowa R. App. P. 6.903(2)(7), the argument must contain "a statement of how the issue was preserved for appellate review, with references to the places in the record where the issue was raised and decided."
**Severity**: CORRECTION

##### SEC-012 — Conclusion with Precise Relief
**Rule**: 6.903(2)(8) — requires a conclusion stating the precise relief sought
**Look for**: A "Conclusion" section that states what the party wants the court to do (e.g., "reverse and remand", "affirm the judgment", "reverse with instructions to dismiss").
**Pass if**: Conclusion exists and states specific relief sought.
**Fail if**: No conclusion, or conclusion is vague (e.g., "For the above reasons, the Court should rule in Appellant's favor" without specifying the relief).
**Severity**: CORRECTION

##### SEC-018 — Request for Oral Argument
**Rule**: 6.903(2)(9) — requires a request for oral argument or waiver
**Look for**: A statement in the brief that either requests oral argument or states that oral argument is not requested (waived).
**Pass if**: Brief includes a request for oral argument or states argument is waived/not requested.
**Fail if**: Neither a request nor a waiver is present.
**Note**: Under Iowa R. App. P. 6.907(1), if no request for oral argument is made, the case may be submitted without argument. Including this in the brief is expected per Rule 6.903(2)(9).
**Severity**: NOTE

##### SEC-013 — Certificate of Compliance
**Rule**: 6.903(1)(i) — requires Form 7 certificate
**Look for**: A Certificate of Compliance section that certifies the typeface (font name, point size) and word count or line count, conforming to Form 7 (Iowa R. App. P. 6.1401).
**Pass if**: A certificate of compliance section is present.
**Fail if**: Missing.
**Severity**: CORRECTION

##### SEC-019 — Certificate of Filing/Service
**Rule**: 6.903(2)(11) — requires a certificate of filing and service
**Look for**: A certificate stating that the brief has been filed and served, typically noting electronic filing through EDMS.
**Pass if**: A certificate of filing/service is present.
**Fail if**: Missing.
**Severity**: CORRECTION

##### SEC-014 — Amicus: Identity/Interest Statement
**Rule**: 6.906(3) — requires identity and interest statement
**Look for**: A section identifying who the amicus is and why they have an interest in the case.
**Pass if**: Identity and interest statement is present.
**Fail if**: Missing.
**Severity**: REJECT

##### SEC-015 — Amicus: Disclosure Statement
**Rule**: 6.906(3) — disclosure of authorship and funding
**Look for**: A statement disclosing whether a party or party's counsel authored the brief and whether anyone other than the amicus or its counsel made a monetary contribution to the preparation or submission of the brief.
**Pass if**: Disclosure statement present.
**Fail if**: Missing.
**Severity**: CORRECTION

##### CNT-001 — Party References Use Actual Names
**Rule**: 6.904(1) — counsel should use parties' actual names
**Look for**: Whether the brief predominantly uses actual party names (e.g., "Smith", "Johnson", "the City") versus procedural labels ("Appellant", "Appellee").
**Pass if**: The brief primarily uses actual names or lower-court designations. Occasional use of "Appellant"/"Appellee" for clarity is acceptable.
**Fail if**: The brief predominantly uses "Appellant"/"Appellee" instead of names.
**Note**: Rule 6.904(1) uses "should" — this is a preference, not an absolute command. Be somewhat lenient.
**Severity**: CORRECTION

##### CNT-002 — Brief Is Concise, No Irrelevant Matter
**Rule**: 6.903 — brief must be concise
**Look for**: Whether the brief contains obviously irrelevant, scandalous, or excessively repetitive material.
**Pass if**: The brief appears focused and relevant. Most briefs pass this check.
**Fail if**: The brief contains clearly irrelevant, scandalous, or grossly repetitive material.
**Note**: Apply a generous standard — only fail for egregious cases.
**Severity**: NOTE

##### CNT-003 — Statutes/Rules in Brief or Addendum
**Rule**: 6.904(3) — relevant statutes/rules must be set out in the brief or addendum
**Look for**: If the brief discusses statutes, rules, or regulations, whether the relevant text is included in the brief body or in an addendum.
**Pass if**: Relevant statutes/rules are quoted or an addendum contains them, OR the brief does not involve statutory interpretation requiring the text.
**Fail if**: The brief argues about specific statutory/regulatory language that is neither quoted in the brief nor included in an addendum.
**Severity**: NOTE

##### REC-002 — Record Citation Format
**Rule**: 6.904(2) — record citations should use (App. pp. ___) or (Tr. p. ___) format
**Look for**: Whether record references consistently use the appendix/transcript citation format prescribed by Iowa R. App. P. 6.904(2).
**Pass if**: Record citations consistently use the (App. pp. ___) or (Tr. p. ___) format, or a close variant.
**Fail if**: The brief uses non-standard formats for most record citations (e.g., bare page numbers, "Doc." references, or ND-style (R#:#) format).
**Note**: If the brief uses a mix of formats, note which are non-compliant. Iowa uses appendix-based record citation, not index-based.
**Severity**: CORRECTION

##### REC-003 — Record Citations Identify Items
**Rule**: 6.904(2) — record references should include context identifying the item
**Look for**: Whether record citations provide enough context to identify what is being cited, either in the surrounding text or in the citation itself.
**Pass if**: Record citations are generally accompanied by identifying context (e.g., "the district court's order (App. pp. 45-46)", "Dr. Smith's testimony (Tr. pp. 112-13)").
**Fail if**: Many citations are bare references with no surrounding context about what the item is.
**Note**: Be somewhat lenient — if the context is clear from the surrounding sentence, the citation need not repeat the identification.
**Severity**: NOTE

### Recommendation Logic

1. **Hard-rule pass**: Any REJECT-severity failure → REJECT. Any CORRECTION-severity failure → CORRECTION_LETTER. Otherwise → ACCEPT.
2. In the skill workflow, recommendation is computed by `build_report.py` using hard-rule logic only (no API call). In fallback mode, Claude applies this same logic directly.

---

## Bundled Rules

### Iowa R. App. P. 6.903 — Briefs

**Note:** This is a summary of the key provisions. The authoritative text is available at
https://www.legis.iowa.gov/law/courtRules/courtRulesListings (Chapter 6, Division IX).

#### 6.903(1) — Form of Briefs

**(a) Filing.** Briefs must be filed electronically through EDMS in accordance with Iowa R. Elec. P. 16.302.

**(b) Cover Page.** The front cover of a brief must contain:
- The name of the court (Supreme Court of Iowa or Court of Appeals of Iowa)
- The case number
- The title of the case
- The nature of the proceeding and the name of the court or agency below
- The title of the brief, identifying the party for whom the brief is filed
- The name, address, telephone number, email address, and attorney number of counsel

**(c) Binding and Reproduction.** If a paper copy is required, the brief must be bound at the left in a secure manner. The text must yield a clear black image on white paper. Only one side of the paper may be used.

**(d) Paper Size, Margins, and Line Spacing.** The brief must be on 8½ by 11 inch paper. Margins must be at least one inch on all four sides. The text must be double-spaced, except that headings, quotations, and footnotes may be single-spaced. Pages must be numbered consecutively.

**(e) Typeface.** A brief must use either a proportionally spaced or monospaced typeface:
- **Proportionally spaced typeface**: Must be a serif typeface of 14 points or more (e.g., Times New Roman, Century Schoolbook, Georgia, Bookman Old Style, Garamond, Book Antiqua).
- **Monospaced typeface**: Must be no more than 10½ characters per inch (e.g., Courier New).

**(f) Type Styles.** A brief must be set in a plain, roman style, although italics or boldface may be used for emphasis. Case names must be italicized or underlined.

**(g) Type-Volume Limitation.**
- **(1) Proportionally spaced typeface**: A principal brief (appellant or appellee) must not exceed **14,000 words**. A reply brief must not exceed **7,000 words**. An amicus curiae brief must not exceed **7,000 words**.
- **(2) Monospaced typeface**: A principal brief must not exceed **1,300 lines of text**. A reply brief must not exceed **650 lines of text**. An amicus curiae brief must not exceed **650 lines**.
- The word or line count excludes the table of contents, table of authorities, signature block, certificate of compliance, certificate of filing, and any attached court order.

**(h) Certificate of Cost.** When a brief incurs printing costs, a certificate of cost must be attached.

**(i) Certificate of Compliance.**
- **(1)** A brief prepared in a proportionally spaced typeface must include a certificate stating the typeface name, point size, and word count.
- **(2)** A brief prepared in a monospaced typeface must include a certificate stating the typeface name, point size, and number of lines of text.
- **(3)** The word or line count must be calculated by the word-processing software used to prepare the brief.
- **(4)** The certificate must conform to Form 7 (Iowa R. App. P. 6.1401).

#### 6.903(2) — Appellant's Brief

The appellant's brief must contain, under appropriate headings and in the order indicated:

> (1) **Table of contents** — with page references.

> (2) **Table of authorities** — cases (alphabetically arranged), statutes, and other authorities, with page references.

> (3) **Statement of the issues presented for review** — each issue must include a citation to where the issue was preserved in the district court record and a citation to the most apposite authority.

> (4) **Routing statement** — a concise statement regarding whether the case should be retained by the supreme court or transferred to the court of appeals, referencing the criteria in Iowa R. App. P. 6.1101(2) and (3).

> (5) **Statement of the case** — the nature of the case, the course of proceedings, and the disposition in the court or agency below.

> (6) **Statement of the facts** — relevant to the issues presented for review, with appropriate references to the record (Iowa R. App. P. 6.904).

> (7) **Argument** — divided under a separate heading for each issue. Each issue must contain:
>
> > (A) A statement of the scope or standard of review, with supporting authorities.
> >
> > (B) A statement of how the issue was preserved for appellate review, with references to the places in the record where the issue was raised and decided.
> >
> > (C) The party's contentions and the reasons for them, with citations to authorities and the record.

> (8) **Conclusion** — a short conclusion stating the precise relief sought.

> (9) **Request for oral argument** — or a statement that oral argument is not requested.

> (10) **Certificate of compliance** — with typeface requirements and type-volume limitation (Form 7).

> (11) **Certificate of filing** — stating that the brief has been filed and served electronically.

> (12) **Attached judgment** — a file-stamped copy of the written judgment(s), order(s), or decision(s) being appealed.

#### 6.903(3) — Appellee's Brief

The appellee's brief must conform to subdivision (2), except that the following need not appear unless the appellee is dissatisfied with the appellant's statement:
- Statement of the issues
- Routing statement
- Statement of the case
- Statement of the facts

#### 6.903(4) — Reply Brief

A reply brief is limited to a response to new matter raised in the appellee's brief. It must contain a table of contents with page references and a table of authorities with page references.

### Iowa R. App. P. 6.904 — References in Briefs

#### 6.904(1) — References to Parties.
Counsel should refer to the parties by their names or designations used in the district court or agency, not by procedural labels such as "Appellant" or "Appellee."

#### 6.904(2) — References to the Record.
References to the record must cite the specific volume and page of the appendix where the material appears. The preferred citation format is:
- **(App. pp. ___)** for references to the appendix
- **(Tr. p. ___)** for references to the trial transcript
- **(Conf. App. pp. ___)** for references to the confidential appendix

#### 6.904(3) — Reproduction of Statutes, Rules, and Regulations.
If the court's determination requires the study of statutes, rules, regulations, or similar materials, the relevant parts must be set out in the brief or in an addendum.

#### 6.904(4) — Transcripts of Oral Rulings.
Transcripts of oral rulings may not be attached to the brief. Parties must cite to the relevant transcript in their brief using appropriate record references.

### Iowa R. App. P. 6.906 — Brief of an Amicus Curiae

#### 6.906(1) — When Permitted.
An amicus curiae may file a brief only by leave of court or at the court's request.

#### 6.906(2) — Motion for Leave.
A motion for leave to file an amicus brief must be accompanied by the proposed brief. The motion must state:
- The movant's interest in the case
- The reasons why an amicus brief is desirable and relevant to the disposition of the case

#### 6.906(3) — Contents and Form.
An amicus brief must comply with Iowa R. App. P. 6.903(1) (form of briefs). The cover must identify the party supported, if any, and whether the brief supports affirmance or reversal. An amicus brief must include:

1. A **table of contents** with page references.
2. A **table of authorities** with page references.
3. A concise **statement of the identity** of the amicus curiae and its **interest in the case**.
4. A **disclosure statement** indicating whether:
   - A party's counsel authored the brief in whole or in part;
   - A party or party's counsel contributed money intended to fund preparing or submitting the brief;
   - Any other person contributed money intended to fund preparing or submitting the brief (and if so, identifying each such person).
5. An **argument**, which may be preceded by a summary.

#### 6.906(4) — Length.
An amicus brief must not exceed **7,000 words** (proportionally spaced) or **650 lines** (monospaced), which is one-half the maximum length authorized for a party's principal brief.

#### 6.906(5) — Time for Filing.
An amicus brief must be filed within the time allowed for filing the principal brief of the party being supported. An amicus that does not support either party must file within the time for the appellant's principal brief.

#### 6.906(6) — Reply Brief.
An amicus curiae may not file a reply brief except by leave of court.

#### 6.906(7) — Oral Argument.
An amicus curiae may participate in oral argument only with the court's permission.

### Iowa R. App. P. 6.907 — Oral Argument

#### 6.907(1) — Request for Oral Argument.
A party desiring oral argument must include a request in the party's brief in accordance with Iowa R. App. P. 6.903(2)(9) (appellant) or 6.903(3) (appellee).

#### 6.907(2) — Submission Without Argument.
A case will be submitted without oral argument unless a party requests argument in the brief. The court may, in its discretion, schedule or decline oral argument regardless of whether it has been requested.

#### 6.907(3) — Time Allowed.
Each side is ordinarily allowed 20 minutes for oral argument. The court may extend or limit the time for argument.

#### 6.907(4) — Cross-Appeals and Separate Appeals.
A cross-appeal or separate appeal will be argued at the same time as the initial appeal unless the court directs otherwise.

### Iowa R. App. P. 6.1101 — Routing of Cases

#### 6.1101(1) — General.
All cases are filed with the supreme court. Cases may be retained by the supreme court or transferred to the court of appeals. Cases not retained by the supreme court will be transferred to the court of appeals.

#### 6.1101(2) — Cases Retained by the Supreme Court.
The supreme court ordinarily retains cases involving:
- Substantial constitutional questions regarding the validity or construction of a statute, ordinance, or court rule.
- Substantial issues of enunciating or changing legal principles.
- Fundamental and urgent issues of broad public importance requiring prompt resolution by the supreme court.

#### 6.1101(3) — Cases Transferred to the Court of Appeals.
The court of appeals ordinarily receives cases involving:
- Questions of sufficiency of the evidence (including review of findings of fact in equity cases).
- Questions involving existing legal principles.
- Sentencing in criminal cases.
- Procedural matters.
- Cases involving application of existing law to the facts.

#### 6.1101(4) — Transfer Back.
The court of appeals may, on its own motion or on the motion of a party, transfer a case to the supreme court.

### Iowa Confidential Filings — Iowa R. Elec. P. 16.601 & Iowa Code Ch. 232

Iowa court rules and statutes require that certain personal information be redacted or filed confidentially.

#### Information That Must Be Redacted or Protected:
- **Social Security numbers** — must be redacted to show only the last four digits.
- **Financial account numbers** — must be redacted to show only the last four digits.
- **Birth dates** — in certain cases, should show only the year.
- **Names of minors** — in juvenile cases and certain family law matters, minors should be identified by initials only, per Iowa Code chapter 232 and related provisions.

#### Confidential Appendix:
Iowa R. App. P. 6.905 provides for a **confidential appendix** that is filed separately from the main appendix and is not publicly accessible. Materials that are confidential under statute or court order must be placed in the confidential appendix and referenced as **(Conf. App. pp. ___)**.

#### Juvenile Proceedings:
Iowa Code chapter 232 governs confidentiality of juvenile proceedings. Records in juvenile cases are generally confidential and not open to public inspection.

#### Sealed Records:
The court may order that particular documents or portions of the record be sealed. Motions to seal must state the grounds for sealing.

#### Responsibility:
The filing party is responsible for ensuring that confidential information is properly redacted or filed in the confidential appendix.
