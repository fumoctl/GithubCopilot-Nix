# GitHub Copilot Nix Flake Developer & Agent Guide

This repository contains a Nix flake for packaging the official GitHub Copilot Desktop application and the GitHub Copilot CLI tool. This guide provides context for human developers and AI coding agents on how to maintain, test, update, or modify these packages.

## Repository Layout

*   **[flake.nix](./flake.nix)**: The main entry point defining inputs, multi-system outputs (`packages`, `devShells`), and system overlays.
*   **[pkgs/desktop.nix](./pkgs/desktop.nix)**: Package definition for the desktop AppImage (Tauri).
*   **[pkgs/cli.nix](./pkgs/cli.nix)**: Package definition for the standalone Node SEA CLI binary.
*   **[artifacts/versions.json](./artifacts/versions.json)**: The lock file storing current URLs and pre-fetched SHA256 hashes for all supported platforms.
*   **[scripts/check-version.sh](./scripts/check-version.sh)**: Compares locked versions in `versions.json` with current upstream releases.
*   **[scripts/update-version.sh](./scripts/update-version.sh)**: Automatically updates locked URLs and prefetches hashes for newly discovered releases.
*   **[.github/workflows/](./.github/workflows/)**: GitHub Actions for CI builds, daily auto-updates, releases, and branch pruning.

---

## Binary Fetching & Version Locking

To guarantee reproducible builds and work within Nix's sandboxed environment, this flake does not execute network commands during derivation builds. Instead, it uses a version-locking mechanism:

1. **Metadata Store**: Version URLs and hashes are locked in **[artifacts/versions.json](./artifacts/versions.json)**.
2. **Evaluation**: Inside the Nix derivations, Nix reads the lockfile using `builtins.readFile` and parses the JSON:
   ```nix
   versions = builtins.fromJSON (builtins.readFile ../artifacts/versions.json);
   platformInfo = versions."GitHub Copilot Desktop".${system};
   ```
3. **Fetch Phase**: Nix downloads the asset using standard `fetchurl` with the pinned sha256 hash:
   ```nix
   src = fetchurl {
     inherit (platformInfo) url;
     sha256 = platformInfo.hash;
   };
   ```
4. **Target Sources**:
   - **Desktop AppImages** are downloaded from GitHub Releases of [github/app](https://github.com/github/app/releases) (`GitHub-Copilot-linux-x64.AppImage` and `GitHub-Copilot-linux-arm64.AppImage`).
   - **CLI Binaries** are downloaded from GitHub Releases of [github/copilot-cli](https://github.com/github/copilot-cli/releases) (`copilot-linux-x64.tar.gz` and `copilot-linux-arm64.tar.gz`).

---

## Packaging Strategies

### 1. CLI Packaging (Dynamic Linker Wrapper Strategy)
The GitHub Copilot CLI is a Node.js Single Executable Application (Node SEA).
*   **The Issue**: Standalone Node SEA binaries bundle JavaScript assets and V8 snapshots. Running `autoPatchelfHook` or allowing `strip` to run can alter the binary's internal structure or offsets. Furthermore, running during sandbox build phases requires writable `$HOME` because Node SEA unpacks temporary cached artifacts upon initialization.
*   **The Solution**:
    - We set `dontStrip = true;` and `dontPatchELF = true;`.
    - `cli.nix` copies the untouched binary to `$out/libexec/copilot` and writes a shell wrapper to `$out/bin/copilot`:
      ```bash
      exec ${stdenv.cc.bintools.dynamicLinker} --library-path "${lib.makeLibraryPath [ stdenv.cc.libc stdenv.cc.cc.lib ]}" $out/libexec/copilot "$@"
      ```
    - Shell completions are generated during build using `export HOME=$(mktemp -d); installShellCompletion --cmd copilot ...` for `bash`, `zsh`, and `fish`.
    - Executable symlinks are created for `github-copilot-cli` and `github-copilot`.

### 2. Desktop Packaging (extractType2 + wrapType2 Strategy)
The GitHub Copilot Desktop application is distributed as a Linux AppImage built with Tauri.
*   We use `appimageTools.wrapType2` to handle bubblewrap FHS sandboxing, Wayland support, and dynamic library linking.
*   We use `appimageTools.extractType2` to unpack SquashFS contents during build so we can extract application icons and metadata.
*   Permissions on extracted directories are recursively set to writable (`chmod -R u+w $out/share/icons`) so custom icons and resized variants can be installed into standard hicolor directories.
*   A desktop file is installed with protocol handler associations for `x-scheme-handler/github-app`, `ghapp`, and `gh`.
*   An executable symlink `copilot-desktop` is provided alongside `github-copilot-desktop`.

---

## Update and Maintenance Workflows

### Automated CI/CD & Updates (GitHub Actions)
The repository includes automated GitHub Actions workflows:
* **`.github/workflows/update.yml`**: Runs daily at 07:00 UTC (and manual via `workflow_dispatch`). Checks upstream for new Desktop and CLI releases, updates `artifacts/versions.json`, verifies builds (`nix flake check` & `nix build`), and opens a PR with auto-merge enabled.
* **`.github/workflows/ci.yml`**: Runs on pushes and pull requests to `main` to verify flake checks and package builds.
* **`.github/workflows/release.yml`**: Creates versioned GitHub releases and git tags when updates land on `main`.
* **`.github/workflows/cleanup-branches.yml`**: Automatically cleans up merged `auto-update/*` branches weekly or upon PR merge.

### How to Check for Updates Locally
To check if a newer version of the Desktop or CLI is available upstream:
```bash
nix shell .# -c ./scripts/check-version.sh
```

### How to Update Versions Locally
To fetch the latest versions, download their binaries, compute hashes, and update `artifacts/versions.json`:
```bash
nix shell .# -c ./scripts/update-version.sh
```

### How to Test and Build
To verify changes and compile the packages locally:
```bash
# Stage any new/modified files so Nix can see them
git add -A

# Run checks
nix flake check

# Build the CLI tool
nix build .#github-copilot-cli

# Build the Desktop app
nix build .#github-copilot-desktop
```
