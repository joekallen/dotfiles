use std/dirs
use git/utils
use toolkit/prompt [agree]
# use toolkit/check-flags

export-env {
  # Workaround for #13403 to load export-env blocks from submodules
  # use toolkit/check-flags []
  use git/utils []
  use std/dirs []
  # use std/log []
}

# Command to calculate a worktree path
# This command does not ensure a worktree exists because it is mostly used when creating a worktree
def worktree-path [worktree: string]: nothing -> string {
  repo-root | path join $worktree | path expand
}

# Creates a new worktree from the latest HEADcurrent branch
# and will automatically move into the new worktree
@category git
export def --env "add" [
  worktree: string          # The name of the new worktree, the checkout path is automatically added
  commitish: string = ''    # defaults to HEAD of the remote default branch. If you want to use the branch the command is ran from use '.', or you can use any other local or remote branch name
  --branch (-b)     = false # Create or reset branch. Set this to true if there already is a local or remote branch that you want to overwrite
  --keep-path (-p)  = false # Whether to keep the current relative path when entering the new worktree
]: nothing -> nothing {
  let span = (metadata $worktree).span

  let worktrees = list

  $worktrees | where name == $worktree
    | if ($in | is-not-empty) {
        first
        | if $branch {
            remove $in.name
          } else if (agree $'Worktree `($in.name)` already exists locally, would you like to use it instead?') {
            use $in.name --keep-path=$keep_path
            return
          } else if (agree $'Worktree `($in.name)` already exists at `($in.path)`, would you like to delete it?') {
            remove $in.name
          } else {
            error make {
              msg: 'Worktree already exists locally'
              label: {
                span: $span
                text: $'($worktree) already exists at `($in.path)`'
              }
              help: $'Run `git worktree use ($in.name)` and verify if you want to use or delete the existing worktree'
            }
          }
      }

  let worktree_path = worktree-path $worktree
  let relative_path = if $keep_path { $env.PWD | path relative-to (branch-root) }
  let source_worktree = if $commitish == '.' { current-branch } else { $commitish }

  # Getting a list of ignored files to sync - useful for directories like .terraform and node_modules
  let sync_list = if (is-working-tree) {
    ^git status --ignored --porcelain
      | complete
      | if $in.exit_code != 0 {
          error make --unspanned {msg: r#'Couldn't sync untracked files between worktrees'# }
        } else {
          $in.stdout | lines
        }
      | str replace --regex '^!! ' ''
      | each {
        {
          source: ($env.PWD | path join $in | path parse)
          target: ($worktree_path | path join $in | path parse)
        }
      }
    } else { [] }

  # move to the bare repo for the source of the new tree if one wasn't set
  if ($source_worktree | is-empty) { repo-root | cd $in }
  let branch_path_args = [$worktree, $worktree_path, $source_worktree]
    | if $branch {
        prepend '-B'
      } else {
        prepend '-b'
      }
    | compact --empty

  print $'running command: ^git worktree add ($branch_path_args) | complete | print $in.stdout'
  # ^git worktree add ...$branch_path_args | complete | print $in.stdout
  ^git worktree add ...$branch_path_args

  # Do a copy on write sync of the ignore files
  $sync_list | each {
    if ($in.target.parent | path exists) == false {
        mkdir $in.target.parent
      }

      cp -r ($in.source | path join) ($in.target | path join)
      # try { cp -r ($in.source | path join) ($in.target | path join) } catch { }
    }

  if ($relative_path | is-not-empty ) {
    $worktree_path | path join $relative_path
  } else {
    $worktree_path
  } | path expand | dirs add $in
}

# Removes a worktree and will automatically move into the default branch
@category git
export def --env remove [
  worktree: string = '.'
  --force (-f) = false
]: nothing -> nothing {
  let worktrees = list
  let target_worktree = $worktrees
    | where $it.name == $worktree or ($it.is_current == true and $worktree == '.')
    | if ( $in | is-empty) {
        print $'Worktree `($worktree)` not found'
        return
      } else {
        $in | first
      }

  if $target_worktree.is_current { dirs add (repo-root) }

  if $force { '--force '} else { '--no-force' }
    | ^git worktree remove $in $target_worktree.name | print
    | if $target_worktree.name != (default-branch) {
        ^git branch -D $target_worktree.name
        null
      }
}

# Switches to a worktree
# If already on the worktree, will move to the root of it
@category git
export def --env use [
  worktree?: string        # The name of the worktree
  --keep-path (-p) = false # Whether to keep the current relative path when entering the new worktree
  ]: nothing -> nothing {
    if ($worktree | is-empty) {
      working-tree-root | dirs add $in | return
    }

    let worktrees = list | where name == $worktree
    let relative_path = null | if $keep_path { $env.PWD | path relative-to (working-tree-root) }

    if ($worktrees | is-empty) {
      print $'Worktree `($worktree)` not found'
      return
    }

    $worktrees
      | first
      | if $keep_path and (not $in.is_current) {
          $in.path | path join $relative_path | path expand
        } else {
         $in.path
        }
      | dirs add $in
}

# Lists all available worktrees
# This is probably most uiseful for auto-complete
@category git
export def list []: nothing -> table<name: string, path: string, sha: string, ref: string, is_current: bool> {
  error-is-not-repo

  let current_branch = current-branch
  let default_branch = default-branch

  ^git worktree list --porcelain
  | lines
  | chunk-by { $in | is-empty }
  | where { ($in | length) == 3 }
  | each {
      $in
      | split row ' '
      |
        {
          name: ($in.1 | str replace -r r#'.*/(.*)'# '$1')
          path: $in.1
          sha: $in.3
          ref: $in.5
          is_current: false
          # is_default: false
        }
        | update is_current ($in.name == $current_branch)
        # | update is_default ($in.name == $default_branch)
    }
  | sort-by -c {|a,b|
      if $b.is_current {
        false
      } else {$a.is_current or ($a.name < $b.name)}
    }
}
