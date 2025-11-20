# LnzLive Guide

LnzLive is an interactive editor for P.F. Magic LNZ data. This guide will walk you through the various features of LnzLive and how to use them!

## Quickstart

### Loading LNZ into the Editor

> Note: *Loading and saving LNZ data of game files directly is a **planned feature**. For now, you still need to open your `.pet`/`.baby`/`.cat`/`.dog` file first in LnzPro or another editor, and copy the LNZ text directly or export to file, to load into LnzLive. If you are using the web version of LnzLive, then you will have to import/export LNZ as files due to browsers restricting clipboard access.*

You can load LNZ data in several ways:

*   **Examples:** Double-click a preset LNZ file under `Examples` in the file tree (left-hand panel). These are useful for getting started and experimenting with the editor's features.
*   **Copy-and-Paste:** Paste LNZ data copied from a pet file (`.pet`, `.baby`) or breed file (`.dog`, `.cat`) into the text editor (right-hand panel).
*   **Import from File:** Click `File > Import LNZ / BMP / PNG` to load a `.lnz` text file from your computer.

To see your changes, click `Apply Changes` or save with `CTRL+S`. Your imported files will appear under `Local Storage` in the file tree, where you can right-click to rename, create backups, or export as a `.lnz` text file.

### Help! It crashes when I do X!

LnzLive is a work in progress! Please make regular backups of your LNZ files.

If you encounter a bug or have a suggestion, please raise an issue in the GitHub repository so it can be tracked and resolved.

## User Interface Overview

Helpful tips will appear at the top of the screen about visual and text editing tools.

### Controls

| Context | Input / Hotkey | Action |
| :--- | :--- | :--- |
| **Viewport** | `wheel up` / `wheel down` | Zoom View In / Out |
| **Viewport** | `SPACE` + `left-click drag` or `middle/wheel drag` | Pan Camera View |
| **Viewport** | `left-click drag` | Rotate Camera View |
| **Viewport** | `1` through `6` | Set Orthogonal Views (Front, Bottom, Top, Right, Left, Back) |
| **Viewport** | `7` through `0` | Set Isometric Views (Right-Bottom, Right-Top, Left-Bottom, Left-Top |
| **Tools** | `A` | Open/Close Auto Paintballer |
| **Tools** | `T` | Open/Close Palette Viewer |
| **Tools** | `G` | Open/Close Color Swap |
| **Tools** | `H` | Capture `[Head Shot]` |
| **Text Editing** | `CTRL` + `S` | Apply and Save Changes |
| **Text Editing** | `CTRL` + `Q` | Flash Ballz / Linez |
| **Text Editing** | `CTRL` + `F` | **Find/Replace**: Toggles Find and Replace panel |
| **Visual Editing** | `SHIFT` + `left-click drag` | **Move** selected Ball |
| **Visual Editing** | `SHIFT` + `ALT` + `left-click drag` | **Scale/Resize** selected Ball |
| **Visual Editing** | `X`, `Y`, or `Z` (hold during drag) | **Axis Lock** movement to specific axis |
| **Select Mode** | `S` | **Open/Close Select Mode** |
| **Select Mode** | `left-click` | Select Ball (or Deselect, if background clicked) |
| **Select Mode** | `B` or `Z` or `Double left-click` | Jumps to the `[Ballz Info]` or `[Add Ball]` entry defining hovered ball |
| **Select Mode** | `X` or `M` | Jumps to the `[Move]` entries involving hovered ball |
| **Select Mode** | `C` or `P` | Jumps to the `[Project Ball]` entries involving hovered ball |
| **Select Mode** | `V` or `L` | Jumps to the `[Linez]` entries involving hovered ball |
| **Select Mode** | `TAB` | Cycle through nearby balls (when overlapping or hard to select) |
| **Select Mode** | `right-click` | Open Tools Menu for hovered ball |
| **Select Mode** | `CTRL` + `SPACE` or `right-click` | Open Tools Menu for hovered ball |
| **Project Mode** | `D` | **Open/Close Paintball Mode** |
| **Paintball Mode** | `W` | **Open/Close Paintball Mode** |
| **Paintball Mode** | `left-click` | **Draw**: Add paintballz by point-and-click |
| **Paintball Mode** | `CTRL` + `left-click` | **Eraser**: Delete nearest queued paintballz |
| **Paintball Mode** | `SHIFT` + `left-click drag` | **Freeline**: Draw paintballz continuously by click-and-drag |
| **Paintball Mode** | `SHIFT` + `wheel up` / `Down` | **Scale/Resize**: Resize diameter of paintballz |
| **Preset Mode** | `R` | **Open/Close Preset Mode** |
| **Preset Mode** | `left-click` | **Apply Preset**: Apply current Preset to ball |
| **Preset Mode** | `ALT` + `left-click` | **Eyedropper**: Sample properties from ball |
| **Line Mode** | `E` | **Open/Close Linez Mode** |
| **Line Mode** | `left-click` | Connect linez between first and second clicked ball |

### File Tree (Left Panel)

The file tree organizes your LNZ files, textures, and palettes.

*   **Examples:** Contains preset LNZ files for you to explore and learn from.
*   **Local Storage:** Stores LNZ files you have saved from the editor.
*   **Local Textures:** Shows imported BMP texture files with a thumbnail preview. This allows you to quickly see which textures you have available.
*   **Local Palettes:** Shows imported PNG palette files. Double-click to apply a palette to the current model.

Right-click on a file in `Local Storage` for more options:

*   **Delete:** Permanently removes the file.
*   **Rename:** Changes the name of the file.
*   **Backup File:** Creates a copy of the file named `{filename}_backup_#.lnz`. LnzLive keeps the 3 most recent backups, so you can revert to a previous version if something goes wrong.
*   **Copy Filename:** For any LNZ, BMP, or PNG file, you can right-click and choose "Copy Filename" to get the file prefix for easy pasting into LNZ.
*   **Export File:** Exports LNZ data to a `.lnz` text file to a save spot of your choosing. 

### Viewport (Center Panel)

The 3D viewport displays the LNZ model.

*   **Rotate:** Click and hold the left mouse button to rotate the model.
*   **Zoom:** Use the mouse wheel to zoom in and out.
*   **Pan:** Press the middle mouse button or hold `Space` and drag to move the model.
*   **Quick Views:** Use the number keys `1-0` to jump to different camera angles (front, top, isometric, etc.).

#### Navigation

- Click and hold the left mouse button in the viewport (center panel) to rotate the pet.
- Use the mouse wheel to zoom in and out.
- Press down on mouse wheel or hold space and drag to move pet around viewport.
- Tap these numbers to perform a quick jump to various camera views:
    - 1: Front View
	- 2: Top View
	- 3: Bottom View
	- 4: Left View
	- 5: Right View
	- 6: Back View
	- 7: Right-Bottom Isometric View
	- 8: Right-Top Isometric View
	- 9: Left-Bottom Isometric View
	- 0: Left-Top Isometric View

### Text Editor (Right Panel)

The text editor displays the raw LNZ data. You can edit the data directly and see the changes in the viewport after applying them.

#### Find / Replace

Search panel to find and replace.

#### Variation Control Panel

If the loaded LNZ file contains variation blocks (e.g., `#1`, `#2.A`), a **Variation Control Panel** will automatically appear between the toolbar and the text editor.

*   **Link Groups:** Use these dropdowns to toggle entire sets of variations linked by an ID (e.g., `#1.A`, `#2.A`). Changing a Link Group (e.g., "Set A") will update all LNZ sections that contain variations tagged with that link ID.
*   **Section Overrides:** Use these dropdowns to override the specific variation index for a single section (e.g., force `[Ballz Info]` to use variation #2), regardless of the active Link Group.
*   **Real-time Updates:** Changing any dropdown will instantly update the 3D visualization to reflect the chosen combination of variations.

## Menu Options

### File

- **Import LNZ / BMP / PNG:** Load LNZ files or custom texture/palette image files from your computer.

### Tool

#### Auto Paintballer

The `Auto Paintballer` is tool for procedurally generating either simple spots, complex patterns, or intricate fractals using `[Paintballz]`, which get placed according to selected distribution modes.

**Common Properties:**

These settings are used by most distribution modes.

- **Affected Ballz:** A comma-separated list of ball numbers (or ranges, e.g., `1,5,10-15`) that paintballs can be attached to.
- **Number of Spots:** The total number of spots, which could comprise multiple paintballz, to generate.
- **Size Min/Max:** The random size range for each paintball.
- **Color/Outline Color List:** Comma-separated lists of color indices (or ranges, e.g., `150-159,180-189,214`) to be used for the fill and outline of the paintballs.
- **Outline Type Min/Max:** The random range for the outline type.
- **Fuzz Min/Max:** The random range for fuzziness.
- **Texture List:** A comma-separated list of texture IDs to apply. Use -1 for no texture.
- **Group:** The group number to assign to the generated paintballs.
- **Anchored:** If checked, the paintballs will be anchored.

**Distribution Modes:**

This dropdown determines the algorithm used to place paintballs.

- Uniform: Places paintballs randomly across the entire surface.
- Spiral: Arranges paintballs in a spiral pattern around the pet.
- Star: Creates starburst patterns with configurable points and ray length.
- Bands: Creates bands of spots. 'Bands' controls the number of bands. Use 'Direction' to choose horizontal or vertical alignment.
- Noise: Places spots organically based on simplex noise.
- Grid/Checkerboard: Arranges paintballs in a grid or checkerboard pattern.
- Random Walk: Each new paintball is placed near the previous one, creating winding paths.
- Clustered: Groups paintballs into tight, randomly placed clusters.
- Pole/Equator-Focused: Concentrates paintballs at the top/bottom or the middle of the pet.
- Halfie: Restricts paintballs to one half of the pet along a selected axis (X, Y, or Z) and size (positive or negative).
- Bullseye: Creates concentric rings of different colors.
- Leopard: Creates irregular, ringed spots. You can control the spot radius, irregularity, and how complete the rings are. Use "Paired Colors" to define ordered outer/inner colors from your color list (e.g., `155,45,185,45` will only sample 155 outer / 45 inner and 185 outer / 45 inner if "Paired Colors" is checked; otherwise, random pairs will be drawn).
- Rainbow: Generates multi-color arcs of paintballz. You can control the angle, curvature, width, and length of the arcs.
- Stripes: Generates natural Turing patterns like stripes and blotches using Gray-Scott reaction-diffusion. Feed/Kill rates determine density and Diffusion controls feature size.
- Fractal: A powerful mode using Lindenmayer system aka turtle-walking procedure for generating complex, self-repeating patterns.

    - *Preset:* Choose a classic fractal like Dragon Curve, Sierpinski Triangle, or Barnsley Fern to see how it works. Select "Custom" to define your own rules.
	- *Generate Random:* When "Custom" preset is selected, this button creates a new, randomized (but valid) rules for you to experiment with making new fractals.
	- *Axiom:* The starting string for the fractal (e.g., `F`).
	- *Rules:* The replacement rules, one per line (e.g., `F=F+G`). The allowed characters are `F`, `G`, `A`, `B`, `X`, `+`, `-`, `[, ]`. The *Axiom* and *Rules* fields are only editable when the "Custom" preset is selected.
	- *Iterations:* How many times to apply the rules. Higher numbers create more complex patterns.
	- *Angle:* The angle in degrees for turning commands (`+` or `-`). Each preset comes with a recommended angle.

	The Lindenmayer system works by starting with a string of characters (the *Axiom*) and repeatedly replacing characters according to a set of *Rules*. This process, called iteration, creates a long and complex string of commands. This string is then used to guide a "turtle" that moves across the ballz surface, placing paintballz along the pattern.
	
	The basic commands are:

	`F`, `G`, `A`, `B`: Move forward and draw a paintball.

	`X`: A placeholder character used in rules that could replace it. It does not draw any paintballz itself.

	`+`: Turn right by the specified *Angle*.

	`-`: Turn left by the specified *Angle*.

	`[`: Save the current position and direction (creates a branch).

	`]`: Return to the last saved position and direction (ends a branch).

- Voronoi: Creates patterns based on cellular boundaries. 'Cells' controls the density of the pattern, and 'Edge Size' controls the thickness of the lines.

- Wave: Generates wave-like or banded patterns using spherical harmonics. 'Degree (L)' controls vertical frequency and 'Order (M)' controls horizontal frequency.

#### View Palette

Pops open a numbered preview of the paletted color index matching whichever game species and color palette is loaded currently.

#### Color Swap

The "Color Swap" option opens a menu can be used to quickly recolor and retexture ballz, paintballz, and linez. Enter the color and texture mappings you want to apply (e.g., 35 -> 15). Use the checkboxes to select to which LNZ elements to apply the swap. If you select "Ramp", then all corresponding color members of a given ramp (even non-texturable ramps like 150s) will be converted. The "Autofill" button will populate the most frequent color and texture pairs present across `[Ballz Info]`, `[Add Ball]`, and `[Paintball]` sections. The "Randomize" button will populate swap colors and textures randomly, and, if "Ramp" is checked, then will restrict to texturable ramps (10s, 20s, ..., 140s).

#### Capture Head Shot

Captures the current animation frame and camera angle and writes it to the `[Head Shot]` section of the LNZ with helpful comments.

### Mode

#### Select Mode

In `Select Mode`, hovering over ballz will report their index # and double clicking, or pressing the following keys, will jump you to relevant sections and entries in the LNZ text editor.

- **Z** or **B**: go directly to the LNZ line defining ballz in `[Ball Info]` or `[Add Ball]`.
- **X** or **M**: cycle through `[Move]` lines that affect this ball. If none are found, goes to the `[Move]` header.
- **C** or **P**: cycle through `[Project Ball]` lines that affect this ball. If none are found, goes to the `[Project Ball]` header.
- **V** or **L**: cycle through `[Linez]` that include this ball. If none are found, goes to the `[Linez]` header.

#### Paintball Mode

In `Paintball Mode`, you can place prepared paintballs by point-and-click. This mode can be entered via the top menu or by right-clicking a specific ball to lock editing to that ball. When applying paintballs to Babyz, LnzLive automatically repeats the LNZ entries five times with `;rep#` comments to improve their stability in-game.

#### Project Mode

In `Project Mode`, you can quickly prototype body shapes. This mode allows you to set ranges and randomize entries from `[Project Ball]` and extension and scale sections (e.g., `[Leg Extension]` or `[Default Scales]`). For projections, the defaults given per species represent a normal distribution of fixed-projected ball pairs from official breed files, but the min and max projection values can be modified or you can add new fixed-projected pairs. You can also flag a pair with `Mirror` to also write out the same values to any ballz with left/right equivalents. If you check `Lock` on any entry in the table, then those values will not change when you randomize. When you are happy with the values, then hit `Apply Projections to LNZ` to write to LNZ. Order of `[Project Ball]` entries does matter for how ballz get placed and influence eachother, so you can also alter the order of planned entries in the properties panel.

#### Preset Mode

In `Preset Mode`, you can copy properties of existing ballz, including any applied paintballz, and apply these properties onto other ballz. It is here that you can also enter paintballz LNZ and have those paintballz get added to other ballz. You can also rotate those paintballz designs before applying.

Holding the ALT key and clicking on a ballz will copy its properties and paintballz to the panel.

For applying size properties, you have three options: true, set, and sum. True size determines what size difference is needed for a base ballz to match the effective visual size, or just sets that value for add ballz. Set applies the same value to base ballz and add ballz regardless. Sum can be used to increase or decrease sizes of ballz. The default is true size. Note that resizing ballz can also be done visually by holding SHIFT + ALT + left-click and dragging a ball inward (decrease) or outward (increase), which can be faster than click through sums via `Preset Mode`.

#### Line Mode

In `Line Mode`, you can click a series of start and end ballz to connect linez with the properties specified.

### Render

Here, you will find toggles for what elements should be drawn in the pet view. Transparency on color index `253` (typically, magenta in default game palette) can be toggled on or off. Special ballz refers to transient ballz like tears in Babyz that do not usually render but aren't explicitly omitted in `[Omissions]`.

### Export

- **Export OBJ 3D Model:** Experimental feature to export a 3D model of the loaded LNZ and animation frame! Your mileage may vary.

### Help

This option offers links to several handy resources, including [Carolyn Horn's hexing information](https://github.com/melissamcewen/carolyns-bible) and this [User Guide](https://github.com/tabbzi/LnzLive/blob/master/GUIDE.md)!

### Axis Helper

This XYZ axis indicates model's left (L) and right (R) and negative/positive directions for X, Y, and Z axes.

> Note: *LnzLive camera view is actually mirrored over the X axis from the view in-game. This will get fixed, someday.*

### Background Color Selector

Clicking on the square after the menu options brings up a color selector, which you can use to pick the background color of the pet view.

### Eyelid Toggle

Clicking on the eyeball will cycle through eyelid rendering options: neutral, none, angry, and scared.

### Animation Controller

Use these controls to preview and navigate animations:

- Jump through animations with the arrows or by entering an animation index in the box.
- Click `Play` button or press `SPACE` to start or stop a playback.
- Slide through animation frames by dragging the handle.

### T-Pose Toggle

Poses the model using perfect symmetry rather than game animation frames.

## Visual editing

Ballz can be moved and resized directly in the pet view.

### Move a ball
SHIFT + left-click and drag to move a ball in 3D space.

The move will be reflected as a Move entry in the LNZ. If a Move line does not exist, one will be created.

Hold X, Y, or Z while dragging to constrain movement to that axis.

### Scale a ball
SHIFT + ALT + left-click and drag to resize a ball interactively.

The size change will be reflected in the Ballz Info or Add Ball line in the LNZ.

## Tools menu

Press CTRL + SPACE in the pet view to open the tools menu, or right-click on a ball in the pet view.

### Color...

The "Color..." option opens a menu of additional options for recoloring.

For most of these, when you select what to recolor, two text entry boxes will appear at your cursor. The first is for the ball colour, the second is for outline color. Type a color number (e.g., 25) and hit Enter to apply. Leave a box blank if you don't want to affect the color/outline.

The "Color Swap" option opens a menu can be used to quickly recolor and retexture ballz, paintballz, and linez. Enter the color and texture mappings you want to apply (e.g., 35 -> 15). Use the checkboxes to select to which LNZ elements to apply the swap. If you select "Ramp", then all corresponding color members of a given ramp (even non-texturable ramps like 150s) will be converted. The "Autofill" button will populate the most frequent color and texture pairs present across `[Ballz Info]`, `[Add Ball]`, and `[Paintball]` sections. The "Randomize" button will populate swap colors and textures randomly, and, if "Ramp" is checked, then will restrict to texturable ramps (10s, 20s, ..., 140s).

### Create Add Ballz (+ Linez)

While a ball/addball is hovered or selected, use "Create Addballz" or "Create Addballz + Linez" to create a new addball and/or line. If an addball is selected, the new addball will be parented to the same ball as the selected addball. The line will connect the selected addball and the new addball.

### Delete Addballz / Omit Ballz

While a ball/addball is hovered or selected, use "Delete Addballz / Omit Ballz" to either remove an addballz and its associated linez and paintballz completely, or add base ballz to the `[Omissions]` list.

### Connect with Linez

While a ball is hovered or selected, use "Connect with Linez" line creation mode.

Click another ball to connect the two with a Linez entry in the LNZ.

### Copy-Mirror

The Copy-Mirror tool on all ballz will apply all changes on the model's right (R) to the model's left (L) side (LnzLive is mirrored, so the left side of the viewport to the right side). This includes ballz, addballz, paintballz, linez, etc. Alternatively, if selected by right-clicking a specific ballz, then properties of that ball will be mirrored to its symmetrical equivalent. Or, if the ball is a center ball, applied to itself but mirrored on the X axis.

### Move Head

LNZ has no such thing as a 'neck extension', so this is a small util to move all head ballz at once. The three text boxes are for X, Y, Z coordinates to move by. Hit Enter to apply. You can keep hitting Enter to continue moving.

### Copy Ballz Colors to Clipboard

Useful for making Color Info Override sections in breeds. Not supported in all browsers.

## Backups

Destructive tools like `Color Swap` and `Copy-Mirror` will trigger an automatic backup. The visual editing tools like move and scale ballz are especially hard to reverse without backups, as these take effect immediately. LnzLive takes a backup of your file before applying these tools, and saves it as `{filename}_backup.lnz`. The backup will overwrite any existing backup file.

> Note: *Improved save states or file versioning is a **planned feature**.*

## Textures and Palettes

Custom BMP files can be loaded from local storage by clicking "Import LNZ / BMP / PNG" button. These should now appear under `Local Textures` in the file tree. You can now apply textures as normal in the LNZ data. LnzLive doesn't care about the full filepath, only the filename.

Similar to textures, custom palettes can be loaded from local storage, but need to be in a color ramp PNG format. **You will need to convert your BMP palette image to a PNG in the format that LnzLive expects**. You can generate this using either of these web tools:

- [Petz Palette Converter](https://draconizations.github.io/petz-palette-converter/)
- [Petz Paletteiare](https://tabbzi.github.io/petz-paletteiare/)

To load your palette image, use the "Import LNZ / BMP / PNG" button. These should now appear under `Local Palettes` in the file tree. You can now apply the palettes as normal in the LNZ data, make sure to omit the `.png` at the end. Or, double-click the palette file name to apply automatically.

You can also add files directly for LnzLive to access from your file system:

Go to `%APPDATA%/Godot/app_userdata/LnzLive/resources/textures` (you may have to create this folder).

After adding your files directly to this folder, relaunch LnzLive to load it. If your files have been loaded correctly, you will see them if you expand the `Local Textures` or `Local Palettes` part of the file tree.

> Note: *Loading palettes from palette BMP files directly is a **planned feature**.*

## Other features

While editing the LNZ:

- Place the editing cursor on any line in `[Ballz Info]`, `[Add Ball]`, `[Linez]`, `[Polygons]`, `[Paintballz]`, `[Move]`, or `[Project Ball]`. You don't need to select the entire line, just place the cursor within it. Hit Ctrl+Q to make affected ballz and/or linez flash in the pet view so you can locate.