#!/bin/bash

# export all functions
set -a

# removing this check for now.
#if [ "$CSM_BASHRC_EXECUTED" = "1" ]; then
#    return
#fi;

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

function _update_dotfiles() {
    setup_step "attempting dotfile update"
    curl -s https://raw.githubusercontent.com/csm10495/dotfiles/master/install.sh | PS1="" bash --norc &>/dev/null
    if [[ $? == 0 ]]; then
        # reload (new) self
        export CSM_BASHRC_EXECUTED=0
        source ~/.bashrc
    fi;
}

if (( "$CSM_UPDATE_CHECKPOINT" < `date +%s` )); then
    create_update_checkpoint
    _update_dotfiles
    return
fi;

# don't execute this again
export CSM_BASHRC_EXECUTED=1

# install.sh should fill in the actual repo hash here.
export CSM_BASHRC_HASH="REPLACE_WITH_REPO_HASH"

# install.sh should fill in the version here.
export CSM_BASHRC_VERSION="REPLACE_WITH_VERSION"

if [[ "$CSM_BASHRC_VERSION" != "" ]]; then
    if [[ "$CSM_BASHRC_VERSION" != REPLACE_WITH_VERSIO* ]]; then
        printf "\e[44mcsm10495/dotfiles: v$CSM_BASHRC_VERSION\e[49m";sleep .25;printf "\r                                        \r"
    fi
fi

function _csm_cmd_exists() {
    if [[ "$(which "$1" 2>/dev/null)" != "" ]]; then
        echo "true"
    else
        echo "false"
    fi;
}

function _csm_cmd_not_exists() {
    if [[ "$(which "$1" 2>/dev/null)" != "" ]]; then
        echo "false"
    else
        echo "true"
    fi;
}

function _csm_user_package_install() {
    # default does nothing
    return 1
}

# ensure .local exists
mkdir -p ~/.local

# is this a mac?
if [[ $(uname -s) == "Darwin" ]]; then
    export CSM_IS_MAC=1
    if [[ "$(_csm_cmd_exists brew)" == "true" ]]; then
        function _csm_user_package_install() {
            brew install $1 &> /dev/null
            return $?
        }
    fi
else
    export CSM_IS_LINUX_LIKE=1
    if [[ "$(_csm_cmd_exists apt-get)" == "true" ]]; then
        true # todo.
    elif [[ "$(_csm_cmd_exists yum)" == "true" ]]; then
        # yum supported
        if [[ "$(_csm_cmd_exists yumdownloader)" == "true" ]]; then
            function _csm_user_package_install() {
                _TEMP_DIR=`mktemp -d`
                _RET=-1
                pushd "$_TEMP_DIR" > /dev/null
                yumdownloader $1 --resolve &>/dev/null
                popd > /dev/null
                if [[ $? == 0 ]]; then
                    pushd "$HOME/.local" > /dev/null
                    for filename in $_TEMP_DIR/*.rpm; do
                        rpm2cpio "$filename" 2>/dev/null | cpio -idv 2>/dev/null
                    done
                    _RET=$?
                    popd > /dev/null
                fi;
                return $_RET
            }
        fi
    fi
fi

# check if i have git
export CSM_HAS_GIT=0
if [[ $(which git 2>/dev/null) != "" ]]; then
    export CSM_HAS_GIT=1
fi;

# to get a colorful terminal
function _set_ps1() {
    RETVAL=$?
    if [[ $RETVAL == "0" ]]; then
        RETVAL=""
    else
        RETVAL="$RETVAL\[\e[0m\] "
    fi;

    _GIT_INFO=""
    if [[ "$CSM_HAS_GIT" == 1 ]]; then
        _BRANCH=`git rev-parse --abbrev-ref HEAD 2>/dev/null`

        if [[ "$_BRANCH" != "" ]]; then
            # see https://stackoverflow.com/a/5143914/3824093
            git diff-index --quiet HEAD 2>/dev/null
            if [[ "$?" != "0" ]]; then
                _EXTRA_STUFF="+"
            else
                _EXTRA_STUFF=""
            fi
            _GIT_INFO=" ($_BRANCH$_EXTRA_STUFF)"
        fi
    fi

    export PS1="\[\e[36m\]\u\[\e[m\]@\[\e[32m\]\h\[\e[m\]:\[\e[33m\]\w\[\e[m\]$_GIT_INFO \[\e[97;41m\]$RETVAL\[\e[m\]\[\e[35m\]\\$\[\e[m\]\[\e[40m\] \[\e[m\]"
}
export PROMPT_COMMAND=_set_ps1

export CLICOLOR=1
export LSCOLORS=ExFxBxDxCxegedabagacad
if [[ "$CSM_IS_MAC" == "1" ]]; then
    alias ls='ls -GFh'
else
    alias ls='ls -C --color=auto -h'
fi;

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# make history huge
export HISTFILESIZE=10000000
export HISTSIZE=10000000

# see https://github.com/pypa/pipenv/issues/187
export LC_ALL=en_US.UTF-8 2>/dev/null
export LANG=en_US.UTF-8 2>/dev/null

#https://superuser.com/questions/848516/long-commands-typed-in-bash-overwrite-the-same-line
export TERM=xterm
set horizontal-scroll-mode-off

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

## Key bindings
### Tested on WSL Bash

# Ctrl-Del to delete next word
bind '"\e[3;5~":kill-word'

# Ctrl-Backspace to delete last word
bind "\C-h":backward-kill-word

# Arrow up to do a history search back
bind '"\e[A": history-search-backward'

# Arrow down to do a history search forward
bind '"\e[B": history-search-forward'

# Install and post install steps

# get brew if mac
if [[ "$CSM_IS_MAC" == "1" ]]; then
    if [[ $(which brew 2>/dev/null) == "" ]]; then
        setup_step "installing brew"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
    fi;
fi;

# Do i have kyrat? If not download it.
if [[ (! -d ~/.local/share/kyrat) && ("$CSM_HAS_GIT" == "1") ]]; then
    setup_step "cloning kyrat"
    git clone https://github.com/fsquillace/kyrat ~/.local/share/kyrat &>/dev/null
fi;

# add local lib paths (only support x64 and x86)
if [[ "$(uname -m)" == "x86_64" ]]; then
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:~/.local/usr/lib64/
else
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:~/.local/usr/lib/
fi;

# add kyrat (and a local bin) to path
mkdir -p ~/.local/usr/local/bin
mkdir -p ~/.local/usr/bin
export PATH=$PATH:~/.local/share/kyrat/bin:~/.local/usr/bin:~/.local/usr/local/bin

# i'd greatly prefer nano to vi so see if we can get it.
CSM_NANO=""
if [[ "$(_csm_cmd_exists nano)" == "true" ]]; then
    CSM_NANO=`which nano`
else
    _csm_user_package_install nano
    if [[ $? == 0 ]]; then
        echo "... installed nano"
        CSM_NANO=`which nano`
    fi
fi;

# to get nano as the default editor in terminal
export EDITOR=$CSM_NANO

# if we can't find kyrat, don't mess with ssh anymore
if [[ "$(_csm_cmd_exists ssh)" == "true" ]]; then
    if [[ "$(which kyrat 2>/dev/null)" != "" ]]; then
        # kyrat will source... don't take its definitions.
        set +a
        # auto use kyrat as ssh
        unalias _ssh 2>/dev/null
        alias _ssh="`which ssh`"

        function ssh() {
            printf "\n\e[1m Using kyrat... use _ssh to use the real ssh executable\e[0m \n\n"
            kyrat "$@"
            return $?
        }
        set -a
    fi;
fi;

# stop exporting all functions
set +a
