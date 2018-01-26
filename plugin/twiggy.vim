" twiggy.vim -- Maintain your bearings while branching with git
" Maintainer: Andrew Haust <andrewwhhaust@gmail.com>
" Website:    https://www.github.com/sodapopcan/vim-twiggy
" License:    Same terms as Vim itself (see :help license)

if exists('g:loaded_twiggy') || &cp
  finish
endif
let g:loaded_twiggy = 1

command -nargs=* -complete=custom,twiggy#TwiggyCompleteGitBranches Twiggy call twiggy#Branch(<f-args>)
