#!/usr/bin/env bash

if [[ "$OSTYPE" == "darwin"* ]]; then
    # Ansible requires this variable or python fork() will break it on MacOS
    export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
fi

packer build -var "iso_url=$1" ./windows_server_2004.json "${@:2}"