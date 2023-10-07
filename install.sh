#!/bin/bash

if ! command -v curl &>/dev/null; then
    echo "curl is required to run this script. Please install it and re-run!"
    exit 1
fi

# Without jq , we can't parse json, so just use master.
if command -v jq &>/dev/null; then
    HAS_JQ=true
else
    HAS_JQ=false
fi

# Without sed, we can't do find/replace.. so just use master
if command -v sed &>/dev/null; then
    HAS_SED=true
else
    HAS_SED=false
fi

# need sed and jq to use the hash
if [[ $HAS_SED == "true" ]] && [[ $HAS_JQ == "true" ]]; then
    USE_HASH=true
else
    USE_HASH=false
fi

CURL_LOW_TIMEOUT="curl -s --connect-timeout 5 --max-time 5 "

if [[ -n "$GITHUB_TOKEN" ]]; then
    echo "Adding Github token to curl requests"
    CURL_LOW_TIMEOUT="$CURL_LOW_TIMEOUT --header \"Authorization: Bearer $GITHUB_TOKEN\""
fi

if [[ $USE_HASH == true ]]; then

    COMMIT_HASH=$($CURL_LOW_TIMEOUT https://api.github.com/repos/csm10495/dotfiles/branches/master | jq -r .commit.sha)

    if [ -z "$COMMIT_HASH" ]; then
        echo "Couldn't calculate commit hash.. falling back to master"
        USE_HASH=false
    else
        # download corresponding files
        $CURL_LOW_TIMEOUT https://raw.githubusercontent.com/csm10495/dotfiles/$COMMIT_HASH/home/.bash_profile > /tmp/.bash_profile
        $CURL_LOW_TIMEOUT https://raw.githubusercontent.com/csm10495/dotfiles/$COMMIT_HASH/home/.bashrc > /tmp/.bashrc

        # get the auto-incremented version number
        VERSION=$($CURL_LOW_TIMEOUT -I "https://api.github.com/repos/csm10495/dotfiles/commits?per_page=1&sha=$COMMIT_HASH" | sed -n 's/.*&page=\(.*\)>.*/\1/p')

        if [ -n "$VERSION" ]; then
            # replace the version number in the bashrc
            sed -i "s/REPLACE_WITH_VERSION/$VERSION/g" /tmp/.bashrc
            sed -i "s/REPLACE_WITH_REPO_HASH/$COMMIT_HASH/g" /tmp/.bashrc
        else
            echo "Couldn't calculate version... falling back to master"
            USE_HASH=false
        fi
    fi
fi

# Not using else since we could set USE_HASH to false in the above
if [[ $USE_HASH == false ]]; then
    echo "Falling to legacy install behavior (either no commit hash, no sed/jq, or other issue)"
    $CURL_LOW_TIMEOUT https://raw.githubusercontent.com/csm10495/dotfiles/master/home/.bash_profile > /tmp/.bash_profile
    $CURL_LOW_TIMEOUT https://raw.githubusercontent.com/csm10495/dotfiles/master/home/.bashrc > /tmp/.bashrc
fi

# Lets also add git-completion
$CURL_LOW_TIMEOUT -s https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash > /tmp/.git-completion.bash

# Overwrite current files with the ones we downloaded.
# We don't want to save directly to the final location in case update/install gets stopped mid way.
yes | cp -rf /tmp/.bash_profile ~/.bash_profile
yes | cp -rf /tmp/.bashrc ~/.bashrc
yes | cp -rf /tmp/.git-completion.bash ~/.git-completion.bash

echo Done!
