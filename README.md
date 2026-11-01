# dotfiles

New Mac, one command:

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/qpxv/dotfiles/main/install.sh)"
```

It installs Homebrew, logs into GitHub, clones every repo of `qpxv` into
`~/Projects/<repo>`, clones `claude-config` into `~/.claude`, installs the tools from
`Brewfile` and `npm-globals.txt`, links `zshrc`, `zprofile` and `gitconfig` into `~`, and
builds + starts `terminal-theme-sync` (Terminal.app follows light/dark mode).

The repo list comes from GitHub at run time, so new repos need no change here. The
local folder name is the repo name. Rerun anytime with `dots` to pick up new repos and
tools; anything already there is skipped.

Change an alias: edit `zshrc` here (it is what `~/.zshrc` points to), commit, push.
