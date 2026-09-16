{
  description = "GitHub Copilot Desktop and CLI tools (Nix package)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in {
        packages = {
          default = pkgs.callPackage ./pkgs/desktop.nix {};
          github-copilot-desktop = pkgs.callPackage ./pkgs/desktop.nix {};
          copilot-desktop = pkgs.callPackage ./pkgs/desktop.nix {};
          github-copilot-cli = pkgs.callPackage ./pkgs/cli.nix {};
          copilot-cli = pkgs.callPackage ./pkgs/cli.nix {};
        };

        # Development shell for working on this flake
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nix
            git
            curl
            jq
          ];

          shellHook = ''
            echo "GitHub Copilot development environment"
            echo "Available commands:"
            echo "  ./scripts/check-version.sh  - Check current vs latest version"
            echo "  ./scripts/update-version.sh - Update to latest version"
          '';
        };
      }
    )
    // {
      # Overlay for easy integration into NixOS configurations
      overlays.default = final: prev: {
        github-copilot-desktop = final.callPackage ./pkgs/desktop.nix {};
        copilot-desktop = final.github-copilot-desktop;
        github-copilot-cli = final.callPackage ./pkgs/cli.nix {};
        copilot-cli = final.github-copilot-cli;
      };
    };
}
