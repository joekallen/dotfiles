use std/log

export-env {
  use std/log []
}

export def test [to_check: list<string>, params: list]: nothing -> record<found: bool, flags: list> {
  let flags_found = $to_check | filter {|flag| $flag in $params }
  {
    found: ($flags_found | is-not-empty)
    flags: $flags_found
  }
}

export def warn [to_check: list<string>, params: list]: nothing -> nothing {
  let check = test $to_check $params
  if ($check.found) {
    log warning $'Provided flags are not supported and should be removed: ($check.flags)'
  }
}

export def error [to_check: list<string>, params: list]: nothing -> nothing {
  let check = test $to_check $params
  if ($check.found) {
    error make --unspanned { msg: $'Provided flags are not allowed and must be removed: ($check.flags)' }
  }
}
