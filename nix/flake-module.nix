_localFlake:
{
  config,
  lib,
  flake-parts-lib,
  ...
}:
{
  options = { };
  config = {
    perSystem =
      { pkgs, ... }:
      {
        packages.nix-auto-ci-transform = pkgs.stdenv.mkDerivation {
          name = "nix-auto-ci-transform";
          buildInputs = [
            pkgs.nushell
          ];
          dontUnpack = true;
          installPhase = "install -m755 -D ${../transform.nu} $out/bin/nix-auto-ci-transform";
        };
        packages.nix-auto-ci-report = pkgs.stdenv.mkDerivation {
          name = "nix-auto-ci-report";
          nativeBuildInputs = [
            pkgs.makeWrapper
          ];
          buildInputs = [
            pkgs.nushell
          ];
          dontUnpack = true;
          installPhase = ''
            install -m755 -D ${../report.nu} $out/bin/nix-auto-ci-report
            wrapProgram $out/bin/nix-auto-ci-report --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.unixtools.script ]}
          '';
        };
        packages.__patched-nix-fast-build = pkgs.nix-fast-build.overrideAttrs (oldAttrs: {
          patches = (oldAttrs.patches or [ ]) ++ [ ../nix-fast-build.patch ];
        });
        packages.__patched-lix-fast-build =
          pkgs.lixPackageSets.latest.nix-fast-build.overrideAttrs
            (oldAttrs: {
              patches = (oldAttrs.patches or [ ]) ++ [ ../nix-fast-build.patch ];
            });
      };
  };
}
