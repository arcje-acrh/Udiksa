THEMES -- every folder here is a theme. Pick one with Super+T.

Add a theme      make a new folder here and put pictures in it (.jpg .png .webp). Done: it shows up in Super+T.
                 The first time, its colours are made from its pictures and saved as colors.toml in the folder.
Remove a theme   delete its folder.
More wallpapers  drop more pictures into the theme's folder.
See colours     `udiksa theme colors <picture>` in a terminal shows a picture's main colours + the theme colours it gives.
Change colours   open colors.toml in the theme's folder, change the "#rrggbb" values (each line says what it
                 colours; `accent` is the main one), save, then pick the theme again (Super+T) or run
                 `udiksa theme reapply` in a terminal. Delete colors.toml to have the colours made from the pictures again.
Each picture shifts the colours a little, so every wallpaper of a theme feels slightly different.
SOURCES.txt in each folder says where the pictures came from.

======================================================================================================
WHAT VALUE GOES WHERE (colors.toml)
======================================================================================================
Think of it as a LADDER from dark to light, plus one "personality" colour (accent) and the terminal colours.
First look at the picture's colours:  udiksa theme colors <picture>

THE LADDER (dark theme, darkest -> lightest)
  darker_background    deepest shade (rarely seen)                    -> darker than background
  dark_background      a darker shade (some apps)                     -> between the two
  background           THE NOTCH, THE TERMINAL, APP WINDOWS           -> the darkest main colour (5-12 % light)
  lighter_background   the panels / cards inside the notch            -> a step lighter than background
  selection            buttons, empty slider segments, selected text  -> another step lighter
  muted                icons that are off, hints, disabled text       -> a mid-dark grey, quiet but visible
  dark_foreground      labels, notes, the prompt's branch / time      -> a mid-light colour (~60 %)
  foreground           NORMAL TEXT                                    -> very light (85-92 %), slightly tinted
  light_foreground,
  bright_foreground    brightest text, the terminal cursor            -> near-white

THE PERSONALITY
  accent               everything "on" or selected: switches, LED bars, window border, the prompt ❯,
                       today in the calendar, highlights
                       -> the picture's MOST STRIKING colour, and fairly LIGHT (60-75 %) so it glows on the
                          dark background. Its lighter tint (volume above 100 %, border gradient) is made from
                          it automatically.

TERMINAL COLOURS
  red green yellow blue magenta cyan (+ bright_ versions): ls, git, errors (red), success (green), the
  prompt's git changes (magenta). Keep each one recognisable as its colour, you may nudge it toward the
  picture's mood. bright_ = a lighter version.

LIGHT THEMES
  mode = "light" flips the ladder: background is the lightest, foreground the darkest, and accent should
  then be fairly DARK.

WORKED EXAMPLE (the Graphite lake picture; `udiksa theme colors` showed greys #141617 (28 %) ... #909293 (32 %))
  background         = "#141617"   # darkest main colour
  lighter_background = "#232426"   # next step up
  selection          = "#333536"   # next step
  muted              = "#525456"
  dark_foreground    = "#909293"   # the big light grey
  foreground         = "#e2e3e5"   # the light grey pushed near-white
  accent             = "#b9bcc4"   # no vivid colour in the picture -> a bright silver from the sky

RULES OF THUMB
  * Each ladder step only a little lighter than the one below (big jumps look harsh, tiny ones blur).
  * The accent is the one colour you would describe the picture by: "the orange sunset", "the teal water".
  * Don't worry about perfect contrast: the theme engine automatically lightens / darkens any value that
    would make text, buttons or icons hard to read.
  * After editing: save, then `udiksa theme reapply` (or pick the theme again with Super+T).
