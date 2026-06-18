use std/log

export def --env --wrapped main [
  --profile (-p): string@cmpl-profile-list
  ...rest
] {
  if (which aws-sso | is-not-empty) {
    let profiles = cmpl-profile-list | $in.completions
    let valid_profiles = [$profile $'($profile):Viewer' 'infra:Viewer'] | where $it in $profiles
    if ($valid_profiles | is-empty) {
      error make {
        msg: $'Profile `($profile)` not found in aws-sso profiles ($profiles)'
      }
    }

    let selected_profile = $valid_profiles | first
    log info $'Running opencode with profile: ($selected_profile)'
    sleep 250ms
    aws-sso exec --profile=$'($selected_profile)' --sts-refresh -- opencode ...$rest
  } else { ^opencode ...$rest }
}

def cmpl-profile-list [] {
  let completions = if (which aws-sso | is-not-empty) {
      aws-sso list --csv
        | from csv -n
        | rename expires account profile account_id role
        | where role == 'ViewOnlyAccess'
        | get profile
    } else { [] }
  {
    options: {
      case_sensitive: false
      completion_algorithm: substring,
      sort: true,
    },
    completions: $completions
  }
}
