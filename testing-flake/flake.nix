{
  description = "Flake for testing nix-auto-ci";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";
    git-hooks.inputs.flake-compat.follows = "";
    git-hooks.inputs.gitignore.follows = "";

    actions-nix.url = "github:nialov/actions.nix";
    actions-nix.inputs = {
      nixpkgs.follows = "nixpkgs";
      flake-parts.follows = "flake-parts";
      pre-commit-hooks.follows = "git-hooks";
    };

    nix-auto-ci.url = "path:..";
    nix-auto-ci.inputs = {
      nixpkgs.follows = "nixpkgs";
      flake-parts.follows = "flake-parts";
      git-hooks.follows = "git-hooks";
      actions-nix.follows = "actions-nix";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      flake-parts,
      actions-nix,
      self,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {

      systems = [
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      imports = [
        inputs.git-hooks.flakeModule
        inputs.actions-nix.flakeModules.default
        inputs.nix-auto-ci.flakeModule
      ];

      flake.actions-nix = {
        pre-commit.enable = false;
        defaults = {
          jobs = {
            timeout-minutes = 60;
            runs-on = "ubuntu-latest";
          };
        };
        workflows = {
          ".github/workflows/main.yaml" = inputs.nix-auto-ci.makeNixGithubAction {
            flake = self;
            useLix = true;
          };
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
          checks = {
            check-a = pkgs.stdenv.mkDerivation {
              name = "check-a";
              src = ./.;
              doCheck = true;
              dontBuild = true;
              nativeBuildInputs = [ pkgs.bashhh ];
              checkPhase = ''
                patchShebangs *.sh
                if [[ "$(./a.sh)" == *a* ]]; then true; else echo "fail" && false; fi;
              '';
              installPhase = ''
                mkdir "$out"
              '';
            };
            check-b = pkgs.stdenv.mkDerivation {
              name = "check-b";
              src = ./.;
              doCheck = true;
              dontBuild = true;
              nativeBuildInputs = [ pkgs.bash ];
              checkPhase = ''
                patchShebangs *.sh
                if [[ "$(./b.sh)" == *b* ]]; then true; else echo "fail" && false; fi;
              '';
              installPhase = ''
                echo b > $out
              '';
            };
            check-c = pkgs.stdenv.mkDerivation {
              name = "check-c";
              src = ./.;
              doCheck = true;
              dontBuild = true;
              nativeBuildInputs = [ pkgs.bash ];
              checkPhase = ''
                patchShebangs *.sh
                if [[ "$(./c.sh)" == *c* ]]; then true; else echo "fail" && false; fi;
              '';
              installPhase = ''
                mkdir "$out"
              '';
            };
          };
        };
    };
}
