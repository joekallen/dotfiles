use std/dirs
use toolkit/check-flags

export-env {
  # Workaround for #13403 to load export-env blocks from submodules
  use toolkit/check-flags []
  use std/dirs []
  use std/log []
}

const CLONE_WARN_FLAGS = ['--bare', '--checkout', '--no-separate-git-dir', '--no-sparse']
const CLONE_ERROR_FLAGS = ['--no-bare', '-n', '--no-checkout', '--separate-git-dir', '--sparse']

export def --env init [
  remote: string
] {
  let directory = repo-from-remote $remote | $in.repo | path join 'main'
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

  let repo = repo-from-remote $remote | get repo
  $repo
    |
      if ($repo | path exists) {
        error make --unspanned { msg: $'Destination ($env.pwd | path join $repo) already exists' }
      }
    | do -c --env {
      let $default_branch = (remote-default-branch $remote).name

      let repo_git_folder = $repo | path join '.git'
      let config = {
        remote.origin.fetch: '+refs/heads/*:refs/remotes/origin/*'
        init.defaultBranch: $default_branch
      } | transpose k v | each { format pattern '-c {k}={v}' }

      ^git clone --bare ...$config $remote $repo_git_folder ...$rest

      dirs add $repo

      ^git worktree add $default_branch
      ^git fetch
    }
}

# Convenience command to get the repo name from the remote url
@category git
export def repo-from-remote [remote: string]: nothing -> record<repo: string, remote: string> {
  $remote
    | split row '/' | last | str trim | str replace -r '\.git$' ''
    | {repo: $in, remote: $remote}
}

# Convenience command to get the default branch from a remote repository
@category git
export def remote-default-branch [remote: string]: nothing -> record<name: string, repo: string, default: bool> {
  ^git ls-remote --symref $remote HEAD
    | lines | first
    | split row --regex '\s+'
    | $in.1 | split row '/' | last | str trim
    | {name: $in, default: true }
    | merge (repo-from-remote $remote)
    | move default --after repo
}

# Convience command to check if the CWD is inside a git repo
@category git
export def is-repo []: nothing -> bool {
  # catching exception to test if inside a working tree
  # is the easiest way to check if we are in a git repo
  (^git rev-parse --is-inside-work-tree | complete).exit_code == 0
}

# Convenience command to check if the CWD is not inside a git repo
@category git
export def is-not-repo []: nothing -> bool {
  not (is-repo)
}

# Convenience command to generate an error if the CWD is not inside a git repo
@category git
export def error-is-not-repo []: nothing -> nothing {
  if (is-not-repo) {
    error make --unspanned {msg: 'Not in a git repository'}
  }
}

# Convenience command to check if the CWD is inside a working tree
# This is useful if you work with bare repos
@category git
export def is-working-tree []: nothing -> bool {
  ^git rev-parse --is-inside-work-tree
    | complete
    | if $in.exit_code != 0 {
        error make --unspanned {msg: 'Not in a git repository'}
      } else {
        $in.stdout | into bool
      }
}

# Convenience command to check if the CWD is not inside a git working tree
@category git
export def is-not-working-tree []: nothing -> bool {
  not (is-working-tree)
}

# Convenience command to error if CWD is not in a working tree
# This is useful if you work with bare repos
@category git
export def error-is-not-working-tree []: nothing -> nothing {
  if (is-not-working-tree) {
    error make --unspanned {msg: 'Not in a git working tree'}
  }
}

# Convenience command to return the current git branch
@category git
export def current-branch []: nothing -> string {
  error-is-not-repo
  ^git rev-parse --abbrev-ref HEAD | str trim
}

# Convenience command to return the default git branch
@category git
export def default-branch []: nothing -> string {
  git config --get init.defaultBranch | str trim
}

# Convenience command to return the root of a git working tree
@category git
export def working-tree-root []: nothing -> string {
  error-is-not-working-tree
  ^git rev-parse --show-toplevel | str trim
}

# Gets branches
export def branches [
  pattern: string = '' # list only the branches that match the pattern(s)
]: nothing -> list<record<name: string, source: string>> {
  let args = if ($pattern | is-not-empty ) { ['-l', $pattern] } else { [] }
  ^git branch -a --no-column ...$args | lines
    | each {|line|
        {
          name: ($line | str replace -r '(?:(?:[\+\*]\s)|(?:\s+remotes\/.+\/))(.+)' '$1' | str trim)
          source: (
            if $line =~ '.*remotes\/.+?\/.*' {
              $line | str replace -r '(?:\s+remotes\/)(.+?)\/.*' '$1'
            } else { 'local' }
          )
        }
      }
    | sort-by -c {|a,b|
        if $a.name == $b.name {
          $b.source == 'local'
        } else {$a.name < $b.name}
      }
    | uniq-by name
}

# Convenience command to return the root of the git repo
@category git
export def repo-root [] {
  error-is-not-repo
  git worktree list --porcelain
    | lines
    | chunk-by { $in | is-empty }
    | where { ($in | length) >  1 and $in.1 == 'bare' }
    | first
    | split row ' '
    | $in.1
}

# Command to calculate a worktree path
# This command does not ensure a worktree exists because it is mostly used when creating a worktree
def worktree-path [worktree: string]: nothing -> string {
  repo-root | path join $worktree | path expand
}

# Creates a new worktree from the latest HEAD on the current branch and will automatically move into the new worktree
@category git
def --env "worktree-add" [
  worktree: string       # The name of the new worktree, the checkout path is automatically added
  commitish: string = '' # defaults to HEAD of the remote default branch. If you want to use the branch the command is ran from use '.', or you can use any other local or remote branch name
  --keep-path (-p)       # Whether to keep the current relative path when entering the new worktree
  --branch (-b)          # Creates a new branch. This isn't needed if there is no branch with this name, but it should specifically be used if you don't want to pick up a remote branch with the same name
  --branch-force (-B)    # Create or reset branch. This is the same as -b, but if a local branch with already exists it will reset it
]: nothing -> nothing {
  let worktrees = worktree-list | where name == $worktree

  # check if
  if ($worktrees | is-not-empty) {
    $worktrees | first
      | if (agree $'Worktree `($in.name)` already exists locally, would you like to use it instead?') {
          worktree-use $in.name --keep-path=$keep_path
          return
        } else if (agree $'Worktree `($in.name)` already exists at `($in.path)`, would you like to delete it?') {
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

  if ($worktrees | is-empty) {
    $branches = git branch -l | split row ' ' | filter { $in == $worktree }

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
      | each {|subpath|
        {
          source: ($env.PWD | path join $subpath | path parse)
          target: ($worktree_path | path join $subpath | path parse)
        }
      }
    } else { [] }

  # move to the bare repo for the source of the new tree if one wasn't set
  if ($source_worktree | is-empty) { repo-root | dirs add $in }
  let branch_path_args = [$worktree, $worktree_path, $source_worktree]
    | if $branch {
        prepend '-B'
      } else {
        prepend '-b'
      }
    | compact --empty

  ^git worktree add ...$branch_path_args
    | complete
    | if $in.exit_code == 0 {
        dirs drop
      } else {
        # print the error, but move back to the previous directory
        print $in.stdout
        dirs drop
        return
      }


  # Do a copy on write sync of the ignore files
  $sync_list |
    | if ($sync_list | is-not-empty) {
        $sync_list
          | each {
              {
                from: ($in.source | path join | path relative-to (repo-root))
                to: ($in.target | path join | path relative-to (repo-root))
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
  } | path expand | do {
    print $'moving to directory: ($in)'
    dirs add $in
  }
}

# Removes a worktree and will automatically move into the default branch
@category git
def --env worktree-remove [
  worktree: string = '.'
  --force (-f) = false
]: nothing -> nothing {
  let worktrees = worktree-list
  let target_worktree = $worktrees
    | where $it.name == $worktree or ($it.is_current == true and $worktree == '.')
    | if ( $in | is-empty) {
        log info $'Worktree `($worktree)` not found'
        return
      } else {
        $in | first
      }

  if $target_worktree.is_current {
    dirs drop
    dirs add (repo-root)
  }

  if $force { '--force '} else { '--no-force' }
    | ^git worktree remove $in $target_worktree.name | print
    | if $target_worktree.name != (default-branch) {
        # should we let these get cleaned up on their own?
        # in any case, we can't delete main
        # ^git branch -D $target_worktree.name
      }
    | null
}

# Switches to a worktree

# If already on the worktree, will move to the root of it
@category git
export def --env worktree-use [
  worktree?: string        # The name of the worktree
  --keep-path (-p) = false # Whether to keep the current relative path when entering the new worktree
  ]: nothing -> nothing {
    if ($worktree | is-empty) {
      working-tree-root | dirs add $in | return
    }

    let worktrees = worktree-list | where name == $worktree
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
export def worktree-list []: nothing -> table<name: string, path: string, sha: string, ref: string, is_current: bool> {
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

export module worktree {
  export alias add = worktree-add
  export alias remove = worktree-remove
  export alias use = worktree-use
  export alias list = worktree-list
}
