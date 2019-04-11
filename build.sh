#!/usr/bin/env sh
cd `dirname $0`
docker build ./ -t mysql-builder
