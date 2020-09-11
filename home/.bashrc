#!/bin/bash

# figure out python version early
PYTHON=""
if [[ `which python3 2>/dev/null` != "" ]]; then
    PYTHON="python3"
elif [[ `which python 2>/dev/null` != "" ]]; then
    PYTHON="python"
elif [[ `which python2 2>/dev/null` != "" ]]; then
    PYTHON="python2"
fi

# make logging available as early as possible
function _csm_log() {
    # make log directory
    _CSM_LOG_DIR=~/.local/var/log/dotfiles

    _CSM_DATETIME=$(date --rfc-3339=ns 2>/dev/null)
    if [[ "$_CSM_DATETIME" == "" ]]; then
        # try gdate for gnu date on mac
        _CSM_DATETIME=$(gdate --rfc-3339=ns 2>/dev/null)
    fi
    _CSM_LOG_PREFIX="log"
    _CSM_LOG_SUFFIX=".txt"
    _CSM_DEFAULT_LOG_FILE="${_CSM_LOG_DIR}/${_CSM_LOG_PREFIX}${_CSM_LOG_SUFFIX}"
    _CSM_LOG_FILE_ROTATE_THRESHOLD=1000000

    LOG_FILES=$(set -o pipefail; ls -r ${_CSM_LOG_DIR} 2>/dev/null | grep ${_CSM_LOG_PREFIX})

    # if ls fails, then make sure the dir exists
    if [[ $? != 0 ]]; then
        mkdir -p ${_CSM_LOG_DIR}
    fi

    if [[ "$LOG_FILES" != "" ]]; then
        # if it is not the first time, check for a need to log rotate
        if (( "$(wc -c ${_CSM_DEFAULT_LOG_FILE} | xargs | cut -d " " -f 1)" > ${_CSM_LOG_FILE_ROTATE_THRESHOLD} )); then
            _PYTHON_LOGROTATE_OUTPUT=$(${PYTHON} <<EOF
import os
import re

LOG_DIR="""${_CSM_LOG_DIR}"""
LOG_PREFIX="""${_CSM_LOG_PREFIX}"""
LOG_SUFFIX="""${_CSM_LOG_SUFFIX}"""

for file in reversed(sorted(os.listdir(LOG_DIR))):
    if file.startswith(LOG_PREFIX) and file.endswith(LOG_SUFFIX):
        pre = os.path.join(LOG_DIR, file)

        match = re.findall(r'\d+', file)
        if match:
            num = int(match[0])
            newNum = num + 1

            if newNum > 9:
                print ("LogRotate: %s -> DELETE" % pre)
                os.remove(pre)
                continue

        else:
            # no number, so this is the default file
            newNum = 0

        post = os.path.join(LOG_DIR, "%s%d%s" % (LOG_PREFIX, newNum, LOG_SUFFIX))
        print ("LogRotate: %s -> %s" % (pre, post))
        os.rename(pre, post)
EOF
)
            # ensure default file exists again
            touch ${_CSM_DEFAULT_LOG_FILE}

            # log the LogRotate messages
             _csm_log "$_PYTHON_LOGROTATE_OUTPUT"
        fi
    fi

    if [[ "$@" != "" ]]; then
        echo ${_CSM_DATETIME} "$@" >> ${_CSM_DEFAULT_LOG_FILE}
    else
        while read line
        do
            echo ${_CSM_DATETIME} ${line} >> ${_CSM_DEFAULT_LOG_FILE}
        done
    fi
}

function _csm_log_command() {
    _csm_log "Calling command: "$@""
    eval "$@" 2>&1  | sed 's/^/>  /' | _csm_log
    _RET=${PIPESTATUS[0]}
    _csm_log ">> Exit Code: ${_RET}"
    return ${_RET}
}

# install.sh should fill in the actual repo hash here.
export CSM_BASHRC_HASH="REPLACE_WITH_REPO_HASH"

# install.sh should fill in the version here.
export CSM_BASHRC_VERSION="REPLACE_WITH_VERSION"

_csm_log "dotfile startup"
_csm_log "CSM_BASHRC_HASH:    $CSM_BASHRC_HASH"
_csm_log "CSM_BASHRC_VERSION: $CSM_BASHRC_VERSION"

# ensure we have the global profile info
if [[ -f /etc/profile ]]; then
    source /etc/profile
fi;

# To get it to not ask me to use zsh
export BASH_SILENCE_DEPRECATION_WARNING=1

# check for homebrew updates once every 10 days instead of multiple times
export HOMEBREW_AUTO_UPDATE_SECS=864000

# setup an update checkpoint for my dotfiles
export CSM_UPDATE_CHECKPOINT_IN_SECONDS=86400

function create_update_checkpoint() {
    _csm_log "creating update checkpoint"
    echo $(( `date +%s` + $CSM_UPDATE_CHECKPOINT_IN_SECONDS )) > ~/.csm_update_checkpoint
}
export -f create_update_checkpoint

if [[ ! -f ~/.csm_update_checkpoint ]]; then
    create_update_checkpoint
fi;

chmod 777 ~/.csm_update_checkpoint
CSM_UPDATE_CHECKPOINT=`cat ~/.csm_update_checkpoint`

function _update_dotfiles() {
    _csm_log "attempting dotfile update"
    _INSTALL_SCRIPT=`curl --connect-timeout 1 --max-time 1 -s https://raw.githubusercontent.com/csm10495/dotfiles/master/install.sh`
    if [[ $? == 0 ]]; then
        PS1="" bash --norc -c "$_INSTALL_SCRIPT" &>/dev/null

        # reload (new) self
        source ~/.bashrc
        return 0
    fi;
    return 1
}
export -f _update_dotfiles

if (( "$CSM_UPDATE_CHECKPOINT" < `date +%s` )); then
    create_update_checkpoint
    _update_dotfiles
    if [[ "$?" == "0" ]]; then
        return
    fi
fi;

if [[ "$CSM_BASHRC_VERSION" != "" ]]; then
    if [[ "$CSM_BASHRC_VERSION" != REPLACE_WITH_VERSIO* ]]; then
        # do not print if not in ptty
        if [ -t 1 ]; then
            printf "\e[44mcsm10495/dotfiles: v$CSM_BASHRC_VERSION\e[49m";sleep .25;printf "\r                                        \r"
        fi
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
mkdir -p ~/.local/usr/local/bin

# is this a mac?
if [[ $(uname -s) == "Darwin" ]]; then
    export CSM_IS_MAC=1
    if [[ "$(_csm_cmd_exists brew)" == "true" ]]; then
        function _csm_user_package_install() {
            _csm_log_command brew install $1
            return $?
        }
    fi
else
    export CSM_IS_LINUX_LIKE=1
    if [[ "$(_csm_cmd_exists apt-get)" == "true" ]]; then
        curl --connect-timeout 1 --max-time 1 -s "https://raw.githubusercontent.com/Gregwar/notroot/master/notroot" > ~/.local/usr/local/bin/notroot
        if [[ "$?" == "0" ]]; then
            chmod +x ~/.local/usr/local/bin/notroot
            function _csm_user_package_install() {
                # Copy notroot to `root of local`. We do this so it installs in the correct .local place
                cp ~/.local/usr/local/bin/notroot ~/.local/
                chmod +x ~/.local/notroot

                # Run notroot
                _csm_log_command ~/.local/notroot install $1
                _RET=$?

                # delete copy
                rm ~/.local/notroot

                return $_RET
            }
        fi

    elif [[ "$(_csm_cmd_exists yum)" == "true" ]]; then
        # yum supported
        if [[ "$(_csm_cmd_exists yumdownloader)" == "true" ]]; then
            function _csm_user_package_install() {
                _TEMP_DIR=`mktemp -d`
                _RET=-1
                pushd "$_TEMP_DIR" > /dev/null
                _csm_log_command yumdownloader $1 --resolve
                popd > /dev/null
                if [[ $? == 0 ]]; then
                    pushd "$HOME/.local" > /dev/null
                    for filename in $_TEMP_DIR/*.rpm; do
                        _csm_log_command "rpm2cpio \"$filename\" 2>/dev/null | cpio -idv"
                    done
                    _RET=$?
                    popd > /dev/null
                fi;
                return $_RET
            }
        fi
    fi
fi

export -f _csm_user_package_install

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
        if [[ "$_BRANCH" == "HEAD" ]]; then
            _BRANCH=`git name-rev --name-only HEAD 2>/dev/null`
        fi

        if [[ "$_BRANCH" != "" ]]; then
            # see https://stackoverflow.com/a/5143914/3824093
            _OUT=`git status -s -uno 2>/dev/null`

            # no output means no changes
            if [[ "$_OUT" == "" ]]; then
                _EXTRA_STUFF=""
            else
                _EXTRA_STUFF="+"
            fi
            _GIT_INFO=" ($_BRANCH$_EXTRA_STUFF)"
        fi
    fi

    # show virtualenv info if available
    _VENV_INFO=""
    if [[ "$VIRTUAL_ENV" != "" ]]; then
        _VENV_INFO="(venv:${VIRTUAL_ENV##*/}) "
    fi

    # add to history right now
    history -a
    
    # add other things that end with _PS1
    _OTHER_PS1S=""
    for i in $(awk 'BEGIN{for(v in ENVIRON) print v}' | grep _PS1$); do
        # make sure there is a space between ps1s
        if [[ $_OTHER_PS1S != "" ]]; then
            _OTHER_PS1S="$_OTHER_PS1S ${!i}"
        else
            _OTHER_PS1S="${!i}"
        fi
    done
    
    # make sure there is a space at the end
    if [[ $_OTHER_PS1S != "" ]]; then
        _OTHER_PS1S="$_OTHER_PS1S "
    fi
    
    export PS1="$_OTHER_PS1S$_VENV_INFO\[\e[36m\]\u\[\e[m\]@\[\e[32m\]\h\[\e[m\]:\[\e[33m\]\w\[\e[m\]$_GIT_INFO \[\e[97;41m\]$RETVAL\[\e[m\]\[\e[35m\]\\$\[\e[m\]\[\e[40m\] \[\e[m\]"
}

export -f _set_ps1
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

# colored man pages
# see https://unix.stackexchange.com/questions/119/colors-in-man-pages
export LESS_TERMCAP_mb=$'\e[1;31m'     # begin bold
export LESS_TERMCAP_md=$'\e[1;33m'     # begin blink
export LESS_TERMCAP_so=$'\e[01;44;37m' # begin reverse video
export LESS_TERMCAP_us=$'\e[01;37m'    # begin underline
export LESS_TERMCAP_me=$'\e[0m'        # reset bold/blink
export LESS_TERMCAP_se=$'\e[0m'        # reset reverse video
export LESS_TERMCAP_ue=$'\e[0m'        # reset underline
export GROFF_NO_SGR=1                  # for konsole and gnome-terminal

# percentage in manpages
export MANPAGER='less -s -M +Gg'

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

# append to history, do not overwrite
shopt -s histappend

# allow recursive globs ** (go to /dev/null since not every shell supports globstar)
shopt -s globstar 2>/dev/null

## Key bindings
### Tested on WSL Bash

# Ctrl-Del to delete next word
bind '"\e[3;5~":kill-word' &>/dev/null

# Ctrl-Backspace to delete last word
bind "\C-h":backward-kill-word &>/dev/null

# Arrow up to do a history search back
bind '"\e[A": history-search-backward' &>/dev/null

# Arrow down to do a history search forward
bind '"\e[B": history-search-forward' &>/dev/null

# Install and post install steps

# get brew if mac
if [[ "$CSM_IS_MAC" == "1" ]]; then
    if [[ $(which brew 2>/dev/null) == "" ]]; then
        _csm_log "installing brew"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
    fi;
fi;

# Do i have a command to timeout 'long-running' commands
CSM_TIMEOUT_CMD_TIMEOUT='3s'
CSM_TIMEOUT_CMD=''
if [[ "$(_csm_cmd_exists timeout)" == "true" ]]; then
    CSM_TIMEOUT_CMD="timeout -k 1s $CSM_TIMEOUT_CMD_TIMEOUT"
elif [[ "$(_csm_cmd_exists gtimeout)" == "true" ]]; then
    CSM_TIMEOUT_CMD="gtimeout -k 1s $CSM_TIMEOUT_CMD_TIMEOUT"
fi;

# Do i have kyrat? If not download it.
if [[ (! -d ~/.local/share/kyrat) && ("$CSM_HAS_GIT" == "1") ]]; then
    _csm_log "cloning kyrat"
    _csm_log_command $CSM_TIMEOUT_CMD git clone https://github.com/fsquillace/kyrat ~/.local/share/kyrat
    if [[ "$?" != "0" ]]; then
        _csm_log "kyrat clone failed"
        rm -rf ~/.local/share/kyrat
    fi;
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
export PATH=$PATH:~/.local/share/kyrat/bin:~/.local/usr/bin:~/.local/usr/local/bin:~/.local/usr/:~/.local/usr/games:~/.local/usr/local/games:~/.local/bin

# i'd greatly prefer nano to vi so see if we can get it.
CSM_NANO=""
if [[ "$(_csm_cmd_exists nano)" == "true" ]]; then
    CSM_NANO=`which nano`
else
    _csm_user_package_install nano
    if [[ $? == 0 ]]; then
        _csm_log "... installed nano"
        CSM_NANO=`which nano`
    fi
fi;

# to get nano as the default editor in terminal
export EDITOR=$CSM_NANO

function _title() {
    echo -en "\033]0;$1\a"
    _LAST_TITLE="$1"
}

# if we can't find kyrat or ssh, don't mess with ssh anymore
if [[ "$(_csm_cmd_exists ssh)" == "true" ]]; then
    if [[ "$(which kyrat 2>/dev/null)" != "" ]]; then
        # kyrat will source... don't take its definitions.
        # auto use kyrat as ssh
        unalias _ssh 2>/dev/null | true
        alias _ssh="`which ssh`"

        function ssh() {
            if [[ "$HIDE_KYRAT_SSH_BANNER" != "1" ]]; then
                printf "\n\e[1m Using kyrat... use _ssh to use the real ssh executable\e[0m \n\n"
            fi;
            
            __SAVED="$_LAST_TITLE"
            _title "$@"
            function _undo_title() {
                _title "$__SAVED"
            }

            trap _undo_title SIGINT
            kyrat "$@"
            RETCODE=$?

            # clear trap
            trap - SIGINT
            _undo_title

            return $RETCODE
        }
    fi;
fi;

# Load git autocompletion if we have git
if [[ "$CSM_HAS_GIT" == "1" && -f ~/.git-completion.bash ]]; then
    source ~/.git-completion.bash
fi
