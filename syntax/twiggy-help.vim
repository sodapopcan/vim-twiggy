syntax match TwiggyQuickhelpMapping "\v%<7c[A-Za-z\-\?\^\<\>!,]"
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
