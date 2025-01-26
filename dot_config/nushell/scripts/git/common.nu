export def agree [
  prompt
  --default-not (-n)
] {
  let prompt = if ($prompt | str ends-with '!') {
      $'(ansi red)($prompt)(ansi reset)'
  } else {
      $'($prompt)'
  }
  (if $default_not { [no yes] } else { [yes no] } | input list $prompt) == 'yes'
}
