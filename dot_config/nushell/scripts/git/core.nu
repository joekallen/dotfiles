export def git-stash [
  --apply (-a)
  --clear (-c)
  --drop (-d)
  --list (-l)
  --pop (-p)
  --show (-s)
  --all (-A)
  --include-untracked (-i)
] {
  if $apply {
    git stash apply
  } else if $clear {
    git stash clear
  } else if $drop {
    git stash drop
  } else if $list {
    git stash list
  } else if $pop {
    git stash pop
  } else if $show {
    git stash show --text
  } else if $all {
    git stash --all ...(if $include_untracked {[--include-untracked]} else {[]})
  } else {
    let s = _git_status
    if ($s | sum_prefix 'wt_') > 0 {
      git stash
    } else {
      git stash pop
    }
  }
}
