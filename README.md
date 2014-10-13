# twiggy.vim

Maintain your bearings while branching with git

## About

Twiggy is a [fugitive](https://github.com/tpope/vim-fugitive) extension that
loads, decorates and sorts(!) git branches into an interactive buffer.  It
provides basic merge and rebase support, stashing, and some other goodies.

It also has [dispatch](https://github.com/tpope/vim-dispatch) support!

## NB!

While I have been developing and using this plugin for quite some time, it's
only been publicly available since Oct 11, 2014.  It was developed entirely on a
2013 MacBook Air with Vim 7.3/7.4 and most git 1.8/1.9/2.x (I didn't update to
2.x until very recently).  It hasn't been tested in any other context.  Also,
this is my very first Vim plugin.

## Basic Usage

Invoke Twiggy with the `:Twiggy`, or simply `:Twig` command.

Once inside the buffer, you can navigate branch names with `j` and `k`
or jump between groups (locals/remotes) with `<C-N>` and `<C-P>`.  As your
cursor moves, information about the branch under the cursor will be echoed to
the command prompt.

To checkout a branch, hit `c`.  If the branch is remote and a tracking branch
doesn't yet exist for it, one will be created.  `C` works the same way only it
will checkout a remote branch in detached HEAD.  You can also `o` and `O`.
`<C-R>` (Enter) is an alias for `c`.

`m` merges the branch under the cursor into the current branch.  `M` merges the
remote of the branch under the cursor into the current branch.  Use `r` and `R`
for rebasing.  `f` fetches the branch under the cursor whereas `F` performs a
`git fetch --all`.

Create a new branch with `:Twig <branch-name>`.

Press `i` to cycle through sorting options.

Type `q` to quit.

`:h twiggy` for plenty more.

## Installation

NeoBundle, Vundle or Pathogen are all fine options.

You __must__ have [fugitive](https://github.com/tpope/vim-fugitive) installed!

## Contributing
This is my first-ever Vim plugin.  Any feedback and/or contributions are very
welcome.
