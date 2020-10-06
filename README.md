# twiggy.vim

Maintain your bearings while branching with Git

## About

Twiggy is a [fugitive](https://github.com/tpope/vim-fugitive) extension that
loads, decorates and sorts(!) git branches into an interactive buffer.  It
provides basic merge and rebase support, stashing, and some other goodies.

<img src="https://raw.githubusercontent.com/sodapopcan/-/master/twiggy-preview.png" width=1500>

## Usage

Invoke Twiggy with the `:Twiggy` command.

Use `j` and `k` to jump between branch names and `<C-N>` and `<C-P>` to jump
between groups.  As your cursor moves, information about the branch under the
cursor will be echoed to the command prompt.

To checkout a branch, hit `c`.  If the branch is remote and a tracking branch
doesn't yet exist for it, one will be created.  `C` will checkout a remote
branch in detached HEAD... even if your cursor on the local version!
You can also use `o` and `O`.
`<CR>` (Enter) is an alias for `c`.

#### Sorting

Press `i` to cycle through sorting options (`I` to go backwards) and `a` to
toggle the grouping of local branches by slash (`/`).

Sorting locals by most-recently-used and __not__ grouping them by slash is super
useful!  So is sorting remotes by date.  If you really wanted to, you could
make this your default with the following in your vimrc:

```viml
let g:twiggy_group_locals_by_slash = 0
let g:twiggy_local_branch_sort = 'mru'
let g:twiggy_remote_branch_sort = 'date'
```

In any event, these are settings you may want to play around with.  Your last
settings will be remembered until you close Vim.

### Merging and Rebasing

With your cursor on a branch, `m` merges it into the current branch.  With your
cursor on a local branch, `M` will merge its tracked remote into the current
branch.  Use `r` and `R` for rebasing.  `f` fetches the branch under the cursor.

`u` aborts a merge or rebase.

### And finally...

`P` to push (also sets the upstream).

`p` to pull.

`dd` to delete a branch.  You will be prompted if it's unmerged.

Create or checkout a branch with `:Twiggy <branch-name>`.

Type `q` to quit.

`:help twiggy` for plenty more.

### Example fetch and merge workflow

Press `F` on the current branch to fetch from the upstream.  Without moving
your cursor, press `C` to checkout the remote branch in detached HEAD.  If
everything looks good, move your cursor back to the original branch and press
`c` to checkout, then press `M` to merge the upstream changes.

### Git Log

Twiggy itself is only concerned with branching, but it does have very warm
feelings toward the following plugins:

* [gv.vim](https://github.com/junegunn/gv.vim)
* [gitv](https://github.com/gregsexton/gitv)

Install one of them and you will get the following mappings:

`gl` show commits for the branch under the cursor

`gL` show range of commits from branch under the cursor to the current one

## Installation

Use vim's built-in package support or your favourite package manager.

[There](https://github.com/junegunn/vim-plug) [sure](https://github.com/Shougo/neobundle.vim)
[are](https://github.com/VundleVim/Vundle.vim) [a](https://github.com/tpope/vim-pathogen)
[lot](https://github.com/Shougo/dein.vim)
[of](https://github.com/k-takata/minpac)
[options](http://vimhelp.appspot.com/repeat.txt.html#packages)
[😳](http://www.shrugguy.com/)

My personal fave is [vim-plug](https://github.com/junegunn/vim-plug):
```viml
Plug 'tpope/vim-fugitive'
Plug 'sodapopcan/vim-twiggy'
```

## About

If you like this plugin, please star it and vote for it on
[vim.org](https://www.vim.org/scripts/script.php?script_id=5643)!
