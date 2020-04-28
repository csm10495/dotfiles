#!/bin/bash

if [ "$CSM_BASHRC_EXECUTED" = "1" ]; then
    return
fi;

# ensure we have the global profile info
if [[ -f /etc/profile ]]; then
    source /etc/profile
fi;

function setup_step() {
    echo "dotfile setup: $1"
}

# To get it to not ask me to use zsh
export BASH_SILENCE_DEPRECATION_WARNING=1

# check for homebrew updates once every 10 days instead of multiple times
export HOMEBREW_AUTO_UPDATE_SECS=864000

# setup an update checkpoint for my dotfiles
export CSM_UPDATE_CHECKPOINT_IN_SECONDS=86400

function create_update_checkpoint() {
    setup_step "creating update checkpoint"
    echo $(( `date +%s` + $CSM_UPDATE_CHECKPOINT_IN_SECONDS )) > ~/.csm_update_checkpoint
}

if [[ ! -f ~/.csm_update_checkpoint ]]; then
    create_update_checkpoint
fi;

chmod 777 ~/.csm_update_checkpoint
CSM_UPDATE_CHECKPOINT=`cat ~/.csm_update_checkpoint`

function _dotfile_update() {
    setup_step "attempting dotfile update"
    curl -s https://raw.githubusercontent.com/csm10495/dotfiles/master/install.sh | PS1="" bash --norc &>/dev/null
    
    # reload (new) self
    export CSM_BASHRC_EXECUTED=0
    source ~/.bashrc
}

if (( "$CSM_UPDATE_CHECKPOINT" < `date +%s` )); then
    create_update_checkpoint
    _dotfile_update
    return
fi;

# don't execute this again
export CSM_BASHRC_EXECUTED=1

# is this a mac?
if [[ $(uname -s) == "Darwin" ]]; then
    export CSM_IS_MAC=1
    export CSM_PACKAGE_MANAGER="brew"
else
    export CSM_IS_LINUX_LIKE=1
    export CSM_PACKAGE_MANAGER=""

    if [[ "$(which apt-get 2>/dev/null)" == "" ]]; then
        if [[ "$(which dnf 2>/dev/null)" == "" ]]; then
            if [[ "$(which yum 2>/dev/null)" != "" ]]; then
                export CSM_PACKAGE_MANAGER="yum"
            fi;
        else
            export CSM_PACKAGE_MANAGER="dnf"
        fi;
    else
        export CSM_PACKAGE_MANAGER="apt-get"
    fi;
fi;

# to get a colorful terminal
function _nonzero_return_code() {
    RETVAL=$?
    [ $RETVAL -ne 0 ] && printf "$RETVAL\e[0m "
}

export PS1="\[\e[36m\]\u\[\e[m\]@\[\e[32m\]\h\[\e[m\]:\[\e[33m\]\w\[\e[m\] \[\e[36;41m\]\`_nonzero_return_code\`\[\e[m\]\[\e[35m\]\\$\[\e[m\]\[\e[40m\] \[\e[m\]"
export CLICOLOR=1
export LSCOLORS=ExFxBxDxCxegedabagacad
if [[ "$CSM_IS_MAC" == "1" ]]; then
    alias ls='ls -GFh'
else
    alias ls='ls -C --color=auto -h'
fi;

# to get nano as the default editor in terminal
export EDITOR=nano

# make history huge
export HISTFILESIZE=10000000
export HISTSIZE=10000000

# see https://github.com/pypa/pipenv/issues/187
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

#https://superuser.com/questions/848516/long-commands-typed-in-bash-overwrite-the-same-line
export TERM=xterm
set horizontal-scroll-mode-off

# Install and post install steps

# get brew if mac
if [[ "$CSM_IS_MAC" == "1" ]]; then
    if [[ $(which brew 2>/dev/null) == "" ]]; then
        setup_step "installing brew"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
    fi;
fi;

# check if i have git
export CSM_HAS_GIT=0
if [[ $(which git 2>/dev/null) != "" ]]; then
    export CSM_HAS_GIT=1
fi;

# Do i have kyrat? If not download it.
if [[ (! -d ~/.local/share/kyrat) && ("$CSM_HAS_GIT" == "1") ]]; then
    setup_step "cloning kyrat"
    git clone https://github.com/fsquillace/kyrat ~/.local/share/kyrat &>/dev/null
fi;

# add kyrat to path
export PATH=$PATH:~/.local/share/kyrat/bin

# if we can't find kyrat, don't mess with ssh anymore
if [[ "$(which kyrat 2>/dev/null)" != "" ]]; then
    # auto use kyrat as ssh
    alias _ssh="`which ssh`"
    function ssh() {
    printf "\n\e[1m Using kyrat... use _ssh to use the real ssh executable\e[0m \n\n"
    kyrat "$@"
    }
fi;
