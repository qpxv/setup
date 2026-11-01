gc() {
  git stage . && git commit -m "$1"
}

alias gp='git push'

gcp() {
  git stage . && git commit -m "$1" && git push
}

alias clauded='claude --dangerously-skip-permissions'

alias ws='cd ~/Projects/websites'

# rerun the setup: clones repos that are new on github, installs new tools
alias dots='~/Projects/dotfiles/install.sh'
