# twiggy.vim

Maintain your bearings while branching with git

## About

Twiggy is a [fugitive](https://github.com/tpope/vim-fugitive) extension that
loads, decorates and sorts(!) git branches into an interactive buffer.  It
provides basic merge and rebase support, stashing, and some other goodies.

It also has [dispatch](https://github.com/tpope/vim-dispatch) support!

## NB!

This plugin was developed on a 2013ish MacBook Air with Vim 7.3/7.4,
Git 1.8, 1.9 and 2.1.2 using mostly zsh (but also a bit of bash).  I've
opened it in MacVim a couple of times, but that's it. It hasn't been tested
in any other context.  Some area are in need of some polish (see "Ramble"below).

Pull requests welcome!

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
branch.  Use `r` and `R` for rebasing.  `F` fetches the branch under the cursor.

Hint: to pull on the current branch, move your cursor to it and press `F` then
press `M`.

`^` to push.

Create a new branch with `:Twig <branch-name>`.

Press `i` to cycle through sorting options.

Type `q` to quit.

`:h twiggy` for plenty more.

## Installation

NeoBundle, Vundle or Pathogen are all fine options.

You __must__ have [fugitive](https://github.com/tpope/vim-fugitive) installed!

## Ramble

I started work on this in early 2014.  After getting it to do everything I
wanted it to do, plus some extra stuff I just thought was cool, I ceased work
on it for about six months, yet continued to use it daily.  I finally put it
online in October 2014.  It still has a ways to go, but I'm actively working
toward a stable release.

Currently in the works (in rough order you can expect them):

- A nicer rebase/merge experience (fixes and polish)
- Fix the jarring cursor jump after deleting a branch
- A mapping for `git pull` (but really, just F then R or M)
- A mapping for `git cherry-pick`
- Quick help (maybe)
- Improve, er... "command option mapping composition thing" (see `:h twiggy-cmd`)

This is my first-ever Vim plugin, so please excuse any erraticness in
development over the next few weeks.  Any input anyone has for me is greatly
appreciated!
