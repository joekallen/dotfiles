# See https://www.nushell.sh/book/configuration.html
use std/dirs shells-aliases *
use std/util 'path add'
use std/log

##### setup common directories #####

# used for anything that isn't config related
mkdir $nu.data-dir # for anthing that isn't config related

# setup user autoload directory - this should mainly be used for modularizing config
mkdir ...$nu.user-autoload-dirs

# setup data-dir subfolders
[
  'aliases',
  'completions',
  'modules',
  'scripts',
  'vendor/autoload'
] | each {|folder| mkdir ($nu.data-dir | path join $folder) }

# additonal config settings
$env.config = {
  buffer_editor: 'code'
  history: {
    file_format: sqlite
    isolation: true
    max_size: 1_000_000
    sync_on_enter: true
  }
  show_banner: false
  rm: {
    always_trash: true
  }
}
