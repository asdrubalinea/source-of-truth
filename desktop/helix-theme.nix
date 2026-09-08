{
  lib,
  config,
  ...
}:
# The buffer's colour discipline, after NANO emacs (Nicolas Rougier's N Λ N O).
#
# WHY. base16's convention is one hue per syntax category — six colours carrying
# no relative meaning, so all the palette says is "a different KIND of token",
# which the shape of the code already said. This applies principle 3 of
# docs/ember-visual-language.md ("colour means something") inside the buffer,
# which the 2026-09-02 pass never reached.
#
# NANO picks FACES by how much attention the text deserves, not by what it is:
#
#   default   your own names — what you are reading now
#   faded     prose, not code — comments
#   strong    same colour, more weight — definitions, headings, focused row
#   salient   the language itself — keywords, types, tags
#   literal   values written out in the source — strings, numbers
#   popout    look here now, and it will stop being true shortly
#   critical  something is wrong
#
# `strong` has no palette entry: it is default + bold.
#
# THE RAMP HAS TWO LEVELS, NOT THREE. Contrast against the ground: base03
# 3.41:1, base04 9.19:1, base05 14.74:1 — so base04→base05 is 1.60:1, under the
# threshold where the eye reads two values as different. base04 is a FILL, not a
# third foreground step, and it is only ever used as a background below. Spending
# it as a text colour on punctuation (justified as "a real step, 43/255" — a raw
# channel delta, the exact error principle 3 records) filled in the middle of the
# comment→code gap and flattened the buffer. Punctuation is `default`, as in NANO.
#
# Two levels means exactly ONE thing can recede, so `faded` is single-tenant:
# prose. NANO fades strings too and can afford to on a white ground; here it made
# string literals read as commented-out code, so strings take a hue instead.
#
# THREE HUES, NOT TWO. Every hue here sits 1.4–2.7:1 from base05, so hues
# separate from code by hue and not by value — which is why the base16 rainbow
# "worked" and why collapsing it onto a two-level ramp lost the separation. The
# buffer therefore keeps exactly the distinctions the ramp cannot carry: the
# language, literal values, your own names, prose. No hue for a token *category*.
#
# NOT IN rices/ember, because a rice owns the palette while this owns the
# *mapping* onto roles, which holds for any base16 scheme. It is also what keeps
# an ocelot honest — homes/ocelot.nix imports ../desktop/helix.nix so "the shell
# inside an ocelot is the shell outside it", and a rice-gated theme would have
# broken that.
#
# TWO SLOT COMMENTS ARE DELIBERATELY CONTRADICTED: ember-3400k-dark.yaml
# annotates base0D "functions" and base0E "keywords", describing the convention
# this file departs from. They stay accurate for every other consumer of the
# scheme, so the yaml is not edited — here functions are `strong`, keywords are
# `salient`, and base0E goes unused. base09 ("the ember") is absent on purpose:
# principle 3 spends it in exactly one place on the whole desktop so that it
# still reads as a signal. popout has its own slot in base0A.
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
      # stylix's helix target points settings.theme at its own generated file
      # at normal priority, hence mkForce. The target is left enabled rather
      # than switched off in each stylix config that reaches helix: the cost is
      # one unread file in the store, and nothing has to stay in sync.
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
        # An unmapped scope falls through to ui.text, i.e. `default` — and that
        # fallthrough does most of the work here. Variables, fields, parameters
        # and every language-specific capture are simply the text you are
        # reading; listing them to say "default" would only make this longer.

        # faded — prose, and nothing else; single-tenant for the reason above.
        # Italic does the rest, and it's a real face (Ioskeley ships Italic, so
        # nothing is synthesised).
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
        # Heading level is already carried by the marker and the indent, so all
        # six levels share one face, and bold/italic carry no colour at all.
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
        # The one place hue is spent on severity — which is exactly the "how
        # much attention" question the faces answer. Curl for the two worth
        # acting on, dotted for the two that aren't; wezterm's own terminfo is
        # what makes both render.
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
        # meaning IS its colour — there is no shape to fall back on. `delta` is
        # salient, not popout: "changed" is a fact, not an alarm, and popout has
        # to stay scarce to keep working.
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

        # No `bg` on the gutter, line numbers or statusline. The stock theme
        # fills all three with base01, 6/255 above the ground — an invisible
        # fill is the worst trade available: it lights pixels for the panel's
        # lifetime (ADR 0009) and tells the reader nothing. Removing it also
        # gives NANO's bottom modeline, a line of secondary text rather than a
        # bar. ui.gutter is absent entirely so it falls through to
        # ui.background, which is the point.
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

        # Popups are the one thing that DOES get an edge: a floating surface
        # needs a boundary, and on a palette this compressed a fill can't give
        # one (see the gutter note). A 1px outline in `faded` is the same answer
        # the bar gives (principle 2) rather than a second idea. `lifted` behind
        # it only stops the buffer text reading through as part of the popup.
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

        # Anything virtual is faded. Inlay hints are why it matters:
        # `lsp.display-inlay-hints` is on and rust-analyzer emits them on most
        # lines, and the stock theme left them at ui.text — so inferred types
        # read as loudly as the code they annotate.
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
