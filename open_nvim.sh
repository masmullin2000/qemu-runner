#!/bin/bash

NEORUNNING=$(ps -A | grep neovide)
if [[ -z "$NEORUNNING" ]]; then
    env NVIM_LISTEN_ADDRESS=/tmp/nvimsocket neovide $1 > /dev/null &
else
    nvr --remote-tab $1
fi
