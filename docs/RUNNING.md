# Running the original-data workflow

This is a frozen, dataset-specific prototype. The original acquisition and saved sessions are private and are not included. Development and further annotation are paused. These instructions document the existing workflow, not a request to generate new results.

## Manual pilot

1. Start Fiji. The macro requires ImageJ 1.54p or later.
2. Open the original `vukan protoplasts.lif` through Bio-Formats and choose `protoplasts 2h post irradiation image 1`. Use the single-channel 8-bit 1024×1024 stack with 46 z-slices and one timepoint. Do not flatten or project it.
3. Save any unrelated ROI Manager work and clear ROI Manager.
4. Use **Plugins → Macros → Run**, selecting `scripts/pcna_field1_pilot.ijm`. Select the macro here, not the LIF.
5. When the macro separately asks for the source LIF, select the original acquisition. Choose New session only in an empty dedicated session folder; otherwise choose Resume saved session and select its top-level folder containing `latest.txt`.
6. Use the macro menu to add or edit a stable ID. Follow the nucleus through z, draw its locator on the reference slice, then enter first/reference/last z, pattern, eligibility and reasons. Uncertain or excluded records require a reason.
7. Save and stop before closing. Do not add, delete or rename ROI Manager entries outside the tool. The pilot permits at most 15 records and always exports incomplete results.

Resume requires the same source path and file size, image dimensions/calibration, matching ROI names and table geometry. Retain the whole session directory, including prior checkpoints. Do not move or manually edit saved session files to make a check pass.

## Existing full-field survey

Open the original field and clear ROI Manager as above, then run `scripts/pcna_field1_survey.ijm`. Select the existing prepared `results_field1_full` session when prompted. This macro resumes a prepared survey; it does not create an empty survey from scratch.

The preparation script requires Python 3.11+ (standard library only): `python scripts/prepare_field1_full.py`. It expects `results/` to contain the validated original 15-record pilot, including its specific saved boundary decisions. It refuses an existing destination. **Do not rerun it on an existing survey or use it to overwrite saved work.** It is not needed to resume the author's current survey.

Coverage flags are observer attestations, not proof that no nuclei were missed. Finish field requires all 16 areas and final confirmations; it was not GUI-validated by the author. Current work remains IN_PROGRESS.

## Checkpoints and exports

Each committed checkpoint contains session metadata, annotation/count TSVs, ROI ZIPs when records exist, and a READY marker. Survey checkpoints also contain coverage and survey state. The `latest.txt` pointer is updated last. Keep files from each checkpoint together.

Primary denominator: eligible diffuse + eligible punctate + eligible uncertain. Exclusions are separate. The additional confident-only punctate percentage uses diffuse + punctate and has a different denominator. Incomplete exports must not be presented as whole-field prevalence.

## Public examples

`examples/synthetic_annotations.tsv` contains fabricated teaching records and a simplified schema. It is readable in a spreadsheet or text editor. It is not compatible with the checkpoint loader and is not a biological result or an interactive macro demo.
