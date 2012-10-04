" Name:          guessindent
" Version:       1.0
" Author:        Alex Ogier <alex.ogier.NO@SPAM.gmail.com>
" Updates:       http://github.com/ogier/guessindent
" Purpose:       Guess file indent settings
"
" License:       You may redistribute this plugin under the same terms as Vim
"                itself.
"
" Usage:         :GuessIndent
"
"                " to prefer expandtab to noexpandtab in ambiguous cases:
"                :let g:guessindent_prefer_tabs = 1
"
" Requirements:  Untested on Vim versions below 7.2

if exists("loaded_guessindent")
    finish
endif
let loaded_guessindent = 1

if !exists('g:guessindent_verbosity')
    let g:guessindent_verbosity = 1
endif

fun! <SID>HasCStyleComments()
    return index(["c", "cpp", "java", "javascript", "php"], &ft) != -1
endfun

fun! <SID>IsCommentStart(line)
    " &comments aren't reliable
    return <SID>HasCStyleComments() && a:line =~ '/\*'
endfun

fun! <SID>IsCommentEnd(line)
    return <SID>HasCStyleComments() && a:line =~ '\*/'
endfun

fun! <SID>IsCommentLine(line)
    return <SID>HasCStyleComments() && a:line =~ '^\s\+//'
endfun

fun! <SID>GuessIndent()
    let l:leading_tabs                = 0
    let l:leading_spaces              = 0
    let l:shortest_leading_spaces_run = 0
    let l:shortest_leading_spaces_idx = 0
    let l:longest_leading_spaces_run  = 0
    let l:max_lines                   = 1024
    if exists("g:guessindent_max_lines_to_analyse")
      let l:max_lines = g:guessindent_max_lines_to_analyse
    endif

    let verbose_msg = ''
    if ! exists("b:guessindent_cursettings")
      " remember initial values for comparison
      let b:guessindent_cursettings = {'expandtab': &et, 'shiftwidth': &sw, 'softtabstop': &sts}
    endif

    let l:idx_end = line("$")
    let l:idx = 1
    while l:idx <= l:idx_end
        let l:line = getline(l:idx)

        " try to skip over comment blocks, they can give really screwy indent
        " settings in c/c++ files especially
        if <SID>IsCommentStart(l:line)
            while l:idx <= l:idx_end && ! <SID>IsCommentEnd(l:line)
                let l:idx = l:idx + 1
                let l:line = getline(l:idx)
            endwhile
            let l:idx = l:idx + 1
            continue
        endif

        " Skip comment lines since they are not dependable.
        if <SID>IsCommentLine(l:line)
            let l:idx = l:idx + 1
            continue
        endif

        " Skip lines that are solely whitespace, since they're less likely to
        " be properly constructed.
        if l:line !~ '\S'
            let l:idx = l:idx + 1
            continue
        endif

        let l:leading_char = strpart(l:line, 0, 1)

        if l:leading_char == "\t"
            let l:leading_tabs = l:leading_tabs + 1

        elseif l:leading_char == " "
            " only interested if we don't have a run of spaces followed by a
            " tab.
            if -1 == match(l:line, '^ \+\t')
                let l:leading_spaces = l:leading_spaces + 1
                let l:spaces = strlen(matchstr(l:line, '^ \+'))
                if l:shortest_leading_spaces_run == 0 ||
                            \ l:spaces < l:shortest_leading_spaces_run
                    let l:shortest_leading_spaces_run = l:spaces
                    let l:shortest_leading_spaces_idx = l:idx
                endif
                if l:spaces > l:longest_leading_spaces_run
                    let l:longest_leading_spaces_run = l:spaces
                endif
            endif

        endif

        let l:idx = l:idx + 1

        let l:max_lines = l:max_lines - 1

        if l:max_lines == 0
            let l:idx = l:idx_end + 1
        endif

    endwhile

    if l:leading_spaces || l:leading_tabs
        let l:verbose_msg = "Detected leading whitespace"

        if l:leading_tabs >= 3 * l:leading_spaces
            setl noexpandtab
            let &l:softtabstop = 0
        elseif l:leading_tabs >= 0.33 * l:leading_spaces &&
                \ exists("g:guessindent_prefer_tabs")
            setl noexpandtab
            let &l:softtabstop = 0
        else
            setl expandtab
            let &l:shiftwidth  = l:shortest_leading_spaces_run
            let &l:softtabstop = l:shortest_leading_spaces_run
        endif

    else
        let l:verbose_msg = "Detected no spaces and no tabs"
    endif

    if &verbose >= g:guessindent_verbosity
        echo l:verbose_msg
                    \ ."; leading_tabs:" l:leading_tabs
                    \ .", leading_spaces:" l:leading_spaces
                    \ .", shortest_leading_spaces_run:" l:shortest_leading_spaces_run
                    \ .", shortest_leading_spaces_idx:" l:shortest_leading_spaces_idx
                    \ .", longest_leading_spaces_run:" l:longest_leading_spaces_run

        let changed_msg = []
        for [setting, oldval] in items(b:guessindent_cursettings)
          exec 'let newval = &'.setting
          if oldval != newval
            let changed_msg += [ setting." changed from ".oldval." to ".newval ]
          end
        endfor
        if len(changed_msg)
          echo "Initial buffer settings changed:" join(changed_msg, ", ")
        endif
    endif
endfun

command! -bar -nargs=0 GuessIndent call <SID>GuessIndent()

