# fish/config.fish - Interactive Fish configuration for development environment.
#
# Mirrors the environment setup in .zshrc (Node/NVM, pnpm, pyenv, PATH) and the
# directory/git macros, expressed fish-natively. Symlinked to
# ~/.config/fish/config.fish by lib/fish.sh.
#
# Fish is a supported-but-secondary shell here: zsh remains the login shell.
# Anything machine-specific belongs in ~/.config/fish/conf.d/, not this file.

# ------------------------------------------------------------------ #
#  Distro defaults (optional, present on CachyOS and friends)
# ------------------------------------------------------------------ #

for _distro_config in /usr/share/cachyos-fish-config/cachyos-config.fish
    test -r $_distro_config; and source $_distro_config
end
set -e _distro_config

# ------------------------------------------------------------------ #
#  Node / NVM
#
#  nvm is a bash/zsh shell *function*, so fish cannot source nvm.sh. Instead
#  put the bin directory of nvm's default version straight onto PATH. Node,
#  npm and every npm global (pnpm, ni, diff-so-fancy) then resolve in fish.
#  Version switching stays a zsh concern; fish follows whatever nvm's
#  "default" alias points at.
# ------------------------------------------------------------------ #

set -gx NVM_DIR $HOME/.nvm

# Follow an nvm alias chain to a concrete version.
# e.g. default -> lts/* -> lts/krypton -> v24.18.0
function _nvm_resolve_alias --description 'Resolve an nvm alias to a version'
    set -l name $argv[1]
    # Bounded so a self-referential alias cannot spin forever.
    for _hop in (seq 5)
        set -l file "$NVM_DIR/alias/$name"
        test -r $file; or break
        set name (string trim (cat $file))
    end
    echo $name
end

# Print the node bin directory fish should use, or return 1 if there is none.
function _nvm_bin_dir --description 'Best nvm-managed node bin directory'
    set -l root "$NVM_DIR/versions/node"
    test -d $root; or return 1

    set -l want (_nvm_resolve_alias default)
    if test -n "$want" -a -d "$root/$want/bin"
        echo "$root/$want/bin"
        return 0
    end

    # No usable default alias — fall back to the newest installed version.
    set -l newest (basename -a $root/v* 2>/dev/null | sort -V | tail -n1)
    if test -n "$newest" -a -d "$root/$newest/bin"
        echo "$root/$newest/bin"
        return 0
    end

    return 1
end

set -l _node_bin (_nvm_bin_dir)
test -n "$_node_bin"; and fish_add_path -gp $_node_bin

# ------------------------------------------------------------------ #
#  Environment / PATH  (kept in step with .zshrc)
# ------------------------------------------------------------------ #

# pnpm's own global bin dir (separate from npm globals above).
set -gx PNPM_HOME $HOME/.local/share/pnpm
test -d $PNPM_HOME; and fish_add_path -gp $PNPM_HOME

# Homebrew (Linux)
if test -x /home/linuxbrew/.linuxbrew/bin/brew
    /home/linuxbrew/.linuxbrew/bin/brew shellenv | source
end

# pyenv
set -gx PYENV_ROOT $HOME/.pyenv
test -d $PYENV_ROOT/bin; and fish_add_path -gp $PYENV_ROOT/bin
if command -q pyenv
    pyenv init - fish | source
end

# Google Cloud SDK
test -d $HOME/google-cloud-sdk/bin; and fish_add_path -gp $HOME/google-cloud-sdk/bin

# Composer
test -d $HOME/.composer/vendor/bin; and fish_add_path -gp $HOME/.composer/vendor/bin

fish_add_path -gp $HOME/.local/bin

# Ubuntu ships bat as batcat; expose it under the conventional name.
if not command -q bat; and command -q batcat
    function bat --wraps batcat --description 'bat (Ubuntu ships it as batcat)'
        batcat $argv
    end
end

# ================================================================== #
#  Macros (fish-native)
#  Ported from a zsh/oh-my-zsh rc. Modernized for Linux + Wayland.
#  - hub -> git/gh          (hub is unmaintained)
#  - pbcopy -> wl-copy      (macOS -> Wayland, with fallbacks)
#  - diff-so-fancy -> delta (with graceful fallback)
#  - origin/master -> auto-detected default branch
# ================================================================== #

# ------------------------------------------------------------------ #
#  Helpers (guarded so nothing explodes when a tool is missing)
# ------------------------------------------------------------------ #

# Copy stdin to the system clipboard, whatever this box happens to have.
function clip --description 'Pipe stdin to the system clipboard'
    if command -q wl-copy
        wl-copy
    else if command -q xclip
        xclip -selection clipboard
    else if command -q xsel
        xsel --clipboard --input
    else if command -q pbcopy
        pbcopy
    else
        echo "clip: no clipboard tool found (install wl-clipboard)" >&2
        return 1
    end
end

# Fancy diff pager: delta > diff-so-fancy > plain colored less.
function _diff_pager --description 'Best available diff pager'
    if command -q delta
        delta
    else if command -q diff-so-fancy
        diff-so-fancy | less --tabs=4 -RFX
    else
        less -RFX
    end
end

# Print the repo's default branch (remote HEAD, else main/master, else main).
function git_default_branch --description 'Detect the default branch name'
    set -l ref (git symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null)
    if test -n "$ref"
        string replace refs/remotes/origin/ '' -- $ref
        return
    end
    for b in main master
        if git show-ref --verify --quiet refs/heads/$b
            echo $b
            return
        end
    end
    echo main
end

# ------------------------------------------------------------------ #
#  Node Package Manager  (https://github.com/antfu-collective/ni)
#  Abbreviations expand inline so you always see/edit the real command.
# ------------------------------------------------------------------ #
if status is-interactive
    abbr -a pn pnpm
    abbr -a nio 'ni --prefer-offline'
    abbr -a s 'nr start'
    abbr -a d 'nr dev'
    abbr -a b 'nr build'
    abbr -a bw 'nr build --watch'
    abbr -a t 'nr test'
    abbr -a tu 'nr test -u'
    abbr -a tw 'nr test --watch'
    abbr -a w 'nr watch'
    abbr -a p 'nr play'
    abbr -a c 'nr typecheck'
    abbr -a lint 'nr lint'
    abbr -a lintf 'nr lint --fix'
    abbr -a release 'nr release'
    abbr -a re 'nr release'

    # ---------------------------------------------------------------- #
    #  Git
    # ---------------------------------------------------------------- #
    abbr -a gs 'git status'
    abbr -a gp 'git push'
    abbr -a gpf 'git push --force-with-lease' # was --force; --force-with-lease is safer
    abbr -a gpft 'git push --follow-tags'
    abbr -a gpl 'git pull --rebase'
    abbr -a gcl 'git clone'
    abbr -a gst 'git stash'
    abbr -a grm 'git rm'
    abbr -a gmv 'git mv'

    abbr -a gco 'git checkout'
    abbr -a gcob 'git checkout -b'
    abbr -a gsw 'git switch' # modern checkout for branches
    abbr -a gswc 'git switch -c'

    abbr -a gb 'git branch'
    abbr -a gbd 'git branch -d'

    abbr -a grb 'git rebase'
    abbr -a grbc 'git rebase --continue'
    abbr -a grba 'git rebase --abort'

    abbr -a gl 'git log'
    abbr -a glo 'git log --oneline --graph --decorate'

    abbr -a grh 'git reset HEAD'
    abbr -a grh1 'git reset HEAD~1'

    abbr -a ga 'git add'
    abbr -a gA 'git add -A'

    abbr -a gc 'git commit'
    abbr -a gcm 'git commit -m'
    abbr -a gca 'git commit -a'

    abbr -a ghci 'gh run list -L 1'
end

# --- Git: functions (need arguments or logic) --- #

# Go to the repo root.
function grt --description 'cd to the git repo root'
    cd (git rev-parse --show-toplevel)
end

# Checkout the default branch (main/master, auto-detected).
function main --description 'Checkout the default branch'
    git checkout (git_default_branch)
end

# Add everything and commit with a message.
function gcam --description 'git add -A && git commit -m'
    git add -A; and git commit -m $argv
end

# Rebase onto the up-to-date default branch.
function grbm --description 'Rebase onto origin/<default-branch>'
    set -l base (git_default_branch)
    git rebase origin/$base
end

# Fetch then rebase onto the default branch.
function gfrb --description 'Fetch origin then rebase onto the default branch'
    set -l base (git_default_branch)
    git fetch origin; and git rebase origin/$base
end

# Copy the current commit SHA to the clipboard.
function gsha --description 'Copy HEAD sha to clipboard'
    git rev-parse HEAD | clip
end

# Dry-run / actual clean.
function gxn --description 'git clean dry-run'
    git clean -dn $argv
end
function gx --description 'git clean (force)'
    git clean -df $argv
end

# git log, last N commits, no pager (default 10).
function glp --description 'git log -N, no pager (default 10)'
    set -l n $argv[1]
    test -z "$n"; and set n 10
    git --no-pager log -n $n
end

# Fancy working-tree diff.
function gd --description 'git diff through a fancy pager'
    git diff --color=always $argv | _diff_pager
end

# Fancy staged diff.
function gdc --description 'git diff --cached through a fancy pager'
    git diff --color=always --cached $argv | _diff_pager
end

# ------------------------------------------------------------------ #
#  GitHub (gh)
# ------------------------------------------------------------------ #

# `pr ls` lists PRs; `pr <n>` checks one out.
function pr --description 'gh pr checkout <n>, or "pr ls" to list'
    if not command -q gh
        echo "pr: gh (GitHub CLI) is not installed" >&2
        return 1
    end
    if test "$argv[1]" = ls
        gh pr list
    else
        gh pr checkout $argv
    end
end

# ------------------------------------------------------------------ #
#  Directory navigation
#    ~/development  main working tree
#    ~/projects     personal projects
#    ~/repros       reproductions
#    ~/forks        forks
#  These names match .zshrc and the directories lib/zsh.sh creates.
# ------------------------------------------------------------------ #

# Define <name> as a function that cds to ~/<name>[/<subdir>].
function _dotfiles_define_nav --description 'Define a workspace nav function'
    set -l name $argv[1]
    function $name --inherit-variable name \
        --description "cd to ~/$name or a subdirectory within it"
        if test -n "$argv[1]"
            cd $HOME/$name/$argv[1]
        else
            cd $HOME/$name
        end
    end
end

for _nav in development projects repros forks
    _dotfiles_define_nav $_nav
end
set -e _nav

# mkdir (incl. parents) then cd into it.
function dir --description 'mkdir -p then cd into it'
    if test -z "$argv[1]"
        echo 'usage: dir <new-dir>' >&2
        return 2
    end
    mkdir -p -- $argv[1]; and cd $argv[1]
end

# Clone a repo with gh, then cd into it. `clone <repo> [dir]`.
function clone --description 'gh repo clone then cd into the repo'
    if test -z "$argv[1]"
        echo 'usage: clone <repo> [dir]' >&2
        return 2
    end
    gh repo clone $argv; or return 1
    if test -n "$argv[2]"
        cd $argv[2]
    else
        cd (basename $argv[1] .git)
    end
end

# Clone into a workspace dir, open in VS Code, then return to where you were.
function _clone_into --description 'Clone into a workspace dir, open, return'
    set -l target $argv[1]
    set -l origin $PWD
    $target; and clone $argv[2..-1]; and code .
    cd $origin
end

function cloned --description 'Clone into ~/development, open in VS Code, return'
    _clone_into development $argv
end
function clonep --description 'Clone into ~/projects, open in VS Code, return'
    _clone_into projects $argv
end
function cloner --description 'Clone into ~/repros, open in VS Code, return'
    _clone_into repros $argv
end
function clonef --description 'Clone into ~/forks, open in VS Code, return'
    _clone_into forks $argv
end

# Open a project in ~/development with VS Code, then return.
function coded --description 'Open ~/development/<project> in VS Code, then return'
    set -l origin $PWD
    development; and code $argv
    cd $origin
end

# ------------------------------------------------------------------ #
#  Serve a directory over HTTP (live reload if available, else fall back).
# ------------------------------------------------------------------ #
function serve --description 'Serve a directory over http'
    set -l dir dist
    test -n "$argv[1]"; and set dir $argv[1]
    if command -q live-server
        live-server $dir
    else if command -q npx
        npx --yes serve $dir
    else
        python3 -m http.server --directory $dir
    end
end

# ------------------------------------------------------------------ #
#  Local overrides (untracked, mirrors ~/.zshrc.local)
# ------------------------------------------------------------------ #
test -r $HOME/.config/fish/config.local.fish; and source $HOME/.config/fish/config.local.fish
