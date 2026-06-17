# ~/.config/bash/wal-prompt.sh
export VIRTUAL_ENV_DISABLE_PROMPT=1   # stop venv activate fighting our prompt
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
    local c_venv=${color5:-#b294bb}
    local c_dark=${background:-#1d1f21}
    local c_fg=${foreground:-#c5c8c6}
    local sep=$'\ue0b0' gico=$'\ue0a0' icon=$'\uedff' pyico=$'\ue73c'
    # path: leading … plus last component
    local p=${PWD/#$HOME/\~} short
    if [[ $p == "~" || $p == "/" || $p != */* ]]; then short=$p
    else short="…/${p##*/}"; fi
    # python venv (basename of $VIRTUAL_ENV)
    local venv=""
    [[ -n $VIRTUAL_ENV ]] && venv="${VIRTUAL_ENV##*/}"
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
    local P="" last
    # user segment (always first now)
    P+="$(_walp_bg "$c_name")$(_walp_fg "$c_dark") $icon "
    P+="$(_walp_bg "$c_path")$(_walp_fg "$c_name")$sep"
    # path segment
    P+="$(_walp_fg "$c_fg") $short "
    last=$c_path
    # venv segment, if active
    if [[ -n $venv ]]; then
        P+="$(_walp_bg "$c_venv")$(_walp_fg "$last")$sep"
        P+="$(_walp_fg "$c_dark") $pyico $venv "
        last=$c_venv
    fi
    # git segment, if present
    if [[ -n $gitseg ]]; then
        P+="$(_walp_bg "$c_git")$(_walp_fg "$last")$sep"
        P+="$(_walp_fg "$c_dark") $gitseg "
        last=$c_git
    fi
    P+="${_walp_reset}$(_walp_fg "$last")$sep"
    PS1="\n$P${_walp_reset} "
}
PROMPT_COMMAND=__set_wal_prompt
