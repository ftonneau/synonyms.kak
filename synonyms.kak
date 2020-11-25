# Find synonyms of a word in a MyThes thesaurus.
# Author: Francois Tonneau

# This script assumes that the MyThes thesauri (or symbolic links to them) are
# installed in a 'synonyms' subdirectory of $HOME/.config/kak/

# PUBLIC OPTION

declare-option \
-docstring 'Character class to skip at word start. Default is [-_*"''`({[<]' \
str synonyms_skip [-_*"'`({[<]

# PRIVATE VARIABLES

declare-option -hidden str synonyms_path synonyms
declare-option -hidden str synonyms_file ''

declare-option -hidden str synonyms_word ''

# PUBLIC COMMANDS

define-command \
-docstring 'synonyms-set-thesaurus <thesaurus>: choose synonym book' \
-params 1 \
-shell-script-candidates %{
    path=$kak_config'/'$kak_opt_synonyms_path
    find -L "$path"  -mindepth 1 -maxdepth 1 -type f -name '*\.dat' \
    | sed -e 's,^.*/,,' -e 's,\.dat$,,' \
    | sort
} \
synonyms-set-thesaurus %{
    evaluate-commands %sh{
        file=$kak_config'/'$kak_opt_synonyms_path'/'$1.dat
        if  [ -f "$file" ] && [ -r "$file" ]; then
            printf %s\\n "set-option window synonyms_file $file"
        else
            printf %s\\n 'fail cannot access thesaurus'
        fi
    }
}

define-command \
-docstring 'synonyms-enable-on <key>: find synonym with <key>' \
-params 1 \
synonyms-enable-on %{
    try %{
        remove-hooks global synonyms
    }
    hook -group synonyms global InsertKey %arg(1) %{
        synonyms-call-menu insert
    }
}

define-command \
-docstring 'Disable synonym finding' \
synonyms-disable %{
    remove-hooks global synonyms
}

define-command \
-docstring 'Replace selection(s) with synonym (in Normal mode)' \
synonyms-replace-selection %{
    synonyms-call-menu normal
}

alias global syr synonyms-replace-selection

# IMPLEMENTATION

define-command \
-hidden \
-params 1 \
synonyms-call-menu %{
    #
    # Arg = mode (insert or normal).
    evaluate-commands synonyms-read-word %arg(1)
    evaluate-commands %sh{
        mode=$1
        word=$kak_opt_synonyms_word
        [ ! "$word" ] && exit
        file=$kak_opt_synonyms_file
        [ ! "$file" ] && printf %s\\n 'echo thesaurus not set' && exit
        #
        entries=$(grep -i -n "^$word|" "$file" 2>/dev/null)
        [ ! "$entries" ] && exit
        #
        if [ "$mode" = insert ]; then
            #
            # Help undoing word replacement by committing changes. Then clean
            # commit message.
            printf %s\\n 'execute-keys <c-u>'
            printf %s\\n echo
        fi
        #
        printf %s 'menu -- '
        printf %s\\n "$entries" | while read entry; do
            head=${entry%%:*}
            count=${entry##*|}
            #
            # Select item lines, remove ...-| headers and parenthetical notes,
            # replace braces with ! for string safety, and build menu content.
            sed -n "$((head + 1)),$((head + count))p" "$file" \
            | \
            sed -e 's,^[^|]*|,,' -e 's, *([^()]*) *,,g' -e 's,[{}],!,g' \
            | tr '|' '\n' \
            | sort \
            | uniq \
            | awk -v mode="$mode" '
                {
                    printf "%%{%s} ", $0
                    printf "%%{synonyms-do-replacement %s %%{%s}} ", mode, $0
                }
            '
        done
    }
}

define-command \
-hidden \
-params 1 \
synonyms-read-word %{
    #
    # Arg = mode (insert or normal).
    set-option window synonyms_word ''
    evaluate-commands -draft %{
        evaluate-commands "synonyms-adjust-selection-%arg(1)"
        set-option window synonyms_word %val(selection)
    }
}

define-command \
-hidden \
synonyms-adjust-selection-insert %{
    try %{
        execute-keys <a-h>
        execute-keys 1 s %opt(synonyms_skip)* (\S+?) \s* \z <ret>
    }
}

define-command \
-hidden \
synonyms-adjust-selection-normal %{
    nop
}

define-command \
-hidden \
-params 2 \
synonyms-do-replacement %{
    #
    # Args: 1 = mode, 2 = replacement.
    evaluate-commands -save-regs x -draft %{
        evaluate-commands "synonyms-adjust-selection-%arg(1)"
        set-register x %arg(2)
        execute-keys %{"} x R
    }
}

