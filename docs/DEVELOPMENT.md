# LnzLive - Developer Guide

LnzLive is an interactive editor for P.F. Magic LNZ data. This guide will walk you through how to contribute to the codebase!

## Contributing to LnzLive

We welcome contributions of all sizes! If you're new to the codebase, the best way to start is to familiarize yourself with the **Pipeline** and **Logic** below. LnzLive is built using a custom version of the Godot 3.2 game engine, which can be found in `engine/godot.zip`, and can be exported using the export templates included under `export/` for executable (`windows`) or web (`javascript`) versions. Most logic is written in GDScript (`.gd`) and uses custom shaders (`.tres`) to emulate the aesthetic of the original P.F. Magic games. Contributors are welcome to extend to other languages supported by Godot, though, especially if inclusion will help optimize the program!

### Where to Begin?

#### 1. **Check the LnzLive Task Tracker**

Start by checking out the [LnzLive Task Tracker](https://github.com/users/tabbzi/projects/3), which logs tasks slated for upcoming versions of LnzLive. Those in the Status "Ready" and labeled as "good first issue" are a good place to start, and the ticket should describe what is needed to complete these tasks.

#### 2. **Fork the Repository**

Before you can change the code, you need your own "copy" of the project on GitHub where you have permission to save your work. Navigate to the [tabbzi/LnzLive](https://github.com/tabbzi/LnzLive) on GitHub and click "Fork". GitHub will create a copy of the entire repository under your own account. You now have a version at `github.com/YourUsername/LnzLive`.

#### 3. **Clone the Codebase to your Computer**

Now, you need to get those files onto your computer so that you can open them in the Godot editor. On your new fork page, click the green `<>` Code button and follow methods to clone the repository using git or download [GitHub Desktop](https://desktop.github.com/download/) to manage repositories.

#### 4. **Create a Feature Branch**

Creating a new branch keeps your additions separate from the main code until you are ready to review and merge.

Before starting a new task, open your terminal in the project folder and type:

`git checkout -b feature-name`

(Replace "feature-name" with something short, like `add-variation-viewer` or `fix-eyelash-shader`.)

#### 5. **Open LnzLive in Godot**

Navigate to where LnzLive repository has been cloned (probably `Documents/GitHub/LnzLive`) and copy and extract the contents of `engine/godot.zip` somewhere else on your computer. This is the custom Godot engine executable. Open Godot using this executable, and load the LnzLive folder. You can test that the program works as expected by pressing `F5` in the editor.

#### 6. **???**

Start making changes! Be sure to refer to the [Godot 3.2 docs](https://docs.godotengine.org/en/3.2/) and not newer versions of Godot like Godot 4, which has undergone major changes. Don't even try opening LnzLive into Godot 4 engine, it is futile. Unless you have a lot of fortitude to port it...

#### 7. **Save Your Work (Commit & Push)**

As you write your code and test it in Godot, you need to "save" those snapshots to GitHub.

Stage your changes: `git add .`

Commit with a message: `git commit -m "Added the basic UI for the variation viewer"`

Upload to GitHub: `git push origin feature-name`

#### 8. **Test LnzLive**

Try to break your new feature, and any other functionalities of LnzLive that your feature might have affected! It helps to go about systematically... the best way is to hex. ;) LnzLive does include a set of unit tests using [GUT](https://gut.readthedocs.io/en/godot_3x/index.html) (see [Developer Tools](#developer-tools)).

#### 9. **Export LnzLive**

Export LnzLive to Windows (`.exe`), Linux (x11 64-bit executable), and web (HTML/JS that can be packaged into a `.zip` archive for itch.io) using the export templates (release and debug versions) generously compiled and provided by [Draconizations/godot-petz](https://github.com/Draconizations/godot-petz/releases/tag/v0.1.0) and copied to the `export/` folder. 

Recommended export Options matching releases need to be manually set in Godot editor:

```
64_bits: true
emned_pck: true
s3tc: true
no_bptc_fallbacks: true
timestamp: true
file_version: LnzLive_PB-beta-v###-preview-##
product_version: PB-beta-v###
company_name: LnzLive
product_name: LnzLive Petz & Babyz
file_description: A visual editor for P.F. Magic game files!
```

The following settings for Resources in export pabel are also required:

```
export_mode: Export all resources in the project
filter_include: *.bmp,*.lnz,*.bdt,*.bhd,*.png,*.gif,*.ico,*.ttf,*.json
filter_exclude: export/
```

To test the web export, you can serve locally from the export directory using `python -m http.server 8080` and navigating to `http://localhost:8080` in your browser. It won't catch everything as hosts or browsers may block certain elements, such as clipboard access.

#### 10. **Submit a Pull Request**

Once your feature is finished and tested, it’s time to ask for it to be reviewed and merged into this LnzLive repository.

Go to GitHub and navigate to your fork, click "Contribute" and then "Open pull request". Or, open GitHub Desktop and you will usually see a "Compare & pull request" button to click.

Ensure the "base repository" is the LnzLive (`tabbzi/LnzLive:main`) "main" branch that you had forked originally and that the "head repository" is your fork. It might automatically suggest the original LnzLive (`mnemoliLnzLive:master`) but this is *not* the branch that you want to merge.

Give the pull request a clear title and summary (e.g., "Add Move Mode functionality"). Cite the specific Issue # or Task this pull request addresses. Explain what you changed and how to test it.

Once submitted, maintainer(s) will look over your code and might suggest small changes. If they do, just make the edits on your computer, commit, and push again. The pull request will update automatically!

### Pipeline

LnzLive renders models from P.F. Magic games using LNZ data and game resources. It converts text from LNZ files into interactive 3D visual models, and serializes any changes made by tools / modes / visual interactions safely back to LNZ text or vice versa, text changes back into visual. The raw text LNZ file is *always* the source of truth. Fidelity to how P.F. Magic games parse the LNZ in consideration of the BHD (model) and BDT files (animations) is ideal, but is still a work in progress that could be improved. At minimum, we do not want any valid LNZ to go unparsed and unrendered, even if it isn't yet 1:1 on par with in-game visuals. Interactive visual editing in the 3D viewport should ultimately trigger text updates, which then trigger 3D rebuilds.

The pipeline flows as follows: **Text Input \-\> LNZ Parser \-\> Data Classes \-\> Model Generator \-\> Interactive Viewport**

1. **Text Input (`scenes/editor/LnzTextEdit.gd`)**: The user loads an LNZ file. This script manages the raw string representation, regex searching, and maintains the undo/redo history states.  
2. **Data Classes and Parsers (`data_classes/`)**: Parsed data is stored in structures that map to respective LNZ sections. The raw text is scanned and parsed into sections (`[Ballz Info]`, `[Linez]`, etc.) and variation blocks (`#1`, `#2.A`), then compiled into a structured map by the `lnz_parser.gd` script (`LnzParser` class). These scripts also parse model (`.bhd`) and animation (`.bdt`) files included in `resources/animations/`.
3. **Model Generator (`scenes/dog_generator.gd`)**: Process takes structured data (alongside model `.bhd` and animations `.bdt` frame data) to dynamically create and configure Godot visual nodes.
4. **Viewport (`scenes/editor/PetViewContainer.gd`)**: The generated model is rendered in the 3D viewport. The user interacts via 2D mouse inputs (raycasting, dragging, selecting), which in turn signal changes back to the Text Input.

### Logic

1. **User interacts via Viewport:** A user clicks and drags a 3D ball. PetViewContainer.gd uses Godot's 3D raycasting to identify the node, reads its attached metadata (like `ball_no`), and translates the 3D drag delta into LNZ integer units.  
2. **Viewport signals Text Editor:** PetViewContainer calls a targeted function on LnzTextEdit (e.g., `update_ball_position_in_text(ball_no, new_x, new_y, new_z)`) to update the LNZ text. It does *not* modify the visual 3D nodes directly except for preview visuals prior to applying changes to LNZ.
3. **Text Editor triggers Model Generator:** LnzTextEdit emits an `apply_changes` signal to notify `dog_generator.gd` that the file content has changed, which triggers a reload of the visual model. This is why LnzLive isn't exactly *live*...

## Resources

### Model (BHD) files

### Animation (BDT) files

### LNZ files

### Textures

#### Texture (BMP) files

#### Atlas (PNG) files

### Palettes

## Graphics

### Shaders

Graphics in P.F. Magic games operate as 2D billboards in a 3D space. The vertex shaders orient these shapes to always face the camera, a technique known as billboarding. These are projected into 3D space, like a collection of cardboard cutouts moving in a 3D world. Because the shapes are perfectly flat, traditional 3D lighting wouldn't work, which is why z-shading is applied to adjust colors in textures by distance of ballz to viewer.

#### Fragment Shader

The fragment shader operates per pixel:

- **Step: Culling / Discarding**
    * Discards the fragment entirely based on view normals or backface logic before doing heavy math.
    * Throws away pixels early if they belong to a shape that is facing backwards or hidden from the camera.

- **Step: Fuzz / Jitter Calculation**
    * Generates a pseudo-random value based on the fragment's screen coordinates and offsets the UV to produce a jitter.
    * Slightly scrambles the pixels along the edge to make the shape look fuzzy instead of smooth.

- **Step: Shape & Outline Math**
    * Computes distance fields (vector lengths from center) to determine if the current fragment falls within the geometry, on the outline, or outside the geometry.
    * Draws a perfect shape inside the invisible canvas, and figures out which pixels are fill versus outline.

- **Step: Texture Tiling & Rotation**
    * Maps screen-space or object-space coordinates to UVs, handling atlas rect boundaries, centering, and tiling parameters.
    * Figures out which part of a texture should be painted onto each specific pixel.

- **Step: Palette Quantization**
    * Samples the texture and palette, resolves transparency color index, and resolves palette colors.
    * Looks up exact color for each pixel from a limited set of colors (a 256-color palette).

- **Step: Color Sampling & Z-Shifting**
    * Conditionally shifts the base palette index based on texture argument and Z-depth.
    * Paints the pixel! If it's further away, it picks a darker shade of the color; if it's an outline, it paints it the outline color.

- **Step: Eyelids & Eyelashes**
    * Applies rotational matrices and trigonometric projections to mask out specific pixels for eyelids and eyelashes.
    * Draws extra details like eyelids or eyelashes on top of the base shape by calculating angles.

- **Step: Transparency & Alpha Clipping**
    * Makes sure the pixels outside the actual shape or marked as transparent become completely invisible.

#### Vertex Shader

The vertex shader operates per billboard:

- **Step: Billboard Transformation**
    * Transforms 3D vertices into clip/view space. Aligns the geometry to face the camera (billboarding) or projects specific 3D coordinates to screen space.
    * Figures out where the shape should be on the screen and makes sure it faces the camera perfectly flat, like a cardboard cutout.

- **Step: Depth Calculation for Z-Shading**
    * Computes the Z-depth of the object's center in view space and compares it to the pet's depth for dynamic palette shifting.
    * Measures how far away the shape is compared to the center of the pet so it can be darkened if it's in the background or lightened if it's in the foreground.

- **Step: Screen-Space Center Calculation**
    * Projects the 3D center of the object into normalized device coordinates (NDC) and computes the exact pixel coordinate on the viewport.
    * Finds the exact pixel on the screen that marks the dead center of the shape, which helps draw perfect circles or lines later.
    
- **Step: Vertex Extrusion / Padding**
    * Offsets the clip-space vertices outward by a calculated radius or normal to ensure the fragment shader's bounding box encompasses the entire generated shape (including fuzz).
    * Makes the invisible canvas for the shape slightly bigger than necessary so there is room to draw fuzzy edges or thick borders without cutting them off.

## Codebase

Below is a breakdown of the scripts and shaders organized by directory.

### `data_classes/`

This directory holds the parsers, utils, and memory structures that bridge raw text and the 3D generator.

* `lnz_parser.gd`: The core text parser for extracting information from LNZ sections.
* `bhd_parser.gd`: Parses binary `.bhd` animation headers to extract metadata (number of ballz, default sizes) and the specific memory offset ranges mapping to `.bdt` frames. Uses heuristic fallback scanning for custom/non-standard files.
* `bdt_parser.gd`: Parses binary `.bdt` animation frames to extract precise Vector3 position and rotation data for every ball at a given frame. Relies heavily on exact byte-level struct unpacking.
* `key_balls_data.gd`: A Singleton/Autoload acting as the central anatomy metadata repository. Maps hardcoded integer ball IDs to semantic names (e.g., 48: belly), assigns mirror/symmetry pairs, and body groups. Used for Mirror and Group operations.
* `lnzlive_utils.gd`: Static utility class providing regex number list parsing (expanding "1-5" to `[1,2,3,4,5]`), Petz-specific color ramp calculation logic, and 3D raycast math.
* `ball_data.gd`: Memory structure for `[Ballz Info]` attributes.
* `addball_data.gd`: Extends ball data for `[Add Ball]`, including properties specific to addballz (e.g., base ball, body area).
* `paintball_data.gd`: Memory structure for `[Paint Ballz]`. Pre-calculates `normalised_position` which is required for placing paintballz on surface of base ballz.
* `line_data.gd`: Memory structure for `[Linez]`, storing start/end ballz IDs and linez properties (e.g., left/right edge outline colors).
* `polygon_data.gd`: Memory structure for `[Polygons]`, representing flat 2D rectangles connecting 3 or 4 ballz.

### `scripts/`
Core scripts that attach directly to the 3D visual nodes and manage their spatial properties for the shaders.

* `Ball.gd`, `Line.gd`, `Paintball.gd`, `Polygon.gd`: The scripts attached to their respective `Spatial` scenes. They act as receptors, taking the properties assigned by `dog_generator.gd` and feeding them directly into the shader parameters (`.tres`).
* `texture_atlas_baker.gd`, `texture_reimporter.gd`, `thumbnail_baker.gd`: Utility scripts used to generate and format base game resource files. Contributors will rarely need to run or modify these.

### `shaders/`

Custom Spatial shaders (`.tres`) designed to emulate P.F. Magic games rendering logic inside Godot visual 3D engine.

* `ball.tres`
* `line.tres`
* `paintball.tres`
* `polygon.tres`

### `scenes/`

Root controllers and initialization scripts.

* `dog_generator.gd`: **"Model Generator"**. Central script generating model visuals. It takes structured LNZ data and `.bhd`/`.bdt` animations, computes extensions and scales, and generates spatial nodes (`Ball.tscn`, `Paintball.tscn`). Sets up dictionaries mapping LNZ IDs to actual nodes (e.g., ball_map`[48]` \= \<Node\>) allowing the UI to cross-reference 3D clicks back to text IDs.
* `bootsplash.tscn / bootsplash.gd`: Handles the initial loading screen, restores persistent window positions/sizes from `user://settings.cfg` before launching the editor scene.

### `scenes/editor/`

The core UI, Viewport, and Text Editor functionalities.

#### **Core Editors & Interaction**

* `LnzTextEdit.gd`: Manages LNZ text as the source of truth. Manages the raw string array, handles file saving, backup creation, and undo/redo history. Helps commit visual 3D interactions to LNZ text blocks.  
* `PetViewContainer.gd`: The 2D viewport overlay translating mouse inputs (clicks, drags) into 3D raycasts. It also manages all the Tools / Modes (Select, Move, Recolor, Paintball). Calculates 3D-to-2D dragging math and commits visual edits to `LnzTextEdit.gd`.  
* `editor.tscn`: The root UI scene containing all layouts, panels, buttons, and viewports.

#### **User Interface**

* `FileTree.gd`: Tree UI scanning `res://` and `user://` to display files. Handles import logic, crucially converting legacy 8-bit `.bmp` palettes into standard RGBA .png files during upload.  
* `SidebarController.gd`: Manages the left-hand dockable sidebar, allowing panels to snap into tabs or pop out into floating CanvasLayer windows.  
* `ToolsMenu.gd`: The dynamic right-click context menu in the 3D viewport. Rewrites its own options and enabled states based on whether the selected node is a base ball, addball, or line.  
* `UserSettings.gd` / `UserSettingsDialog.gd`: Manages global preferences (background color, screen scaling, undo history size, delimiter defaults) saving to settings.cfg to persist across sessions.  
* `VariationTree.gd`: Displays LNZ variation logic. Handles mutual exclusivity and "Global" toggling, modifying `current_variation_config` to tell `dog_generator.gd` exactly what code blocks to compile.  
* `PaletteViewer.gd` / `ColorSelector.gd`: Generates a dynamic popup grid of all 256 colors in the loaded palette. Calculates luminance on the fly to ensure index text (black or white) remains readable over different background colors.  
* `ActiveHotkeys.gd` / `HotkeyOverlay.gd`: Dynamic fading text labels catching raw InputEventKey events to display currently pressed shortcut combinations, plus a static F1 cheat sheet overlay.  
* `ExportButtonOBJ.gd`: Iterates over the visible ball_map nodes to generate and export standard 3D Wavefront .obj mesh strings (vertices and faces) programmatically.  
* `ExportClothes.gd` / `ExportButtonClothes.gd`: Filters out a targeted root base ball and its attached addballz/linez, re-mapping their indices to generate CLZ expected for a clothing (`.clo`) file.  
* `AxisOverlay.gd`: Projects the inverse 3D basis vectors of the main camera into 2D space to draw a responsive, screen-aligned XYZ widget in the corner of the viewport.  
* `ConsoleLog.gd, FPSLabel.gd, BallNo.gd`: Simple UI scripts for transient system messages, framerate, and hovering ID tooltips respectively.  
* `MenuButton.gd, OptionButton.gd, PlayButton.gd, FrameSlider.gd`: Standard UI behavioral wrappers for links, hover-to-open dropdown menus, animation playback, and timeline scrubbing.
* `RecolorLine.tscn`: A small, reusable UI snippet (two LineEdits and an arrow) used dynamically in recolor rule generation.

#### **Settings Panels**

Most tools and modes have settings panels that extend `DraggablePanel.gd` to allow them to be docked in the sidebar or float.

* `AutoPaintballerSettings.gd`:  **"Auto Paintballer"**. Procedurally generates complex arrays of paintballz. Contains massive algorithmic math for distributions like Uniform, Voronoi, Reaction-Diffusion (Stripes), and L-System Fractals mapped as paintballz coordinates.  
* `LineModeSettings.gd`: **"Line Mode"**. Dictates thickness, color, outline, and fuzz for connecting elements, with toggles for replacing specific attributes versus untouched data.  
* `MoveModeSettings.gd`: **"Mode Mode"**. UI and logic for translating, aligning, rotating, flipping, scaling, and mirroring selections. Centralizes transformation math (like Pivot rotations) before applying them to the file.  
* `PaintballSettings.gd`: **"Paintball Mode"**. Settings for drawing individual spots, freelines, or drawn patterns. Handles the math to project 2D canvas designs (`paste_paintball_design()`) onto a 3D spherical surface using tangent and binormal vectors. Includes the `DesignCanvas.gd` logic.  
* `PresetSettings.gd`: **"Preset Mode"**. Allows users to define properties (color, texture, addballz) or sample them via eyedropper, and batch-apply them to other ballz. Includes its own embedded 3D viewport for previewing copied setups.  
* `ProjectSettings.gd`: **"Shape Mode"**. Manages `[Project Ball]` definitions, body proportion randomizers, and move randomizers. Autogenerates mirrored symmetry pairs based on species models.  
* `RecolorSettings.gd`: **"Recolor Mode"**. Supports targeted Paint Bucket fills and batch Color Swap rules. Features an "Autofill" scanner that finds the most common color/texture pairings. Understands palette "Ramps" via LnzLiveUtils to shift entire shading gradients simultaneously.

## Resources

All the static assets, examples, and original game data required to render the models.

- **`animations/`**: Contains the original binary `.bhd` and `.bdt` files for standard base models (e.g., `DOG`, `CAT`, `BABY`) and toys (e.g., `BONE`, `MOUSE`). These are parsed to determine base body proportions and frame-by-frame 3D positioning.
- **`fonts/`**: Custom fonts used throughout the editor interface, including monospaced coding fonts (`PixelCode`, `CascadiaCode`) for the text editor and retro pixel fonts for the UI labels.
- **`icons/`**: The visual assets for the editor. This includes toolbar icons, tab graphics, and custom mouse cursors (like the paintbrush, eyedropper, and pinching hands) that swap dynamically based on the active mode.
- **`images/`**: Graphic assets such as splash screens and launcher rolls.
- **`lnz/`**: A library of example `.lnz` files categorized by species (`babyz/`, `catz/`, `dogz/`, `toyz/`). These serve as default templates, testing resources, and base structures for users to load and modify.
- **`palettes/`**: The original 256-color lookup tables used by the custom shaders to accurately map LNZ color indices to RGB values.
- **`styles/`**: Godot UI theme resources (`.tres` StyleBoxes) for panels, buttons, and text fields across the editor.
- **`textures/` & `texture_atlas/`**: The massive collection of base `.bmp` and `.png` textures. The `texture_atlas/` folder contains pre-baked sprite sheets generated by the utility scripts to allow the shaders to sample textures efficiently without loading hundreds of individual images into memory.

## Best Practices

### Treat LNZ as the source of truth

Currently, the data model that LnzLive builds from LNZ is temporary, and  the only persistent data exists in the LNZ text. The games are awfully (frurstratingly) flexible with what is valid LNZ, which means there is no canonical order or organization and delimiters can vary even in the same line. LnzLive allows users to modify their hex via the text editor, various modes, and visual interactions, but it all ultimately writes back to the LNZ file.

The `.lnz` text file is the only thing that matters. The 3D viewport is just a visualization of that text. Never try to save changes directly to the 3D nodes and hope they stick. Always ensure your changes are serialized back to the `LnzTextEdit` script. If the text doesn't update, the visual change is temporary and will vanish on reload.

### Check the Godot 3.2 documentation and use built-in linter

LnzLive is basically locked to Godot version 3.2, unless someone is willing to take on migrating to Godot 4, which would be admirable but masochistic. The custom Godot engine is compiled for Windows and provided in `engine/godot.zip`, but you can compile from source in  from [mnemoli/godot-petz](https://github.com/mnemoli/godot-petz/ or [Draconizations/godot-petz](https://github.com/Draconizations/godot-petz/).

If you use code assistants, then anticipate that these will likely spit out Godot 4 syntax that just won't work for Godot 3. Notably, Godot 3 does not use `@onready`, `await`, or typed signals (`signal name(arg: Type)`).

The Godot editor has a good built-in linter when you use its script editor, but you can also install Godot Tools extension for VSCode. Just keep in mind that for the linter to work outside of the editor, the editor needs to be open.

When in doubt, check out the [Godot 3.2 docs](https://docs.godotengine.org/en/3.2/)!

## Helpers and utilities are your friend

- Don't hardcode ball IDs but rather pull respective ballz or groups using arrays and dictionaries from `data_classes/key_balls_data.gd` specified by species using `KeyBallsData.FUNCTION()`.
- Put code that you might reuse multiple times as static functions in `data_classes/lnzlive_utils.gd` and call as `LnzLiveUtils.FUNCTION()`. For example, there are functions for color ramp calculations, number list parsing (e.g., `"1-5"` to `[1,2,3,4,5]`), and coordinate conversions.
- Review how data is pulled out of LNZ in `data_classes/lnz_parser.gd` and what gets stored in data classes.

## Style Guide

Godot has a few ways to do the same operation. Usually, these do not have performance differences, so the below recommendations are largely for consistency, maintainability, or preference.

- Use tabs for indentation
- Use `not` over `!` for conditionals as these are easier to read and spot
- Declare and enforce type on variables *unless* these can ever assume a `null` value
- Declare variables for nodes at the top of scripts to make easier to call elsewhere, e.g., `onready var node_variable: NodeType = find_node("NodeName")`
- Use `enums` and `match` instead of long `if`/`elif`/`else` blocks
- Use `enums` also for index items that may change in the future (makes easier to reorder later! see `ToolsMenu.gd` for examples)
- Use `snake_case` for variables and functions, `PascalCase` for classes and node types
- Place `export` and `signal` declarations at the top of scripts, followed by `var` declarations, then functions
- Use consistent array/dictionary spacing: `[1, 2, 3]` and `{key = value}`

## Console and Debug Messages

Use the following method to send messages to both the debug window and in-editor ConsoleLog UI panel (`ConsoleLog.gd`):

1. **Cache the reference** at the top of your script: `onready var console_log = find_node("ConsoleLog")`
2. **Use `print()`** for the debug window: `print("[STATUS] Loading file...")`
3. **Call `console_log.log_message()`** for the UI panel: `if console_log: console_log.log_message("[STATUS] Loading file...")`

Use descriptive prefixes to categorize messages: `[STATUS]`, `[ERROR]`, `[WARNING]`, `[TIME]`, `[HELPER]`, and also note the script from which the message originated (helps pinpoint bugs later, too!)

## Developer Tools

### Godot Unit Testing (GUT)

LnzLive includes a set of unit tests under `test/` for the [GUT](https://gut.readthedocs.io/en/godot_3x/index.html) test system intended to keep existing functions functional. The test set is far from having every function or edge case covered. We recommend running these tests before moving to the next step, or the reviewer will do so before including your changes in new versions of LnzLive.

Even better if your new feature adds unit test(s) for new functions! When writing unit tests, focus on pure logic and isolated math.

Check out [GUT v7.4.3 documentation](https://gut.readthedocs.io/en/godot_3x/index.html) and this [video tutorial on GUT](https://youtu.be/5DrhMiuLRl0?si=xYc7ewrJqfZhFoYb) or this [longer talk on unit tests by the GUT developer](https://youtu.be/ImqhHLlPfZg?si=qrk4ZZwU3IsV_s_p). This version of GUT is already included in the repository under `addons/gut/`, but does need to be enabled in Godot editor...

1. Enable GUT and Open the Interface
   - In the Godot editor, go to Project -> Project Settings.
   - Click the Plugins tab at the top.
   - Find Gut in the list and check the Enable box.
   - Close the settings. You will now see a new GUT tab at the very bottom of your editor window (next to Output, Debugger, etc.). Click it to open the testing panel.

2. Run `test_LnzLive.gd`
   - Inside the GUT panel, scroll down until you see a section called "Test Directories".
   - Enter `res://test` into "Directory 0"
   - Scroll to "XML Output" and enter `res://test/test.xml` (this will save a success/fail test record)
   - Click the "Run All" button. GUT will automatically find your script and execute all functions starting with `test_`.

## Helpful Links
- [**Godot 3.2 Docs**](https://docs.godotengine.org/en/3.2/)
- [**GUT Docs**](https://gut.readthedocs.io/en/godot_3x/index.html)
- [**LnzLive Task Tracker**](https://github.com/users/tabbzi/projects/3)
