{
  description = "Automatically generate CI pipelines from your nix flake checks.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";
    git-hooks.inputs.flake-compat.follows = "";

    actions-nix.url = "github:nialov/actions.nix";
    actions-nix.inputs = {
      nixpkgs.follows = "nixpkgs";
      flake-parts.follows = "flake-parts";
      pre-commit-hooks.follows = "git-hooks";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      flake-parts,
      git-hooks,
      actions-nix,
      self,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { withSystem, flake-parts-lib, ... }:
      let
        inherit (flake-parts-lib) importApply;
        flakeModule = importApply ./nix/flake-module.nix { inherit withSystem; };
      in
      {
        systems = [
          "x86_64-linux"
          "aarch64-linux"
          "x86_64-darwin"
          "aarch64-darwin"
        ];

        imports = [
          git-hooks.flakeModule
          actions-nix.flakeModules.default
          flakeModule
          #./nix/checks.nix # disabled until i can get it to work right
        ];

        flake.actions-nix = {
          defaults = {
            jobs = {
              timeout-minutes = 60;
              runs-on = "ubuntu-latest";
            };
          };
          workflows = {
            ".github/workflows/nix-x86_64-linux.yaml" = (import ./nix/github.nix).makeNixGithubAction {
              flake = self;
              useLix = true;
            };
          };
        };

        flake = {
          inherit flakeModule;
          lib = {
            makeNixGithubAction = (import ./nix/github.nix).makeNixGithubAction;
          };
        };

        perSystem =
          {
            config,
            self',
            inputs',
            pkgs,
            system,
            lib,
            ...
          }:
          {
            devShells.default = pkgs.mkShell {
              packages = with pkgs; [
                nixfmt-rfc-style
                nushell
              ];
            };

            pre-commit.settings.hooks.nixfmt-rfc-style.enable = true;
          };
      }
    );
}
