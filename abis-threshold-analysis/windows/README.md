# Windows x64 offline bundle

## Build with GitHub Actions

Commit `.github/workflows/windows-portable.yml` at the repository root and the complete `abis-threshold-analysis` directory to GitHub. The workflow must be on the default branch to appear as a manually runnable workflow.

1. Open the repository's **Actions** tab.
2. Select **Windows x64 portable ABIS**, then **Run workflow**.
3. Keep R version `4.5.2` for the initial test. The version input refers to CRAN's Windows archive.
4. Leave **include_results** unchecked to package synthetic data. Check it to package the committed `abis-threshold-analysis/data/results.csv`. This only controls artifact contents; it does not prevent committed files from being uploaded to GitHub.
5. When the build succeeds, download the **abis-windows-x64** artifact from the run page. It expires after 14 days.
6. GitHub wraps artifacts in a ZIP. Extract that download to find `abis-windows-x64.zip` and its SHA256 checksum file.

The online build runner downloads R and installs all required Windows binary packages. It runs runtime checks, the business-logic tests, Shiny reactive tests and a local HTTP startup test from a relocated folder with spaces in its path. It then archives the tested bundle. Package versions are recorded in `packages.csv`; subsequent builds may use newer CRAN package versions even with the same R version.

## Try the portable runtime offline

On Windows 10/11 x64 (or a supported x64 Windows Server with a browser):

1. Transfer `abis-windows-x64.zip` to the offline PC.
2. Extract the entire ZIP to a local folder, for example `C:\ABIS-test`. Do not run files inside the ZIP viewer.
3. Disconnect the network if you want to verify offline operation.
4. Open the extracted `ABIS` folder and double-click **Test offline runtime.cmd**. It should report the R version, package count, cases and profiles without downloading anything.
5. Double-click **Start ABIS.cmd**. The dashboard opens in the default browser on `127.0.0.1` using an available port. Keep the console window open. Press Ctrl+C to stop.
6. Replace `app\data\results.csv` with your semicolon-delimited results, or upload them in the app. Restart after replacing the default file. Optional defaults belong in `app\data\thresholds.csv`.

RStudio, Quarto, Rtools, and an installed copy of R are not required for this route. The runtime and package files are all included. Nothing is installed automatically on the offline PC. The PC must permit local executables and localhost browser access. Use a writable local folder; avoid network shares. If the browser does not open automatically, copy the `Listening on http://127.0.0.1:...` URL from the console.

## Try conventional R installation offline

The `installers` folder contains the original `R-4.5.2-win.exe` installer (or the version selected when building). Run it manually on the offline PC. It installs R; no package downloads are required because the ZIP already contains the packages.

To confirm that the installed R also runs the app, open Command Prompt in the extracted `ABIS` folder and run, adjusting the installed path:

```bat
"C:\Program Files\R\R-4.5.2\bin\Rscript.exe" --vanilla "launch.R"
```

If R was installed only for your user, find it under `%LOCALAPPDATA%\Programs\R`. Some installations put Rscript under `bin\x64` instead of `bin`. The launcher selects `library` relative to itself, so installing or downloading packages into the new R installation is unnecessary. Use the exact R version included in the ZIP; the launcher checks this before loading packages. **Start ABIS.cmd** continues to use the portable runtime regardless of other R installations.

## Bundle contents

- `runtime/`: Windows x64 R distribution, including its original documentation and license files.
- `library/`: installed Windows packages and all required dependencies.
- `installers/`: original R installer for a separate offline installation test.
- `app/`: standalone application, input data, documentation and tests.
- `Start ABIS.cmd`, `launch.R`: double-click startup without downloading packages.
- `Test offline runtime.cmd`, `verify_runtime.R`: runtime/package/input checks.
- `R-version.txt`, `packages.csv`: version inventory.

The build verifies relocation and avoids reliance on a developer's installed R or package library. It does not simulate every locked-down Windows configuration or enforce network isolation on the build runner. The actual offline-PC test is still required. If it fails, retain the console error and the workflow build log.

## References

- [CRAN Windows R archive](https://cran.r-project.org/bin/windows/base/old/4.5.2/)
- [R Windows FAQ: running from removable media and installation](https://cran.r-project.org/bin/windows/base/rw-FAQ.html)
- [GitHub: manually running workflows](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)
