# Set PATH, MANPATH, etc., for Homebrew.
eval "$(/opt/homebrew/bin/brew shellenv)"

# Show Isengard profile
eval "$(isengardcli shell-profile)"

# Show git branch
# Find and set branch name var if in git repository.
function git_branch_name()
{
  branch=$(git symbolic-ref HEAD 2> /dev/null | awk 'BEGIN{FS="/"} {print $NF}')
  if [[ $branch == "" ]];
  then
    :
  else
    echo '- ('$branch')'
  fi
}

# Enable substitution in the prompt.
setopt prompt_subst

# Config for prompt. PS1 synonym.
prompt='%2/ $(git_branch_name) > '


alias sshcd="ssh dev-dsk-marcosmx-2a-499004ab.us-west-2.amazon.com"
alias c="clear"
alias km="kinit && mwinit -k id_ecdsa.pub"
alias python="python3"
alias isengard="isengardcli"
alias bb="brazil-build"


PATH="~/.nvm/versions/node/v16.19.1/bin:$PATH"
