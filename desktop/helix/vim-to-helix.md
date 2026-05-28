# Vim → Helix: a noob's survival guide

You don't need to be a Vim wizard for this. The point of this doc is to get you
productive in Helix fast: moving around, selecting, cutting/copying/pasting,
searching, editing. Everything below is **stock Helix** except one custom key
(`Space f`, noted at the end) — so it matches the config in this repo.

---

## 1. The ONE thing you must internalize

Vim is **verb → noun**: you type an action, then what to act on.
- `dw` = "**d**elete a **w**ord"
- `ci(` = "**c**hange **i**nside **(** "

Helix is **noun → verb**: you *select first*, then act. The selection is always
visible, so you see what you're about to hit before you hit it.
- `w` then `d` = select word, then delete it
- `mi(` then `c` = select inside parens, then change

> Whenever your Vim brain wants to type `d<motion>`, in Helix you instead do
> `<motion>` (which selects) and *then* `d`. Almost every Vim command maps this
> way once you flip the order.

There's always a selection — even a single character counts as a 1-char
selection. Movement *extends or replaces* that selection.

---

## 2. Modes (same idea as Vim, one extra)

| Mode | How you get there | What it's for |
|------|-------------------|---------------|
| **Normal** | `Esc` | Default. Move, select, run commands. |
| **Insert** | `i` `a` `o` etc. | Type text. |
| **Select** | `v` | "Visual mode." Movements *extend* the selection instead of replacing it. |

Helix has no separate visual-line / visual-block modes — multiple cursors
(section 8) replace block mode, and `x` (section 4) replaces line mode.

---

## 3. Moving / navigating

Mostly identical to Vim:

| Key | Does |
|-----|------|
| `h` `j` `k` `l` | left / down / up / right |
| `w` / `b` | next / previous word start *(also selects the word!)* |
| `e` | end of word |
| `0` | start of line |
| `$` *(or* `End`*)* | end of line — **but in Helix the canonical key is** `gl` |
| `gh` | start of line (alias for `0`) |
| `gs` | first non-whitespace char of line |
| `gg` | top of file |
| `ge` | end of file *(Vim's `G`)* |
| `Ctrl-d` / `Ctrl-u` | half page down / up |
| `Ctrl-f` / `Ctrl-b` | full page down / up |
| `f<char>` / `t<char>` | jump to / till char (also selects to it) |
| `%` | matching bracket |

### The `g` menu (goto)
Press `g` and a popup shows your options. Most useful:
- `gg` top, `ge` bottom
- `gl` end of line, `gh` start of line
- `gd` **go to definition** (LSP — works in this repo for rust/ts/nix/etc.)
- `gr` go to references
- `gy` go to type definition
- `gi` go to implementation
- `gn` / `gp` next / previous buffer

> **Gotcha:** Vim's `G` (go to end of file) is `ge` in Helix. `gg` still works
> for the top.

---

## 4. Selecting text

This is where Helix shines. Movements select as you go, but the explicit tools:

| Key | Selects |
|-----|---------|
| `w` `b` `e` | a word (forward / back / to end) |
| `x` | the **current line** (press again to extend line-by-line) |
| `v` | enter select mode — now `w`, `j`, `f`, etc. *extend* the selection |
| `%` | the **entire file** |
| `mi(` | **inside** the parens — `m`atch `i`nner. Also `mi{`, `mi"`, `mi<`, … |
| `ma(` | **around** the parens (includes the brackets) |
| `miw` | inner word; `maw` a word + surrounding space |
| `mip` | inner paragraph |
| `s` | **select within selection by regex** — type a pattern, get a cursor on each match |

> `mi` / `ma` = Vim's `i` / `a` text objects (`ci(` → here it's `mi(` then `c`).
> The `m` stands for "match".

To **shrink/grow** a selection to the whole line use `x`. To **collapse** a
multi-line mess back to a single cursor, press `;` (collapse selection to one
cursor) and `,` (remove all but the primary cursor).

---

## 5. Cut, copy, paste, delete

| Key | Does | Vim equivalent |
|-----|------|----------------|
| `y` | **yank** (copy) the selection | `y` |
| `d` | **delete** the selection *(also puts it in the register — so this is your "cut")* | `d` / `x` |
| `c` | **change**: delete selection + drop into insert mode | `c` |
| `p` | paste **after** cursor/selection | `p` |
| `P` | paste **before** | `P` |
| `R` | replace selection with yanked text | `vp` / `"_dP` |
| `r<char>` | replace each selected char with `<char>` | `r` |
| `u` / `U` | undo / redo *(note: redo is `U`, not `Ctrl-r`)* | `u` / `Ctrl-r` |
| `.` | repeat last insert/change | `.` |

### Common recipes (Vim → Helix)

| You want to… | Vim | Helix |
|--------------|-----|-------|
| Delete a word | `dw` | `w` `d` |
| Change a word | `cw` | `w` `c` (or `miw` `c` for the word under cursor) |
| Delete a line | `dd` | `x` `d` |
| Copy a line | `yy` | `x` `y` |
| Change inside quotes | `ci"` | `mi"` `c` |
| Delete to end of line | `D` | `gl` then... actually just `Esc` then in select: `vgl d`. Simpler: `t<char>` to select, or use `Alt-l`. |
| Copy from cursor to end of line | `y$` | `vgl y` (enter select, go to line end, yank) |
| Select & delete to end of file | `dG` | `vge d` |

> **Big gotcha #1:** `dd` does *not* delete a line in Helix. `d` with no
> selection deletes one character (like Vim's `x`). Use `x` `d` to delete a
> line, or `xd` quickly.

> **Big gotcha #2:** **Redo is `U`** (capital), not `Ctrl-r`. `Ctrl-r` in normal
> mode is "insert register contents."

> **Clipboard:** `y`/`d`/`p` use Helix's internal register, not your OS
> clipboard. For the **system clipboard** prefix with `Space`:
> `Space y` (copy to clipboard), `Space p` (paste from clipboard),
> `Space R` (replace from clipboard).

---

## 6. Entering insert mode (same as Vim)

| Key | Does |
|-----|------|
| `i` / `a` | insert before / after cursor |
| `I` / `A` | insert at line start / end |
| `o` / `O` | open new line below / above |
| `c` | change selection (delete + insert) |

---

## 7. Search

| Key | Does |
|-----|------|
| `/` | search forward (then `Enter`) |
| `?` | search backward |
| `n` / `N` | next / previous match |
| `*` | search for word under cursor |
| `Space /` | **global search** across the whole workspace (ripgrep-style picker) |

Each search match becomes a *selection*, which means you can immediately act on
it or turn matches into multiple cursors.

---

## 8. Multiple cursors — Helix's superpower

This replaces a ton of Vim macros and `:%s` substitutions.

| Key | Does |
|-----|------|
| `C` | add a cursor on the line **below** (repeat to keep adding) |
| `Alt-C` | add a cursor on the line **above** |
| `s` | within the current selection, place a cursor on **every regex match** |
| `,` | collapse back to a single (primary) cursor |
| `;` | collapse each selection to a single cursor |
| `Alt-)` / `Alt-(` | rotate which cursor is "primary" |

**Classic workflow — rename every `foo` in a block to `bar`:**
1. `x` a few times (or `mip`) to select the region.
2. `s`, type `foo`, `Enter` → a cursor on each `foo`.
3. `c`, type `bar`, `Esc`. Done — every occurrence changed at once.

This is the thing that makes ex-Vim users stop missing `:s/.../.../g`.

---

## 9. Files, buffers, and the `Space` menu

Press `Space` and a popup menu appears — you don't need to memorize these,
just read the menu. Highlights:

| Key | Does |
|-----|------|
| `Space f` | **open file picker** — *in this repo it's customized to show recent files first, then all workspace files* |
| `Space b` | buffer picker (switch open files) |
| `Space /` | global text search (ripgrep) |
| `Space s` | symbol picker (jump to functions/types in current file) |
| `Space S` | workspace symbol picker |
| `Space k` | hover docs (LSP) |
| `Space a` | code actions (LSP — quick fixes, imports) |
| `Space r` | rename symbol (LSP) |
| `Space d` | diagnostics picker |
| `Space y` / `Space p` | system-clipboard copy / paste (see §5) |
| `Space '` | resume last picker |

Switch buffers fast with `gn` / `gp` (next/prev). Close a buffer with `:bc`.

---

## 10. LSP / code intelligence

Your config wires up language servers for rust, typescript/tsx/js/jsx, php, vue,
nix, markdown, typst, java. So these work out of the box:

| Key | Does |
|-----|------|
| `gd` | go to definition |
| `gr` | find references |
| `Space k` | show hover documentation |
| `Space a` | code action (auto-import, quick-fix) |
| `Space r` | rename symbol project-wide |
| `]d` / `[d` | next / previous diagnostic (error/warning) |
| `=` | format selection (some langs auto-format on save here) |

---

## 11. Saving & quitting (command mode)

Type `:` then a command — same muscle memory as Vim:

| Command | Does |
|---------|------|
| `:w` | write (save) |
| `:wq` or `:x` | write and quit |
| `:q` | quit |
| `:q!` | quit without saving |
| `:wa` / `:qa` | write all / quit all buffers |
| `:o <path>` | open a file by path |
| `:reload` | reload file from disk |

`:` opens a fuzzy command palette — start typing and it autocompletes, so you
don't have to remember exact names.

---

## 12. Cheat-sheet of Vim habits that will bite you

| Your Vim reflex | What actually happens in Helix | Do this instead |
|-----------------|-------------------------------|-----------------|
| `dd` to delete a line | deletes one char | `x` then `d` |
| `yy` to copy a line | yanks one char | `x` then `y` |
| `dw` to delete a word | deletes one char, then... nothing useful | `w` then `d` |
| `Ctrl-r` to redo | inserts a register | `U` |
| `G` to go to end | nothing | `ge` |
| `ciw` change word | no-op | `miw` then `c` |
| `:%s/a/b/g` | works, but unnecessary | `%` `s` `a` ⏎, then `c` `b` |
| `y` then `p` pastes to system clipboard | pastes from internal register | `Space y` / `Space p` for OS clipboard |

---

## 13. Built-in help

- **`Space ?`** opens the command list — searchable.
- Hit any prefix key (`g`, `Space`, `m`, `z`, `[`, `]`) and **wait half a
  second**: a popup shows every key available from there. This is the real way
  to learn Helix — you almost never need this doc once the menus click.
- `hx --tutor` in a terminal runs the interactive tutorial (~30 min, worth it).

---

### TL;DR to be productive today
1. **Select first, act second** (`w d`, not `d w`).
2. `x` selects lines (`x d` = delete line, `x y` = copy line).
3. **Redo is `U`**, system clipboard is `Space y` / `Space p`.
4. `Space f` for files, `Space /` for project search, `gd` to jump to a definition.
5. When stuck, press a prefix key and read the popup menu.
