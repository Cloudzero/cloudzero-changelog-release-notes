# Changelog Release Notes

This action is used to validate that release notes are present in a given directory.

## Usage

Typical usage

```yaml
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Version
        id: version
        uses: flatherskevin/semver-action@v1
        with:
          incrementLevel: patch
          source: tags
      - name: Validate Release Notes
        uses: Cloudzero/cloudzero-changelog-release-notes@v1
        with:
          version: ${{ steps.version.outputs.nextVersion }}
      - name: Release
        uses: softprops/action-gh-release@v1
        with:
          name: ${{ steps.version.outputs.nextVersion }}
          tag_name: ${{ steps.version.outputs.nextVersion }}
          make_latest: true
          target_commitish: ${{ github.sha }}
          body_path: ${{ steps.changelog.outputs.releaseNotesFile }}
```
