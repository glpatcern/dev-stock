#!/bin/bash
set -e

export REPO_ROOT=`pwd`
export EFSS1=nc1
export EFSS2=nc2
export DB1=nextcloud
export DB2=nextcloud
./scripts/sciencemesh-testing.sh
