# Changelog Release Notes

This action is used to validate that release notes are present in a given directory.

## Usage

Typical usage

```yaml
name: Release

on:
  workflow_dispatch:
    inputs:
      version:
        description: Version to release (e.g. 1.2.3)
        required: true
        type: string

concurrency:
  group: ${{ github.ref }}-release

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
      - name: Validate Release Notes
        uses: Cloudzero/cloudzero-changelog-release-notes@v1
        id: changelog
        with:
          version: ${{ github.event.inputs.version }}
      - name: Create Release
        uses: softprops/action-gh-release@v2
        with:
          name: ${{ github.event.inputs.version }}
          tag_name: ${{ github.event.inputs.version }}
          make_latest: true
          target_commitish: ${{ github.sha }}
          body_path: ${{ steps.changelog.outputs.releaseNotesFile }}
```
