# Convience command to check if the CWD is inside a git repo
@category git
export def git-is-repo []: nothing -> bool {
  # catching exception to test if inside a working tree
  # is the easiest way to check if we are in a git repo
  (^git rev-parse --is-inside-work-tree | complete).exit_code == 0
}

# Convenience command to check if the CWD is not inside a git repo
@category git
export def git-is-not-repo []: nothing -> bool {
  not (git-is-repo)
}

# Convenience command to generate an error if the CWD is not inside a git repo
@category git
export def git-is-not-repo-error []: nothing -> nothing {
  if (git-is-not-repo) {
    error make --unspanned {msg: 'Not in a git repository'}
  }
}

# Convenience command to check if the CWD is inside a working tree
# This is useful if you work with bare repos
@category git
export def git-is-working-tree []: nothing -> bool {
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
export def git-is-not-working-tree []: nothing -> bool {
  not (git-is-working-tree)
}

# Convenience command to error if CWD is not in a working tree
# This is useful if you work with bare repos
@category git
export def git-is-not-working-tree-error []: nothing -> nothing {
  if (git-is-not-working-tree) {
    error make --unspanned {msg: 'Not in a git working tree'}
  }
}

# Convenience command to get the repo name from the remote url
@category git
export def git-repo-from-remote [remote: string]: nothing -> record<repo: string, remote: string> {
  $remote
    | split row '/' | last | str trim | str replace -r '\.git$' ''
    | {repo: $in, remote: $remote}
}

# Convenience command to get the default branch from a remote repository
@category git
export def git-remote-default-branch [remote: string]: nothing -> record<name: string, repo: string, default: bool> {
  ^git ls-remote --symref $remote HEAD
    | lines | first
    | split row --regex '\s+'
    | $in.1 | split row '/' | last | str trim
    | {name: $in, default: true }
    | merge (git-repo-from-remote $remote)
    | move default --after repo
}

# Convenience command to return the current git branch
@category git
export def git-current-branch []: nothing -> string {
  git-is-not-repo-error
  ^git rev-parse --abbrev-ref HEAD | str trim
}

# Convenience command to return the default git branch
@category git
export def git-default-branch []: nothing -> string {
  git config --get init.defaultBranch | str trim
}

# Convenience command to return the root of the git repo
@category git
export def git-repo-root []: nothing -> string {
  git-is-not-repo-error
  ^git worktree list --porcelain
    | lines
    | chunk-by { $in | is-empty }
    | where { ($in | length) >  1 and $in.1 == 'bare' }
    | first
    | split row ' '
    | $in.1
}

# Convenience command to return the root of a git working tree
@category git
export def git-working-tree-root []: nothing -> string {
  git-is-not-working-tree-error
  ^git rev-parse --show-toplevel | str trim
}

# Command to calculate a worktree path
# This command does not ensure a worktree exists because it is mostly used when creating a worktree
export def git-worktree-path [worktree: string]: nothing -> string {
  let folder = $worktree | split row '/' | compact -e | str join '-'
  git-repo-root | path join $folder | path expand
}

# Gets branches
export def git-branches [
  --pattern (-p): string = '' # list only the branches that match the pattern(s)
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
