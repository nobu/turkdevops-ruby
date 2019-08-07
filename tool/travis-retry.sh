#!/bin/sh
retry-with-waits() {
    for seconds in ${WAITS-1 25 100}; do
        eval "$@" && return
        sleep $seconds
    done
    return 1
}
