# Failed 3D separation baseline

**Experiment paused. No new detection, parameter tuning or scoring is required for the class wrap-up.**

## Method

The frozen experiment used the same complete 1024×1024×46 field for context, with only grid area A01 intended for evaluation. An earlier 384×384 context attempt was retained separately; context was expanded because foreground reached its artificial boundary. Detector parameters and all 46 slices stayed unchanged.

- Gaussian smoothing: sigma 0.5 µm in XYZ, using 32-bit float intensities.
- Foreground: smoothed raw-intensity units ≥0.8 (not 80% and not display brightness).
- 26-connected 3D components; minimum component volume 1 µm³.
- No watershed, maximum-volume filter, learned detector or pattern classifier.

## Outcome

The saved run produced 41 raw components, seven intersecting A01. **Neither number is a nucleus count.** P002 contained 98.65% of all mask foreground and 97.03% of A01 foreground. Broad fluorescence connected into one field-spanning component through z.

The uploaded diagnostic reports zero disagreements between all 46 saved mask sections and the rule `smoothed >= 0.8`. That establishes implementation of the threshold, not successful separation. Smoothing and threshold choice were not independently varied, so their separate contributions are unresolved. No validated precision, recall or accuracy was produced. No proposals were imported into the research session.

These figures summarize the author's saved diagnostic; research-derived image volumes and per-nucleus records are not distributed or recomputed in this release.

## Dependencies and historical launch

The launcher uses Python 3.11+ and the standard library. The configured Java runtime was JDK 21, with Fiji Java libraries, ImageJ 1.54p, Bio-Formats 8.5.0 and `3D_Objects_Counter-2.0.1.jar`. Its Java source accesses private Counter3D internals via reflection and is tied to that implementation. The configured heap is 4 GB.

`scripts/run_a01_proposals.py` retains a redacted `<FIJI_INSTALLATION>` placeholder; its JAVA path still describes the author's bundled Windows JDK layout. Those constants would need the actual local installation paths before use. The launcher expects the original LIF in `data/` and private checkpoint 37 in `results_field1_full/`, including its exact saved reference state. Historical command: `python scripts/run_a01_proposals.py`. A completed trial is not overwritten.

The proposal viewer is launched in Fiji via Plugins → Macros → Run using `scripts/view_a01_proposals.ijm`, with the original field active and an existing generated run folder. It reads saved proposal/reference tables and shows one magenta proposal box with an optional green manual reference. Its latest GUI appearance has not been author-confirmed.

`scripts/A01MaskDiagnostic.java` reads four existing trial TIFFs and writes a separate diagnostic folder. It assumes this field's dimensions, threshold and component label 2. It is not a general image-analysis utility. Neither the necessary TIFFs nor a launchable example trial is distributed.
