" twiggy.vim -- Maintain your bearings while branching with git
" Maintainer: Andrew Haust <andrewwhhaust@gmail.com>
" Website:    https://www.github.com/sodapopcan/vim-twiggy
" License:    Same terms as Vim itself (see :help license)
" Version:    0.4

if exists('g:autoloaded_twiggy')
  finish
endif
let g:autoloaded_twiggy = 1

" {{{1 Utility
"   {{{2 buffocus
function! s:buffocus(bufnr) abort
  let switchbuf_cached = &switchbuf
  set switchbuf=useopen
  exec 'sb ' . a:bufnr
  exec 'set switchbuf=' . switchbuf_cached
endfunction

"   {{{2 sub
" Stolen right from tpope
function! s:sub(str,pat,rep) abort
  return substitute(a:str, '\v\C'.a:pat, a:rep, '')
endfunction

"   {{{2 gsub
" Stolen right from tpope
function! s:gsub(str,pat,rep) abort
  return substitute(a:str, '\v\C'.a:pat, a:rep, 'g')
endfunction

"   {{{2 fexists
function! s:fexists(file)
  return !empty(glob(a:file))
endfunction

"   {{{2 mapping
" Create local mappings in the twiggy buffer
function! s:mapping(mapping, fn, args) abort
  let s:mappings[s:encode_mapping(a:mapping)] = [a:fn, a:args]
  exe "nnoremap <buffer> <silent> " .
        \ a:mapping . " :<C-U>call <SID>call('" .
        \ s:encode_mapping(a:mapping) . "')<CR>"
endfunction

"   {{{2 encode_mapping
function! s:encode_mapping(mapping) abort
  return s:sub(a:mapping, '\v^\<', '___',)
endfunction

" {{{1 Script Variables
let s:init_line                = 0
let s:mappings                 = {}
let s:branch_line_refs         = {}
let s:last_branch_under_cursor = {}
let s:last_output              = []
let s:requires_buf_refresh     = 1

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
let g:twiggy_adapt_columns          = get(g:,'twiggy_adapt_columns',          0                                                        )
let g:twiggy_split_position         = get(g:,'twiggy_split_position',         ''                                                       )
let g:twiggy_local_branch_sort      = get(g:,'twiggy_local_branch_sort',      'alpha'                                                  )
let g:twiggy_local_branch_sorts     = get(g:,'twiggy_local_branch_sorts',     ['alpha', 'date', 'track', 'mru']                        )
let g:twiggy_remote_branch_sort     = get(g:,'twiggy_remote_branch_sort',     'alpha'                                                  )
let g:twiggy_remote_branch_sorts    = get(g:,'twiggy_remote_branch_sorts',    ['alpha', 'date']                                        )
let g:twiggy_group_locals_by_slash  = get(g:,'twiggy_group_locals_by_slash',  1                                                        )
let g:twiggy_set_upstream           = get(g:,'twiggy_set_upstream',           1                                                        )
let g:twiggy_prompted_force_push    = get(g:,'twiggy_prompted_force_push',    1                                                        )
let g:twiggy_enable_remote_delete   = get(g:,'twiggy_enable_remote_delete',   0                                                        )
let g:twiggy_use_dispatch           = get(g:,'twiggy_use_dispatch',           exists('g:loaded_dispatch') && g:loaded_dispatch ? 1 : 0 )
let g:twiggy_close_on_fugitive_cmd  = get(g:,'twiggy_close_on_fugitive_cmd',  0                                                        )
let g:twiggy_enable_quickhelp       = get(g:,'twiggy_enable_quickhelp',       1                                                        )
let g:twiggy_show_full_ui           = get(g:,'twiggy_show_full_ui',           g:twiggy_enable_quickhelp                                )
let g:twiggy_git_log_command        = get(g:,'twiggy_git_log_command',        ''                                                       )
let g:twiggy_refresh_buffers        = get(g:,'twiggy_refresh_buffers',        1                                                        )

" TODO: before merging to 'master', make keymaps configurable w/o magic numbers
"   For example,
"   'gP': 'Push', ['REMOTE']
"   '!P': 'Push', ['--force']
let g:twiggy_keymaps_on_branch = get(g:, 'twiggy_keymaps_on_branch', {
      \ '<CR>': ['Checkout',   [1]],
      \ 'c':    ['Checkout',   [1]],
      \ 'C':    ['Checkout',   [0]],
      \ 'o':    ['Checkout',   [1]],
      \ 'O':    ['Checkout',   [0]],
      \ 'gc':   ['CheckoutAs', []],
      \ 'go':   ['CheckoutAs', []],
      \ 'dd':   ['Delete',     []],
      \ 'F':    ['Fetch',      [0]],
      \ 'f':    ['Fetch',      [0]],
      \ 'm':    ['Merge',      [0, '']],
      \ 'M':    ['Merge',      [1, '']],
      \ 'gm':   ['Merge',      [0, '--no-ff']],
      \ 'gM':   ['Merge',      [1, '--no-ff']],
      \ 'r':    ['Rebase',     [0]],
      \ 'R':    ['Rebase',     [1]],
      \ '^':    ['Push',       [0, 0]],
      \ 'g^':   ['Push',       [1, 0]],
      \ '!^':   ['Push',       [0, 1]],
      \ 'V':    ['Pull',       []],
      \ 'P':    ['Push',       [0, 0]],
      \ 'gP':   ['Push',       [1, 0]],
      \ '!P':   ['Push',       [0, 1]],
      \ 'p':    ['Pull',       []],
      \ ',':    ['Rename',     []],
      \ '<<':   ['Stash',      [0]],
      \ '>>':   ['Stash',      [1]],
      \ })

let g:twiggy_keymaps_to_sort = get(g:, 'twiggy_keymaps_to_sort', {
      \ 'i':  ['CycleSort',       [0, 1]],
      \ 'I':  ['CycleSort',       [0, -1]],
      \ 'gi': ['CycleSort',       [1, 1]],
      \ 'gI': ['CycleSort',       [1, -1]],
      \ 'a':  ['ToggleSlashSort', []],
      \ })

"   {{{2 show_full_ui
function! s:showing_full_ui()
  return g:twiggy_enable_quickhelp && g:twiggy_show_full_ui
endfunction

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
    let output = systemlist(command)
    if v:shell_error
      let s:last_output = output
    endif

    return output
  endif
endfunction

"   {{{2 attn
function! s:attn_mode() abort
  if exists('t:twiggy_git_mode') &&
        \ index(['rebase', 'merge', 'cherry-pick'], t:twiggy_git_mode) >= 0
    return 1
  endif
  return 0
endfunction

"   {{{2 gitize
function! s:gitize(cmd) abort
  if exists('t:twiggy_bufnr') && t:twiggy_bufnr == bufnr('')
    let git_cmd = t:twiggy_git_cmd
  else
    let git_cmd = fugitive#repo().git_command()
  end
  let parts = split(git_cmd, " ")
  let worktree = "--work-tree=".s:sub(split(parts[1], "=")[1], '\v/.git$', "/")
  call insert(parts, worktree, 1)
  let git_cmd = join(parts, " ")
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
  let deprecated_mappings = {
        \ 'F': 'f',
        \ '^': 'P',
        \ 'g^': 'gP',
        \ '!^': '!P',
        \ 'V': 'p',
        \ 'd^': 'dP'
        \ }
  let encoded_mapping = s:encode_mapping(a:mapping)
  if has_key(deprecated_mappings, encoded_mapping)
    let t:twiggy_deprecation_notice = "WARNING: `".a:mapping
          \ ."` is deprecated and will eventually be removed.  "
          \ ."Use `".deprecated_mappings[encoded_mapping]."` instead."
  endif
  if call('s:' . s:mappings[key][0], s:mappings[key][1])
    call s:ErrorMsg()
  else
    call s:Render()
    call s:refresh_buffers()
    call <SID>buffocus(t:twiggy_bufnr)
    if s:attn_mode()
      wincmd p
      Gstatus
    endif
    call s:RenderOutputBuffer()
  endif
endfunction



" {{{1 Branch Parser
function! s:parse_branch(branch, type) abort
  let branch = {}

  let pieces = split(a:branch, "\t\t")

  let branch.current = pieces[0] ==# "*"

  let branch.decoration = ' '
  if branch.current
    let git_mode = exists('t:twiggy_git_mode') ? t:twiggy_git_mode : s:get_git_mode()
    let branch.decoration = git_mode !=# 'normal' ? s:icons.unmerged : s:icons.current
  endif

  let remote_details = pieces[3] . ' ' . pieces[4]
  let branch.tracking = ''
  if a:type ==# 'heads'
    let branch.tracking = pieces[3]
  endif
  let branch.remote =  branch.tracking != '' ? split(branch.tracking, '/')[0] : ''
  if branch.tracking !=# ''
    if pieces[4] !=# ''
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
  else
    let branch.status      = ''
    let branch.decoration .= ' '
  endif

  let branch.fullname = pieces[1]

  if a:type == 'heads'
    let branch.is_local = 1
    let branch.type  = 'local'
    if g:twiggy_group_locals_by_slash
      if match(branch.fullname, '/') >= 0
        let group = matchstr(branch.fullname, '\v[^/]*')
        let branch.group = group
        let branch.name = s:sub(branch.fullname, group . '/', '')
      else
        let branch.group = 'local'
        let branch.name = branch.fullname
      endif
    else
      let branch.group = 'local'
      let branch.name = branch.fullname
    endif
  else
    let branch.is_local = 0
    let branch.type = 'remote'
    let branch_split = split(branch.fullname, '/')
    let branch.name  = join(branch_split[1:], '/')
    let branch.group = branch_split[0]
  endif

  let remote_details = pieces[3]
  if pieces[4] !=# ''
    let remote_details = remote_details . ': ' . pieces[4][1:-2]
  endif

  if remote_details ==# ''
    let branch.details = join([pieces[2], pieces[5]], ' ')
  else
    let remote_details = '['.remote_details.']'
    let branch.details = join([pieces[2], remote_details, pieces[5]], ' ')
  endif

  return branch
endfunction

" {{{1 Git
"   {{{2 no_commits
function! s:no_commits() abort
  return s:gsub(s:git_cmd('rev-list -n 1 --all | wc -l', 0)[0], ' ', '') ==# '0'
endfunction

"   {{{2 dirty_tree
function! s:dirty_tree() abort
  return !empty(s:git_cmd('diff --shortstat', 0))
endfunction

"   {{{2 _git_branch_vv
function! s:_git_branch_vv(type) abort
  let branches = []
  let format = join([
        \ '%(HEAD)',
        \ '%(refname:short)',
        \ '%(objectname:short)',
        \ '%(upstream:short)',
        \ '%(upstream:track)',
        \ '%(contents:subject)',
        \ ], "\t\t")
  for branch in s:git_cmd('for-each-ref refs/' . a:type . " --format=$'".format."'", 0)
    call add(branches, s:parse_branch(branch, a:type))
  endfor

  return branches
endfunction

"   {{{2 branch_status
function! s:get_git_mode() abort
  let git_dir = exists('t:twiggy_git_dir') ? t:twiggy_git_dir : b:git_dir
  if isdirectory(git_dir . '/rebase-apply') ||
        \ isdirectory(git_dir . '/rebase-merge')
    return 'rebase'
  elseif s:fexists(git_dir . '/MERGE_HEAD') ||
        \ !empty(s:git_cmd('diff --shortstat --diff-filter=U | tail -1', 0))
    return 'merge'
  elseif s:fexists(git_dir . '/CHERRY_PICK_HEAD')
    return 'cherry-pick'
  else
    return 'normal'
  endif
endfunction

"   {{{2 get_branches
function! twiggy#get_branches() abort
  let locals = s:_git_branch_vv('heads')
  let locals_sorted = []

    let head = s:git_cmd('rev-parse --symbolic-full-name --abbrev-ref HEAD', 0)[0]
    if head ==# "HEAD"
      call add(locals_sorted, {
            \ 'decoration': s:icons['detached'].' ',
            \ 'status': 'detached',
            \ 'fullname': 'HEAD',
            \ 'name': 'HEAD@'.s:git_cmd('rev-parse --revs-only --short HEAD', 0)[0],
            \ 'is_local': 1,
            \ 'current': 0,
            \ 'remote': s:git_cmd('remote', 0)[0],
            \ 'type': 'local',
            \ 'tracking': '',
            \ 'details': 'detached',
            \ 'group': 'local'
            \  })
    endif

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

  let remotes = s:_git_branch_vv('remotes')
  let remotes_sorted = []

  if g:twiggy_remote_branch_sort ==# 'date'
    let remote_refs = {}

    for branch in remotes
      let remote_refs[branch.fullname] = branch
    endfor

    for remote in s:git_cmd('remote', 0)
      for branch_name in s:get_by_commiter_date('remotes/' . remote)
        let remote_branch_name = remote.'/'.branch_name
        if has_key(remote_refs, remote_branch_name)
          call add(remotes_sorted, remote_refs[remote_branch_name])
          call remove(remotes, index(remotes, remote_refs[remote_branch_name]))
        endif
      endfor
    endfor
  endif

  return extend(locals, extend(remotes_sorted, remotes))
endfunction

"   {{{2 get_current_branch
function! s:get_current_branch() abort
  return s:git_cmd('rev-parse --abbrev-ref HEAD', 0)[0]
endfunction

"   {{{2 branch_exists
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

" Note: this may change
function! TwiggyBranchUnderCursor() abort
  if &ft !=# 'twiggy'
    throw "Not in twiggy buffer"
  endif

  return s:branch_under_cursor()
endfunction

"   {{{2 get_uniq_branch_names_from_reflog
" http://stackoverflow.com/questions/14062402/awk-using-a-file-to-filter-another-one-out-tr
function! s:get_uniq_branch_names_from_reflog() abort
  let cmd = "awk 'FNR==NR { a[$NF]; next } $NF in a' <(" . s:gitize('branch --list') . ") "
  let cmd.= "<(" . s:gitize('reflog') . " | awk -F\" \" '/checkout: moving from/ { print $8 }' | "
  let cmd.= "awk " . shellescape('!f[$0]++') . ")"

  return s:system(cmd, 0)
endfunction

"   {{{2 get_merged_branches
" I'm sure there is a better plumbing command to figure this out
function! s:get_merged_branches() abort
  return map(s:git_cmd('branch --list --merged', 0), '\n')
endfunction

"   {{{2 get_by_committer_date
function! s:get_by_commiter_date(type) abort
  let cmd = s:gitize(
        \ "for-each-ref --sort=-committerdate --format='%(refname)' " .
        \ "refs/" . a:type . " | sed 's/refs\\/" .
        \ s:sub(a:type, '/', '\\/') . "\\///g'")
  return s:system(cmd, 0)
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
        let group_name = (t:twiggy_git_mode == 'normal') ? 'local' : t:twiggy_git_mode
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
  " Starting the line at 1 will cause an empty line to be added if the
  " quickhelp hint is showing.
  let line   = s:showing_full_ui() ? 1 : 0

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
  call add(output, 'gc    checkout as: <name>')
  call add(output, 'go    checkout as: <name>')
  call add(output, 'f     fetch remote')
  call add(output, 'm     merge')
  call add(output, 'M     merge remote')
  call add(output, 'gm    `m` --no-ff')
  call add(output, 'gM    `M` --no-ff')
  call add(output, 'r     rebase')
  call add(output, 'R     rebase remote')
  call add(output, 'P     push')
  call add(output, 'gP    push (prompted)')
  call add(output, '!P    force push')
  call add(output, 'p     pull')
  if g:twiggy_git_log_command !=# ''
    call add(output, 'gl    git log')
    call add(output, 'gL    git log `..`')
  endif
  call add(output, ',     rename')
  call add(output, 'dd    delete')
  if g:twiggy_enable_remote_delete
    call add(output, 'dP    delete from server')
  endif
  call add(output, '.     :Git <cursor> <branch>')
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
  if g:twiggy_show_full_ui
    call add(output, '')
    call add(output, '****************************')
    call add(output, 'For more detailed info:')
    call add(output, ':help twiggy-mappings')
  endif

  return output
endfunction

"   {{{2 rebase_view
function! s:rebase_view() abort
  return [
        \ "rebase in progress",
        \ "",
        \ "from this window:",
        \ "  c to continue",
        \ "  s to skip",
        \ "  a to abort"
        \ ]
endfunction

"   {{{2 merge_view
function! s:merge_view() abort
  return [
        \ "merge in progress",
        \ "",
        \ "from this window:",
        \ "  a to abort"
        \ ]
endfunction

"   {{{2 cherry_pick_view
function! s:cherry_pick_view() abort
  return [
        \ "cherry pick in progress",
        \ "",
        \ "from this window:",
        \ "  c to continue",
        \ "  a to abort"
        \ ]
endfunction

"   {{{2 Branch Details
function! s:show_branch_details() abort
  let line = line('.')
  if has_key(s:branch_line_refs, line)
    let max_len = &columns - 16
    let details = s:branch_line_refs[line].details
    if len(details) > max_len
      let details = details[0:max_len] . '...'
    endif
    redraw
    " Hacky deprecation code
    if exists('t:twiggy_deprecation_notice')
      redraw
      echohl WarningMsg
      echomsg t:twiggy_deprecation_notice
      echohl None
      unlet t:twiggy_deprecation_notice
    else
      echo details
    endif
  end
endfunction

"   {{{2 Stdout/Stderr Buffer
function! s:RenderOutputBuffer() abort
  if empty(s:last_output)
    return
  endif
  silent keepalt botright new TwiggyOutput
  let output = s:last_output
  let height = len(output)
  if height < 5 | let height = 5 | endif
  exec 'resize ' . height
  normal! ggdG
  setlocal modifiable
  call append(0, output)
  normal! ddgg

  setlocal nomodified nomodifiable noswapfile nowrap nonumber
  setlocal buftype=nofile bufhidden=delete
  if exists('+relativenumber')
    setlocal norelativenumber
  endif
  let s:last_output = []

  syntax clear
  syntax match TwiggyOutputText "\v^[^ ](.*)"
  highlight link TwiggyOutputText  Comment
  syntax match TwiggyOutputFile "\v^\t(.*)"
  highlight link TwiggyOutputFile Constant

  nnoremap <buffer> q :quit<CR>
  nnoremap <buffer> Q :quit<CR>:call <SID>Close()<CR>
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
  else
    return -1
  endif

  return 0
endfunction

function! s:PromptToStash() abort
  return s:Confirm("Working tree is dirty.  Stash first?",
        \ "s:git_cmd('stash', 0)", 1)
endfunction

"    {{{2 ErrorMsg
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
"     {{{3 traverse_branches
function! s:traverse_branches(motion) abort
  execute "normal! " . a:motion
  let current_line = line('.')
  let border_line = s:showing_full_ui() ? 3 : 1
  if current_line ==# s:total_lines && a:motion ==# 'j'
    return
  elseif (a:motion ==# 'k' && current_line <=# border_line)
    normal! j
  else
    while getline('.') =~# '\v^[A-Za-z]' || getline('.') ==# ''
      execute "normal! " . a:motion
    endwhile
  end
endfunction

"     {{{3 traverse_groups
function! s:traverse_groups(motion) abort
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

"     {{{3 jump_to_current_branch
function! s:jump_to_current_branch() abort
  call search(s:icons.current)
endfunction

"     {{{3 bufrefresh
function! s:bufrefresh()
  if &ft ==# 'gitcommit'
    Gstatus
  elseif &modifiable && &buftype ==# ''
    try
      silent edit
    catch
    endtry
  endif
endfunction

"     {{{3 refresh_buffers
function! s:refresh_buffers()
  if g:twiggy_refresh_buffers
    if s:requires_buf_refresh
      windo call <SID>bufrefresh()
    endif
    let s:requires_buf_refresh = 1
  endif
endfunction

"   {{{2 Main
"     {{{3 Render
function! s:Render() abort
  redraw

  if exists('b:git_dir') && &filetype !=# 'twiggy'
    let t:twiggy_git_dir = b:git_dir
    let t:twiggy_git_cmd = fugitive#repo().git_command()
  elseif !exists('t:twiggy_git_cmd')
    echo "Not a git repository"
    return
  endif

  if !exists('t:twiggy_bufnr') || !(exists('t:twiggy_bufnr') && t:twiggy_bufnr ==# bufnr(''))
    let fname = 'twiggy://' . t:twiggy_git_dir . '/branches'
    if &filetype ==# 'twiggyqh'
      exec "edit" fname
    else
      exec 'silent keepalt' g:twiggy_split_position g:twiggy_num_columns . 'vsplit' fname
    endif
    setlocal filetype=twiggy buftype=nofile bufhidden=delete
    setlocal nonumber nowrap lisp
    if exists('+relativenumber')
      setlocal norelativenumber
    endif
    let t:twiggy_bufnr = bufnr('')
  endif

  nnoremap <buffer> <silent> q :<C-U>call <SID>Close()<CR>
  if g:twiggy_enable_quickhelp
    nnoremap <buffer> <silent> ? :<C-U>call <SID>Quickhelp()<CR>
  endif

  autocmd! BufWinLeave twiggy://*
        \ if exists('t:twiggy_bufnr') |
        \   unlet! t:twiggy_bufnr |
        \   unlet! t:twiggy_git_dir |
        \   unlet! t:twiggy_git_cmd |
        \   unlet! t:twiggy_git_mode |
        \ endif

  if s:no_commits()
    set modifiable
    silent 1,$delete _
    call append(0, "No commits")
    delete _
    set nomodifiable
    return
  endif

  let t:twiggy_git_mode = s:get_git_mode()

  let output = []

  if s:showing_full_ui() && !s:attn_mode()
    " We don't need to manually add a second empty line here since
    " s:standard_view() will automatically add one.
    call extend(output, ["press ? for help"])
  endif

  if s:attn_mode()
    let view = "s:" . s:sub(t:twiggy_git_mode, '-', '_') . "_view"
    call extend(output, call(view, []))
  else
    call extend(output, s:standard_view())
  end

  if g:twiggy_adapt_columns
    let cols = 0
    for line in output
      let line_length = len(line)
      if line_length > cols
        let cols = line_length
      endif
    endfor
    exec "vertical resize ".(cols + 3)
  endif

  set modifiable
  silent 1,$delete _
  call append(0, output)
  normal! G
  delete _
  normal! gg

  setlocal nomodified nomodifiable noswapfile

  if s:attn_mode()
    if t:twiggy_git_mode ==# 'rebase'
      call s:mapping('c', 'Continue', ['rebase'])
      call s:mapping('s', 'Skip', [])
      call s:mapping('a', 'Abort', ['rebase'])
    elseif t:twiggy_git_mode ==# 'merge'
      call s:mapping('a', 'Abort', ['merge'])
    elseif t:twiggy_git_mode ==# 'cherry-pick'
      call s:mapping('s', 'Continue', ['cherry-pick'])
      call s:mapping('a', 'Abort', ['cherry-pick'])
    endif

    syntax match TwiggyAttnModeMapping "\v%3c(s|c|a)"
    highlight link TwiggyAttnModeMapping Identifier

    syntax match TwiggyAttnModeTitle "\v^(rebase|merge|cherry pick) in progress"
    highlight link TwiggyAttnModeTitle Type

    syntax match TwiggyAttnModeInstruction "\v^from this window:"
    highlight link TwiggyAttnModeInstruction String

    normal! 0

    return
  endif

  call s:show_branch_details()
  let s:total_lines = len(output)

  exec "normal! " . s:init_line . "gg"
  normal! 0

  augroup twiggy
    autocmd!
    autocmd CursorMoved twiggy://* call s:show_branch_details()
    autocmd CursorMoved twiggy://* call s:update_last_branch_under_cursor()
    autocmd BufReadPost,BufEnter,VimResized twiggy://* call <SID>Refresh()
  augroup END

  nnoremap <buffer> <silent> j      :<C-U>call <SID>traverse_branches('j')<CR>
  nnoremap <buffer> <silent> k      :<C-U>call <SID>traverse_branches('k')<CR>
  nnoremap <buffer> <silent> <Down> :<C-U>call <SID>traverse_branches('j')<CR>
  nnoremap <buffer> <silent> <Up>   :<C-U>call <SID>traverse_branches('k')<CR>
  nnoremap <buffer> <silent> <C-N>  :<C-U>call <SID>traverse_groups('j')<CR>
  nnoremap <buffer> <silent> <C-P>  :<C-U>call <SID>traverse_groups('k')<CR>
  nnoremap <buffer> <silent> J      :<C-U>call <SID>jump_to_current_branch()<CR>
  if s:showing_full_ui()
    nnoremap <buffer> <silent> gg    :normal! 4gg<CR>
  else
    nnoremap <buffer> <silent> gg    :normal! 2gg<CR>
  endif

  for s:key in keys(g:twiggy_keymaps_on_branch)
    call s:mapping(s:key,
          \ g:twiggy_keymaps_on_branch[s:key][0],
          \ g:twiggy_keymaps_on_branch[s:key][1])
  endfor
  for s:key in keys(g:twiggy_keymaps_to_sort)
    call s:mapping(s:key,
          \ g:twiggy_keymaps_to_sort[s:key][0],
          \ g:twiggy_keymaps_to_sort[s:key][1])
  endfor
  unlet s:key

  nnoremap <buffer> <expr> . <SID>dot()
  function! s:dot() abort
    let branch = s:branch_under_cursor()

    return ':Git  '.branch.fullname."\<C-Left>\<Left>"
  endfunction

  if g:twiggy_git_log_command ==# ''
    if exists(':GV')
      let g:twiggy_git_log_command  = 'GV'
    elseif exists(':Gitv')
      let g:twiggy_git_log_command = 'Gitv'
    endif
  endif

  if g:twiggy_git_log_command !=# ''
    nnoremap <buffer> gl :exec ':' . g:twiggy_git_log_command . ' ' . <SID>branch_under_cursor().fullname<CR>
    nnoremap <buffer> gL :exec ':' . g:twiggy_git_log_command . ' ' . <SID>branch_under_cursor().fullname . '..'<CR>
  endif

 " {{{ Syntax
  syntax clear

  exec "syntax match TwiggyGroup '\\v(^[^\\ " . s:icons.current . "]+)'"
  highlight default link TwiggyGroup Type

  exec "syntax match TwiggyCurrent '\\v%3v" . s:get_current_branch() . "$'"
  highlight default link TwiggyCurrent Identifier

  exec "syntax match TwiggyCurrent '\\V\\%1c" . s:icons.current . "'"
  highlight default link TwiggyCurrent Identifier

  exec "syntax match TwiggyTracking '\\V\\%2c" . s:icons.tracking . "'"
  highlight default link TwiggyTracking String

  exec "syntax match TwiggyAhead '\\V\\%2c" . s:icons.ahead . "'"
  highlight default link TwiggyAhead Type

  exec "syntax match TwiggyAheadBehind '\\V\\%2c" . s:icons.behind . "'"
  exec "syntax match TwiggyAheadBehind '\\V\\%2c" . s:icons.both . "'"
  highlight default link TwiggyAheadBehind Type

  exec "syntax match TwiggyDetached '\\V\\%2c" . s:icons.detached . "'"
  highlight default link TwiggyDetached Type

  exec "syntax match TwiggyUnmerged '\\V\\%1c" . s:icons.unmerged . "'"
  highlight default link TwiggyUnmerged Identifier

  syntax match TwiggySortText '\v[[a-z]+]'
  highlight default link TwiggySortText Comment

  if exists('s:branches_not_in_reflog') && len(s:branches_not_in_reflog)
    return
    exec "syntax match TwiggyNotInReflog '" .
          \ s:gsub(s:gsub(join(s:branches_not_in_reflog), '\(', ''), '\)', '') .
          \ "'"
    highlight default link TwiggyNotInReflog Comment
  endif

  exec "syntax match TwiggyDetachedText '\\v%3vHEAD\\@[a-z0-9]+'"
  highlight default link TwiggyDetachedText Identifier

  if s:showing_full_ui()
    syntax match TwiggyHelpHint "\v%1l"
    highlight default link TwiggyHelpHint Normal
    syntax match TwiggyHelpHintKey "\v%1l\?"
    highlight default link TwiggyHelpHintKey Identifier
  endif

  " }}}
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
  if exists('+relativenumber')
    setlocal norelativenumber
  endif
  setlocal modifiable
  silent 1,$delete _
  let b:git_dir = t:twiggy_cached_git_dir
  unlet t:twiggy_cached_git_dir
  let bufnr = bufnr('')

  nnoremap <buffer> <silent> q :quit<CR>
  nnoremap <buffer> <silent> ? :Twiggy<CR>

  call append(0, s:quickhelp_view())
  normal! G
  delete _
  normal! gg
  setlocal nomodifiable

  syntax clear
  syntax match TwiggyQuickhelpMapping "\v%<7c[A-Za-z\-\?\^\<\>!,.]"
  highlight link TwiggyQuickhelpMapping Identifier
  syntax match TwiggyQuickhelpSpecial "\v\`[a-zA-Z]+\`"
  highlight link TwiggyQuickhelpSpecial Identifier
  syntax match TwiggyQuickhelpHeader "\v[A-Za-z ]+\n[=]+"
  highlight link TwiggyQuickhelpHeader String
  syntax match TwiggyQuickhelpSectionHeader "\v[\-]+\n[a-z,\/ \:]+\n[\-]+"
  highlight link TwiggyQuickhelpSectionHeader String
  if g:twiggy_show_full_ui
    syntax match TwiggyQuickhelpRecommendation "\v^\*+\n[A-Za-z\: ]+\n[a-z\:\- ]+"
    highlight link TwiggyQuickhelpRecommendation String
  endif
endfunction

"     {{{3 Refresh
function! s:Refresh() abort
  if exists('t:refreshing') || !exists('t:twiggy_bufnr') || !exists('b:git_dir')
    return
  endif
  let t:refreshing = 1
  if &filetype !=# 'twiggy'
    let t:twiggy_git_dir = b:git_dir
    let t:twiggy_git_cmd = fugitive#repo().git_command()
    call s:buffocus(t:twiggy_bufnr)
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
    call s:RenderOutputBuffer()
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
        let t:twiggy_git_cmd = fugitive#repo().git_command()
        call s:buffocus(t:twiggy_bufnr)
      end
    endif
  endif
endfunction

"     {{{3 Close
function! s:Close() abort
  quit
  redraw | echo ''
endfunction

"   {{{2 Sorting
"     {{{3 Helpers
function! s:sort_branches(type, int)
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

  let s:requires_buf_refresh = 0

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

  if a:track && current_branch ==# switch_branch.fullname
    echo "Already on " . current_branch
    return 1
  else
    redraw
    echo 'Moving from ' . current_branch . ' to ' . switch_branch.fullname . '...'
    if a:track && !switch_branch.is_local " tracking and branch is remote
      if index(map(s:git_cmd('branch --list', 0), 'v:val[2:]'), switch_branch.name) >= 0
        " Checkout remote in detached HEAD
        call s:git_cmd('checkout ' . switch_branch.fullname, 0)
      else
        " Create a new tracking branch
        call s:git_cmd('checkout -b ' . switch_branch.name . ' ' . switch_branch.fullname , 0)
      endif
    elseif !a:track && !switch_branch.is_local " not tracking and branch is remote
      call s:git_cmd('checkout ' . switch_branch.fullname, 0)
    elseif !a:track && switch_branch.is_local " not tracking and branch is local
      call s:git_cmd('checkout ' . switch_branch.tracking, 0)
    else " tracking and branch is local
      call s:git_cmd('checkout ' . switch_branch.fullname, 0)
    endif
  endif

  let s:init_line = 0
  let s:last_branch_under_cursor = 0

  return 0
endfunction

"     {{{3 Checkout As
function! s:CheckoutAs() abort
  let branch = s:branch_under_cursor()

  redraw
  let new_name = input("Checkout " . branch.name . " as: ", "", "custom,TwiggyCompleteBranches")
  if new_name !=# ""
    if new_name ==# branch.name
      redraw
      echo branch.name . " already exists."
      return 1
    endif
    call s:git_cmd("checkout -b " . new_name . " " . branch.fullname, 0)
    redraw
    echo 'Moving from ' . branch.name . ' to ' . new_name . '...'

    let s:init_line = 0
    let s:last_branch_under_cursor = 0

    return 0
  endif

  return 1
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
      let s:last_output = []
      return s:Confirm(
            \ 'UNMERGED!  Force-delete local branch ' . branch.fullname . '?',
            \ "s:git_cmd('branch -D " . branch.fullname . "', 0)[0]", 0)
    endif
  else
    return s:Confirm(
          \ 'Delete remote branch ' . branch.fullname . '?',
          \ "s:git_cmd('branch -d -r " . branch.fullname . "', 0)[0]", 0)
  endif
endfunction

function! s:DeleteRemote() abort
  let branch = s:branch_under_cursor()

  return s:Confirm(
        \ 'WARNING! Delete branch ' . branch.name . ' from remote repo: ' . branch.group . '?',
        \ "s:git_cmd('push " . branch.group . " :" . branch.name . "', 1)[0]", 0)
endfunction

"     {{{3 Fetch
function! s:Fetch(pull) abort
  let cmd = a:pull ? 'pull' : 'fetch'
  let branch = s:branch_under_cursor()
  if branch.tracking !=# ''
    let remote = split(branch.tracking, '/')[0]
    call s:git_cmd(cmd . ' ' . remote . ' ' . branch.name, 1)
  else
    redraw
    echo branch.name . ' is not a tracking branch'
    return 1
  endif
  return 0
endfunction

"     {{{3 Pull
function! s:Pull() abort
  return s:Fetch(1)
endfunction

"     {{{3 Merge
function! s:Merge(remote, flags) abort
  let branch = s:branch_under_cursor()

  if a:remote
    if branch.tracking ==# ''
      let v:warningmsg = 'No tracking branch for ' . branch.fullname
      return 1
    else
      call s:git_cmd('merge ' . a:flags . ' ' . ' ' . branch.tracking, 1)
    endif
  else
    if branch.name ==# s:get_current_branch()
      let v:warningmsg = 'Can''t merge into self'
      return 1
    else
      call s:git_cmd('merge ' . a:flags . ' ' . ' ' . branch.fullname, 1)
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
      call s:git_cmd('rebase ' . ' ' . branch.tracking, 1)
    endif
  else
    if branch.fullname ==# s:get_current_branch()
      let v:warningmsg = 'Can''t rebase off of self'
      return 1
    else
      call s:git_cmd('rebase ' . ' ' . branch.fullname, 1)
    endif
  endif

  return 0
endfunction

"     {{{3 Continue Rebase
function! s:Continue(type) abort
  call s:git_cmd(a:type . ' --continue', 1)
endfunction

"     {{{3 Skip Rebase
function! s:Skip() abort
  call s:git_cmd('rebase --skip', 1)
endfunction

"     {{{3 Merge/Rebase Abort
function! s:Abort(type) abort
  call s:git_cmd(a:type . ' --abort', 0)
  cclose
  redraw | echo a:type . ' aborted'
endfunction

"     {{{3 Push
function! s:Push(choose_upstream, force) abort
  let branch = s:branch_under_cursor()

  if !branch.is_local
    let v:warningmsg = "Can't push a remote branch"
    return 1
  endif

  let s:requires_buf_refresh = 0

  let remote_groups = s:git_cmd('remote', 0)

  let flags = ''
  if a:force
    let flags .= ' --force'
  end

  if branch.tracking ==# '' && !a:choose_upstream
    if g:twiggy_set_upstream
      let flags .= ' -u'
    endif
    if len(remote_groups) > 1
      redraw
      let group = input("Push to which remote?: ", '', "custom,TwiggyCompleteRemotes")
    elseif len(remote_groups) == 0
      redraw
      echo "There are no remotes to push to"
      return 1
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
    let cmd = 'push ' . flags . ' ' . group . ' ' . branch.fullname
    if !a:force || !g:twiggy_prompted_force_push
      call s:git_cmd(cmd, 1)
    else
      return s:Confirm("Force push to " . branch.tracking . "?",
            \ "s:git_cmd('" . cmd . "', 1)", 0)
    endif
  endif

  return 0
endfunction

function! TwiggyCompleteRemotes(A,L,P) abort
  for remote in s:git_cmd('remote', 0)
    if match(remote, '\v^' . a:A) >= 0
      return remote
    endif
  endfor

  return ''
endfunction

"     {{{3 Rename
function! s:Rename() abort
  let s:requires_buf_refresh = 0

  let branch = s:branch_under_cursor()
  let new_name = input("Rename " . branch.fullname . " to: ")
  redraw
  echo "Renaming \"" . branch.fullname . "\" to \"" . new_name . "\"... "
  call s:git_cmd("branch -m " . branch.fullname . " " . new_name, 0)
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
