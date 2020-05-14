# pdf-scribe.nvim

A Neovim plugin for importing annotations and metadata from PDFs

[[_TOC_]]

## Dependencies

You will need `LuaJIT` (if you're using this with Neovim, it's baked in), `poppler-glib`, `GObject`,
and `GLib` installed on your machine.

## Installation

Once you have the dependencies installed, use your preferred Neovim package manager. With
[`vim-packager`](https://github.com/kristijanhusak/vim-packager), this looks like:
```vim
call packager#add('wbthomason/pdf-scribe.nvim')
```

## Usage

`pdf-scribe` is **(a)** a (mostly) Neovim-agnostic LuaJIT library for extracting information (title,
author, keywords, external links) and (highlight, underline, and pop-up) annotations from PDFs, and
**(b)** a Neovim plugin serving as an example use of the library/a hopefully good out-of-the-box
experience for general users.

For **(a)**, the best documentation is [the code](lua/pdfscribe.lua). The short version is that the
module `pdfscribe` provides a function `load_pdf(pdf_file_path)` which returns a `PDF` object for a
given PDF file path. The `PDF` object has methods to extract the aforementioned information and
annotations from its PDF file. There are also convenience functions provided by the `pdfscribe`
module to get just annotations from a PDF (`get_annotations(pdf_file_path)`) and to get **all** info
from  a file (`get_all_info(pdf_file_path)`).

You can use the `pdfscribe` library to write your own PDF manipulation plugins.

**(b)** is designed to cover the most common imagined use case for `pdfscribe`: creating and
updating plain-text notes on PDF files. See [the docs](docs/pdfscribe.txt) for complete information.
The short version is that there are two commands provided: `:PdfScribeInit` to create a notes file
and `:PdfScribeUpdateNotes` to re-extract annotations and update the file. Both commands use
configurable templates with primitive conditional value substitution to generate files in whatever
format you prefer.

### Example Configuration

The only values you **must** configure are `g:pdfscribe_pdf_dir` and `g:pdfscribe_notes_dir`, which
set the directory in which `pdfscribe` looks for your PDF files and for your notes files,
respectively. See [the docs](docs/pdfscribe.txt) for more complete information.

## Contributing

PRs and issues (bugs and feature requests) are welcome!

## Notes
- The core PDF library only depends on Neovim for checking if files exist. The rest of it is
  portably reusable in any LuaJIT environment.
- As the LuaJIT module is a wrapper around a C library, bugs may cause segfaults. Bug reports for
  segfault bugs are **particularly** welcomed.
- This plugin may eat your files, lunch, and/or car.
