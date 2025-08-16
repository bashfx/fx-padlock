#!/usr/bin/env bash
#
#  ____            _  _            _    
# |  _ \ __ _  __| || | ___   ___| | __
# | |_) / _` |/ _` || |/ _ \ / __| |/ /
# |  __/ (_| | (_| || | (_) | (__|   < 
# |_|   \__,_|\__,_||_|\___/ \___|_|\_\
#                                     
# Git Repository Security Orchestrator
#
# name: padlock
# version: 1.0.0
# author: fx-padlock
# description: Age-based encryption for git repositories with locker pattern
# 
# portable: age, age-keygen, git, tar, find, curl, head, tail, grep, awk, sed
# builtins: printf, read, local, declare, case, if, for, while, source, export

set -euo pipefail