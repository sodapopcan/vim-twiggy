setlocal buftype=nofile bufhidden=delete nonumber nowrap noswapfile lisp nomodifiable

augroup twiggy
    autocmd! * <buffer>
    autocmd CursorMoved <buffer> call twiggy#show_branch_details()
    autocmd CursorMoved <buffer> call twiggy#update_last_branch_under_cursor()
    autocmd BufReadPost,BufEnter,VimResized twiggy://* call twiggy#Refresh()
    autocmd BufWinLeave <buffer>
        \ if exists('t:twiggy_bufnr') |
        \   unlet! t:twiggy_bufnr |
        \   unlet! t:twiggy_git_dir |
        \   unlet! t:twiggy_git_cmd |
        \   unlet! t:twiggy_git_mode |
        \ endif
augroup END

let close_string = g:twiggy_close_on_fugitive_cmd ? 'call twiggy#Close()' : 'wincmd w'
exec "command! -buffer Gstatus " . close_string . " | silent normal! :<\C-U>Gstatus\<CR>"
exec "command! -buffer Gcommit " . close_string . " | silent normal! :<\C-U>Gcommit\<CR>"
exec "command! -buffer Gblame  " . close_string . " | silent normal! :<\C-U>Gblame\<CR>"

nnoremap <buffer> <silent> q :<C-U>call twiggy#Close()<CR>
if g:twiggy_enable_quickhelp
    nnoremap <buffer> <silent> ? :<C-U>call twiggy#Quickhelp()<CR>
endif

nnoremap <buffer> <silent> j      :<C-U>call twiggy#traverse_branches('j')<CR>
nnoremap <buffer> <silent> k      :<C-U>call twiggy#traverse_branches('k')<CR>
nnoremap <buffer> <silent> <Down> :<C-U>call twiggy#traverse_branches('j')<CR>
nnoremap <buffer> <silent> <Up>   :<C-U>call twiggy#traverse_branches('k')<CR>
nnoremap <buffer> <silent> <C-N>  :<C-U>call twiggy#traverse_groups('j')<CR>
nnoremap <buffer> <silent> <C-P>  :<C-U>call twiggy#traverse_groups('k')<CR>
nnoremap <buffer> <silent> J      :<C-U>call twiggy#jump_to_current_branch()<CR>
if twiggy#showing_full_ui()
    nnoremap <buffer> <silent> gg :normal! 4gg<CR>
else
    nnoremap <buffer> <silent> gg :normal! 2gg<CR>
endif

call twiggy#local_mapping('<CR>','Checkout',  [1])
call twiggy#local_mapping('C',   'Checkout',  [0])
call twiggy#local_mapping('o',   'Checkout',  [1])
call twiggy#local_mapping('O',   'Checkout',  [0])
call twiggy#local_mapping('dd',  'Delete',    [])
call twiggy#local_mapping('F',   'Fetch',     [0])
call twiggy#local_mapping('m',   'Merge',     [0, ''])
call twiggy#local_mapping('M',   'Merge',     [1, ''])
call twiggy#local_mapping('gm',  'Merge',     [0, '--no-ff'])
call twiggy#local_mapping('gM',  'Merge',     [1, '--no-ff'])
call twiggy#local_mapping('r',   'Rebase',    [0])
call twiggy#local_mapping('R',   'Rebase',    [1])
call twiggy#local_mapping('^',   'Push',      [0, 0])
call twiggy#local_mapping('g^',  'Push',      [1, 0])
call twiggy#local_mapping('!^',  'Push',      [0, 1])
call twiggy#local_mapping('V',   'Pull',      [])
" call twiggy#local_mapping(',',   'Rename',    [])
call twiggy#local_mapping('<<',  'Stash',     [0])
call twiggy#local_mapping('>>',  'Stash',     [1])
call twiggy#local_mapping('i',   'CycleSort', [0, 1])
call twiggy#local_mapping('I',   'CycleSort', [0, -1])
call twiggy#local_mapping('gi',  'CycleSort', [1, 1])
call twiggy#local_mapping('gI',  'CycleSort', [1, -1])

if g:twiggy_git_log_command !=# ''
    nnoremap <buffer> gl :exec ':' . g:twiggy_git_log_command . ' ' . twiggy#branch_under_cursor().fullname<CR>
    nnoremap <buffer> gL :exec ':' . g:twiggy_git_log_command . ' ' . twiggy#branch_under_cursor().fullname . '..'<CR>
endif

if g:twiggy_enable_remote_delete
    call twiggy#local_mapping('d^', 'DeleteRemote', [])
endif
