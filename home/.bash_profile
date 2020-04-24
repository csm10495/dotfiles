#!/bin/bash

if [[ -z "$CSM_BASH_PROFILE_EXECUTED" ]]; then
    export CSM_BASH_PROFILE_EXECUTED=1
    
    source ~/.bashrc
fi;