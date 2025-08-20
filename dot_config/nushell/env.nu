# initial path setup
$env.PATH = $env.PATH | split row (char esep)
  | prepend '/usr/local/bin'
  | prepend '/opt/homebrew/bin'
  | uniq

# Specifies how environment variables are:
# - converted from a string to a value on Nushell startup (from_string)
# - converted from a value back to a string when running external commands (to_string)
# Note: The conversions happen *after* config.nu is loaded
$env.ENV_CONVERSIONS = {
  'PATH': {
    from_string: {|s| $s | split row (char esep) | path expand --no-symlink }
    to_string: {|v| $v | path expand --no-symlink | str join (char esep) }
  }
  'Path': {
    from_string: {|s| $s | split row (char esep) | path expand --no-symlink }
    to_string: {|v| $v | path expand --no-symlink | str join (char esep) }
  }
}

# Nu Logging
$env.NU_LOG_FORMAT = '%LEVEL%: %MSG%'
$env.NU_LOG_LEVEL = 'INFO'

# Directories to search for scripts such as aliases and completions
# we probably don't need to add all of these, the data-dir folder and module is probably enough
$env.NU_LIB_DIRS = [
  # 'aliases',
  'completions',
  'modules',
  'scripts'
] | each {|folder| $nu.data-dir | path join $folder } | append $nu.data-dir

# Directories to search for plugin binaries when calling register
$env.NU_PLUGIN_DIRS = ['plugins'] | each {|folder|
    [
      ($nu.data-dir | path join $folder | path join (version).version),
      ($nu.config-path | path dirname | path join $folder)
    ]
  } | flatten
