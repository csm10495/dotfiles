#!/bin/bash

pushd ~
curl https://raw.githubusercontent.com/csm10495/dotfiles/master/home/.bash_profile > ~/.bash_profile
curl https://raw.githubusercontent.com/csm10495/dotfiles/master/home/.bashrc > ~/.bashrc
popd