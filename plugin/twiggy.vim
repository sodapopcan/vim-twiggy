" twiggy.vim -- Maintain your bearings while branching with git
" Maintainer: Andrew Haust <andrewwhhaust@gmail.com>
" Website:    https://www.github.com/sodapopcan/vim-twiggy
" License:    Same terms as Vim itself (see :help license)

if exists('g:loaded_twiggy') || &cp
  finish
endif
let g:loaded_twiggy = 1

function! TwiggyCompleteBranches(A,L,P) abort
  let branches = ''
  for branch in twiggy#get_branches()
    let slicepos = len(split(a:A, '/')) - 1
    let branch = join(split(branch.fullname, '/')[0:slicepos], '/')
    let branches = branches . branch . "\n"
  endfor
  return branches
endfunction

command -nargs=* -complete=custom,TwiggyCompleteBranches Twiggy call twiggy#Branch(<f-args>)
