# SwiftGDTF
A Swift library for interacting with GDTF files.

This library:
- Handles the decompression and parsing of GDTF Files, and their file resources (when using `loadFixtureModePackage`)
- Resolves node links present in attributes
  - This allows you to get all necessary data by just parsing a DMXMode
  - We cannot resolve the following nodes, they are currently represented as a String:
    - `modeMaster` in `ChannelFunction`
    - `mainAttribute` in `FixtureAttribute`
- Does not currenty parse FTPresets, or Protocols nodes currently, if you would like to add support, submit a PR!

## Installation
Install with SPM with the following:

```
dependencies: [
    .package(url: "https://github.com/bwees/SwiftGDTF.git", from: "1.0.0")
]
```
