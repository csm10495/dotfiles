#!/bin/bash

if [[ -z "$CSM_BASH_PROFILE_EXECUTED" ]]; then
    # i'm guessing it doesn't matter if we re-source bashrc
    # export CSM_BASH_PROFILE_EXECUTED=1

    source ~/.bashrc
fi;