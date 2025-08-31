# make sure global tools are installed
let missing_tools = ^mise ls -m --json | from json | columns
if ($missing_tools | is-not-empty) {
  print $'Running mise install for missing tools [($missing_tools | str join ", ")]'
  ^mise install
    | complete
    | do {
        if $in.exit_code != 0 {
          error make --unspanned {
            msg: $'mise install: existed with code ($in.exit_code)'
            label: {
              text: $in.stderr
            }
          }
        }
      }
}

# make sure plugins are registered
mise bin-paths | lines
  | find nu-plugin
  | each {ls $in | get name}
  | flatten
  | each {plugin add $in}

#^aws-sso | ignore

# add overlays here
use std/dirs shells-aliases *
use git
