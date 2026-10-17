# PCNA1–GFP annotation in Fiji

A beginner's F3111 coding-class project by Vukan, CEITEC Masaryk University.
Developed with the official OpenAI Codex extension in VS Code, signed in using a paid ChatGPT account. ChatGPT helped with planning, output review and error interpretation.

**Status: manual annotation prototype; automatic detection baseline unsuccessful; development paused.**

## Scientific question

How can identifiable GFP-positive nuclei in an Arabidopsis protoplast confocal z-stack be recorded once and assigned diffuse/non-punctate, punctate or uncertain PCNA patterns?

The observer follows each nucleus through z and assigns one stable ID. A locator ROI on one reference slice and a first/reference/last slice range record its location. **The locator is not a full 3D segmentation.** Eligibility and exclusion reasons are separate from pattern labels. Eligible uncertain cases stay in the primary percentage denominator; exclusions are reported separately.

## What works and what remains incomplete

- Manual entry and editing, stable IDs, duplicate warnings from overlapping XY boxes and z-ranges, checkpoint saving/resuming, ROI ZIPs and TSV exports.
- A full-field version adds a 4×4 viewing grid, saved coverage flags and a separate completion action.
- The author verified pilot save/reopen/resume, editing and rejection of a deliberately triggered duplicate warning in Fiji. One survey grid area was also verified through save/close/reopen/resume.
- The field is still **IN_PROGRESS**. Selected/incomplete annotations are not whole-field percentages. No treated-versus-untreated comparison has been completed.
- A classical 3D baseline generated connected foreground components but failed to separate nuclei. No validated accuracy scores or trained PCNA-pattern classifier exist.

## Repository contents

| File | Purpose |
|---|---|
| `scripts/pcna_field1_pilot.ijm` | Original manual pilot, capped at 15 records |
| `scripts/pcna_field1_survey.ijm` | Dataset-specific survey with coverage tracking |
| `scripts/prepare_field1_full.py` | Validates and copies the original pilot session; not needed to resume an existing survey |
| `scripts/run_a01_proposals.py`, `scripts/A01Proposals.java` | Paused experimental detector |
| `scripts/view_a01_proposals.ijm` | Viewer for already-generated proposal tables |
| `scripts/A01MaskDiagnostic.java` | Diagnostic for the saved trial mask |
| `examples/synthetic_annotations.tsv` | Invented, simplified records illustrating the annotation design |

## Dependencies and running

Manual macros require Fiji with ImageJ **1.54p or later** and Bio-Formats for the original Leica LIF. Python and a separate JDK are not needed for manual annotation.

These scripts deliberately validate a particular private acquisition: one 1024×1024, 46-slice, 8-bit field with the expected series title and LIF filename. The public repository contains **no acquisition, research annotations, checkpoints or research images**. It is a source release, not a turnkey workflow for arbitrary stacks. Do not rename unrelated data to bypass the checks. The synthetic TSV illustrates the design; it cannot be loaded as a saved Fiji session.

For the original-data workflow, see [running instructions](docs/RUNNING.md). The Python/Java experiment and its pinned dependencies are described in [the baseline report](docs/EXPERIMENTAL_BASELINE.md). No pip packages or JAR binaries are distributed.

## Evidence and limitations

See [validation and AI coding lessons](docs/VALIDATION_AND_LESSONS.md). Historical automated checks and author-performed GUI checks are distinguished there. This source package has not been rerun against the private data during packaging.

All samples came from one protoplast isolation split into treated and untreated aliquots. This descriptive pilot has no independent biological replication for a general treatment-effect test. PCNA pattern labels alone do not establish completed repair.

Source code is retained as uploaded except for replacing the detector launcher's personal Fiji installation path with `<FIJI_INSTALLATION>`. Documentation was rewritten for this release; historical notes referring to private outputs are not included. No license has been selected for this initial package.
