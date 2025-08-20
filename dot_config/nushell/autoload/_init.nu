##### setup folders and vendor auto loads #####

# carapace - completion
carapace _carapace nushell | save -f ($nu.data-dir | path join 'vendor/autoload/carapace.nu')

# mise - tool for managing multiple versions of nushell
mise activate nu | save -f ($nu.data-dir | path join 'vendor/autoload/mise.nu')

# starship - terminal styling
starship init nu | save -f ($nu.data-dir | path join 'vendor/autoload/starship.nu')
