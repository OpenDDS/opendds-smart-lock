#!/bin/bash

declare _SMART_LOCK_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

function _smart-lock {
    while IFS= read -r line; do
        COMPREPLY+=("${line}")
    done < <(COMP_CWORD="${COMP_CWORD}" COMP_LINE="${COMP_LINE}" COMP_POINT="${COMP_POINT}" COMP_TYPE="${COMP_TYPE}" COMP_KEY="${COMP_KEY}" COMP_WORDBREAKS="${COMP_WORDBREAKS}" COMP_WORDS="${COMP_WORDS[@]}" "${_SMART_LOCK_DIR}/smart-lock" "${COMP_WORDS[@]:1}")
}
complete -F _smart-lock smart-lock
