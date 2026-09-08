{
  lib,
  config,
  ...
}:
# The buffer's colour discipline, after NANO emacs (Nicolas Rougier's N Λ N O).
#
# WHY THIS EXISTS. stylix's helix target generates a stock base16 theme, and
# base16's slot convention is one hue per syntax category — variables red,
# types yellow, strings green, functions blue, keywords magenta. That is six
# colours carrying no relative meaning: nothing on screen is more urgent than
# anything else, so all the palette says is "this is a different KIND of
# token", which the shape of the code already said. The rest of this desktop
# stopped working that way in the 2026-09-02 pass — docs/ember-visual-language.md,
# principle 3, "colour means something" — but that pass never reached inside a
# buffer, which is where most of the day is spent. This is that principle,
# applied there.
#
# NANO's model is a small set of FACES chosen by how much attention the text
# deserves, rather than by what the text is:
#
#   default   your own names — what you are reading now
#   faded     prose, not code — comments
#   strong    same colour, more weight — definitions, headings, the focused row
#   salient   the language itself — keywords, types, tags
#   literal   values written out in the source — strings, numbers
#   popout    look here now, and it will stop being true shortly
#   critical  something is wrong
#
# `strong` is not a colour and so has no palette entry — it is default + bold.
#
# HOW MANY LEVELS THE RAMP ACTUALLY HAS: two, not three. Measured against the
# ground, as WCAG contrast ratios:
#
#   base03  3.41:1     base04  9.19:1     base05  14.74:1
#
# so base04 → base05 is 1.60:1 — under the threshold where the eye reads two
# values as different at all. base04 is NOT a third foreground step; it is a
# fill (9.19:1 against the ground is a perfectly good *background*, which is
# all it is used for below, in ui.menu.selected and the statusline).
#
# The first cut of this file spent it as a text colour on punctuation and
# operators, justified as "a real step (43/255)". That is a raw channel delta,
# which is the same error principle 3 records under "tick marks a value step
# below the brackets" — it read as code with a smudge on it, and its one real
# effect was to fill in the middle of the comment→code gap and flatten the
# whole buffer. Deleted; punctuation is `default`, which is what NANO does too.
#
# The consequence for `faded`: with two levels there is exactly ONE thing that
# can recede, so `faded` is single-tenant — prose. NANO fades strings as well,
# and on NANO's own white ground it can afford to (its faded/default separation
# is ~7x; ember's dark end gives 4.3x). Here that made string literals read as
# commented-out code, so strings take a hue instead.
#
# WHY THREE HUES AND NOT TWO. Every hue in this palette sits 1.4–2.7:1 from
# base05 — hues do not separate from code by *value*, they separate by hue.
# That is why the base16 rainbow "worked" and why collapsing all of it onto a
# two-level ramp lost the separation. So the buffer keeps exactly the
# distinctions the ramp cannot carry: the language (`salient`), values written
# out literally (`literal`), your own names (`default`), prose (`faded`). Four
# roles, three hues, and no hue for a mere token *category*.
#
# WHY NOT IN rices/ember. A rice owns the palette; this file owns the *mapping*
# from palette slots onto those roles, which is a claim about how code should be
# read and holds for any base16 scheme (orchid's estradiol included). Keeping it
# in desktop/ is also what keeps an ocelot honest: homes/ocelot.nix imports
# ../desktop/helix.nix and switches on stylix's helix target precisely so "the
# shell inside an ocelot is the shell outside it", and a rice-gated theme would
# have quietly broken that the moment it landed.
#
# TWO SLOT COMMENTS ARE DELIBERATELY CONTRADICTED. rices/ember/ember-3400k-dark.yaml
# annotates base0D "blue — functions" and base0E "magenta — keywords". Those
# describe the base16 convention this file departs from, and they stay accurate
# for every other consumer of the scheme (the ANSI palette, fish's syntax
# highlighting, the diff tools), so the yaml is not edited. Here functions are
# `strong` and keywords are `salient`, and base0E goes unused.
#
# base09 — "the ember" — is absent on purpose. Principle 3 spends it in exactly
# one place on the entire desktop (the wallpaper's centre reticle) so that it
# still reads as a signal; popout has a slot of its own in base0A, which the
# scheme already annotates "warnings, matches".
lib.mkIf (config.stylix.enable or false) (
  let
    inherit
      (config.lib.stylix.colors.withHashtag)
      base00
      base01
      base02
      base03
      base04
      base05
      base08
      base0A
      base0B
      base0D
      ;
  in {
    programs.helix = {
      # stylix's helix target writes themes/stylix.toml and points
      # settings.theme at it at normal priority, hence mkForce. The target is
      # left enabled rather than switched off in the three stylix configs that
      # reach helix (rices/ember, rices/estradiol, homes/ocelot.nix); the cost
      # is one unread file in the store, and nothing has to stay in sync.
      settings.theme = lib.mkForce "nano";

      themes.nano = {
        palette = {
          ground = base00;
          lifted = base01;
          subtle = base02;
          faded = base03;
          # base04. A fill only — never a text colour inside a buffer; see the
          # ramp note in the header.
          dim = base04;
          default = base05;
          critical = base08;
          popout = base0A;
          # Both base0B. Two names for one value because they are two roles
          # that happen to agree: a string in a buffer and a `+` in a diff are
          # not the same statement, and a later palette could separate them.
          literal = base0B;
          added = base0B;
          salient = base0D;
        };

        # ---- syntax -------------------------------------------------------
        # An unmapped scope falls through to ui.text, which is `default`. That
        # fallthrough is doing most of the work: variables, fields, parameters
        # and every language-specific capture are simply the text you are
        # reading, and listing them here to say "default" would only make the
        # theme longer, not quieter.

        # faded — prose, and nothing else. Single-tenant on purpose: the ramp
        # has one level to spend on receding, so spending it twice is what made
        # strings look commented out. Italic does the rest of the work, and it
        # is a real face (Ioskeley ships Italic, so nothing is synthesised).
        comment = {
          fg = "faded";
          modifiers = ["italic"];
        };

        # literal — written-out values. A string and a number are the same kind
        # of thing (data sitting in the source), which is why they share a face
        # rather than getting one hue each the way base16 hands them out.
        string = "literal";
        "string.regexp" = "literal";
        constant = "literal";
        "constant.character.escape" = "literal";

        # strong — a definition, or the thing being pointed at.
        function = {
          fg = "default";
          modifiers = ["bold"];
        };
        constructor = {
          fg = "default";
          modifiers = ["bold"];
        };
        label = {
          fg = "default";
          modifiers = ["bold"];
        };

        # salient — the language, as opposed to anything you named or wrote out.
        keyword = "salient";
        type = "salient";
        "variable.builtin" = "salient";
        namespace = "salient";
        attribute = "salient";
        special = "salient";
        tag = "salient";

        # ---- markup (markdown, typst — marksman/tinymist/harper are on) ---
        # Heading level is conveyed by the marker and the indent, so all six
        # levels share one face; bold and italic carry no colour at all, which
        # is the clearest case of "weight and shape, not value".
        "markup.heading" = {
          fg = "default";
          modifiers = ["bold"];
        };
        "markup.bold".modifiers = ["bold"];
        "markup.italic".modifiers = ["italic"];
        "markup.strikethrough".modifiers = ["crossed_out"];
        "markup.link.url" = {
          fg = "salient";
          modifiers = ["underlined"];
        };
        "markup.link.text" = "salient";
        "markup.list" = "default";
        # Inline code and fenced blocks are literal content, same as a string.
        "markup.raw" = "literal";
        "markup.quote" = {
          fg = "faded";
          modifiers = ["italic"];
        };

        # ---- diagnostics --------------------------------------------------
        # The one place hue is spent on severity, because severity is exactly
        # the "how much attention" question the faces answer. Curl for the two
        # that want acting on, dotted for the two that do not; wezterm's own
        # terminfo is what makes both render (see rices/ember/wezterm.nix).
        error = "critical";
        warning = "popout";
        info = "salient";
        hint = "faded";
        debug = "faded";

        "diagnostic.error".underline = {
          color = "critical";
          style = "curl";
        };
        "diagnostic.warning".underline = {
          color = "popout";
          style = "curl";
        };
        "diagnostic.info".underline = {
          color = "salient";
          style = "dotted";
        };
        "diagnostic.hint".underline = {
          color = "faded";
          style = "dotted";
        };
        "diagnostic.unnecessary".modifiers = ["dim"];
        "diagnostic.deprecated".modifiers = ["crossed_out"];

        # ---- diff ---------------------------------------------------------
        # Three hues in a one-column gutter, kept because the sign's entire
        # meaning is its colour — there is no shape to fall back on. `delta` is
        # salient rather than popout: "changed" is a fact, not an alarm, and
        # popout has to stay scarce to keep working.
        "diff.plus" = "added";
        "diff.minus" = "critical";
        "diff.delta" = "salient";

        # ---- chrome -------------------------------------------------------
        "ui.background".bg = "ground";
        "ui.text" = "default";
        "ui.text.focus" = {
          fg = "default";
          modifiers = ["bold"];
        };
        "ui.text.inactive" = "faded";
        "ui.text.directory" = "faded";
        "ui.text.info" = "default";

        # Reversed, not a coloured block: the cursor is the terminal's steady
        # block (docs/ember-visual-language.md, "A terminal") and inverting the
        # cell is how you get that shape without introducing a hue.
        "ui.cursor".modifiers = ["reversed"];
        "ui.cursor.primary".modifiers = ["reversed"];
        "ui.cursor.match" = {
          fg = "popout";
          modifiers = ["bold"];
        };

        "ui.selection".bg = "subtle";

        # No `bg` on the gutter, the line numbers or the statusline. The stock
        # base16 theme fills all three with base01, which on this palette is
        # 6/255 above the ground — an invisible fill is the worst of both
        # trades: it lights pixels for the panel's lifetime (ADR 0009) and
        # tells the reader nothing. Removing it also gives NANO's bottom
        # modeline: a line of secondary text, not a bar. ui.gutter is simply
        # absent — with no bg of its own it falls through to ui.background,
        # which is the point.
        "ui.linenr" = "faded";
        "ui.linenr.selected" = {
          fg = "default";
          modifiers = ["bold"];
        };

        "ui.statusline".fg = "dim";
        "ui.statusline.inactive".fg = "faded";
        "ui.statusline.separator".fg = "faded";

        # Same treatment for the bufferline: open buffers as a row of names,
        # the current one by weight rather than by a tab-shaped fill.
        "ui.bufferline".fg = "faded";
        "ui.bufferline.active" = {
          fg = "default";
          modifiers = ["bold"];
        };

        # Popups are the one thing that DOES get an edge. A floating surface
        # needs a boundary, and on a palette this compressed a fill cannot
        # provide one (see the gutter note) — so the boundary is a 1px outline
        # in `faded`, which is the same answer the bar gives (principle 2,
        # flush and square with a 1px outline) rather than a second idea.
        # `lifted` behind it only stops the buffer text underneath from
        # reading through as part of the popup.
        "ui.popup" = {
          fg = "faded";
          bg = "lifted";
        };
        "ui.popup.info" = {
          fg = "faded";
          bg = "lifted";
        };
        "ui.window".fg = "faded";
        "ui.help" = {
          fg = "default";
          bg = "lifted";
        };
        "ui.menu" = {
          fg = "default";
          bg = "lifted";
        };
        # The only inverse in the theme, and the only lit block: one row of one
        # transient list, marked without a hue.
        "ui.menu.selected" = {
          fg = "ground";
          bg = "dim";
        };
        "ui.menu.scroll" = {
          fg = "faded";
          bg = "lifted";
        };

        "ui.picker.header".fg = "faded";
        "ui.picker.header.column.active" = {
          fg = "default";
          modifiers = ["bold"];
        };

        # Anything virtual is faded by default; inlay hints are the reason it
        # matters, since `lsp.display-inlay-hints` is on and rust-analyzer
        # emits them on most lines. The stock theme left them at ui.text, so
        # inferred types read as loudly as the code they annotate.
        "ui.virtual" = "faded";
        "ui.virtual.inlay-hint" = "faded";
        "ui.virtual.wrap" = "faded";
        "ui.virtual.whitespace" = "subtle";
        "ui.virtual.indent-guide" = "subtle";
        "ui.virtual.ruler".bg = "lifted";
        # Jump labels are the textbook popout: they appear, you look, they go.
        "ui.virtual.jump-label" = {
          fg = "popout";
          modifiers = ["bold"];
        };

        "ui.highlight" = {
          bg = "subtle";
          modifiers = ["bold"];
        };
        "ui.highlight.frameline".bg = "subtle";

        "ui.debug.breakpoint".fg = "critical";
        "ui.debug.active".fg = "popout";
      };
    };
  }
)
