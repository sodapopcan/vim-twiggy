# twiggy.vim

Maintain your bearings while branching with git

## About

Twiggy is a [fugitive](https://github.com/tpope/vim-fugitive) extension that
loads, decorates and sorts(!) git branches into an interactive buffer.  It
provides basic merge and rebase support, stashing, and some other goodies.

It also has [dispatch](https://github.com/tpope/vim-dispatch) support!

## NB!

This plugin was developed on a 2013ish MacBook Air with Vim 7.3/7.4 and
Git 1.8, 1.9 and 2.1.2.  It hasn't been tested in any other context.  Pull
Requests are welcome!

## Basic Usage

Invoke Twiggy with the `:Twiggy`, or simply `:Twig` command.

Once inside the buffer, use `j` and `k` to jump between branch names and `<C-N>`
and `<C-P>` to jump between groups (locals/remotes).  As your cursor moves,
information about the branch under the cursor will be echoed to the command
prompt.

To checkout a branch, hit `c`.  If the branch is remote and a tracking branch
doesn't yet exist for it, one will be created.  `C` works the same way only it
will checkout a remote branch in detached HEAD.  You can also use `o` and `O`.
`<C-R>` (Enter) is an alias for `c`.

With your cursor on a branch, `m` merges it into the current branch.  With your
cursor on a local branch, `M` will merge its tracking branch into the current
branch.  Use `r` and `R` for rebasing.  `f` fetches the branch under the cursor
whereas `F` performs a `git fetch --all`.

Hint: to pull on the current branch, move your cursor to it and press `f` then
press `M`.

`^` to push.

Create a new branch with `:Twig <branch-name>`.

Press `i` to cycle through sorting options.

Type `q` to quit.

`:h twiggy` for plenty more.

## Installation

NeoBundle, Vundle or Pathogen are all fine options.

You __must__ have [fugitive](https://github.com/tpope/vim-fugitive) installed!
