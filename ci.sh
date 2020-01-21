#!/usr/bin/env nix-shell
#! nix-shell -p yq -p jq -i bash

if [ $# -eq 0 ]
then
  for jobname in $(yq -r 'keys| .[]' .gitlab-ci.yml); do
    if [ "$jobname" != "stages" ]; then
      gitlab-runner exec shell "$jobname"
    fi
  done
else
  gitlab-runner exec shell "$1"
fi