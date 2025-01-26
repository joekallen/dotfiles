use common.nu agree
use utils.nu
use std/dirs shells-aliases enter

def git-worktree-path [worktree: string] {
  git-repo-root | path join $worktree | path expand
}

# Creates a new worktree from the current branch
# and will automatically move into the new worktree
@category git
export def --env --wrapped git-worktree-add [
  worktree: string         # The name of the new worktree
  --keep-path (-p) = false # Whether to keep the current relative path when entering the new worktree
  --delete (-d) = false    # Whether to delete the worktree if it already exists
  ...rest                  # Optional arguments to pass along to the git worktree add command
]: nothing -> nothing {
  let span = (metadata $worktree).span

  let worktrees = git-worktree-list

  $worktrees | where name == $worktree
    | if ($in | is-not-empty) {
        first
        | if $delete {
            git-worktree-remove $in.name
          } else if (agree $'Worktree `($in.name)` already exists locally, would you like to use it instead?') {
            git-worktree-use $in.name --keep-path=$keep_path
            return
          } else if (agree $'Worktree `($in.name)` already exists at `($in.path)`, would you like to delete it?') {
            git-worktree-remove $in.name
          } else {
            error make {
              msg: 'Worktree already exists locally'
              label: {
                span: $span
                text: $'($worktree) already exists at `($in.path)`'
              }
              help: $'Run `git-worktree-use ($in.name)` and verify if you want to use or delete the existing worktree'
            }
          }
      }

  let relative_path = if $keep_path { $env.PWD | path relative-to (git-branch-root) }

  $worktrees | where is_default
    | first
    | if (not $in.is_current) and (agree $'Not on default branch `($in.name)`, switch now?') {
        cd (git-worktree-path $in.name)
      }

  let worktree_path = git-worktree-path $worktree
  ^git worktree add $worktree_path ...$rest | complete | print $in.stdout

  if ($relative_path | is-not-empty ) {
    $worktree_path | path join $relative_path
  } else {
    $worktree_path
  } | path expand | enter $in
}

# Removes a worktree and will automatically move into the default branch
@category git
export def --env git-worktree-remove [
  worktree: string
  --force (-f) = false
] {
  let worktrees = git-worktree-list
  let target_worktree = $worktrees | where name == $worktree

  if ( $target_worktree | is-empty) {
    print $'Worktree `($worktree)` not found'
    return
  }

  $target_worktree
    | first
    | if ($in.is_current) {
        enter ($worktrees | where is_default | first).path
      }

  if $force { '--force '} else { '--no-force' }
    | ^git worktree remove $in $worktree | print
}

# Switches to a worktree
# If already on the worktree, will move to the root of it
@category git
export def --env git-worktree-use [
  worktree?: string        # The name of the new worktree
  --keep-path (-p) = false # Whether to keep the current relative path when entering the new worktree
  ] {
    if ($worktree | is-empty) {
      git-branch-root | enter $in | return
    }

    let worktrees = git-worktree-list | where name == $worktree
    let relative_path = null | if $keep_path { $env.PWD | path relative-to (git-branch-root) }

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
      | enter $in
}
