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

# Convenience command for git clone that will make bare clone as the root of the project
# This type of clone is meant to be used with worktrees
@category git
export def --env --wrapped clone [
  remote: string
  ...rest
] {
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
export def working-tree-root []: nothing -> string {
  error-is-not-working-tree
  ^git rev-parse --show-toplevel | str trim
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
