#!/bin/bash

if [[ $(which curl 2>/dev/null) == "" ]]; then
    echo "curl is required to run this script. Please install it and re-run!"
    exit 1
fi

PYTHON=""
if [[ $(which python3 2>/dev/null) != "" ]]; then
    PYTHON="python3"
elif [[ $(which python 2>/dev/null) != "" ]]; then
    PYTHON="python"
elif [[ $(which python2 2>/dev/null) != "" ]]; then
    PYTHON="python2"
fi

CURL_LOW_TIMEOUT="curl --connect-timeout 1 --max-time 1 "
COMMIT_HASH=$($CURL_LOW_TIMEOUT -s https://api.github.com/repos/csm10495/dotfiles/branches/master | $PYTHON -c "import sys, json; print(json.loads(sys.stdin.read())['commit']['sha'].upper())" 2>/dev/null)
if [[ "$COMMIT_HASH" != "" && "$PYTHON" != "" ]]; then

    $CURL_LOW_TIMEOUT -s https://raw.githubusercontent.com/csm10495/dotfiles/$COMMIT_HASH/home/.bash_profile > /tmp/.bash_profile
    $CURL_LOW_TIMEOUT -s https://raw.githubusercontent.com/csm10495/dotfiles/$COMMIT_HASH/home/.bashrc > /tmp/.bashrc

    VERSION=$($CURL_LOW_TIMEOUT -I -s "https://api.github.com/repos/csm10495/dotfiles/commits?per_page=1&sha=$COMMIT_HASH" | grep "&page=" | $PYTHON -c "import re,sys; print(re.findall(r'page=(\d+?)\>\; rel=\"last\"', sys.stdin.read())[0])" 2> /dev/null)
    if [[ "$VERSION" != "" ]]; then
        printf $VERSION | $PYTHON -c "import os, sys; text = open(os.path.expanduser('/tmp/.bashrc'), 'r').read();open(os.path.expanduser('/tmp/.bashrc'), 'w').write(text.replace('REPLACE_WITH_VERSION', sys.stdin.read().strip()))"
    fi

    printf $COMMIT_HASH | $PYTHON -c "import os, sys; text = open(os.path.expanduser('/tmp/.bashrc'), 'r').read();open(os.path.expanduser('/tmp/.bashrc'), 'w').write(text.replace('REPLACE_WITH_REPO_HASH', sys.stdin.read().strip()))"
else
    # if we can't talk to the github api (maybe we're rate-limited?), just fall back to grabbing master.
    echo "Falling to legacy install behavior (either no commit hash or no python)"
    $CURL_LOW_TIMEOUT -s https://raw.githubusercontent.com/csm10495/dotfiles/master/home/.bash_profile > /tmp/.bash_profile
    $CURL_LOW_TIMEOUT -s https://raw.githubusercontent.com/csm10495/dotfiles/master/home/.bashrc > /tmp/.bashrc
fi

# Lets also add git-completion
$CURL_LOW_TIMEOUT -s https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash > /tmp/.git-completion.bash

# Overwrite current files with the ones we downloaded.
# We don't want to save directly to the final location in case update/install gets stopped mid way.
yes | cp -rf /tmp/.bash_profile ~/.bash_profile
yes | cp -rf /tmp/.bashrc ~/.bashrc
yes | cp -rf /tmp/.git-completion.bash ~/.git-completion.bash

echo Done!
