" twiggy.vim -- Maintain your bearings while branching with git
" Maintainer: Andrew Haust <andrewwhhaust@gmail.com>
" Website:    https://www.github.com/sodapopcan/vim-twiggy
" License:    Same terms as Vim itself (see :help license)

if exists('g:loaded_twiggy') || &cp || !exists('g:loaded_fugitive')
  finish
endif
let g:loaded_twiggy = 1

for cmd in ['Twiggy', 'Twig']
  exec "command! -nargs=* -complete=custom,TwiggyCompleteGitBranches " .
        \ cmd . " call twiggy#Branch(<f-args>)"
endfor

augroup twiggy_booter
  autocmd!
  autocmd BufReadPost * if exists('b:git_dir') | call twiggy#define_commands() | endif
  autocmd BufEnter Twiggy call twiggy#define_commands()
augroup END
