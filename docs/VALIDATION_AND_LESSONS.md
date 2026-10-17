# Validation and AI coding lessons

## Evidence levels

| Evidence | What it supports | Limit |
|---|---|---|
| Author-performed Fiji pilot trial | Save/reopen/resume restored IDs, ROIs and annotations; editing worked; rejecting a deliberately triggered duplicate warning preserved records | Does not validate every possible interactive path |
| Author-performed one-area survey trial | Grid-area flag, annotations and record count survived save/close/reopen/resume | Remaining 15 areas unreviewed; Finish field not author-validated |
| Historical headless helper checks reported in development notes | Selected z-range, table, denominator and overlap logic | Passing helpers did not establish GUI operation |
| Historical detector checks and saved-mask diagnostic | Component connectivity/export consistency and implementation of the chosen threshold | Does not establish biologically useful detections |
| Source inspection during packaging | Dependencies, dataset-specific guards and publication exclusions | No new Fiji GUI trial, private-data run or end-to-end test was performed |

Test harness files referenced in the development notes were not supplied for this package and are not included. The Java detector contains its existing small synthetic self-test; it was not rerun during packaging. No new automated-validation claim is made.

## Tools and prompting

The official OpenAI Codex extension in VS Code was used while signed in with a paid ChatGPT account. ChatGPT helped plan work, review outputs and interpret errors. GitHub Copilot was not used for this project.

Useful prompting constraints were to preserve source data, store experiments separately, keep stable IDs, allow uncertainty, define exclusions and denominators, and stop after a small pilot for visual review. The central scientific requirement was to count a nucleus once across z rather than count bright profiles in individual slices.

## Difficulties and lessons

- Codex generated an unsupported three-argument `Dialog.addNumber` call; it was corrected to the five-argument form.
- A separate macro syntax error occurred in the survey's status-validation function. It was addressed sufficiently for the one-area GUI trial to run.
- Selecting the LIF file in Macros → Run produced an undefined-variable error from the LIF header. This was a user file-selection mistake, not an AI coding failure.
- Headless helper tests passed while interactive paths still failed. GUI validation needs its own evidence.
- Overlays initially became too cluttered. The viewer was simplified, but its latest appearance remains unconfirmed by the author.
- Too much time went into annotation infrastructure before testing detection feasibility. A smaller early detection trial would have exposed separation problems sooner.
- Executing successfully does not make a detector scientifically useful. Manual references remain useful for evaluating future automation, but this detector did not learn from those examples.

## Stopping point

Manual annotation prototype retained; partial survey retained locally; failed baseline documented. No complete field prevalence or treatment-effect estimate exists. Further annotation and feature development are paused.
