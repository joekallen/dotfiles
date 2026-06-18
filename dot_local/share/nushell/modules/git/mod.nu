use std/dirs
use toolkit/check-flags
export use core.nu *
export use utils.nu *

export-env {
  # Workaround for #13403 to load export-env blocks from submodules
  use toolkit/check-flags []
  use std/dirs []
  use std/log []
  use core.nu []
  use utils.nu []
}
