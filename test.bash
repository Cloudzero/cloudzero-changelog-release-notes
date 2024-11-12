#!/bin/bash

NEXT_VERSION="0.0.1"
FILE_PATH="docs/releases/${NEXT_VERSION}.md"

if [ ! -f "$FILE_PATH" ]; then
    echo "Release notes for $NEXT_VERSION are missing. Please create a release notes file at $FILE_PATH"
    exit 1
fi

if ! grep -q "^# \[${NEXT_VERSION}\](\https://github.com/cloudzero/cloudzero-changelog-release-notes/compare/.*) ([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\})" $FILE_PATH; then
    echo "Error: Version $NEXT_VERSION does not have the correct title format \"# [${NEXT_VERSION}](https://github.com/cloudzero/cloudzero-changelog-release-notes/compare/) - YYYY-MM-DD\""
    exit 1
fi