use std/dirs shells-aliases enter

export def --env git-init [
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

export def --env --wrapped git-clone [
  remote: string
  ...rest
] {
  let repo = git-repo-from-remote $remote | get repo
  $repo
    |
      if ($repo | path exists) {
        error make --unspanned { msg: $"Destination ($env.pwd | path join $repo) already exists" }
      }
      $repo
    | path join (git-remote-default-branch $remote).name
    | do -c --env {
      ^git clone $remote $in ...$rest
      enter $in
    }
}

export def git-repo-from-remote [remote: string] {
  $remote
    | str replace -r r#'^.*\/(.*)\.git$'# '$1'
    | {repo: $in, remote: $remote}
}

export def git-remote-default-branch [remote: string] {
  ^git ls-remote --symref $remote HEAD
    | lines | first
    | str replace -r r#'^.*/(.+)\s*HEAD$'# '$1'
    | str trim
    | {name: $in, default: true }
    | merge (git-repo-from-remote $remote)
    | move default --after repo
}

export def git-is-repo [] {
  (git rev-parse --is-inside-work-tree | complete).exit_code == 0
}

export def git-is-not-repo [] {
  not (git-is-repo)
}

export def git-error-is-not-repo [] {
  if (git-is-not-repo) {
    error make {msg: "Not in a git repository"}
  }
}

export def git-current-branch [] {
  git-error-is-not-repo
  ^git rev-parse --abbrev-ref HEAD | str trim
}

export def git-default-branch [] {
  git-error-is-not-repo
  ^git config --get init.defaultBranch | str trim
}

export def git-branch-root [] {
  git-error-is-not-repo
  ^git rev-parse --show-toplevel |  str trim
}

export def git-repo-root [] {
  git-branch-root | path join '..' | path expand
}

export def git-worktree-list [] {
  git-error-is-not-repo

  let current_branch = git-current-branch
  let default_branch = git-default-branch

  ^git worktree list --porcelain
  | lines
  | compact --empty
  | chunks 3
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
          is_default: false
        }
        | update is_current ($in.name == $current_branch)
        | update is_default ($in.name == $default_branch)
    }
  | sort-by -c {|a,b|
      if $b.is_current {
        false
      } else if $b.is_default and (not $a.is_current) {
        false
      } else {$a.is_current or $a.is_default or ($a.name < $b.name)}
    }
}
