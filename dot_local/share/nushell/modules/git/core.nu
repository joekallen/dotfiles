use std/log
use toolkit/check-flags
use toolkit/prompt
use utils.nu *

export-env {
  # Workaround for #13403 to load export-env blocks from submodules
  use toolkit/check-flags []
  use std/log []
  use utils.nu []
}

const CLONE_WARN_FLAGS = ['--bare', '--checkout', '--no-separate-git-dir', '--no-sparse']
const CLONE_ERROR_FLAGS = ['--no-bare', '-n', '--no-checkout', '--separate-git-dir', '--sparse']

export def --env init [
  remote: string
] {
  let directory = git-repo-from-remote $remote | $in.repo | path join 'main'
  mkdir $directory
  cd $directory
  ^git init --initial-branch main
  ^git add .
  ^git commit -m 'initial commit'
  ^git remote add origin $remote
}

# Convenience command for git clone that will make a bare clone as the root of the project
# This type of clone is meant to be used with worktrees
@category git
export def --env --wrapped clone [
  remote: string # the repository to clone
  ...rest        # additional parameters passed to the underlying git clone call
]: nothing -> nothing {
  check-flags warn $CLONE_WARN_FLAGS $rest
  check-flags error $CLONE_ERROR_FLAGS $rest

  let repo = git-repo-from-remote $remote | get repo
  $repo
    |
      if ($repo | path exists) {
        error make --unspanned { msg: $'Destination ($env.pwd | path join $repo) already exists' }
      }
    | do -c --env {
      let $default_branch = (git-remote-default-branch $remote).name

      let repo_git_folder = $repo | path join '.git'
      log debug $'running command: ^git clone --bare --no-tags ($remote) ($repo_git_folder) ($rest | str  join (char space))'
      ^git clone --bare --no-tags $remote $repo_git_folder ...$rest
      cd $repo

      {
        remote.origin.fetch: '+refs/heads/*:refs/remotes/origin/*'
        init.defaultBranch: $default_branch
      } | transpose k v | each {
          log debug $'running command: ^git config ($in.k) ($in.v)'
          ^git config ($in.k) ($in.v)
        }

      ^git fetch origin
      worktree-add $default_branch
      ^git branch --set-upstream-to=$'origin/($default_branch)' $default_branch
    }
}

@category git
export def log [
  --diff (-d): string = ''    # Filters change type, multiple types can be combined, i.e 'AM' (A = added, D = deleted, M = modified, R = renamed, C = copied, T = type change, U = unmerged)
  --file (-f): string = ''    # Filters log lines by file path
  --limit (-l): int   = 5     # Filters the number of log lines to show
] : nothing -> table<commit: string, subject: string, name: string, email: string, date: datetime, files: list<record>> {
  git-is-not-repo-error
  let command = [
    git log --name-status -n $limit --pretty=%h»¦«%s»¦«%aN»¦«%aE»¦«%aD
    (if ($diff | is-not-empty) { $'--diff-filter=($diff)' })
    (if ($file | is-not-empty) { [-- $file] })
  ] | flatten |compact -e

  log debug $'running command: ($command | str join (char space))'
  let rows = run-external ...($command)
    | lines
    | compact -e
    | each { |line|
        if ($line =~ '^[0-9a-fA-F]{7,8}»¦«.*$') {
          $line
            | split column "»¦«" commit subject name email date
            | upsert date {|d| $d.date | into datetime }
        } else {
          $line
            | split row -r '\s+'
            | {
                mode: (
                  match $in.0 {
                    A => 'added'
                    D => 'deleted'
                    M => 'modified'
                    R => 'renamed'
                    C => 'copied'
                    T => 'type changed'
                    U => 'unmerged'
                  }
                )
                path: $in.1
              }
        }
      }
    | enumerate

  $rows
    | each {|row| if ($row.item.commit? | is-not-empty) { $row.index } }
    | compact -e
    | each {|index|
        let commit = $rows | get $index | get item | into record
        let files = $rows
          | skip ($index + 1)
          | take until {|row| $row.item.commit? | is-not-empty }
          | get item
          | sort-by mode
          | table --collapse --theme none
        {
          ...$commit
          files: $files
        }
      }
}

# Creates a new worktree from the latest HEAD on the current branch and will automatically move into the new worktree
@category git
def --env "worktree-add" [
  worktree: string        # The name of the new worktree, the checkout path is automatically added
  commitish: string = ''  # defaults to HEAD of the remote default branch. If you want to use the branch the command is ran from use '-', or you can use any other local or remote branch name
  --keep-path (-p)        # Whether to keep the current relative path when entering the new worktree
  --branch (-b)           # Creates a new branch. This isn't needed if there is no branch with this name, but it should specifically be used if you don't want to pick up a remote branch with the same name
  --branch-force (-B)     # Create or reset branch. This is the same as -b, but if a local branch with already exists it will reset it
]: nothing -> nothing {
  let worktrees = worktree-list | where name == $worktree

  log debug $"worktrees: ($worktrees)"
  # check if
  if ($worktrees | is-not-empty) {
    $worktrees | first
      | if (prompt agree $'Worktree `($in.name)` already exists locally, would you like to use it instead?') {
          worktree-use $in.name --keep-path=$keep_path
          return
        } else if (prompt agree $'Worktree `($in.name)` already exists at `($in.path)`, would you like to delete it?') {
          worktree-remove $in.name
        } else {
          error make {
            msg: 'Worktree already exists locally'
            label: {
              text: $'($worktree) already exists at `($in.path)`'
            }
            help: $'Run `git worktree use ($in.name)` and verify if you want to use or delete the existing worktree'
          }
        }
  }

  let worktree_path = git-worktree-path $worktree
  let relative_path = if $keep_path { $env.PWD | path relative-to (git-branch-root) }
  let source_worktree = if $commitish == '' { $'origin/(git-default-branch)' } else { $commitish }

  # Getting a list of ignored files to sync - useful for directories like .terraform and node_modules
  let sync_list = if (git-is-working-tree) {
    ^git status --ignored --porcelain
      | complete
      | if $in.exit_code != 0 {
          error make --unspanned {msg: r#'Couldn't sync untracked files between worktrees'# }
        } else {
          $in.stdout | lines
        }
      | str replace --regex '^!! ' ''
      | each {|subpath|
        {
          source: ($env.PWD | path join $subpath | path parse)
          target: ($worktree_path | path join $subpath | path parse)
        }
      }
    } else { [] }

  if $branch and $branch_force {
    error make {
      msg: 'Cannot use both --branch and --branch-force at the same time'
      label: {
        text: 'Cannot use both --branch and --branch-force at the same time'
      }
      help: 'Run `git worktree add --help` for more information'
    }
  }

  let branch_exists = git-branches | where name == $worktree | is-not-empty
  let worktree_args = (
    if $branch_force {
      {args: [$worktree_path, -B, $worktree, $source_worktree], message: $'Resetting ($worktree) branch to ($source_worktree) for new worktree'}
    } else if $branch or $branch_exists == false {
      {args: [$worktree_path, -b, $worktree, $source_worktree], message: $'Creating new ($worktree) branch from ($source_worktree) for new worktree'}
    } else {
      {args: [$worktree_path, $worktree], message: $'Creating new worktree from existing ($worktree) branch'}
    }
  )

  log info $worktree_args.message

  log debug $"running command: ^git worktree add ($worktree_args.args)"
  ^git worktree add ...$worktree_args.args
    | complete
    | if $in.exit_code != 0 {
        log error $in.stderr
        return
      }


  log debug $"syncing ignored files: ($sync_list | str join '\n')"
  $sync_list |
    | if ($sync_list | is-not-empty) {
        $sync_list
          | each {
              {
                from: ($in.source | path join | path relative-to (git-repo-root))
                to: ($in.target | path join | path relative-to (git-repo-root))
              }
            }
          | format pattern '  - {from} -> {to}'
          | log info $"syncing ignored files:\n($in | str join '\n')"
        $sync_list
      }
    | each {
        if ($in.target.parent | path exists) == false {
            mkdir $in.target.parent
        }

        cp -r ($in.source | path join) ($in.target | path join)
      }


  if ($relative_path | is-not-empty ) {
    $worktree_path | path join $relative_path
  } else {
    $worktree_path
  }
    | path expand
    | do --env {
      let new_dir = $in
      log debug $'moving to directory: ($new_dir)'
      cd $new_dir
    }
}

# Lists all available worktrees
# This is probably most useful for auto-complete
@category git
def "worktree-list" []: nothing -> table<name: string, path: string, sha: string, ref: string, is_current: bool> {
  git-is-not-repo-error

  # Branch names can have slashes in them and the folder name will have those replaced with hyphens
  let current_branch = git-current-branch | split row '/' | compact -e | str join '-'
  let default_branch = git-default-branch

  ^git worktree list --porcelain
  | lines
  | chunk-by { $in | is-empty }
  | where { ($in | length) == 3 }
  | each {
      $in
      | split row (char space)
      |
        {
          name: ($in.1 | str replace -r r#'.*/(.*)'# '$1')
          path: $in.1
          sha: $in.3
          ref: $in.5
          is_current: false
        }
        | update is_current ($in.name == $current_branch)
    }
  | sort-by -c {|a,b|
      if $b.is_current {
        false
      } else {$a.is_current or ($a.name < $b.name)}
    }
}

def cmpl-worktree-list []: nothing -> list<string> {
  worktree-list | get name
}

# Switches to a worktree
# If already on the worktree, will move to the root of it
@category git
def --env worktree-use [
  worktree: string@cmpl-worktree-list         # The name of the worktree
  --keep-path (-p) = false                   # Whether to keep the current relative path when entering the new worktree
  ]: nothing -> nothing {
    let worktrees = worktree-list | where name == $worktree
    let relative_path = null | if $keep_path { $env.PWD | path relative-to (working-tree-root) }

    if ($worktrees | is-empty) {
      log error $'Worktree `($worktree)` not found'
      return
    }

    $worktrees
      | first
      | if $keep_path and (not $in.is_current) {
          $in.path | path join $relative_path | path expand
        } else $in.path
      | cd $in
}

# Removes a worktree and will automatically move into the default branch
@category git
def --env worktree-remove [
  worktree: string@cmpl-worktree-list
  --force = false
]: nothing -> nothing {
  let worktrees = worktree-list
  let target_worktree = $worktrees | where $it.name == $worktree
    | if ( $in | is-empty) {
        log error $'Worktree `($worktree)` not found'
        return
      } else {
        $in | first
      }

  if $target_worktree.is_current {
    cd (git-repo-root)
  }

  if $force { '--force '} else { '--no-force' }
    | ^git worktree remove $in $target_worktree.name
    | if $target_worktree.name != (git-default-branch) {
        # should we let these get cleaned up on their own?
        # in any case, we can't delete main
        #
        sleep 100ms
        ^git branch -D $target_worktree.name
      }
    | null
}

export module worktree {
  export alias add = worktree-add
  export alias remove = worktree-remove
  export alias use = worktree-use
  export alias list = worktree-list
}
