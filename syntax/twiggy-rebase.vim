syntax match TwiggyAttnModeMapping "\v%3c(s|c|a)"
highlight link TwiggyAttnModeMapping Identifier

syntax match TwiggyAttnModeTitle "\v^(rebase|merge|cherry pick) in progress"
highlight link TwiggyAttnModeTitle Type

syntax match TwiggyAttnModeInstruction "\v^from this window:"
highlight link TwiggyAttnModeInstruction String
