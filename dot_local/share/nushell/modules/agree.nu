# Created a yes/no input promt for command actions
export def agree [
  prompt              # the prompt question
  --default-not (-n)  # should no be the default option
]: nothing -> bool {
  let prompt = if ($prompt | str ends-with '!') {
      $'(ansi red)($prompt)(ansi reset)'
  } else {
      $'($prompt)'
  }
  (if $default_not { [no yes] } else { [yes no] } | input list $prompt) == 'yes'
}

