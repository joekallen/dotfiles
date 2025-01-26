export def --wrapped git [...rest] {
  ^git ...$rest
}

export def --env --wrapped "git clone" [
  repository: string
  ...rest
] {
  $repository
    | str replace -r r#'^.*\/(.*)\.git$'# './$1'
    | path join (git-remote-default-branch $repository)
    | do -c --env {
      ^git clone $repository $in ...$rest
      enter $in
    }
}

export def --env --wrapped "git worktree add" [
  worktree: string,
  ...rest
] {
  let default_branch: string = git-default-branch
  let current_branch: string = git-current-branch
  let relative_path: string = $env.PWD | path relative-to (git-branch-root)
  if $default_branch != $current_branch {
    [y n]
      | input list $'You are on `($current_branch)`, switch to default branch `($default_branch)`'
      | if $in == "y" {
          cd (git-worktree-path $default_branch)
        }
  }

  print $'creating `($worktree)` worktree from: `(git-current-branch)`'
  git-worktree-path $worktree
    | do -c { ^git worktree add $in ...$rest }
    | git worktree use $worktree $relative_path
}

export def --env --wrapped "git worktree remove" [
  worktree: string,
  ...rest
] {
  if (git-current-branch) == $worktree {
    print $'moving to default branch so worktree can be removed'
    git worktree use (git-default-branch)
  }

  do -c { ^git worktree remove $worktree ...$rest }
}

export def --env "git worktree use" [
  worktree: string
  subpath?: string
  --add-dir (-a) = true
] {
  error-is-not-git-repo
  git-worktree-path $worktree
    | if ($subpath | is-not-empty) {
        $in | path join $subpath
      } else {
        $in
      }
    |
      if $add_dir { enter $in } else { cd $in }
}

def git-worktree-path [worktree: string] {
  git-branch-root | path join $'../($worktree)' | path expand
}

def git-remote-default-branch [repository: string] {
  ^git ls-remote --symref $repository HEAD
    | complete | get stdout
    | lines | take 1 | $in.0
    | str replace -r r#'^.*/(.+)\s*HEAD$'# '$1'
    | str trim
}

def git-default-branch [] {
  error-is-not-git-repo
  ^git config --get init.defaultBranch
    | complete | get stdout | str trim
}

def is-git-repo [] {
  ^git rev-parse --is-inside-work-tree
    | complete
    | get exit_code
    | $in == 0
}

def is-not-git-repo [] {
  not (is-git-repo)
}

def error-is-not-git-repo [] {
  if (is-not-git-repo) {
    error make {msg: "Not in a git repository"}
  }
}

def git-current-branch [] {
  error-is-not-git-repo
  ^git rev-parse --abbrev-ref HEAD | complete | get stdout | str trim
}

def git-branch-root [] {
  error-is-not-git-repo
  ^git rev-parse --show-toplevel | complete | get stdout | str trim
}

# def git_log_prettily [args: string = ""] {
#   if (is-git-repo) == false {
#     return
#   }
#   if $args != "" {
#     git log --pretty=$args
#   }
# }
