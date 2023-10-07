#!/bin/bash

# ####################################
## Logging start

function _csm_now_in_seconds() {
    date +%s
}

_CSM_LOG_DIR="$HOME/.local/var/log/dotfiles"
_CSM_LOG_FILE=${_CSM_LOG_DIR}/log.txt
_CSM_LOG_FILE_TMP=$_CSM_LOG_FILE.tmp
_CSM_MAX_LOG_FILE_LINES=10000

# make log directory
mkdir -p $_CSM_LOG_DIR

# chop if needed (but make sure the file exists.. otherwise skip)
if [ -f $_CSM_LOG_FILE ]; then
    tail -n $_CSM_MAX_LOG_FILE_LINES $_CSM_LOG_FILE > $_CSM_LOG_FILE_TMP
    mv -f $_CSM_LOG_FILE_TMP $_CSM_LOG_FILE
fi

function _csm_log() {
    _CSM_DATETIME=$(date --rfc-3339=ns 2>/dev/null)
    if [[ "$_CSM_DATETIME" == "" ]]; then
        # try gdate for gnu date on mac
        _CSM_DATETIME=$(gdate --rfc-3339=ns 2>/dev/null)
    fi

    # passed args.. log them
    if [[ "$@" != "" ]]; then
        echo ${_CSM_DATETIME} [$$] "$@" >> ${_CSM_LOG_FILE}
    else
        # piped stuff.. log the lines piped
        while read -r line; do
            echo ${_CSM_DATETIME} [$$] ${line} >> ${_CSM_LOG_FILE}
        done
    fi
}

function _csm_log_command() {
    _csm_log "Calling command: "$@""
    eval "$@" 2>&1  | sed 's/^/>  /' | _csm_log
    _RET=${PIPESTATUS[0]}
    _csm_log ">> Exit Code ($@): ${_RET}"
    return ${_RET}
}

# install.sh should fill in the actual repo hash here.
export CSM_BASHRC_HASH="REPLACE_WITH_REPO_HASH"

# install.sh should fill in the version here.
export CSM_BASHRC_VERSION="REPLACE_WITH_VERSION"

_csm_log "dotfile startup"
_csm_log "CSM_BASHRC_HASH:    $CSM_BASHRC_HASH"
_csm_log "CSM_BASHRC_VERSION: $CSM_BASHRC_VERSION"
# Logging end
# ####################################
# Commands needed elsewhere start =========================================================
function _csm_run_in_background() {
    if [ -z "$CSM_ALWAYS_FOREGROUND" ]; then
        # Run the given command in the background without job-control messaging, etc.
        ( _csm_log_command "$@" >/dev/null 2>&1 & disown ) &>/dev/null
    else
        _csm_log_command "$@"
    fi

}
export -f _csm_run_in_background
# Commands needed elsewhere end ===========================================================
# ####################################
# Applied everywhere start ==========================================================

# Configure ipython default profile
# As of ipython 8.9, autocomplete on up/down arrows works differently.
# This goes back to the old behavior if there is no existing user config file
_DEFAULT_IPYTHON_CONFIG=~/.ipython/profile_default/ipython_config.py
if [[ ! -f "${_DEFAULT_IPYTHON_CONFIG}" ]]; then
    mkdir -p "$(dirname ${_DEFAULT_IPYTHON_CONFIG})"
    echo "c.TerminalInteractiveShell.autosuggestions_provider = 'AutoSuggestFromHistory'" > "${_DEFAULT_IPYTHON_CONFIG}"
fi

# ensure we have the global profile info
if [[ -f /etc/profile ]]; then
    source /etc/profile
fi

# make certain dirs appear and add them to path
mkdir -p ~/.local/usr/local/bin
mkdir -p ~/.local/usr/bin
export PATH=$PATH:~/.local/share/kyrat/bin:~/.local/usr/bin:~/.local/usr/local/bin:~/.local/usr/:~/.local/usr/games:~/.local/usr/local/games:~/.local/bin

# Applied everywhere end ============================================================
# ####################################
# Hardcoded exports start ===========================================================

# To get it to not ask me to use zsh
export BASH_SILENCE_DEPRECATION_WARNING=1

# check for homebrew updates once every 10 days instead of multiple times
export HOMEBREW_AUTO_UPDATE_SECS=864000

# setup an update checkpoint for my dotfiles
export CSM_UPDATE_CHECKPOINT_IN_SECONDS=86400

# Hardcoded exports end ===========================================================
# ####################################
# Constants setup start ===========================================================

export CSM_IS_MAC=$([[ $(uname -s) == "Darwin" ]] && echo true || echo false)
export CSM_IS_LINUX_LIKE=$([[ $(uname -s) == "Linux" ]] && echo true || echo false)
export CSM_HAS_CURL=$(command -v curl &>/dev/null && echo true || echo false)
export CSM_HAS_GIT=$(command -v git &>/dev/null && echo true || echo false)
export CSM_HAS_SSH=$(command -v ssh &>/dev/null && echo true || echo false)
export CSM_HAS_APT_GET=$(command -v apt-get &>/dev/null && echo true || echo false)
export CSM_HAS_YUM=$(command -v yum &>/dev/null && echo true || echo false)
export CSM_HAS_BREW=$(command -v brew &>/dev/null && echo true || echo false)
export CSM_HAS_TIMEOUT_CMD=$(command -v timeout &>/dev/null && echo true || echo false)
export CSM_HAS_GTIMEOUT_CMD=$(command -v gtimeout &>/dev/null && echo true || echo false)
export CSM_HAS_AWK=$(command -v awk &>/dev/null && echo true || echo false)
export CSM_HAS_NANO=$(command -v nano &>/dev/null && echo true || echo false)
export CSM_NANO=$(command -v nano 2>/dev/null)

# do not use ~ as it won't be expanded when used later
export CSM_LOCAL_NOTROOT_CMD="$HOME/.local/usr/local/bin/notroot"
export CSM_LOCAL_NOTROOT_CMD_DL="$HOME/.local/usr/local/bin/notroot.tmp"
export CSM_KYRAT_DIR="$HOME/.local/share/kyrat"

# These are functions since their values can easily change mid-session
function _csm_has_yumdownloader_and_dependencies() {
    if command -v yumdownloader && command -v cpio && command -v rpm2cpio; then
        return 0
    fi
    return 1
}

export CLICOLOR=1
export LSCOLORS=ExFxBxDxCxegedabagacad

if [[ $CSM_HAS_NANO == true ]]; then
    # to get nano as the default editor in terminal if we have it
    export EDITOR=$CSM_NANO
fi

if [[ "$CSM_IS_MAC" == true ]]; then
    alias ls='ls -GFh'
elif [[ "$CSM_IS_LINUX_LIKE" == true ]]; then
    alias ls='ls -C --color=auto -h'
fi

# prefix for commands to have them timeout
CSM_TIMEOUT_CMD_TIMEOUT='3s'
CSM_TIMEOUT_CMD=''
if [[ "$CSM_HAS_TIMEOUT_CMD" == "true" ]]; then
    CSM_TIMEOUT_CMD="timeout -k 1s $CSM_TIMEOUT_CMD_TIMEOUT"
elif [[ "$CSM_HAS_GTIMEOUT_CMD" == "true" ]]; then
    CSM_TIMEOUT_CMD="gtimeout -k 1s $CSM_TIMEOUT_CMD_TIMEOUT"
fi

# Load git autocompletion if we have git
if [[ "$CSM_HAS_GIT" == "true" && -f ~/.git-completion.bash ]]; then
    source ~/.git-completion.bash
fi

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

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# append to history, do not overwrite
shopt -s histappend

# allow recursive globs ** (go to /dev/null since not every shell supports globstar)
shopt -s globstar 2>/dev/null

# Set a higher open file limit
# Some shells don't like huge values, so do a lower one in that case.
ulimit -S -n 40000 &>/dev/null || ulimit -S -n 4000 &>/dev/null

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

# add local lib paths (only support x64 and x86)
if [[ "$(uname -m)" == "x86_64" ]]; then
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:~/.local/usr/lib64/
#else
    #tbd fix for arm macs
    #export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:~/.local/usr/lib/
fi

# Constants setup end ===========================================================
# ####################################
# shell macros start ======================================================

function _title() {
    echo -en "\033]0;$1\a"
    _LAST_TITLE="$1"
}

# shell macros end ========================================================
# ####################################
# Updater start ===========================================================

function create_update_checkpoint() {
    _csm_log "creating update checkpoint"
    echo $(( $(_csm_now_in_seconds) + $CSM_UPDATE_CHECKPOINT_IN_SECONDS )) > ~/.csm_update_checkpoint
}
export -f create_update_checkpoint

if [[ ! -f ~/.csm_update_checkpoint ]]; then
    create_update_checkpoint
fi

CSM_UPDATE_CHECKPOINT=$(cat ~/.csm_update_checkpoint)

# handle case where the update checkpoint file is somehow corrupt
if ((CSM_UPDATE_CHECKPOINT <= 0)); then
    _csm_log "Possibly corrupted update checkpoint. Attempting to force update."
    CSM_UPDATE_CHECKPOINT=0
fi

function _update_dotfiles() {
    _csm_log "attempting dotfile update"
    if [[ "$CSM_HAS_CURL" == "true" ]]; then
        _INSTALL_SCRIPT=$(curl --connect-timeout 5 --max-time 5 -s https://raw.githubusercontent.com/csm10495/dotfiles/master/install.sh)
        if [[ $? == 0 ]]; then
            PS1="" _csm_log_command bash --norc -c "$_INSTALL_SCRIPT"

            # reload (new) self
            source ~/.bashrc
            return 0
        fi
        _csm_log "curl failed to download install.sh"
        return 1
    fi
    _csm_log "couldn't update dotfiles, because curl is not available"
    return 2
}
export -f _update_dotfiles

# trigger update
if (( "$CSM_UPDATE_CHECKPOINT" < $(_csm_now_in_seconds) )); then
    create_update_checkpoint
    _csm_run_in_background _update_dotfiles
fi;

if [[ "$CSM_BASHRC_VERSION" != "" ]]; then
    # don't print if we don't have the version
    if [[ "$CSM_BASHRC_VERSION" != REPLACE_WITH_VERSIO* ]]; then
        # do not print if not in ptty
        if [ -t 1 ]; then
            printf "\e[44mcsm10495/dotfiles: v$CSM_BASHRC_VERSION\e[49m";sleep .25;printf "\r                                        \r"
        fi
    fi
fi

# Updater end =============================================================
# ####################################
# local package install start ===========================================================

function _csm_user_package_install() {
    # default does nothing
    _csm_log "default no-op _csm_user_package_install called to install $1"
    return 1
}

if [[ $CSM_IS_MAC == true ]] && [[ $CSM_HAS_BREW == true ]]; then
    function _csm_user_package_install() {
        _csm_log_command brew install $1
    }
elif [[ $CSM_IS_LINUX_LIKE == true ]] && [[ $CSM_HAS_APT_GET == true ]]; then
    function _ensure_not_root() {
        if [ -f "$CSM_LOCAL_NOTROOT_CMD" ]; then
            return 0
        fi

        if [[ $CSM_HAS_CURL == true ]]; then
            if [[ ! -f $CSM_LOCAL_NOTROOT_CMD_DL ]]; then
                # download notroot to a tmp location first! We can't have something in the real location unless the download is complete.
                if curl --connect-timeout 5 --max-time 5 -s "https://raw.githubusercontent.com/Gregwar/notroot/master/notroot" > "$CSM_LOCAL_NOTROOT_CMD_DL"; then
                    chmod +x "$CSM_LOCAL_NOTROOT_CMD_DL"
                    mv -f $CSM_LOCAL_NOTROOT_CMD_DL $CSM_LOCAL_NOTROOT_CMD
                    return 0
                else
                    _csm_log "Failed to download notroot"
                fi
            else
                _csm_log "notroot download already in progress"
            fi
        else
            _csm_log "couldn't download notroot, because curl is not available"
        fi
        return 1
    }

    function _csm_user_package_install() {
        if [ -f "$CSM_LOCAL_NOTROOT_CMD" ]; then
            # Copy notroot to `root of local`. We do this so it installs in the correct .local place
            # give a random postfix to make this thread safe
            _LOCAL_NOT_ROOT=~/.local/notroot$RANDOM

            cp "$CSM_LOCAL_NOTROOT_CMD" $_LOCAL_NOT_ROOT
            chmod +x $_LOCAL_NOT_ROOT

            # Run notroot
            _csm_log_command $_LOCAL_NOT_ROOT install $1
            _RET=$?

            # delete copy
            rm $_LOCAL_NOT_ROOT

            return $_RET
        else
            _csm_log "notroot not available.. cannot install $1"
            return 1
        fi
    }

    if [ ! -f $CSM_LOCAL_NOTROOT_CMD ]; then
        _csm_run_in_background _ensure_not_root
    fi


elif [[ $CSM_IS_LINUX_LIKE ]] && [[ $CSM_HAS_YUM ]]; then
    function _csm_user_package_install() {
        if _csm_has_yumdownloader_and_dependencies; then
            _TEMP_DIR=$(mktemp -d)
            _RET=-1
            pushd "$_TEMP_DIR" > /dev/null
            _csm_log_command timeout 25 yumdownloader -y $1 --resolve
            _RET=$?
            popd > /dev/null
            if [[ $_RET == 0 ]]; then
                pushd "$HOME/.local" > /dev/null
                for filename in $_TEMP_DIR/*.rpm; do
                    _csm_log_command "rpm2cpio \"$filename\" 2>/dev/null | cpio -idv"
                done
                _RET=$?
                popd > /dev/null
            else
                _csm_log "yumdownloader failed to download $1"
            fi
            return $_RET
        else
            _csm_log "yumdownloader and dependencies not available.. cannot install $1"
            return 1
        fi
    }
fi

export -f _csm_user_package_install

# local package install end ===========================================================
# ####################################
# ps1 manipulation start ===========================================================

function _get_git_branch() {
    # https://stackoverflow.com/a/36504296/3824093 and some edits
    git rev-parse --abbrev-ref HEAD 2> /dev/null | grep -v HEAD || \
    git name-rev --name-only HEAD 2>/dev/null | grep -v HEAD || \
    git describe --exact-match HEAD 2> /dev/null || \
    git rev-parse --short HEAD 2> /dev/null
}

# to get a colorful terminal
function _set_ps1() {
    RETVAL=$?

    # prompt-related... these things are in this function so if a new shell starts
    #  and this file was carried over by kyrat (and not in ~/.bashrc)
    #  ... this matters because it won't be there to sourced by a subshell and only
    #  $PROMPT_COMMAND is saved, not the other variables.
    #  ... If the colors are not carried over, we get an ugly ps1.
    function ansi_code_escape_for_ps1(){
        # ansi codes should have \[ in front and \] in back
        #  this fixes issues related to bash knowing the length of the prompt
        printf "\["${1}"\]"
    }

    function get_ansi_text_color() {
        RED=$1
        GREEN=$2
        BLUE=$3
        printf $(ansi_code_escape_for_ps1 "\e[38;2;$1;$2;$3m")
    }

    _PS1_ANSI_TEXT_RED=$(get_ansi_text_color 255 0 0)
    _PS1_ANSI_TEXT_GREEN=$(get_ansi_text_color 7 166 38)
    _PS1_ANSI_TEXT_BLUE=$(get_ansi_text_color 82 166 235)
    _PS1_ANSI_TEXT_MAGENTA=$(get_ansi_text_color 211 34 214)
    _PS1_ANSI_TEXT_YELLOW=$(get_ansi_text_color 199 188 32)
    _PS1_ANSI_TEXT_RESET=$(ansi_code_escape_for_ps1 "\e[0m")

    if [[ $RETVAL == "0" ]]; then
        RETVAL=""
    else
        RETVAL="$RETVAL$_PS1_ANSI_TEXT_RESET "
    fi

    _GIT_INFO=""
    if [[ "$CSM_HAS_GIT" == 1 ]]; then
        _BRANCH="$(_get_git_branch)"

        if [[ "$_BRANCH" != "" ]]; then
            # see https://stackoverflow.com/a/5143914/3824093
            _OUT=$(git status -s -uno 2>/dev/null)

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
    if [[ "$CSM_HAS_AWK" == true ]]; then
        for i in $(awk 'BEGIN{for(v in ENVIRON) print v}' | grep _PS1$); do
            # make sure there is a space between ps1s
            if [[ $_OTHER_PS1S != "" ]]; then
                _OTHER_PS1S="$_OTHER_PS1S ${!i}"
            else
                _OTHER_PS1S="${!i}"
            fi
        done
    fi

    # make sure there is a space at the end
    if [[ $_OTHER_PS1S != "" ]]; then
        _OTHER_PS1S="$_OTHER_PS1S "
    fi

    # todo... replace other raw ansi escape sequences
    export PS1="$_OTHER_PS1S$_VENV_INFO${_PS1_ANSI_TEXT_BLUE}\u${_PS1_ANSI_TEXT_RESET}@${_PS1_ANSI_TEXT_GREEN}\h:${_PS1_ANSI_TEXT_YELLOW}\w${_PS1_ANSI_TEXT_RESET}$_GIT_INFO \[\e[97;41m\]$RETVAL${_PS1_ANSI_TEXT_RESET}${_PS1_ANSI_TEXT_MAGENTA}\\$ ${_PS1_ANSI_TEXT_RESET}"
}

export -f _set_ps1
export PROMPT_COMMAND=_set_ps1

# ps1 manipulation end ===========================================================
# ####################################
# personalized downloads start ===================================================

# Kyrat
if [ ! -d ~/.local/share/kyrat ] && [[ $CSM_HAS_GIT == true ]]; then
    function _download_kyrat() {
        _csm_log "cloning kyrat"
        if ! $CSM_TIMEOUT_CMD git clone --depth 1 https://github.com/fsquillace/kyrat "$CSM_KYRAT_DIR"; then
            _csm_log "kyrat clone failed"
            rm -rf ~/.local/share/kyrat
            return 1
        fi
        _csm_log "kyrat clone succeeded"
    }
    _csm_run_in_background _download_kyrat
fi

# Nano
if [[ "$CSM_HAS_NANO" != "true" ]]; then
    _csm_log "nano not found... attempting to install in the background"
    _csm_run_in_background _csm_user_package_install nano
fi

# personalized downloads end =====================================================
# ####################################
# functionality overrides start ==================================================

# ssh -> call kyrat
if [[ $CSM_HAS_SSH == true ]] && [ -d $CSM_KYRAT_DIR ]; then
    # kyrat will source... don't take its definitions.
    # auto use kyrat as ssh
    unalias _ssh 2>/dev/null | true
    alias _ssh="$(which ssh)"

    function ssh() {
        if [[ "$HIDE_KYRAT_SSH_BANNER" == "" ]]; then
            printf "\n\e[1m Using kyrat... use _ssh to use the real ssh executable\e[0m \n\n"
        fi

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
fi

# functionality overrides end ====================================================
# ####################################
