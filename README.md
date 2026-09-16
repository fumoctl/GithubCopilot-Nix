# GithubCopilot-Nix

A Nix Flake packaging the official [GitHub Copilot Desktop application](https://gh.io/copilot-app-linux) and the [GitHub Copilot CLI tool](https://gh.io/copilot-install) for NixOS and Linux systems.

Supports both `x86_64-linux` (amd64) and `aarch64-linux` (arm64) architectures with automated daily updates via GitHub Actions.

---

## Quick Start

You can try the applications immediately without installing them system-wide:

*   **Run the Copilot CLI**:
    ```bash
    nix run github:fumoctl/GithubCopilot-Nix#github-copilot-cli
    # or using the short alias:
    nix run github:fumoctl/GithubCopilot-Nix#copilot-cli
    ```
*   **Run the Desktop GUI**:
    ```bash
    nix run github:fumoctl/GithubCopilot-Nix
    # or explicitly:
    nix run github:fumoctl/GithubCopilot-Nix#github-copilot-desktop
    ```

---

## Installation

### 1. NixOS Configuration
To add these packages to your NixOS configuration, include this flake in your inputs and reference the packages in your modules:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    github-copilot-nix = {
      url = "github:fumoctl/GithubCopilot-Nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, github-copilot-nix, ... }: {
    nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux"; # Or "aarch64-linux"
      modules = [
        ({ pkgs, ... }: {
          # Allow unfree packages since GitHub Copilot is proprietary
          nixpkgs.config.allowUnfree = true;

          environment.systemPackages = [
            github-copilot-nix.packages.${pkgs.system}.github-copilot-desktop
            github-copilot-nix.packages.${pkgs.system}.github-copilot-cli
          ];
        })
      ];
    };
  };
}
```

### 2. Home Manager Configuration
To install for a specific user using Home Manager:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    github-copilot-nix = {
      url = "github:fumoctl/GithubCopilot-Nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, github-copilot-nix, ... }: {
    homeConfigurations.your-user = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        ({ pkgs, ... }: {
          nixpkgs.config.allowUnfree = true;

          home.packages = [
            github-copilot-nix.packages.${pkgs.system}.github-copilot-desktop
            github-copilot-nix.packages.${pkgs.system}.github-copilot-cli
          ];
        })
      ];
    };
  };
}
```

### 3. Overlay Integration
You can use the default overlay to merge these packages directly into your main `pkgs` namespace:

```nix
{
  nixpkgs.overlays = [
    inputs.github-copilot-nix.overlays.default
  ];

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    github-copilot-desktop
    github-copilot-cli
  ];
}
```

---

## Features & Details

* **GitHub Copilot Desktop**:
  - Bundled with Tauri runtime, FHS environment, Wayland and X11 support via `appimageTools`.
  - Installs high-resolution application icons and registers `.desktop` file handling `x-scheme-handler/github-app`, `ghapp`, and `gh` protocols.
  - Executable aliases: `github-copilot-desktop` and `copilot-desktop`.

* **GitHub Copilot CLI**:
  - Wrapped dynamically to load system `glibc` and `libstdc++` cleanly without altering binary payloads or ELF headers.
  - Generates and installs native shell completions automatically for `bash`, `zsh`, and `fish`.
  - Executable aliases: `copilot`, `github-copilot`, and `github-copilot-cli`.

---

## Maintenance & Development

A guide for updating locked versions, testing changes, or modifying package derivations can be found in the **[Developer & Agent Guide (AGENTS.md)](./AGENTS.md)**.
