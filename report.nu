#!/usr/bin/env nu

def main (file: string, attr: string) {
  open $file
  | where {|x| $x.attr == $attr}
  | where {|x| $x.error != null}
  | where {|x| $x.type in ["EVAL", "BUILD"]}
  | $in.0
  | match $in.type {
    "EVAL" => (do {
      print $"Error while evaluating ($attr)"
      $in.error | print --raw
      exit 1
    })
    "BUILD" => (if ($in.success) {
      print $"Successfully built ($attr)"
      $in.error | print --raw
      exit 0
    } else {
      print $"Error while building ($attr)"
      $in.error | print --raw
      exit 1
    })
  }
}
