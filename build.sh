#!/usr/bin/env bash

# TODO: only do this on MacOS. Ansible requires it.
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
packer build --only=parallels-iso -var "iso_url=$1" ./windows_server_2004.json