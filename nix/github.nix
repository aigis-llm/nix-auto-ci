{
  makeNixGithubAction =
    {
      useLix ? false,
      installStep ? null,
      shouldCache ? true,
      preBuild ? [ ],
      postUpload ? [ ],
      pushBranches ? [ "main" ],
      runs-on ? "ubuntu-latest",
      arch ? "x86_64-linux",
      workflowName ? "Nix ${arch}",
      flake,
    }:
    let
      sourceUrl = if (useLix) then "https://install.lix.systems/lix/lix-installer-${arch}" else null;
      customInstallStep =
        if (installStep != null) then
          installStep
        else
          {
            uses = "determinatesystems/nix-installer-action@main";
            "with" = {
              determinate = false;
              logger = "pretty";
              diagnostic-endpoint = "";
            } // (if (sourceUrl != null) then { source-url = sourceUrl; } else { });
          };
      cacheSteps = (
        if (shouldCache) then
          [
            {
              uses = "DeterminateSystems/magic-nix-cache-action@main";
              "with" = {
                diagnostic-endpoint = "";
              };
            }
          ]
        else
          [ ]
      );
    in
    {
      name = workflowName;
      on = {
        push = {
          branches = pushBranches;
        };
        pull_request = { };
      };
      jobs = {
        fast-build = {
          steps =
            [
              {
                uses = "actions/checkout@v4";
              }
              customInstallStep
            ]
            ++ cacheSteps
            ++ preBuild
            ++ [
              {
                name = "nix-fast-build";
                run = "nix run --inputs-from . nixpkgs#${
                  if useLix then "lixPackageSets.latest." else ""
                }nix-fast-build -- --no-nom --flake \".#checks.${arch}\" --result-file result.json || true";
              }
              {
                name = "transform";
                run = "nix run --inputs-from . .#nix-auto-ci-transform -- result.json";
              }
              {
                name = "upload artifact";
                uses = "actions/upload-artifact@v4";
                "with" = {
                  name = "results";
                  path = ''
                    ./result_parsed.json
                    ./result-*
                  '';
                };
              }
            ]
            ++ postUpload;
        };
        report = {
          needs = [ "fast-build" ];
          strategy = {
            fail-fast = false;
            matrix = {
              attr = builtins.attrNames flake.checks.${arch};
            };
          };
          steps =
            [
              {
                uses = "actions/checkout@v4";
              }
              customInstallStep
            ]
            ++ cacheSteps
            ++ [
              {
                uses = "actions/download-artifact@v4";
                "with" = {
                  path = "artifacts";
                };
              }
              {
                name = "report";
                run = "nix run --inputs-from . .#nix-auto-ci-report artifacts/results/result_parsed.json \${{ matrix.attr }}";
              }
            ];
        };
      };
    };
}
