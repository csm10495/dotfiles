#!/bin/bash

if [[ `which curl 2>/dev/null` == "" ]]; then
    echo "curl is required to run this script. Please install it and re-run!"
    exit 1
fi

PYTHON=""
if [[ `which python3 2>/dev/null` != "" ]]; then
    PYTHON="python3"
elif [[ `which python 2>/dev/null` != "" ]]; then
    PYTHON="python"
elif [[ `which python2 2>/dev/null` != "" ]]; then
    PYTHON="python2"
fi

COMMIT_HASH=`curl -s https://api.github.com/repos/csm10495/dotfiles/branches/master | $PYTHON -c "import sys, json; print(json.loads(sys.stdin.read())['commit']['sha'].upper())" 2>/dev/null`
if [[ "$COMMIT_HASH" != "" && "$PYTHON" != "" ]]; then

    curl -s https://raw.githubusercontent.com/csm10495/dotfiles/$COMMIT_HASH/home/.bash_profile > ~/.bash_profile
    curl -s https://raw.githubusercontent.com/csm10495/dotfiles/$COMMIT_HASH/home/.bashrc > ~/.bashrc
    
    printf $COMMIT_HASH | $PYTHON -c "import os, sys; text = open(os.path.expanduser('~/.bashrc'), 'r').read();open(os.path.expanduser('~/.bashrc'), 'w').write(text.replace('REPLACE_WITH_REPO_HASH', sys.stdin.read().strip()))"

    VERSION=`curl -I -s "https://api.github.com/repos/csm10495/dotfiles/commits?per_page=1&sha=$COMMIT_HASH" | grep "&page=" | $PYTHON -c "import re,sys; print(re.findall(r'page=(\d+?)\>\; rel=\"last\"', sys.stdin.read())[0])" 2> /dev/null`
    if [[ "$VERSION" != "" ]]; then
        printf $VERSION | $PYTHON -c "import os, sys; text = open(os.path.expanduser('~/.bashrc'), 'r').read();open(os.path.expanduser('~/.bashrc'), 'w').write(text.replace('REPLACE_WITH_VERSION', sys.stdin.read().strip()))"
    fi

else
    # if we can't talk to the github api (maybe we're rate-limited?), just fall back to grabbing master.
    echo "Falling to legacy install behavior (either no commit hash or no python)"
    curl -s https://raw.githubusercontent.com/csm10495/dotfiles/master/home/.bash_profile > ~/.bash_profile
    curl -s https://raw.githubusercontent.com/csm10495/dotfiles/master/home/.bashrc > ~/.bashrc
fi

# Lets also add git-completion
curl -s https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash > ~/.git-completion.bash

echo Done!
