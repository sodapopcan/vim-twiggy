" twiggy.vim -- Maintain your bearings while branching with git
" Maintainer: Andrew Haust <andrewwhhaust@gmail.com>
" Website:    https://www.github.com/sodapopcan/vim-twiggy
" License:    Same terms as Vim itself (see :help license)

if exists('g:autoloaded_twiggy')
  finish
endif
let g:autoloaded_twiggy = 1

" {{{1 Utility
"   {{{2 focusbuf
function! s:buffocus(bufnr)
  let switchbuf_cached = &switchbuf
  set switchbuf=useopen
  exec 'sb ' . a:bufnr
  exec 'set switchbuf=' . switchbuf_cached
endfunction

" {{{1 Options
"   {{{2 Helpers
function! s:init_option(option, val)
  let var = "g:twiggy_" . a:option
  if !exists(var) | let {var} = a:val | endif
endfunction

function! s:get_option(option)
  let var = "g:twiggy_" . a:option
  if !exists(var)
    return 0
  else
    return {var}
  endif
endfunction

"   {{{2 The Options
call s:init_option('num_coloumns', 31)
call s:init_option('split_position', 'topleft')
call s:init_option('local_branch_sort', 'alpha')
call s:init_option('local_branch_sorts', ['alpha', 'mru', 'date', 'track'])
call s:init_option('remote_branch_sort', 'alpha')
call s:init_option('remote_branch_sorts', ['alpha', 'date'])
call s:init_option('group_locals_by_slash', 1)
call s:init_option('use_dispatch', exists('g:loaded_dispatch') && g:loaded_dispatch ? 1 : 0)
call s:init_option('close_on_fugitive_cmd', 0)
call s:init_option('icon_set', has('multi_byte') ? 'pretty' : 'standard')

" {{{1 Script Variables
let s:init_line                = 2
let s:mappings                 = {}
let s:branch_line_refs         = {}
let s:current_branch_ref       = {}
let s:last_local_sort          = s:get_option('local_branch_sort')
let s:last_branch_under_cursor = {}
let s:last_output              = ''
let s:git_flags                = '' " I regret this
let s:git_mode                 = ''

" {{{1 Icons
let s:icons = {}

let s:icons.pretty   = ['*', '✓', '↑', '↓', '↕', '∅', '✗']
let s:icons.standard = ['*', '=', '+', '-', '~', '%', 'x']
let s:icons.custom   = s:get_option('custom_icons')

let s:icons.current  = s:icons[s:get_option('icon_set')][0]
let s:icons.tracking = s:icons[s:get_option('icon_set')][1]
let s:icons.ahead    = s:icons[s:get_option('icon_set')][2]
let s:icons.behind   = s:icons[s:get_option('icon_set')][3]
let s:icons.both     = s:icons[s:get_option('icon_set')][4]
let s:icons.detached = s:icons[s:get_option('icon_set')][5]
let s:icons.unmerged = s:icons[s:get_option('icon_set')][6]

" hmmmmmm
call s:init_option('custom_icons', s:icons[s:get_option('icon_set')])

" {{{1 System
"   {{{2 cmd
function! s:cmd(cmd, bg)
  let command = a:cmd

  if a:bg
    if exists('g:loaded_dispatch') && g:loaded_dispatch &&
          \ s:get_option('use_dispatch')
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
function! s:gitize(cmd)
  if !exists('g:twiggy_git_cmd')
    let g:twiggy_git_cmd = fugitive#buffer().repo().git_command()
  end
  return g:twiggy_git_cmd . ' ' . a:cmd
endfunction

"   {{{2 git_cmd
function! s:git_cmd(cmd, bg)
  let cmd = s:gitize(a:cmd)
  if a:bg
    call s:cmd(cmd, a:bg)
  else
    return s:cmd(cmd, a:bg)
  endif
endfunction

"   {{{2 call
function! s:call(mapping)
  let key = s:encode_mapping(a:mapping)
  if call('s:' . s:mappings[key][0], s:mappings[key][1])
    call s:ErrorMsg()
  else
    call s:Render()
    call s:ShowOutputBuffer()
  endif
  let s:git_flags = ''
endfunction



" {{{1 Helpers
"   {{{2 mapping
function! s:mapping(mapping, fn, args)
  let s:mappings[s:encode_mapping(a:mapping)] = [a:fn, a:args]
  exe "nnoremap <buffer> <silent> " .
        \ a:mapping . " :<C-U>call <SID>call('" .
        \ s:encode_mapping(a:mapping) . "')<CR>"
endfunction

function! s:encode_mapping(mapping)
  return substitute(a:mapping, '\v^\<', '___', '')
endfunction

" {{{1 Branch Parser
function! s:parse_branch(branch, type)
  let branch = {}

  let branch.current = match(a:branch, '\v^\*') >= 0

  if branch.current
    let s:current_branch_ref = branch
    if s:git_mode !=# 'normal'
      let branch.decoration = s:icons.unmerged
    else
      let branch.decoration = s:icons.current
    end
  else
    let branch.decoration = ' '
  endif

  let detached = match(a:branch, '\v^\(detached from', 2)

  let remote_details = matchstr(a:branch, '\v\[[^\[]+\]')
  let branch.tracking = matchstr(remote_details, '\v[^ \:\]]+', 1)
  if branch.tracking != ''
    let branch.remote = split(branch.tracking, '/')[0]
  else
    let branch.remote = ''
  end
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
    if s:get_option('group_locals_by_slash')
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
function! s:OptionParser()
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
function! s:no_commits()
  call s:git_cmd('rev-list -n 1 --all &> /dev/null', 0)
  return v:shell_error
endfunction

"   {{{2 dirty_tree
function! s:dirty_tree()
  return s:git_cmd('diff --shortstat', 0) !=# ''
endfunction

"   {{{2 _git_branch_vv
function! s:_git_branch_vv(type)
  let branches = []
  for branch in split(s:git_cmd('branch --' . a:type . ' -vv --no-color', 0), '\v\n')
    call add(branches, s:parse_branch(branch, a:type))
  endfor

  return branches
endfunction

"   {{{2 branch_status
function! s:get_git_mode()
  if isdirectory(g:twiggy_git_dir . '/rebase-apply')
    return 'rebasing'
  elseif filereadable(g:twiggy_git_dir . '/MERGE_HEAD')
    return 'merging'
  elseif s:git_cmd('diff --shortstat --diff-filter=U | tail -1', 0) !=# ''
    return 'merging'
  else
    return 'normal'
  endif
endfunction

"   {{{2 get_branches
function! s:get_branches()
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
      if s:get_option('local_branch_sort') ==# 'mru'
        call add(locals_sorted, local_refs[branch_name])
        call remove(locals, index(locals, local_refs[branch_name]))
      endif
    endif
  endfor

  if s:get_option('local_branch_sort') ==# 'track'
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

  if s:get_option('local_branch_sort') ==# 'date'
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

  if s:get_option('remote_branch_sort') ==# 'date'
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
function! s:get_current_branch()
  return s:git_cmd('branch --list | grep \*', 0)[2:-2]
endfunction

"   branch_exists
function! s:branch_exists(branch)
  call s:git_cmd('show-ref --verify --quiet refs/heads/' . a:branch, 0)
  return !v:shell_error
endfunction

"   {{{2 branch_under_cursor
function! s:branch_under_cursor()
  let line = line('.')
  if has_key(s:branch_line_refs, line)
    return s:branch_line_refs[line]
  endif
  return ''
endfunction

"   {{{2 get_uniq_branch_names_from_reflog
" http://stackoverflow.com/questions/14062402/awk-using-a-file-to-filter-another-one-out-tr
function! s:get_uniq_branch_names_from_reflog()
  let cmd = "awk 'FNR==NR { a[$NF]; next } $NF in a' <(" . s:gitize('branch --list') . ") "
  let cmd.= "<(" . s:gitize('reflog') . " | awk -F\" \" '/checkout: moving from/ { print $8 }' | "
  let cmd.= "awk " . shellescape('!f[$0]++') . ")"

  return split(s:cmd(cmd, 0), '\v\n')
endfunction

"   get_merged_branches
" I'm sure there is a better plumbing command to figure this out
function! s:get_merged_branches()
  return map(split(s:git_cmd('branch --list --merged', 0), '\n'), 'v:val[2:]')
endfunction

"   {{{2 get_by_committer_date
function! s:get_by_commiter_date(type)
  let cmd = "cut -d'/' -f 3- <("
        \ . s:gitize("for-each-ref --sort=-authordate refs/" . a:type)
        \ . " | awk -F\" \" ' { print $3 }')"
  return split(s:cmd(cmd, 0), '\v\n')
endfunction

"   {{{2 update_last_branch_under_cursor
function! s:update_last_branch_under_cursor()
  " Yeah, gonna swallow the exception here
  try
    let s:last_branch_under_cursor = s:branch_under_cursor()
  catch
    return
  endtry
endfunction

" {{{1 UI
"   {{{2 Standard
function! s:standard_view()
  " Sort branches by group
  let groups = {}
  let groups['local'] = {}
  let groups['remote'] = {}
  let group_refs = {}
  let group_refs['local'] = []
  let group_refs['remote'] = []

  let branches = s:get_branches()
  for branch in branches
    if !has_key(groups[branch.type], branch.group)
      let groups[branch.type][branch.group] = {}
      if branch.group ==# 'local'
        let group_name = s:git_mode
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

      call add(output, group_ref.name . ' [' . s:get_option(group_type . '_branch_sort') . ']')

      for branch in group_ref['branches']
        call add(output, branch.decoration . branch.name)
        let line = line + 1
        let branch.line = line
        let s:branch_line_refs[line] = branch
        if !empty(s:last_branch_under_cursor)
          if !s:last_branch_under_cursor.is_local
            if branch.status ==# 'detached'
              let s:init_line = line
            elseif exists('s:sorted')
              if branch.fullname ==# s:last_branch_under_cursor.fullname
                unlet s:sorted
                let s:init_line = branch.line
              endif
            else
              for _branch in group_ref['branches']
                if _branch.remote ==# s:last_branch_under_cursor.fullname
                  let s:init_line = _branch.line
                  break
                endif
              endfor
            endif
          elseif s:last_branch_under_cursor.fullname ==# branch.fullname
            let s:init_line = line
          endif
        endif
      endfor

    endfor
  endfor

  return output
endfunction

"   {{{2 Branch Details
function! s:show_branch_details()
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
function! s:ShowOutputBuffer()
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
function! s:Confirm(prompt, cmd, abort)
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

function! s:PromptToStash()
  return s:Confirm("Working tree is dirty.  Stash first?",
        \ "s:git_cmd('stash', 0)", 1)
endfunction

"   {{{2 ErrorMsg
function! s:ErrorMsg()
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
function! s:traverseBranches(motion) abort
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
function! s:traverseGroups(motion)
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

"   {{{2 Main
"     {{{3 Render
function! s:Render()
  redraw

  if exists('b:git_dir') && &filetype !=# 'twiggy'
    let g:twiggy_git_dir = b:git_dir
    let g:twiggy_git_cmd = fugitive#buffer().repo().git_command()
  elseif !exists('g:twiggy_git_cmd')
    echo "Not a git repository"
    return
  endif

  if !s:get_option('bufnr') && s:get_option('bufnr') !=# bufnr('')
    exec 'silent keepalt ' . s:get_option('split_position') . ' vsplit Twiggy'
    setlocal filetype=twiggy buftype=nofile
    exec 'vertical resize ' . s:get_option('num_coloumns')
    setlocal nonumber nowrap lisp
  endif

  nnoremap <buffer> <silent> q     :<C-U>call <SID>Close()<CR>

  if s:no_commits()
    set modifiable
    silent 1,$delete _
    call append(0, "No commits")
    normal! dd
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

  " This is solving a problem I don't have yet :O
  exec "normal! " . s:init_line . "gg"

  nnoremap <buffer> <silent> j     :<C-U>call <SID>traverseBranches('j')<CR>
  nnoremap <buffer> <silent> k     :<C-U>call <SID>traverseBranches('k')<CR>
  nnoremap <buffer> <silent> <C-N> :<C-U>call <SID>traverseGroups('j')<CR>
  nnoremap <buffer> <silent> <C-P> :<C-U>call <SID>traverseGroups('k')<CR>
  nnoremap <buffer>          gg    2gg

  nnoremap <buffer>          s     :<C-U>call <SID>OptionParser()<CR>

  call s:mapping('<CR>',    'Checkout',         [1])
  call s:mapping('c',       'Checkout',         [1])
  call s:mapping('C',       'Checkout',         [0])
  call s:mapping('o',       'Checkout',         [1])
  call s:mapping('O',       'Checkout',         [0])
  call s:mapping('dd',      'Delete',           [])
  call s:mapping('d^',      'DeleteRemote',     [])
  call s:mapping('F',       'Fetch',            [])
  call s:mapping('m',       'Merge',            [0])
  call s:mapping('M',       'Merge',            [1])
  call s:mapping('r',       'Rebase',           [0])
  call s:mapping('R',       'Rebase',           [1])
  call s:mapping('^',       'Push',             [0])
  call s:mapping('<<',      'Stash',            [0])
  call s:mapping('>>',      'Stash',            [1])
  call s:mapping('i',       'CycleSort',        [0,1])
  call s:mapping('I',       'CycleSort',        [0,-1])
  call s:mapping('gi',      'CycleSort',        [1,1])
  call s:mapping('gI',      'CycleSort',        [1,-1])
  call s:mapping('a',       'ToggleSlashSort',  [])

  if s:git_mode ==# 'rebasing'
    call s:mapping('A', 'Abort', ['rebase'])
  elseif s:git_mode ==# 'merging'
    call s:mapping('A', 'Abort', ['merge'])
  else
    nnoremap <buffer> <silent> A :echo 'Nothing to abort'<CR>
  endif

 " {{{ Syntax
  syntax clear

  exec "syntax match TwiggyGroup '\\v(^[^\\ " . s:icons.current . "]+)'"
  highlight link TwiggyGroup Type

  exec "syntax match TwiggyCurrent '\\v" . s:get_current_branch() . "$'"
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
  call s:init_option('bufnr', bufnr(''))
endfunction

"     {{{3 Refresh
function! s:Refresh()
  if !exists('g:twiggy_bufnr') || !exists('b:git_dir') | return | endif
  if exists('s:refreshing') | return | endif
  let s:refreshing = 1
  if &filetype !=# 'twiggy'
    call s:buffocus(g:twiggy_bufnr)
    if g:twiggy_git_dir ==# b:git_dir | return | endif
    let g:twiggy_git_dir = b:git_dir
    let g:twiggy_git_cmd = fugitive#buffer().repo().git_command()
  endif
  call s:Render()
  unlet s:refreshing
endfunction

"     {{{3 Branch
function! twiggy#Branch(...) abort
  if len(a:000)
    let current_branch = s:get_current_branch()
    let f = s:branch_exists(a:1) ? '' : '-b '
    call s:git_cmd('checkout ' . f . join(a:000), 0)
    call s:ShowOutputBuffer()
    if s:get_option('bufnr')
      call s:Refresh()
    end
    redraw
    echo 'Moved from ' . current_branch . ' to ' . a:1
  else
    let twiggy_bufnr = s:get_option('bufnr')
    if !twiggy_bufnr
      call s:Render()
    else
      if twiggy_bufnr ==# bufnr('')
        " :Twiggy closes as well as opens if you the twiggy buffer is focused
        call s:Close()
      else
        " If twiggy is open, :Twiggy will focus the twiggy buffer then redraw " it
        call s:buffocus(s:get_option('bufnr'))
      end
    endif
  endif
endfunction

"     {{{3 Close
function! s:Close()
  bdelete!
  redraw | echo ''
endfunction

"   {{{2 Sorting
"     {{{3 Helpers
function s:sort_branches(type)
  let max_index = len(s:get_option(a:type . '_branch_sorts')) - 1
  let new_index = index(s:get_option(a:type . '_branch_sorts'),
        \  s:get_option(a:type . '_branch_sort')) + 1

  if new_index > max_index
    let new_index = 0
  endif

  exec "let g:twiggy_" . a:type . "_branch_sort = s:get_option('" . a:type
        \ . "_branch_sorts')[new_index]"
endfunction

"     {{{3 Cycle
function! s:CycleSort(alt)
  let local = s:branch_under_cursor().is_local

  if !a:alt
    call s:sort_branches(local ? 'local' : 'remote')
  else
    call s:sort_branches(local ? 'remote' : 'local')
  endif

  " This is a little bit of an unfortunate hack
  let s:sorted = 1

  return 0
endfunction

"     {{{3 Slash Group
function! s:ToggleSlashSort()
  let g:twiggy_group_locals_by_slash = s:get_option('group_locals_by_slash') ? 0 : 1
  return 0
endfunction

"   {{{2 Git
"     {{{3 Checkout
function! s:Checkout(track)
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
      if switch_branch.is_local
        call s:git_cmd('checkout ' . switch_branch.fullname, 0)
      else
        call s:git_cmd('checkout ' . switch_branch.fullname, 0)
      endif
    endif
  endif

  return 0
endfunction

"     {{{3 Delete
function! s:Delete()
  let branch = s:branch_under_cursor()

  if branch.fullname ==# s:get_current_branch()
    return
  endif

  if branch.is_local
    if index(s:get_merged_branches(), branch.fullname) < 0
      return s:Confirm(
            \ 'UNMERGED!  Force-delete local branch ' . branch.fullname . '?',
            \ "s:git_cmd('branch -D " . branch.fullname . "', 0)", 0)
    else
      return s:Confirm(
            \ 'Delete local branch ' . branch.fullname . '?',
            \ "s:git_cmd('branch -d " . branch.fullname . "', 0)", 0)
    endif
  else
    return s:Confirm(
          \ 'Delete remote branch ' . branch.fullname . '?',
          \ "s:git_cmd('branch -d -r " . branch.fullname . "', 0)", 0)
  endif
endfunction

function! s:DeleteRemote()
  let branch = s:branch_under_cursor()

  return s:Confirm(
        \ 'WARNING! Delete branch ' . branch.name . ' from ' . branch.group . '?',
        \ "s:git_cmd('push " . branch.group . " :" . branch.name . "', 1)")
endfunction

"     {{{3 Fetch
function! s:Fetch()
  let branch = s:branch_under_cursor()
  if branch.tracking !=# ''
    let parts = split(branch.tracking, '/')
    call s:git_cmd('fetch ' . s:git_flags . parts[0] . ' ' . join(parts[1:], '/') .
          \ ':refs/remotes/' . parts[0] . '/' . branch.fullname, 1)
  else
    redraw
    echo branch.name . ' is not a tracking branch'
    return 1
  endif
  return 0
endfunction

"     {{{3 Merge
function! s:Merge(remote)
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
function! s:Rebase(remote)
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
function! s:Abort(type)
  call s:git_cmd(a:type . ' --abort', 0)
  redraw | echo a:type . ' aborted'
endfunction

"     {{{3 Push
function! s:Push(current)
  let branch = a:current ? s:current_branch_ref : s:branch_under_cursor()

  if !branch.is_local
    let v:warningmsg = "Can't push a remote branch"
    return 1
  endif

  let remote_groups = split(s:git_cmd('remote', 0), "\n")

  if branch.tracking ==# ''
    let flag = '--set-upstream'
    if len(remote_groups) > 1
      redraw
      let group = input("Push to which remote?: ", '', "custom,TwiggyCompleteRemotes")
    else
      let group = remote_groups[0]
    endif
  else
    let flag = ''
    let group = split(branch.tracking, '/')[0]
  endif

  if index(remote_groups, group) < 0
    let v:warningmsg = "Remote does not exist"
    return 1
  else
    call s:git_cmd('push ' . flag . ' ' . s:git_flags . ' ' . group . ' ' . branch.fullname, 1)
  endif

  return 0
endfunction

function! TwiggyCompleteRemotes(A,L,P)
  for remote in split(s:git_cmd('remote', 0), '\v\n')
    if match(remote, '\v^' . a:A) >= 0
      return remote
    endif
  endfor

  return ''
endfunction

"     {{{3 Stash
function! s:Stash(pop)
  let pop = a:pop ? ' pop' : ''
  call s:git_cmd('stash' . pop, 0)

  redraw
  if !v:shell_error
    echo 'Stash' . (a:pop ? ' popped!' : 'ed')
  endif
endfunction

"     {{{3 Revert
function! s:Revert(bang)
  let currfile = expand('%:p')
  if a:bang
    call s:git_cmd('reset ' . currfile, 0)
  endif
  call s:git_cmd('checkout ' . currfile, 0)
  exec "normal :e " . currfile . "\<CR>"
endfunction

"     {{{3 GitCmd
function! s:GitCmd(prompt_to_stash, cmd, ...)
  let choice = ''
  if a:prompt_to_stash && s:dirty_tree() && s:git_mode == 'local'
    let choice = s:PromptToStash()
  endif
  if choice ==# -1
    redraw | echo ''
    return
  endif

  let args = a:0 ? ' ' . join(map(copy(a:000), 'shellescape(v:val)')) : ''
  call s:git_cmd(a:cmd . args, 1)

  if exists('g:twiggy_bufnr')
    call s:Refresh()
  endif
endfunction


" Completion

function! TwiggyCompleteGitBranches(A,L,P)
  for branch in s:get_branches()
    if match(branch.fullname, '\v^' . a:A) >= 0
      let slicepos = len(split(a:A, '/')) - 1
      return join(split(branch.fullname, '/')[0:slicepos], '/')
    endif
  endfor
  return ''
endfunction

function! s:complete_git_cmd(A,L,P,args) abort
  " First part ripped from tpope
  if a:A =~ '^-' || type(a:A) == type(0)
    return filter(a:args,'v:val[0 : strlen(a:A)-1] ==# a:A')
  else
    return [TwiggyCompleteGitBranches(a:A,a:L,a:P)]
  endif
endfunction

function! TwiggyCompletePush(A,L,P) abort
  return s:complete_git_cmd(a:A,a:L,a:P, ['--all', '--prune', '--mirror', '-n', '--dry-run', '--porcelain', '--delete', '--tags', '--follow-tags', '--receive-pack=', '--exec=', '--force-with-lease', '--no-force-with-lease', '-f', '--force', '--repo=', '-u', '--set-upstream', '--thin', '--no-thin', '-q', '--quiet', '-v', '--verbose', '--progress', '--recurse-submodules=', '--verify', '--no-verifiy'])
endfunction

function! TwiggyCompletePull(A,L,P) abort
  return s:complete_git_cmd(a:A,a:L,a:P, ['-q', '--quiet', '-v', '--verbose', '--recurse-submodules=', '--no-recurse-submodules=', '--commit', '--no-commit', '-e', '--edit', '--no-edit', '--ff', '--no-ff', '--ff-only', '--log=', '--no-log', '-n', '--stat', '--no-stat', '--squash', '--no-squash', '-s', '--strategy=', '--verify-signatures', '--no-verify-signatures', '--summary', '--no-summary', '-r', '--rebase', '--no-rebase', '--all', '-a', '--append', '--depth=', '--unshallow', '--update-shallow', '-f', '--force', '-k', '--keep', '--no-tags', '-u', '--update-head-ok', '--upload-pack', '--progress'])
endfunction

function! TwiggyCompleteRebase(A,L,P) abort
  return s:complete_git_cmd(a:A,a:L,a:P, ['--onto', '--continue', '--abort', '--keep-empty', '--skip', '--edit-todo', '-m', '--merge', '-s', '--strategy=', '-X', '--strategy-option=', '-q', '--quiet', '-v', '--verbose', '--stat', '-n', '--no-stat', '--no-verify', '--verifiy', '-C', '-f', '--force-rebase', '--fork-point', '--no-fork-point', 'ignore-whitespace', '--whitespace=', '--committer-date-is-author-date', '--ignore-date', '-i', '--interactive', '-p', '--preserver-merges', '-x', '--exec', '--root', '--autosquash', '--no-autosquash', '--auto-stash', '--no-autostash', '--no-ff'])
endfunction

function! TwiggyCompleteMerge(A,L,P) abort
  return s:complete_git_cmd(a:A,a:L,a:P, ['--commit', '--no-commit', '-e', '--edit', '--no-edit', '--ff', '--no-ff', '--ff-only', '--log=', '--no-log', '-n', '--stat', '--no-stat', '--squash', '--no-squash', '-s', '--strategy=', '-X', '--verify-signatures', '--no-verify-signatures', '--summary', '--no-summary', '-q', '--quiet', '-v', '--verbose', '--progress', '--no-progress', '-S', '--gpg-sign=', '-m', '--rerere-autoupdate', '--no-rerere-autoupdate', '--abort'])
endfunction

function! TwiggyCompleteStash(A,L,P) abort
  return ['list', 'show', 'drop', 'pop', 'apply', 'branch', 'save', 'clear', 'create', 'store']
endfunction

" User Commands

function! twiggy#define_commands()
  command! -buffer -nargs=0 -bang TwigRevert call s:Revert(<bang>0)
  command! -buffer -nargs=* -complete=customlist,TwiggyCompletePush   TwigPush   call s:GitCmd(0, 'push', <f-args>)
  command! -buffer -nargs=* -complete=customlist,TwiggyCompleteFetch  TwigFetch  call s:GitCmd(0, 'fetch', <f-args>)
  command! -buffer -nargs=* -complete=customlist,TwiggyCompleteMerge  TwigMerge  call s:GitCmd(1, 'merge', <f-args>)
  command! -buffer -nargs=* -complete=customlist,TwiggyCompleteRebase TwigRebase call s:GitCmd(1, 'rebase', <f-args>)
  command! -buffer -nargs=* -complete=customlist,TwiggyCompletePull   TwigPull   call s:GitCmd(1, 'pull', <f-args>)
  command! -buffer -nargs=* TwigStash call s:GitCmd(0, 'stash', <f-args>)
endfunction

" {{{1 Auto Commands
augroup twiggy
  autocmd!
  autocmd CursorMoved Twiggy call s:show_branch_details()
  autocmd CursorMoved Twiggy call s:update_last_branch_under_cursor()
  autocmd BufEnter    Twiggy exec 'vertical resize ' . s:get_option('num_coloumns')
  autocmd BufReadPost,BufEnter,BufLeave,VimResized Twiggy call <SID>Refresh()
  autocmd BufWinLeave Twiggy if exists('g:twiggy_bufnr') | unlet g:twiggy_bufnr | endif
augroup END

" {{{1 Fugitive
if s:get_option('close_on_fugitive_cmd')
  let close_string = 'call <SID>Close()'
else
  let close_string = 'wincmd w'
endif

autocmd BufEnter Twiggy exec "command! -buffer Gstatus " . close_string . " | silent normal! :<\C-U>Gstatus\<CR>"
autocmd BufEnter Twiggy exec "command! -buffer Gcommit " . close_string . " | silent normal! :<\C-U>Gcommit\<CR>"
autocmd BufEnter Twiggy exec "command! -buffer Gblame  " . close_string . " | silent normal! :<\C-U>Gblame\<CR>"
