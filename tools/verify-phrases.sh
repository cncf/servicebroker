#!/bin/bash

# Copyright 2017 The authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script will scan all md (markdown) files for bad references.
# It will look for strings of the form [...](...) and make sure that
# the (...) points to either a valid file in the source tree or, in the
# case of it being an http url, it'll make sure we don't get a 404.
#
# Usage: verify-links.sh [ dir | file ... ]
# default arg is root of our source tree

set -o errexit
set -o nounset
set -o pipefail

casePhrases=(   # case matters
"Service Binding" "Service Bindings"
"Service Broker" "Service Brokers"
"Service Offering" "Service Offerings"
"Service Plan" "Service Plans"
"Service Instance" "Service Instances"
MUST
"MUST NOT"
REQUIRED
SHALL
"SHALL NOT"
SHOULD
"SHOULD NOT"
RECOMMENDED
MAY
OPTIONAL
)

bannedPhrases=(  # case does not matter
"OSB API"
"Marketplace"
)

REPO_ROOT=$( cd $(dirname "${BASH_SOURCE}")/.. && pwd)

verbose=""
debug=""
stop=""

while [[ "$#" != "0" && "$1" == "-"* ]]; do
  opts="${1:1}"
  while [[ "$opts" != "" ]]; do
    case "${opts:0:1}" in
      v) verbose="1" ;;
      d) debug="1" ; verbose="1" ;;
      -) stop="1" ;;
      ?) echo "Usage: $0 [OPTION]... [DIR|FILE]..."
         echo "Verify all terms defined in spec are cased correctly."
         echo
         echo "  -v   show each file as it is checked"
         echo "  -?   show this help text"
         echo "  --   treat remainder of args as dir/files"
         exit 0 ;;
      *) echo "Unknown option '${opts:0:1}'"
         exit 1 ;;
    esac
    opts="${opts:1}"
  done
  shift
  if [[ "$stop" == "1" ]]; then
    break
  fi
done

# echo verbose:$verbose
# echo debug:$debug
# echo args:$*

arg=""

if [ "$*" == "" ]; then
  arg="${REPO_ROOT}"
fi

Files=$(find -L $* $arg \( -name "*.md" -o -name "*.htm*" \) | sort)

function checkFile {
  # Determine the max # of words we need to look for
  maxWords=1
  for phrase in "${casePhrases[@]}"; do
    words=( ${phrase[@]} )
    if (( ${#words[@]} > $maxWords )); then
      maxWords=${#words[@]}
    fi
  done

  lines=( "" )
  words=( "" )

  # Error file
  err=tmpCC-$RANDOM

  # Prepend each line of the file with its line number
  cat -n $1 | while read num line ; do
    # Put each word on its own line with its line number before it.
    echo "$line" | \
    # Split on whitespace
    sed "s/[[:space:]]/\n&\n/g" | \
    # Put a \n before any http... word so they're easy to find
    sed "s/http.*[^[[:space:]]]*/\n&\n/g" | \
    ( while read line ; do
        # Lines that start with http are special, just echo them
        if [[ "$line" == "http"* ]]; then
          echo $line
          continue
        fi
        # Now split on words
        echo "$line" | sed "s/[a-zA-Z_\-]\+/\n&\n/g"
      done
    ) | \
	while read word ; do
      # Now put the line number before each word
      echo $num $word
    done
  done | while read line word ; do
    if [[ "$word" == "" ]]; then
      continue
    fi

    # echo $line $word
  
    # Shift our arrays of lineNums and words
    if (( ${#words[@]} >= $maxWords )); then
      lines=( "${lines[@]:1}" "$line" )
      words=( "${words[@]:1}" "$word" )
    else
      lines=( "${lines[@]}" "$line" )
      words=( "${words[@]}" "$word" )
    fi
  
    # echo Lines: "${lines[@]}"
    # echo Words: "${words[@]}"
  
    # For each of our "casePhrases" check to see if its in "words" with
    # the wrong case
    for phrase in "${casePhrases[@]}"; do
      if [[ "${words[@]^^} " == "${phrase^^} "* && \
            "${words[@]} " != "${phrase} "* ]]; then
      ll=${words[*]}
      echo line ${lines[0]}: \'${ll:0:${#phrase}}\' should be \'${phrase}\' | tee -a $err
    fi
    done

    # For each of our "bannedPhrases" check to see if its in "words". Note
    # that the case of the phrase does not matter.
    for phrase in "${bannedPhrases[@]}"; do
      if [[ "${words[@]^^} " == "${phrase^^} "* ]]; then
      ll=${words[*]}
      echo line ${lines[0]}: \'${ll:0:${#phrase}}\' is banned | tee -a $err
    fi
    done

  done
  
  # Check err file to see if something went wrong
  if [ -s $err ]; then
    rm -f $err
    return 1
  fi
  rm -f $err
}

for file in ${Files}; do
  # echo scanning $file
  dir=$(dirname $file)

  [[ -n "$verbose" ]] && echo "> $file"

  checkFile $file
done
