#!/usr/bin/env bash

set -eo pipefail


if [ -t 1 ]; then   
  echo "In terminal"

else 
  echo "Not in terminal"
fi