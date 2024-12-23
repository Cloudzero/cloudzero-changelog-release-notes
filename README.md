# Changelog Release Notes

This action is used to validate that release notes are present in a given directory.

## Usage

Typical usage

```yaml
name: Release

on:
  workflow_dispatch:
    inputs:
      versionIncrementLevel:
        description: Increment level to use for the release
        required: true
        type: choice
        default: patch
        options:
          - major
          - minor
          - patch
          - premajor
          - preminor
          - prepatch
          - prerelease  

concurrency:
  group: ${{ github.ref }}-release

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
      - name: Version
        id: version
        uses: flatherskevin/semver-action@v1
        with:
          incrementLevel: ${{ github.event.inputs.versionIncrementLevel }}
          source: tags
      - name: Validate Release Notes
        uses: Cloudzero/cloudzero-changelog-release-notes@v1
        id: changelog
        with:
          version: ${{ steps.version.outputs.nextVersion }}
      - name: Create Release
        uses: softprops/action-gh-release@v2
        with:
          name: ${{ steps.version.outputs.nextVersion }}
          tag_name: ${{ steps.version.outputs.nextVersion }}
          make_latest: true
          target_commitish: ${{ github.sha }}
          body_path: ${{ steps.changelog.outputs.releaseNotesFile }}
```
