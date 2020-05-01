#!/bin/bash

if [[ `which curl 2>/dev/null` == "" ]]; then
    echo "curl is required to run this script. Please install it and re-run!"
    exit 1
fi

curl -s https://raw.githubusercontent.com/csm10495/dotfiles/master/home/.bash_profile > ~/.bash_profile
curl -s https://raw.githubusercontent.com/csm10495/dotfiles/master/home/.bashrc > ~/.bashrc

PYTHON=""

if [[ `which python3 2>/dev/null` != "" ]]; then
    PYTHON="python3"
elif [[ `which python 2>/dev/null` != "" ]]; then
    PYTHON="python"
elif [[ `which python2 2>/dev/null` != "" ]]; then
    PYTHON="python2"
fi

if [[ "$PYTHON" != "" ]]; then
    COMMIT_HASH=`curl -s https://api.github.com/repos/csm10495/dotfiles/branches/master | $PYTHON -c "import sys, json; print(json.loads(sys.stdin.read())['commit']['sha'].upper())" 2>/dev/null`
    if [[ "$COMMIT_HASH" != "" ]]; then
        printf $COMMIT_HASH | $PYTHON -c "import os, sys; text = open(os.path.expanduser('~/.bashrc'), 'r').read();open(os.path.expanduser('~/.bashrc'), 'w').write(text.replace('REPLACE_WITH_REPO_HASH', sys.stdin.read().strip()))"
    fi
fi

echo Done!
