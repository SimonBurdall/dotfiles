# ~/.config/bash/wal-prompt.sh
_walp_rgb() {
    local h=${1#\#}
    printf '%d;%d;%d' "$((16#${h:0:2}))" "$((16#${h:2:2}))" "$((16#${h:4:2}))"
}
_walp_fg() { printf '\001\033[38;2;%sm\002' "$(_walp_rgb "$1")"; }
_walp_bg() { printf '\001\033[48;2;%sm\002' "$(_walp_rgb "$1")"; }
_walp_reset=$'\001\033[0m\002'

__set_wal_prompt() {
    local code=$?
    [ -r "$HOME/.cache/wal/colors.sh" ] && . "$HOME/.cache/wal/colors.sh"

    local c_name=${color4:-#81a2be}
    [[ $code -ne 0 ]] && c_name=${color1:-#cc6666}
    local c_path=${color8:-#373b41}
    local c_git=${color2:-#b5bd68}
    local c_dark=${background:-#1d1f21}
    local c_fg=${foreground:-#c5c8c6}

    local sep=$'\ue0b0' gico=$'\ue0a0' icon=$'\uedff'

    # path: leading … plus last component, like the Titus one
    local p=${PWD/#$HOME/\~} short
    if [[ $p == "~" || $p == "/" || $p != */* ]]; then short=$p
    else short="…/${p##*/}"; fi

    # git segment
    local branch gitseg=""
    branch=$(git symbolic-ref --short HEAD 2>/dev/null) \
        || branch=$(git rev-parse --short HEAD 2>/dev/null)
    if [[ -n $branch ]]; then
        local f=""
        git diff --quiet --ignore-submodules 2>/dev/null || f+="!"
        git diff --cached --quiet --ignore-submodules 2>/dev/null || f+="+"
        [[ -n $(git ls-files --others --exclude-standard 2>/dev/null) ]] && f+="?"
        gitseg="$gico $branch${f:+ $f}"
    fi

    local P=""
    P+="$(_walp_bg "$c_name")$(_walp_fg "$c_dark") $icon "
    P+="$(_walp_bg "$c_path")$(_walp_fg "$c_name")$sep"
    P+="$(_walp_fg "$c_fg") $short "
    if [[ -n $gitseg ]]; then
        P+="$(_walp_bg "$c_git")$(_walp_fg "$c_path")$sep"
        P+="$(_walp_fg "$c_dark") $gitseg "
        P+="${_walp_reset}$(_walp_fg "$c_git")$sep"
    else
        P+="${_walp_reset}$(_walp_fg "$c_path")$sep"
    fi
    PS1="\n$P${_walp_reset} "
}

PROMPT_COMMAND=__set_wal_prompt
