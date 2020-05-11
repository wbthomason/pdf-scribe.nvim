# pdf-scribe.nvim

A Neovim plugin for importing annotations and metadata from PDFs

## Dependencies

You will need `LuaJIT` (if you're using this with Neovim, it's baked in), `poppler-glib`, `GObject`,
and `GLib` installed on your machine.

## Installation

Use your preferred Neovim package manager. With
[`vim-packager`](https://github.com/kristijanhusak/vim-packager), this looks like:
```vim
call packager#add('wbthomason/pdf-scribe.nvim')
```

## Usage

Forthcoming!

### Example Configuration

Forthcoming!

## Notes
- Incidentally, the core PDF library only depends on Neovim for logging errors. The rest of it is
  portably reusable in any LuaJIT environment.
