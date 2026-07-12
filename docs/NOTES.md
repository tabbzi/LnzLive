# LnzLive - Notes

LnzLive is an interactive editor for P.F. Magic LNZ data. All minor notes about development will be dropped in this document. Major tasks will be added as Issues to the [LnzLive Task Tracker](https://github.com/users/tabbzi/projects/3/views/6) associated with the GitHub repository.

## Code Review

🔴 DRY Violations | 🟡 Needs Optimization | 🔵 Dead Code | 🟣 Structural Issues

Updated: 2026-07-07

### Data Classes (Parsers & Utils)

#### `data_classes/lnz_parser.gd`


#### `data_classes/bhd_parser.gd` & `bdt_parser.gd`


#### `data_classes/lnzlive_utils.gd`


### Model Generation & Logic

#### `scenes/dog_generator.gd`

### Viewports & Inputs

#### `scenes/editor/PetViewContainer.gd`

### Text Editor

#### `scenes/editor/LnzTextEdit.gd`

### Visual Nodes (`Ball.gd`, `Line.gd`, etc.)

### Modes & Settings

#### `AutoPaintballerSettings.gd` & `PaintballSettings.gd`

## Open Issues

Updated: 2026-07-11

#### #53 Parse and render `[Z Shade Slope]` arguments
- **Status:** parsing drafted, rendering missing

#### #89 Add `Apply as Overrides` option to Recolor Menu
- **Status:** not started

#### #165 Allow addballz (+ linez) creation from Move Mode
- **Status:** not started

#### #36 Add function to apply overrides to base data
- **Status:** parser drafted

## Bugs

Recording observations about bugs here... making issues when the problem and solution are more clear...
