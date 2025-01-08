> [!NOTE]  
> This branch forks of the original LnzLive to add resources and code for loading Babyz LNZ, including the Babyz palette and animations, toggleable transparency of color 253 (magenta), more game-consistent view and texture offsets, and rendering `[Polygons]` LNZ section, as well as a few tweaks to the editor UI e.g. having the LNZ text editor expand when the window is enlarged and allowing file uploads to local storage. Additionally, this fork now has been merged with [Draconizations' palette swap fork](https://github.com/Draconizations/LnzLive/tree/add-palette-swaps)!

**2025-01-07**:
Finally released beta version, as imperfect as it may be!

**2024-11-03**:
- Added handling for 3rd and 4th fields of `[Texture List]` height and width, even if not present and not utilized, as this may help resolve scaling of non-rotate textures in the future (textures appear slightly smaller than in-game textures, currently)
- Fixed offsetting of textures so that placement of non-rotate textures doesn't shift when `[Default Scales]` is changed

**2024-10-23**:
- Merged with [Draconizations' palette swap fork](https://github.com/Draconizations/LnzLive/tree/add-palette-swaps)

**2024-10-13**:
- Modified editor UI so that the text editor rescales more when window enlarged
- Enabled UI for loading files into local storage
- Mirrored view and inverted camera controls to be consistent with in-game view
- Offset textures on ball shader to match in-game view (roughly)
- Exported functional EXE

**2024-10-06**:
- Added support for loading Babyz including example LNZ file and in-game palette, textures, and animations
- Added rendering for `[Polygons]` section which is used in Babyz
- Added toggleable transparency for magenta, which is color 253 in Petz and Babyz palettes
- Added toggle for hiding special ballz i.e. tears in Babyz

# LnzLive

![screenshot](screenshot.png)

## Instructions

See the [usage guide](GUIDE.md).

## Limitations

This app is in development. Expect crashes and visual bugs.

If you would like to help with development, raise [an issue](https://github.com/tabbzi/LnzLive/issues) (as long as it's not covered above) or a pull request.
