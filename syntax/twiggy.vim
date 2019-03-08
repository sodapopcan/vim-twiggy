exec "syntax match TwiggyGroup '\\v(^[^\\ " . g:twiggy_icons.current . "]+)'"
highlight default link TwiggyGroup Type

exec "syntax match TwiggyCurrent '\\v%3v" . twiggy#get_current_branch() . "$'"
highlight default link TwiggyCurrent Identifier

exec "syntax match TwiggyCurrent '\\V\\%1c" . g:twiggy_icons.current . "'"
highlight default link TwiggyCurrent Identifier

exec "syntax match TwiggyTracking '\\V\\%2c" . g:twiggy_icons.tracking . "'"
highlight default link TwiggyTracking String

exec "syntax match TwiggyAhead '\\V\\%2c" . g:twiggy_icons.ahead . "'"
highlight default link TwiggyAhead Type

exec "syntax match TwiggyAheadBehind '\\V\\%2c" . g:twiggy_icons.behind . "'"
exec "syntax match TwiggyAheadBehind '\\V\\%2c" . g:twiggy_icons.both . "'"
highlight default link TwiggyAheadBehind Type

exec "syntax match TwiggyDetached '\\V\\%2c" . g:twiggy_icons.detached . "'"
highlight default link TwiggyDetached Type

exec "syntax match TwiggyUnmerged '\\V\\%1c" . g:twiggy_icons.unmerged . "'"
highlight default link TwiggyUnmerged Identifier

syntax match TwiggySortText '\v[[a-z]+]'
highlight default link TwiggySortText Comment

if exists('b:twiggy_branches_not_in_reflog') && len(b:twiggy_branches_not_in_reflog)
    exec "syntax match TwiggyNotInReflog '" .
            \ twiggy#gsub(twiggy#gsub(join(b:twiggy_branches_not_in_reflog), '\(', ''), '\)', '') .
            \ "'"
    highlight default link TwiggyNotInReflog Comment
endif

exec "syntax match TwiggyDetachedText '\\v%3vHEAD:'"
highlight default link TwiggyDetachedText Type

if twiggy#showing_full_ui()
    syntax match TwiggyHelpHint "\v%1l"
    highlight default link TwiggyHelpHint Normal

    syntax match TwiggyHelpHintKey "\v%1l\?"
    highlight default link TwiggyHelpHintKey Identifier
endif
