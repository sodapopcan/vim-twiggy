" twiggy.vim -- Maintain your bearings while branching with git
" Maintainer: Andrew Haust <andrewwhhaust@gmail.com>
" Website:    https://www.github.com/sodapopcan/vim-twiggy
" License:    Same terms as Vim itself (see :help license)

if exists('g:autoloaded_twiggy')
  finish
endif
let g:autoloaded_twiggy = 1

" {{{1 Utility
function! s:buffocus(bufnr) abort
  let switchbuf_cached = &switchbuf
  set switchbuf=useopen
  exec 'sb ' . a:bufnr
  exec 'set switchbuf=' . switchbuf_cached
endfunction

" Create local mappings in the twiggy buffer
function! s:mapping(mapping, fn, args) abort
  let s:mappings[s:encode_mapping(a:mapping)] = [a:fn, a:args]
  exe "nnoremap <buffer> <silent> " .
        \ a:mapping . " :<C-U>call <SID>call('" .
        \ s:encode_mapping(a:mapping) . "')<CR>"
endfunction

function! s:encode_mapping(mapping) abort
  return substitute(a:mapping, '\v^\<', '___', '')
endfunction

" {{{1 Script Variables
let s:init_line                = 0
let s:mappings                 = {}
let s:branch_line_refs         = {}
let s:last_branch_under_cursor = {}
let s:last_output              = ''
let s:git_flags                = '' " I regret this
let s:git_mode                 = ''

let s:sorted      = 0
let s:git_cmd_run = 0

" {{{1 Icons
if exists('g:twiggy_icons')
      \ && type(g:twiggy_icons) == 3
      \ && len(filter(g:twiggy_icons, 'type(v:val) ==# 1 && strchars(v:val) ==# 1')) ==# 7
  let s:icon_set = g:twiggy_icons
elseif has('multi_byte')
  let s:icon_set = ['*', '✓', '↑', '↓', '↕', '∅', '✗']
else
  let s:icon_set = ['*', '=', '+', '-', '~', '%', 'x']
endif

let s:icons = {}
let s:icons.current  = s:icon_set[0]
let s:icons.tracking = s:icon_set[1]
let s:icons.ahead    = s:icon_set[2]
let s:icons.behind   = s:icon_set[3]
let s:icons.both     = s:icon_set[4]
let s:icons.detached = s:icon_set[5]
let s:icons.unmerged = s:icon_set[6]


" {{{1 Options

let g:twiggy_num_columns            = get(g:,'twiggy_num_columns',            31                                                       )
let g:twiggy_split_position         = get(g:,'twiggy_split_position',         ''                                                       )
let g:twiggy_local_branch_sort      = get(g:,'twiggy_local_branch_sort',      'alpha'                                                  )
let g:twiggy_local_branch_sorts     = get(g:,'twiggy_local_branch_sorts',     ['alpha', 'date', 'track', 'mru']                        )
let g:twiggy_remote_branch_sort     = get(g:,'twiggy_remote_branch_sort',     'alpha'                                                  )
let g:twiggy_remote_branch_sorts    = get(g:,'twiggy_remote_branch_sorts',    ['alpha', 'date']                                        )
let g:twiggy_group_locals_by_slash  = get(g:,'twiggy_group_locals_by_slash',  1                                                        )
let g:twiggy_set_upstream           = get(g:,'twiggy_set_upstream',           1                                                        )
let g:twiggy_enable_remote_delete   = get(g:,'twiggy_enable_remote_delete',   0                                                        )
let g:twiggy_use_dispatch           = get(g:,'twiggy_use_dispatch',           exists('g:loaded_dispatch') && g:loaded_dispatch ? 1 : 0 )
let g:twiggy_close_on_fugitive_cmd  = get(g:,'twiggy_close_on_fugitive_cmd',  0                                                        )
let g:twiggy_enable_quickhelp       = get(g:,'twiggy_enable_quickhelp',       1                                                        )

" {{{1 System
"   {{{2 cmd
function! s:system(cmd, bg) abort
  let command = a:cmd

  if a:bg
    if exists('g:loaded_dispatch') && g:loaded_dispatch &&
          \ g:twiggy_use_dispatch
      exec ':Dispatch ' . command
    else
      exec ':!' . command
    endif
  else
    let output = system(command)
    if v:shell_error
      let s:last_output = output
    endif

    return output
  endif
endfunction


"   {{{2 gitize
function! s:gitize(cmd) abort
  if exists('t:twiggy_bufnr') && t:twiggy_bufnr == bufnr('')
    let git_cmd = t:twiggy_git_cmd
  else
    let git_cmd = fugitive#buffer().repo().git_command()
  end
  return git_cmd . ' ' . a:cmd
endfunction

"   {{{2 git_cmd
function! s:git_cmd(cmd, bg) abort
  let cmd = s:gitize(a:cmd)
  let s:git_cmd_run = 1
  if a:bg
    call s:system(cmd, a:bg)
  else
    return s:system(cmd, a:bg)
  endif
endfunction

"   {{{2 call
function! s:call(mapping) abort
  let key = s:encode_mapping(a:mapping)
  if call('s:' . s:mappings[key][0], s:mappings[key][1])
    call s:ErrorMsg()
  else
    call s:Render()
    call s:ShowOutputBuffer()
  endif
  let s:git_flags = ''
endfunction



" {{{1 Branch Parser
function! s:parse_branch(branch, type) abort
  let branch = {}

  let branch.current = match(a:branch, '\v^\*') >= 0

  let branch.decoration = ' '
  if branch.current
    let branch.decoration = s:git_mode !=# 'normal' ? s:icons.unmerged : s:icons.current
  endif

  let detached = match(a:branch, '\v^\(detached from', 2)

  let remote_details = matchstr(a:branch, '\v\[[^\[]+\]')
  let branch.tracking = matchstr(remote_details, '\v[^ \:\]]+', 1)
  let branch.remote =  branch.tracking != '' ? split(branch.tracking, '/')[0] : ''
  if branch.tracking !=# ''
    if match(remote_details, '\vahead [0-9]+\, behind [0-9]') >= 0
      let branch.status      = 'both'
      let branch.decoration .= s:icons.both
    elseif match(remote_details, '\vahead [0-9]') >= 0
      let branch.status      = 'ahead'
      let branch.decoration .= s:icons.ahead
    elseif match(remote_details, '\vbehind [0-9]') >= 0
      let branch.status      = 'behind'
      let branch.decoration .= s:icons.behind
    else
      let branch.status      = ''
      let branch.decoration .= s:icons.tracking
    endif
  elseif detached >= 0
    let branch.status      = 'detached'
    let branch.decoration .= s:icons.detached
  else
    let branch.status      = ''
    let branch.decoration .= ' '
  endif

  let branch.fullname = matchstr(a:branch, '\v(\([^\)]+\)|^[^ ]+)', 2)

  if a:type == 'list'
    let branch.is_local = 1
    let branch.type  = 'local'
    if g:twiggy_group_locals_by_slash
      if match(branch.fullname, '/') >= 0
        let group = matchstr(branch.fullname, '\v[^/]*')
        let branch.group = group
        let branch.name = substitute(branch.fullname, group . '/', '', '')
      else
        let branch.group = 'local'
        let branch.name = branch.fullname
      endif
    else
      let branch.group = 'local'
      let branch.name = branch.fullname
    endif
    if detached >= 0
      let branch.name = substitute(substitute(branch.name, '\v\(detached from ', '', ''), '\v\)', '', '')
    endif
  else
    let branch.is_local = 0
    let branch.type = 'remote'
    let branch_split = split(branch.fullname, '/')
    let branch.name  = join(branch_split[1:], '/')
    let branch.group = branch_split[0]
  endif

  let branch.details = substitute(a:branch,  '\v[* ] [0-9A-Za-z_/\-]+[ ]+', '', '')

  return branch
endfunction


" {{{1 Option Parser
function! s:OptionParser() abort
  let terminators = ['m', 'M', 'r', 'R', 'F', '^']
  let options = {
        \ 'a': 'all',
        \ 'f': 'ff',
        \ '!': 'force',
        \ 'o': 'only',
        \ 's': 'squash',
        \ 't': 'tags'
        \  }
  let chosen_options = []

  redraw | echo 'git <cmd> '

  while 1
    let option = nr2char(getchar())
    let last_input_was_no = len(chosen_options) > 0 && chosen_options[-1] ==# '--no'

    if index(terminators, option) >= 0
      let s:git_flags = join(chosen_options)
      return s:call(option)
    elseif option ==# 'n' && !last_input_was_no
      call add(chosen_options, '--no')
    elseif option ==? "\<c-w>" && len(chosen_options) > 0
      call remove(chosen_options, -1)
    elseif !has_key(options, option)
      call s:Render()
      return 0
    elseif option ==# 'o' && len(chosen_options) > 0 && chosen_options[-1] ==# '--ff'
      let chosen_options[-1] .= '-' . options[option]
    else
      if has_key(options, option)
        if last_input_was_no
          let chosen_options[-1] .= '-' . options[option]
        else
          call add(chosen_options, '--' . options[option])
        endif
      endif
    endif

    redraw | echo 'git <cmd> ' . join(chosen_options) . ' '
  endwhile
endfunction

" {{{1 Git
"   {{{2 any_commits
function! s:no_commits() abort
  call s:git_cmd('rev-list -n 1 --all &> /dev/null', 0)
  return v:shell_error
endfunction

"   {{{2 dirty_tree
function! s:dirty_tree() abort
  return s:git_cmd('diff --shortstat', 0) !=# ''
endfunction

"   {{{2 _git_branch_vv
function! s:_git_branch_vv(type) abort
  let branches = []
  for branch in split(s:git_cmd('branch --' . a:type . ' -vv --no-color', 0), '\v\n')
    call add(branches, s:parse_branch(branch, a:type))
  endfor

  return branches
endfunction

"   {{{2 branch_status
function! s:get_git_mode() abort
  if isdirectory(t:twiggy_git_dir . '/rebase-apply')
    return 'rebasing'
  elseif filereadable(t:twiggy_git_dir . '/MERGE_HEAD')
    return 'merging'
  elseif s:git_cmd('diff --shortstat --diff-filter=U | tail -1', 0) !=# ''
    return 'merging'
  else
    return 'normal'
  endif
endfunction

"   {{{2 get_branches
function! twiggy#get_branches() abort
  let locals = s:_git_branch_vv('list')
  let locals_sorted = []

  let reflog = s:get_uniq_branch_names_from_reflog()
  let s:branches_not_in_reflog = []

  " Index locals by branch name for fast look-up while sorting
  let local_refs = {}
  for local in locals
    let local_refs[local.fullname] = local
    if index(reflog, local.name) < 0
      call add(s:branches_not_in_reflog, local.name)
    endif
  endfor

  for branch_name in reflog
    if has_key(local_refs, branch_name)
      if g:twiggy_local_branch_sort ==# 'mru'
        call add(locals_sorted, local_refs[branch_name])
        call remove(locals, index(locals, local_refs[branch_name]))
      endif
    endif
  endfor

  if g:twiggy_local_branch_sort ==# 'track'
    let ahead_branches               = []
    let behind_branches              = []
    let both_branches                = []
    let up_to_date_tracking_branches = []
    let non_tracking_branches        = []

    for branch in locals
      if branch.tracking !=# ''
        if branch.status ==# 'ahead'
          call add(ahead_branches, branch)
        elseif branch.status ==# 'behind'
          call add(behind_branches, branch)
        elseif branch.status ==# 'both'
          call add(both_branches, branch)
        else
          call add(up_to_date_tracking_branches, branch)
        endif
      else
        call add(non_tracking_branches, branch)
      endif
    endfor

    let locals = []
    call extend(extend(extend(extend(extend(
          \ locals_sorted, ahead_branches), both_branches), behind_branches),
          \   up_to_date_tracking_branches), non_tracking_branches)
  endif

  if g:twiggy_local_branch_sort ==# 'date'
    for branch_name in s:get_by_commiter_date('heads')
      if has_key(local_refs, branch_name)
        call add(locals_sorted, local_refs[branch_name])
        call remove(locals, index(locals, local_refs[branch_name]))
      endif
    endfor
  endif

  let locals = extend(locals_sorted, locals)

  let remotes = s:_git_branch_vv('remote')
  let remotes_sorted = []

  if g:twiggy_remote_branch_sort ==# 'date'
    let remote_refs = {}

    for branch in remotes
      let remote_refs[branch.fullname] = branch
    endfor

    for remote in split(s:git_cmd('remote', 0), '\v\n')
      for branch_name in s:get_by_commiter_date('remotes/' . remote)
        if has_key(remote_refs, branch_name)
          call add(remotes_sorted, remote_refs[branch_name])
          call remove(remotes, index(remotes, remote_refs[branch_name]))
        endif
      endfor
    endfor
  endif

  return extend(locals, extend(remotes_sorted, remotes))
endfunction

"   {{{2 get_current_branch
function! s:get_current_branch() abort
  return s:git_cmd('branch --list | grep \*', 0)[2:-2]
endfunction

"   branch_exists
function! s:branch_exists(branch) abort
  call s:git_cmd('show-ref --verify --quiet refs/heads/' . a:branch, 0)
  return !v:shell_error
endfunction

"   {{{2 branch_under_cursor
function! s:branch_under_cursor() abort
  let line = line('.')
  if has_key(s:branch_line_refs, line)
    return s:branch_line_refs[line]
  endif
  return ''
endfunction

"   {{{2 get_uniq_branch_names_from_reflog
" http://stackoverflow.com/questions/14062402/awk-using-a-file-to-filter-another-one-out-tr
function! s:get_uniq_branch_names_from_reflog() abort
  let cmd = "awk 'FNR==NR { a[$NF]; next } $NF in a' <(" . s:gitize('branch --list') . ") "
  let cmd.= "<(" . s:gitize('reflog') . " | awk -F\" \" '/checkout: moving from/ { print $8 }' | "
  let cmd.= "awk " . shellescape('!f[$0]++') . ")"

  return split(s:system(cmd, 0), '\v\n')
endfunction

"   get_merged_branches
" I'm sure there is a better plumbing command to figure this out
function! s:get_merged_branches() abort
  return map(split(s:git_cmd('branch --list --merged', 0), '\n'), 'v:val[2:]')
endfunction

"   {{{2 get_by_committer_date
function! s:get_by_commiter_date(type) abort
  let cmd = "cut -d'/' -f 3- <("
        \ . s:gitize("for-each-ref --sort=-authordate refs/" . a:type)
        \ . " | awk -F\" \" ' { print $3 }')"
  return split(s:system(cmd, 0), '\v\n')
endfunction

"   {{{2 update_last_branch_under_cursor
function! s:update_last_branch_under_cursor() abort
  " Yeah, gonna swallow the exception here
  try
    let s:last_branch_under_cursor = s:branch_under_cursor()
  catch
    return
  endtry
endfunction

" {{{1 UI
"   {{{2 Standard
function! s:standard_view() abort
  " Sort branches by group
  let groups = {}
  let groups['local'] = {}
  let groups['remote'] = {}
  let group_refs = {}
  let group_refs['local'] = []
  let group_refs['remote'] = []
  let s:init_line = 0

  let branches = twiggy#get_branches()
  for branch in branches
    if !has_key(groups[branch.type], branch.group)
      let groups[branch.type][branch.group] = {}
      if branch.group ==# 'local'
        let group_name = (s:git_mode == 'normal') ? 'local' : s:git_mode
      elseif branch.type ==# 'remote'
        let group_name = 'r:' . branch.group
      else
        let group_name = branch.group
      endif
      let groups[branch.type][branch.group].name = group_name
      let groups[branch.type][branch.group].branches = []
      if branch.group ==# 'local'
        " Sort the no-slash groups to the front like a pro
        let group_refs['local'] = extend([groups['local']['local']], group_refs['local'])
      else
        call add(group_refs[branch.type], groups[branch.type][branch.group])
      endif
    endif

    call add(groups[branch.type][branch.group]['branches'], branch)
  endfor

  let output = []
  let line   = 0

  for group_type in ['local', 'remote']
    for group_ref in group_refs[group_type]

      let line = line + 1
      if line !=# 1
        call add(output, '')
        let line = line + 1
      endif

      exec "let sort_name = g:twiggy_" . group_type . "_branch_sort"
      call add(output, group_ref.name . ' [' . sort_name . ']')

      for branch in group_ref['branches']
        call add(output, branch.decoration . branch.name)
        let line = line + 1
        let branch.line = line
        let s:branch_line_refs[line] = branch
        if !s:init_line
          if s:sorted
            if branch.fullname ==# s:last_branch_under_cursor.fullname
              let s:sorted = 0
              let s:init_line = branch.line
            endif
          elseif !s:git_cmd_run && !empty(s:last_branch_under_cursor)
            let s:init_line = s:last_branch_under_cursor.line
            let s:git_cmd_run = 0
          else
            if match(branch.fullname, '(no branch') >= 0
              let s:init_line = line
            elseif branch.status ==# 'detached'
              let s:init_line = line
            elseif !empty(s:last_branch_under_cursor)
              let s:init_line = s:last_branch_under_cursor.line
            elseif branch.current
              let s:init_line = branch.line
            endif
          endif
        endif
      endfor
    endfor
  endfor

  return output
endfunction

"   {{{2 Quickhelp
function! s:quickhelp_view() abort
  let output = []
  call add(output, 'Twiggy Quickhelp')
  call add(output, '===========================')
  call add(output, '<C-N> jump to next group')
  call add(output, '<C-P> jump to prev group')
  call add(output, 'J     jump to curr branch')
  call add(output, 'q     quit')
  call add(output, '?     toggle this help')
  call add(output, '---------------------------')
  call add(output, 'w/ the cursor on a branch:')
  call add(output, '---------------------------')
  call add(output, 'c     checkout')
  call add(output, 'o     checkout')
  call add(output, '<CR>  checkout')
  call add(output, 'C     checkout remote')
  call add(output, 'O     checkout remote')
  call add(output, 'F     fetch remote')
  call add(output, 'V     pull')
  call add(output, 'm     merge')
  call add(output, 'M     merge remote')
  call add(output, 'r     rebase')
  call add(output, 'R     rebase remote')
  call add(output, 'u     abort merge/rebase')
  call add(output, '^     push')
  call add(output, 'g^    push (prompted)')
  call add(output, 'dd    delete')
  if g:twiggy_enable_remote_delete
    call add(output, 'd^    delete from server')
  endif
  call add(output, '<<    stash')
  call add(output, '>>    pop stash')
  call add(output, '----------------------------')
  call add(output, 'sorting, etc:')
  call add(output, '----------------------------')
  call add(output, 'i     cycle sorts')
  call add(output, 'I     `i` in reverse')
  call add(output, 'gi    cycle remote sorts')
  call add(output, 'gI    `gi` in reverse')
  call add(output, 'a     toggle slash-grouping')

  return output
endfunction

"   {{{2 Branch Details
function! s:show_branch_details() abort
  let line = line('.')
  if has_key(s:branch_line_refs, line)
    let max_len = &columns - 8
    let details = s:branch_line_refs[line].details
    if len(details) > max_len
      let details = details[0:max_len] . '...'
    endif
    redraw
    echo details
  end
endfunction

"   {{{2 Stdout/Stderr Buffer
function! s:ShowOutputBuffer() abort
  if s:last_output ==# ''
    return
  endif
  silent keepalt botright new TwiggyOutput
  let output = split(s:last_output, '\v\n')
  let height = len(output)
  if height < 5 | let height = 5 | endif
  exec 'resize ' . height
  normal! ggdG
  setlocal modifiable
  call append(0, output)
  normal! ddgg

  setlocal nomodified nomodifiable noswapfile nowrap nonumber
  setlocal buftype=nofile
  let s:last_output = ''

  syntax clear
  syntax match TwiggyOutputText "\v^[^ ](.*)"
  highlight link TwiggyOutputText  Comment
  syntax match TwiggyOutputFile "\v^\t(.*)"
  highlight link TwiggyOutputFile Constant

  nnoremap <buffer> q :bdelete<CR>
  nnoremap <buffer> Q :bdelete<CR>:call <SID>Close()<CR>
endfunction

"   {{{2 Confirm
function! s:Confirm(prompt, cmd, abort) abort
  redraw
  echohl WarningMsg
  echo a:prompt . " [Yn" . (a:abort ? 'a' : '') . "]"
  echohl None

  let input = nr2char(getchar())
  if index(['a', "\<esc>"], input) >= 0 && a:abort
    return -1
  elseif index(['Y', 'y', "\<cr>"], input) >= 0
    exec "return " . a:cmd
  endif

  return 0
endfunction

function! s:PromptToStash() abort
  return s:Confirm("Working tree is dirty.  Stash first?",
        \ "s:git_cmd('stash', 0)", 1)
endfunction

"   {{{2 ErrorMsg
function! s:ErrorMsg() abort
  if v:warningmsg !=# ''
    redraw
    echohl WarningMsg
    echomsg v:warningmsg
    let v:warningmsg = ''
    echohl None
  endif
endfunction

" {{{1 Plugin
"   {{{2 Navigation
"     {{{3 traverseBranches
function! s:traverseBranches(motion) abort abort
  execute "normal! " . a:motion
  let current_line = line('.')
  if current_line ==# s:total_lines && a:motion ==# 'j'
    return
  elseif (a:motion ==# 'k' && current_line ==# '1')
    normal! j
  else
    while getline('.') =~# '\v^[A-Za-z]' || getline('.') ==# ''
      execute "normal! " . a:motion
    endwhile
  end
endfunction

"     {{{3 traverseGroups
function! s:traverseGroups(motion) abort
  if a:motion ==# 'j'
    if search('\v^[A-Za-z]', 'W')
      normal! j
    end
  elseif a:motion ==# 'k'
    if search('\v^[A-Za-z]', 'bW')
      call search('\v^[A-Za-z]', 'bW')
      normal! j
    endif
  endif
endfunction

function! s:jumpToCurrentBranch() abort
  call search(s:icons.current)
endfunction

"   {{{2 Main
"     {{{3 Render
function! s:Render() abort
  redraw

  if exists('b:git_dir') && &filetype !=# 'twiggy'
    let t:twiggy_git_dir = b:git_dir
    let t:twiggy_git_cmd = fugitive#buffer().repo().git_command()
  elseif !exists('t:twiggy_git_cmd')
    echo "Not a git repository"
    return
  endif

  if !exists('t:twiggy_bufnr') || !(exists('t:twiggy_bufnr') && t:twiggy_bufnr ==# bufnr(''))
    let fname = 'twiggy://' . t:twiggy_git_dir . '/branches'
    if &filetype ==# 'twiggyqh'
      exec "edit" fname
    else
      exec 'silent keepalt ' . g:twiggy_split_position . ' ' . g:twiggy_num_columns . 'vsplit ' . fname
    endif
    setlocal filetype=twiggy buftype=nofile
    setlocal nonumber nowrap lisp
    let t:twiggy_bufnr = bufnr('')
  endif

  nnoremap <buffer> <silent> q     :<C-U>call <SID>Close()<CR>
  if g:twiggy_enable_quickhelp
    nnoremap <buffer> <silent> ?     :<C-U>call <SID>Quickhelp()<CR>
  endif

  autocmd! BufWinLeave twiggy://*
        \ if exists('t:twiggy_bufnr') |
        \   unlet t:twiggy_bufnr |
        \   unlet t:twiggy_git_dir |
        \   unlet t:twiggy_git_cmd |
        \ endif

  if s:no_commits()
    set modifiable
    silent 1,$delete _
    call append(0, "No commits")
    normal! dd
    set nomodifiable
    return
  endif

  let s:git_mode = s:get_git_mode()

  let output = s:standard_view()
  set modifiable
  silent 1,$delete _
  call append(0, output)
  normal! Gddgg
  call s:show_branch_details()
  let s:total_lines = len(output)

  setlocal nomodified nomodifiable noswapfile

  exec "normal! " . s:init_line . "gg"

  augroup twiggy
    autocmd!
    autocmd CursorMoved twiggy://* call s:show_branch_details()
    autocmd CursorMoved twiggy://* call s:update_last_branch_under_cursor()
    autocmd BufReadPost,BufEnter,BufLeave,VimResized twiggy://* call <SID>Refresh()
  augroup END

  nnoremap <buffer> <silent> j     :<C-U>call <SID>traverseBranches('j')<CR>
  nnoremap <buffer> <silent> k     :<C-U>call <SID>traverseBranches('k')<CR>
  nnoremap <buffer> <silent> <C-N> :<C-U>call <SID>traverseGroups('j')<CR>
  nnoremap <buffer> <silent> <C-P> :<C-U>call <SID>traverseGroups('k')<CR>
  nnoremap <buffer> <silent> J     :<C-U>call <SID>jumpToCurrentBranch()<CR>
  nnoremap <buffer>          gg    2gg

  nnoremap <buffer>          s     :<C-U>call <SID>OptionParser()<CR>

  call s:mapping('<CR>',    'Checkout',         [1])
  call s:mapping('c',       'Checkout',         [1])
  call s:mapping('C',       'Checkout',         [0])
  call s:mapping('o',       'Checkout',         [1])
  call s:mapping('O',       'Checkout',         [0])
  call s:mapping('dd',      'Delete',           [])
  call s:mapping('F',       'Fetch',            [0])
  call s:mapping('V',       'Pull',             [])
  call s:mapping('m',       'Merge',            [0])
  call s:mapping('M',       'Merge',            [1])
  call s:mapping('r',       'Rebase',           [0])
  call s:mapping('R',       'Rebase',           [1])
  call s:mapping('^',       'Push',             [0])
  call s:mapping('g^',      'Push',             [1])
  call s:mapping('<<',      'Stash',            [0])
  call s:mapping('>>',      'Stash',            [1])
  call s:mapping('i',       'CycleSort',        [0,1])
  call s:mapping('I',       'CycleSort',        [0,-1])
  call s:mapping('gi',      'CycleSort',        [1,1])
  call s:mapping('gI',      'CycleSort',        [1,-1])
  call s:mapping('a',       'ToggleSlashSort',  [])

  if s:git_mode ==# 'rebasing'
    call s:mapping('u', 'Abort', ['rebase'])
  elseif s:git_mode ==# 'merging'
    call s:mapping('u', 'Abort', ['merge'])
  else
    nnoremap <buffer> <silent> u :echo 'Nothing to abort'<CR>
  endif

  if g:twiggy_enable_remote_delete
    call s:mapping('d^',      'DeleteRemote',     [])
  endif

 " {{{ Syntax
  syntax clear

  exec "syntax match TwiggyGroup '\\v(^[^\\ " . s:icons.current . "]+)'"
  highlight link TwiggyGroup Type

  exec "syntax match TwiggyCurrent '\\v%3v" . s:get_current_branch() . "$'"
  highlight link TwiggyCurrent Identifier

  exec "syntax match TwiggyCurrent '\\V\\%1c" . s:icons.current . "'"
  highlight link TwiggyCurrent Identifier

  exec "syntax match TwiggyTracking '\\V\\%2c" . s:icons.tracking . "'"
  highlight link TwiggyTracking DiffAdd

  exec "syntax match TwiggyAhead '\\V\\%2c" . s:icons.ahead . "'"
  highlight link TwiggyAhead DiffDelete

  exec "syntax match TwiggyAheadBehind '\\V\\%2c" . s:icons.behind . "'"
  exec "syntax match TwiggyAheadBehind '\\V\\%2c" . s:icons.both . "'"
  highlight link TwiggyAheadBehind DiffDelete

  exec "syntax match TwiggyDetached '\\V\\%2c" . s:icons.detached . "'"
  highlight link TwiggyDetached DiffChange

  exec "syntax match TwiggyUnmerged '\\V\\%1c" . s:icons.unmerged . "'"
  highlight link TwiggyUnmerged DiffDelete

  syntax match TwiggySortText '\v[[a-z]+]'
  highlight link TwiggySortText Comment

  syntax match TwiggyBranchStatus "\v^(rebasing|merging)"
  highlight link TwiggyBranchStatus DiffDelete

  if exists('s:branches_not_in_reflog') && len(s:branches_not_in_reflog)
    exec "syntax match TwiggyNotInReflog '\\v" . substitute(substitute(join(s:branches_not_in_reflog), '(', '', 'g'), ')', '', 'g') . "'"
    highlight link TwiggyNotInReflog Comment
  endif

  " }}}
  " let twiggy_bufnr = get(t:, 'twiggy_bufnr', bufnr(''))
endfunction

"     {{{3 Quickhelp
function! s:Quickhelp() abort
  if &filetype !=# 'twiggy'
    return
  endif

  let t:twiggy_cached_git_dir = t:twiggy_git_dir

  silent keepalt edit quickhelp
  setlocal filetype=twiggyqh buftype=nofile bufhidden=delete
  setlocal nonumber nowrap lisp
  setlocal modifiable
  silent 1,$delete _
  let b:git_dir = t:twiggy_cached_git_dir
  unlet t:twiggy_cached_git_dir
  let bufnr = bufnr('')

  nnoremap <buffer> <silent> q :quit<CR>
  nnoremap <buffer> <silent> ? :Twiggy<CR>

  call append(0, s:quickhelp_view())
  normal! Gddgg
  setlocal nomodifiable

  syntax clear
  syntax match TwiggyQuickhelpMapping "\v%<7c[A-Za-z\-\?\^\<\>]"
  highlight link TwiggyQuickhelpMapping Identifier
  syntax match TwiggyQuickhelpSpecial "\v\`[a-zA-Z]+\`"
  highlight link TwiggyQuickhelpSpecial Identifier
  syntax match TwiggyQuickhelpHeader "\v[A-Za-z ]+\n[=]+"
  highlight link TwiggyQuickhelpHeader String
  syntax match TwiggyQuickhelpSectionHeader "\v[\-]+\n[a-z,\/ \:]+\n[\-]+"
  highlight link TwiggyQuickhelpSectionHeader String
endfunction

"     {{{3 Refresh
function! s:Refresh() abort
  if exists('t:refreshing') || !exists('t:twiggy_bufnr') || !exists('b:git_dir')
    return
  endif
  let t:refreshing = 1
  if &filetype !=# 'twiggy'
    let t:twiggy_git_dir = b:git_dir
    let t:twiggy_git_cmd = fugitive#buffer().repo().git_command()
    call s:buffocus(t:twiggy_bufnr)
    " if t:twiggy_git_dir ==# b:git_dir
    "   unlet t:refreshing
    "   return
    " endif
  endif
  call s:Render()
  unlet t:refreshing
endfunction

"     {{{3 Branch
function! twiggy#Branch(...) abort
  if len(a:000)
    let current_branch = s:get_current_branch()
    let f = s:branch_exists(a:1) ? '' : '-b '
    call s:git_cmd('checkout ' . f . join(a:000), 0)
    call s:ShowOutputBuffer()
    if exists('t:twiggy_bufnr')
      call s:Refresh()
    end
    redraw
    echo 'Moved from ' . current_branch . ' to ' . a:1
  else
    let twiggy_bufnr = exists('t:twiggy_bufnr') ? t:twiggy_bufnr : 0
    if !twiggy_bufnr
      call s:Render()
    else
      if twiggy_bufnr ==# bufnr('')
        " :Twiggy closes as well as opens if you the twiggy buffer is focused
        call s:Close()
      else
        " If twiggy is open, :Twiggy will focus the twiggy buffer then redraw " it
        let t:twiggy_git_dir = b:git_dir
        let t:twiggy_git_cmd = fugitive#buffer().repo().git_command()
        call s:buffocus(t:twiggy_bufnr)
      end
    endif
  endif
endfunction

"     {{{3 Close
function! s:Close() abort
  bdelete!
  redraw | echo ''
endfunction

"   {{{2 Sorting
"     {{{3 Helpers
function s:sort_branches(type, int)
  exec "let sorts     = g:twiggy_" . a:type . "_branch_sorts"
  exec "let sort_name = g:twiggy_" . a:type . "_branch_sort"
  let max_index = len(sorts) - a:int
  let new_index = index(sorts, sort_name) + a:int

  if new_index > max_index
    let new_index = 0
  endif

  exec "let g:twiggy_" . a:type . "_branch_sort = g:twiggy_" . a:type . "_branch_sorts[new_index]"
endfunction

"     {{{3 Cycle
function! s:CycleSort(alt, int) abort
  let local = s:branch_under_cursor().is_local

  if !a:alt
    call s:sort_branches(local ? 'local' : 'remote', a:int)
  else
    call s:sort_branches(local ? 'remote' : 'local', a:int)
  endif

  " This is a little bit of an unfortunate hack
  let s:sorted = 1

  return 0
endfunction

"     {{{3 Slash Group
function! s:ToggleSlashSort() abort
  let g:twiggy_group_locals_by_slash = g:twiggy_group_locals_by_slash ? 0 : 1
  return 0
endfunction

"   {{{2 Git
"     {{{3 Checkout
function! s:Checkout(track) abort
  let current_branch = s:get_current_branch()
  let switch_branch = s:branch_under_cursor()

  if current_branch ==# switch_branch.name
    echo "Already on " . current_branch
  else
    redraw
    echo 'Moving from ' . current_branch . ' to ' . switch_branch.fullname . '...'
    if a:track && !switch_branch.is_local
      if index(map(split(s:git_cmd('branch --list', 0), '\n'), 'v:val[2:]'), switch_branch.name) >= 0
        call s:git_cmd('checkout ' . switch_branch.name, 0)
      else
        echom "Set up a new track branch"
        call s:git_cmd('checkout -b ' . switch_branch.name . ' ' . switch_branch.fullname , 0)
      endif
    else
      let detach = switch_branch.is_local ? '' : '--detach '
      call s:git_cmd('checkout ' . detach . switch_branch.fullname, 0)
    endif
  endif

  let s:init_line = 0
  let s:last_branch_under_cursor = 0

  return 0
endfunction

"     {{{3 Delete
function! s:Delete() abort
  let branch = s:branch_under_cursor()

  if branch.fullname ==# s:get_current_branch()
    return
  endif

  let s:init_line = branch.line

  if branch.is_local
    call s:git_cmd('branch -d ' . branch.fullname, 0)
    if v:shell_error
      " blow out last output to suppress error buffer
      let s:last_output = ''
      return s:Confirm(
            \ 'UNMERGED!  Force-delete local branch ' . branch.fullname . '?',
            \ "s:git_cmd('branch -D " . branch.fullname . "', 0)", 0)
    endif
  else
    return s:Confirm(
          \ 'Delete remote branch ' . branch.fullname . '?',
          \ "s:git_cmd('branch -d -r " . branch.fullname . "', 0)", 0)
  endif
endfunction

function! s:DeleteRemote() abort
  let branch = s:branch_under_cursor()

  return s:Confirm(
        \ 'WARNING! Delete branch ' . branch.name . ' from remote repo: ' . branch.group . '?',
        \ "s:git_cmd('push " . branch.group . " :" . branch.name . "', 1)", 0)
endfunction

"     {{{3 Fetch
function! s:Fetch(pull) abort
  let cmd = a:pull ? 'pull' : 'fetch'
  let branch = s:branch_under_cursor()
  if branch.tracking !=# ''
    let parts = split(branch.tracking, '/')
    call s:git_cmd(cmd . ' ' . s:git_flags . parts[0] . ' ' . join(parts[1:], '/') .
          \ ':refs/remotes/' . parts[0] . '/' . branch.fullname, 1)
  else
    redraw
    echo branch.name . ' is not a tracking branch'
    return 1
  endif
  return 0
endfunction

"     {{{3 Push
function! s:Pull() abort
  return s:Fetch(1)
endfunction

"     {{{3 Merge
function! s:Merge(remote) abort
  let branch = s:branch_under_cursor()

  if a:remote
    if branch.tracking ==# ''
      let v:warningmsg = 'No tracking branch for ' . branch.fullname
      return 1
    else
      call s:git_cmd('merge ' . s:git_flags . ' ' . branch.tracking, 1)
    endif
  else
    if branch.name ==# s:get_current_branch()
      let v:warningmsg = 'Can''t merge into self'
      return 1
    else
      call s:git_cmd('merge ' . s:git_flags . ' ' . branch.fullname, 1)
    endif
  endif

  return 0
endfunction

"     {{{3 Rebase
function! s:Rebase(remote) abort
  let branch = s:branch_under_cursor()

  if a:remote
    if branch.tracking ==# ''
      let v:warningmsg = 'No tracking branch for ' . branch.name
      return 1
    else
      call s:git_cmd('rebase ' . s:git_flags . ' ' . branch.tracking, 1)
    endif
  else
    if branch.fullname ==# s:get_current_branch()
      let v:warningmsg = 'Can''t rebase off of self'
      return 1
    else
      call s:git_cmd('rebase ' . s:git_flags . ' ' . branch.fullname, 1)
    endif
  endif

  return 0
endfunction


"     {{{3 Merge/Rebase Abort
function! s:Abort(type) abort
  call s:git_cmd(a:type . ' --abort', 0)
  cclose
  redraw | echo a:type . ' aborted'
endfunction

"     {{{3 Push
function! s:Push(choose_upstream) abort
  let branch = s:branch_under_cursor()

  if !branch.is_local
    let v:warningmsg = "Can't push a remote branch"
    return 1
  endif

  let remote_groups = split(s:git_cmd('remote', 0), "\n")

  let flag = ''
  if branch.tracking ==# '' && !a:choose_upstream
    if g:twiggy_set_upstream
      let flag = '-u'
    endif
    if len(remote_groups) > 1
      redraw
      let group = input("Push to which remote?: ", '', "custom,TwiggyCompleteRemotes")
    else
      let group = remote_groups[0]
    endif
  else
    if a:choose_upstream
      redraw
      let group = input("Push to which remote?: ", '', "custom,TwiggyCompleteRemotes")
    else
      let group = split(branch.tracking, '/')[0]
    endif
  endif

  if index(remote_groups, group) < 0
    let v:warningmsg = "Remote does not exist"
    return 1
  else
    call s:git_cmd('push ' . flag . ' ' . s:git_flags . ' ' . group . ' ' . branch.fullname, 1)
  endif

  return 0
endfunction

function! TwiggyCompleteRemotes(A,L,P) abort
  for remote in split(s:git_cmd('remote', 0), '\v\n')
    if match(remote, '\v^' . a:A) >= 0
      return remote
    endif
  endfor

  return ''
endfunction

"     {{{3 Stash
function! s:Stash(pop) abort
  let pop = a:pop ? ' pop' : ''
  call s:git_cmd('stash' . pop, 0)

  redraw
  if !v:shell_error
    echo 'Stash' . (a:pop ? ' popped!' : 'ed')
  endif
endfunction

"     {{{3 Revert
function! s:Revert(bang) abort
  let currfile = expand('%:p')
  if a:bang
    call s:git_cmd('reset ' . currfile, 0)
  endif
  call s:git_cmd('checkout ' . currfile, 0)
  exec "normal :e " . currfile . "\<CR>"
endfunction

" {{{1 Fugitive
function! s:close_string() abort
  if g:twiggy_close_on_fugitive_cmd
    return 'call <SID>Close()'
  else
    return 'wincmd w'
  endif
endfunction

autocmd BufEnter twiggy://* exec "command! -buffer Gstatus " . <SID>close_string() . " | silent normal! :<\C-U>Gstatus\<CR>"
autocmd BufEnter twiggy://* exec "command! -buffer Gcommit " . <SID>close_string() . " | silent normal! :<\C-U>Gcommit\<CR>"
autocmd BufEnter twiggy://* exec "command! -buffer Gblame  " . <SID>close_string() . " | silent normal! :<\C-U>Gblame\<CR>"
