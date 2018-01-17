# twiggy.vim

Maintain your bearings while branching with git

## About

Twiggy is a [fugitive](https://github.com/tpope/vim-fugitive) extension that
loads, decorates and sorts(!) git branches into an interactive buffer.  It
provides basic merge and rebase support, stashing, and some other goodies.

It also has [dispatch](https://github.com/tpope/vim-dispatch) support!

Twiggy is *not* a simplified branching abstraction.  It is a convenience tool
for experienced git users.

## Usage

Invoke Twiggy with the `:Twiggy` command.

Use `j` and `k` to jump between branch names and `<C-N>` and `<C-P>` to jump
between groups.  As your cursor moves, information about the branch under the
cursor will be echoed to the command prompt.

To checkout a branch, hit `c`.  If the branch is remote and a tracking branch
doesn't yet exist for it, one will be created.  `C` works the same way only it
will checkout a remote branch in detached HEAD.  You can also use `o` and `O`.
`<CR>` (Enter) is an alias for `c`.

#### Sorting

Press `i` to cycle through sorting options (`I` to go backwards) and `a` to
toggle the grouping of local branches by slash (`/`).

Sorting locals by most-recently-used and __not__ grouping them by slash is super
useful!  So is sorting remotes by date.  If you really wanted to, you could
make this your default with the following in your vimrc:

```vim
  let g:twiggy_group_locals_by_slash = 0
  let g:twiggy_local_branch_sort = 'mru'
  let g:twiggy_remote_branch_sort = 'date'
```

In any event, these are settings you may want to play around with.  Your last
settings will be remembered until you close Vim.

### Merging and Rebasing

With your cursor on a branch, `m` merges it into the current branch.  With your
cursor on a local branch, `M` will merge its tracking branch into the current
branch.  Use `r` and `R` for rebasing.  `F` fetches the branch under the cursor.

Hint: to pull on the current branch, move your cursor to it and press `F` then
press `M`.

`u` aborts a merge or rebase.

### And finally...

`^` to push (also sets the upstream).

`dd` to delete a branch.  You will be prompted if it's unmerged.

Create or checkout a branch with `:Twiggy <branch-name>`.

Type `q` to quit.

`:h twiggy` for plenty more.

## Installation

I personally recommend [vim-plug](https://github.com/junegunn/vim-plug), but
[NeoBundle](https://github.com/Shougo/neobundle.vim),
[Vundle](https://github.com/gmarik/Vundle.vim) or
[pathogen](https://github.com/tpope/vim-pathogen)
are all fine options as well.

You __must__ have [fugitive](https://github.com/tpope/vim-fugitive) installed!

## Ramble

I started work on this in early 2014.  After getting it to do everything I
wanted it to do, plus some extra stuff I just thought was cool, I ceased work
on it for about six months, yet continued to use it daily.  I finally put it
online in October 2014.  It still has a ways to go, but I'm actively working
toward a stable release.

Currently in the works (in rough order you can expect them):

- A mapping for `git pull` (but really, just F then R or M)
- A mapping for `git cherry-pick`
- Quick help (maybe)
- Improve, er... "command option mapping composition thing" (see `:h twiggy-cmd`)

This is my first-ever Vim plugin, so please excuse any erraticness in
development over the next few weeks.  Any input anyone has for me is greatly
appreciated!
