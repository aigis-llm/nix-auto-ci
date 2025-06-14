{ inputs, ... }:
{
  config = {
    perSystem =
      { pkgs, lib, ... }:
      {
        checks.build-and-report = pkgs.testers.runNixOSTest {
          name = "build-and-report";
          nodes.machine =
            { config, pkgs, ... }:
            let
              # see:
              # https://github.com/nikstur/bombon/blob/9696201440b1e2ffa41ccd104ddffa1be60ee70b/nix/buildtime-dependencies.nix
              # https://nmattia.com/posts/2019-10-08-runtime-dependencies/
              # Find the outputs of a derivation.
              #
              # Returns a list of all derivations that correspond to an output of the input
              # derivation.
              drvOutputs =
                drv: if builtins.hasAttr "outputs" drv then map (output: drv.${output}) drv.outputs else [ drv ];

              # Find the dependencies of a derivation via it's `drvAttrs`.
              #
              # Returns a list of all dependencies.
              drvDeps =
                drv:
                lib.mapAttrsToList (
                  k: v:
                  if lib.isDerivation v then
                    (drvOutputs v)
                  else if lib.isList v then
                    lib.concatMap drvOutputs (lib.filter lib.isDerivation v)
                  else
                    [ ]
                ) drv.drvAttrs;

              wrap = drv: {
                key = drv.outPath;
                inherit drv;
              };

              # Walk through the whole DAG of dependencies, using the `outPath` as an
              # index for the elements.
              #
              # Returns a list of all of `drv`'s buildtime dependencies.
              # Elements in the list have two fields:
              #
              #  - key: the store path of the input.
              #  - drv: the actual derivation object.
              #
              # All outputs are included because they have different outPaths
              buildtimeDerivations =
                drv0:
                builtins.genericClosure {
                  startSet = map wrap (drvOutputs drv0);
                  operator = item: map wrap (lib.concatLists (drvDeps item.drv));
                };
            in
            {
              nix.package = pkgs.lix;
              nix.settings.substituters = lib.mkForce [ ];
              nix.settings.experimental-features = [
                "nix-command"
                "flakes"
              ];

              virtualisation.useNixStoreImage = false;
              virtualisation.mountHostNixStore = true;
              virtualisation.writableStore = true;

              environment.systemPackages =
                [
                  pkgs.git
                  pkgs.bash
                  inputs.self.packages.x86_64-linux.__patched-lix-fast-build
                ]
                #++ map (x: x.drv) (lib.flatten (buildtimeDerivations pkgs.stdenv))
                ++ builtins.attrValues inputs;

              environment.etc.nix-auto-ci = {
                mode = "symlink";
                source = ../.;
              };
            };
          testScript =
            { nodes, ... }:
            let
              overrides = builtins.concatStringsSep " " (
                builtins.map (input: "--override-input ${input} ${inputs.${input}}") (
                  builtins.filter (x: x != "self") (builtins.attrNames inputs)
                )
              );
            in
            ''
              machine.wait_for_unit("default.target")
              machine.succeed("cp -r /etc/nix-auto-ci/ /tmp/ && chmod 755 /tmp/nix-auto-ci")
              machine.succeed("cd /tmp/nix-auto-ci && git init && git add .")
              machine.succeed("cat /etc/fstab 1>&2")
              machine.succeed("ls -la /nix/.ro-store/ 1>&2")
              machine.succeed("cd /tmp/nix-auto-ci/testing-flake && nix run ${overrides} -- .#__patched-lix-fast-build --no-nom ${overrides} --flake \".#checks.${nodes.machine.nixpkgs.hostPlatform.system}\" --result-file result.json 1>&2")
            '';
        };
      };
  };
}
