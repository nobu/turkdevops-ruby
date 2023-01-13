#!/bin/sh
cd "$1"

exec sed 's/{\$([^(){}]*)[^{}]*}//g' common.mk
