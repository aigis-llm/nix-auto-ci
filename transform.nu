#!/usr/bin/env nu

def main (file: string) {
  let system = $"(nix eval --raw --impure --expr builtins.currentSystem)"
  $system | inspect
  load-env {
    "TERM": "xterm-256color",
    "PAGER": "cat",
  }
  open $file
  | get results
  | each {|status|
    match $status.type {
        "EVAL" => (if ($status.success) {
          $status
        } else {
          $status.attr | inspect
          let eval_err = (try {
              script -efq -c $"nix eval --show-trace --log-format internal-json \".#checks.($system).($status.attr)\"" e+o>|
              | awk "/@nix/{p=1}p" # avoid any escape codes before the first @nix
              | lines
              | each {|row| $row | cut -c 6-}
              | each {|row| $row | from json}
              | where {|log| $log.action == "msg"}
              | last
              | $in.msg
          })
          rm ./typescript
          $status | update error $eval_err
        })
        "BUILD" => {
          $status.attr | inspect
          let build_log = (try {
            script -efq -c $"nix log --log-format internal-json \".#checks.($system).($status.attr)\""
          })
          rm ./typescript
          # For some reason getting build logs fails, no clue but this fixes it
          if ($build_log == null) {
            $status | update error ""
          } else {
            $status | update error $build_log
          }
        }
        _ => $status
      }
    }
  | to json
  | save -f result_parsed.json
}
