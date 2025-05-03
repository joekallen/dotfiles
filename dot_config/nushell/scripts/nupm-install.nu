export def "main" [
  package: string
  repo: string
] {
  use std/dirs
  # wow this is a hack
  use ../../../.local/share/nupm

  mktemp -d $'($package)-XXXX' | dirs add $in
  do -c {git clone $repo .}

  if (ls | where name == 'nupm.nuon' | is-not-empty) {
    nupm install . --force --no-confirm --path
  } else {
    nupm install . --force --no-confirm
  }
}

nupm install . --path
