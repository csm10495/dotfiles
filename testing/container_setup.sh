#!/bin/bash

GROUP=csm10495group
USER=csm10495

if which groupadd &>/dev/null; then
    echo "groupadd supported"
    groupadd $GROUP
elif which addgroup &>/dev/null; then
    echo "addgroup supported"
    addgroup $GROUP
else
    echo "manually editing /etc/group"
    echo "$GROUP:x:10001:$USER" >> /etc/group
fi

if which useradd &>/dev/null; then
    echo "useradd supported"
    useradd -d /home/$USER $USER -g $GROUP
elif which adduser &>/dev/null; then
    echo "adduser supported"
    yes | adduser --home /home/$USER $USER --ingroup $GROUP --disabled-password --disabled-login
else
    echo "manually editing /etc/passwd"
    echo "$USER:x:10000:10001:$USER:/home/$USER:/bin/false" >> /etc/passwd
fi

chown $USER:$GROUP /home/$USER

# i can't believe some containers are missing which. I've never seen a real host like that.

if apt-get --version &>/dev/null; then
    echo "apt-get supported"
    apt-get update -y
    apt-get install -y curl ssh git jq
fi

if yum --version &>/dev/null; then
    echo "yum supported"
    # yum-utils: yumdownloader
    # cpio: cpio
    yum install -y which yum-utils cpio curl openssh-clients git ca-certificates
fi

if ! command -v jq &>/dev/null; then
    mkdir -p /usr/local/bin
    chmod 775 /usr/local/bin

    if [[ $(uname -m) == "x86_64" ]]; then
        if ! curl -L -o /usr/local/bin/jq https://github.com/jqlang/jq/releases/download/jq-1.7/jq-linux-amd64; then
            echo "Failed to download jq from github"
            exit 1
        fi
    else
        # fail the build right now
        echo "Unknown arch for jq: $(uname -m)"
        exit 2
    fi
    chmod 775 /usr/local/bin/jq
    chmod +x /usr/local/bin/jq
fi