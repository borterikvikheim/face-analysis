# ABIS threshold analysis

Standalone R/Shiny tool for expert assessment of M40 face-search thresholds. It uses no code or runtime dependencies from the existing M30/M40 project. It calculates consequences; final threshold selection requires domain assessment.

## Start

For a double-click Windows x64 runtime and an offline R installer, see [Windows bundle instructions](windows/README.md). The GitHub Actions workflow builds and tests the ZIP on Windows; it requires no local Windows build tools.

From this directory, install missing packages once:

```r
install.packages(c("shiny", "dplyr", "readr", "tidyr", "ggplot2", "DT"))
```

Run:

```sh
Rscript -e 'shiny::runApp(launch.browser = TRUE)'
```

Business-logic tests use base R, not testthat:

```sh
Rscript tests/run_tests.R
Rscript tests/test_shiny.R
```

The app reads `data/results.csv` initially. Replace it for future analyses or upload a semicolon-delimited CSV in the sidebar. Select a profile, then move Weak, Strong or Match. Changing a threshold updates the summary, errors, plots and cases. Strong affects error analysis but does not appear in the current operational flow rules. Choose a table row and use its apply button to transfer candidate thresholds to the simulation.

## Input

Required header:

```text
RowId;ThresholdProfileName;ExpectedFound;ExpectedRank;ExpectedScore;BestNonMatchRank;BestNonMatchScore;ScoreDrop;CandidateCount
```

`ExpectedFound` accepts TRUE/FALSE (case insensitive) or 1/0. Empty numeric fields and `NA` are missing. RowId remains text to preserve leading zeros. Only the listed fields are retained; extra source columns are not exposed. Profiles are discovered dynamically. Duplicate RowIds within a profile, inconsistent ranks, missing scores, and unexpected supplied scores for not-found cases produce visible validation notices. Malformed CSV, missing identifiers and invalid numeric/logical values block analysis.

- ExpectedScore (SP): genuine score against the known same identity; not a probability.
- BestNonMatchScore (SN): highest score against a different identity; not a probability.
- ExpectedFound: whether the known identity was returned. FALSE is a separate search outcome, not a score-based FN.
- ExpectedRank: position of the known identity in returned candidates.
- Weak: lower boundary used in case flow and genuine-miss analysis.
- Strong: decision-support threshold for separation of genuine and non-match scores.
- Match: upper boundary used in case flow.

No synthetic SP is assigned when ExpectedFound is FALSE. The original input score remains visible for inspection if anomalously supplied, but genuine metrics, boundary distances and flow rules treat it as unavailable. Missing scores are never changed to zero.

## Optional defaults and configuration

Create `data/thresholds.csv` with one row per profile:

```text
ThresholdName;Weak;Strong;Match
ExampleProfile;600;750;900
```

This file supplies initial values only. Absent profiles use generic values at 60%, 75%, and 90% of the configured score range (positions on a numeric scale, not biometric probabilities). The sidebar states the source. Invalid configuration is reported; values outside the score range use generic defaults.

Score range defaults to 0 through 1000. Configure before starting:

```sh
Rscript -e 'options(abis.score_range = c(0, 1200)); shiny::runApp(launch.browser = TRUE)'
```

Controls enforce integer Weak <= Strong <= Match. Moving a control beyond another moves the other values to maintain order. For explicit experimental override, set `options(abis.enforce_order = FALSE)` before starting. Production defaults are not embedded in the calculations.

## Operational flow

`R/flow.R::classify_flow()` centralizes the inclusive equality rules:

- Archive: SP >= Match AND SN <= Weak.
- IdentityClaim: (SP <= Weak AND SN <= Weak) OR (SP >= Match AND SN >= Match) OR (SP <= Weak AND SN >= Match).
- Verification: both Archive and IdentityClaim can be ruled out.
- Undetermined: available scores cannot establish one of these outcomes.

Missing SP does not necessarily imply Undetermined: with Weak < SN < Match, all named positive rules are false regardless of SP, so Verification is determinable. With missing SN and Weak < SP < Match, Verification is also determinable. Other unavailable-score cases remain Undetermined. This partial-information interpretation needs domain confirmation.

**Boundary ambiguity:** when Weak = Match, positive rules can overlap. Archive takes precedence. Confirm this precedence or require strictly separated thresholds if the specification changes. Strong equality has no flow effect. All comparisons live in one function so the working rule model can be changed.

## Biometric indicators and candidate analyses

For any threshold T: FP = count(SN >= T); FN = count(SP < T) using available genuine scores only. Weak and Strong indicators remain separate. Counts include equality for FP and exclude equality for FN. Each indicator reports its available denominator. Not-found searches are separately counted. Missing SN is excluded from FP counts. These are case-level best-non-match exceedances, not a candidate-level or population false-match rate.

Strong analysis evaluates every integer in the configured range, sorting by TotalErrors = FP + FN, then abs(FP - FN), then Strong for deterministic ties. The first row is a best calculated candidate according to this criterion, not an objectively correct threshold. Two errors may occur in the same case. No implicit score is used for missing SP. With no genuine scores, FN counts alone do not establish acceptable performance.

Match/Weak analysis evaluates configurable fixed-width windows: defaults width 150, step 10. It reports all four flow counts and percentages relative to all selected-profile cases. Sort columns to investigate tradeoffs; no objective winner is chosen. The generic simulator accepts arbitrary Weak/Strong/Match values and does not depend on window parameters.

Strong counts use sorted-score lookup; window calculations use vectorized flow classification per scenario. Both candidate tables are cached per uploaded file/profile/parameters and do not recalculate for each slider movement. Uploading large files may require increasing Shiny's upload limit via `options(shiny.maxRequestSize = 100 * 1024^2)` before starting.

## Inspection and downloads

Cases can be filtered by flow, any selected error indicator, table column filters, text search and proximity to any current threshold. Signed distances are score minus threshold. Missing distances remain missing. Downloads use semicolons and blank missing values; Strong/windows downloads include the complete candidate table, and case downloads respect sidebar and table filters. RowId is retained without additional identifying fields.

## Limitations requiring assessment

This is aggregated returned-candidate data, not a complete score population. Candidate truncation and missing expected hits limit genuine analysis. Profile comparisons depend on test-set composition and size. Error counts have no confidence intervals and do not establish operational risk. The flow model is a working specification. Boundary precedence, partial-information Verification, permitted threshold ordering, and the relative costs of FP/FN and case outcomes need domain confirmation. Validate any chosen threshold on independent data before deployment.
