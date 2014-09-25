# -*- coding: utf-8 ; mode: sh -*-
#
# bash-prompt.sh
# --------------
# Source me for a git-enabled, utf-8, coloured bash prompt and extra functions
# 'shorten' and 'lengthen' for showing the full path or the rightmost
# directory name for the current working directory.
#
# Be sure to source the git-prompt.sh script first!
#
# :authors: Isis Agora Lovecruft 0xa3adb67a2cdb8b35
# :version: 0.1.0
# :license: WTFPL
#

## uncomment for a colored prompt
force_color_prompt=yes
if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	## We have color support; assume it's compliant with Ecma-48
	## (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	## a case would tend to support setf rather than setaf.)
	    color_prompt=yes
    else
	    color_prompt=no
    fi
fi

## Allow git repos to be discovered on other filesystems:
GIT_DISCOVERY_ACROSS_FILESYSTEM=true
export GIT_DISCOVERY_ACROSS_FILESYSTEMS

## If you set GIT_PS1_SHOWDIRTYSTATE to a nonempty
## value, unstaged (*) and staged (+) changes will be shown next
## to the branch name.  You can configure this per-repository
## with the bash.showDirtyState variable, which defaults to true
## once GIT_PS1_SHOWDIRTYSTATE is enabled.
GIT_PS1_SHOWDIRTYSTATE=true

## You can also see if currently something is stashed, by setting
## GIT_PS1_SHOWSTASHSTATE to a nonempty value. If something is stashed,
## then a '$' will be shown next to the branch name.
GIT_PS1_SHOWSTASHSTATE=true

## If you would like to see if there're untracked files, then you can
## set GIT_PS1_SHOWUNTRACKEDFILES to a nonempty value. If there're
## untracked files, then a '%' will be shown next to the branch name.
##
#GIT_PS1_SHOWUNTRACKEDFILES=true

## If you would like to see the difference between HEAD and its
## upstream, set GIT_PS1_SHOWUPSTREAM="auto".  A "<" indicates
## you are behind, ">" indicates you are ahead, and "<>"
## indicates you have diverged.  You can further control
## behaviour by setting GIT_PS1_SHOWUPSTREAM to a space-separated
## list of values:
##     verbose       show number of commits ahead/behind (+/-) upstream
##     legacy        don't use the '--count' option available in recent
##                   versions of git-rev-list
##     git           always compare HEAD to @{upstream}
##     svn           always compare HEAD to your SVN upstream
##     auto          just the '<', '>', or '<>'
## By default, __git_ps1 will compare HEAD to your SVN upstream
## if it can find one, or @{upstream} otherwise.  Once you have
## set GIT_PS1_SHOWUPSTREAM, you can override it on a
## per-repository basis by setting the bash.showUpstream config
## variable.
GIT_PS1_SHOWUPSTREAM="auto"
#GIT_PS1_SHOWUPSTREAM="verbose"

if [ "$color_prompt" = yes ]; then
    if [ $(id -u) != "0" ]; then
        PROMPT_COMMAND='prmcmd=`__git_ps1 "(%s)"`'
        PS1='\[\033[0m\033[32m\]∃!\[\033[33m\]\u\[\033[32m\]Ⓐ\[\033[36m\]\h\[\033[32m\]:\[\033[33m\]$prmcmd\w\[\033[32m\] ∴ \[\033[0m'
    else
        ## If root make the prompt red so that we notice we're in a root shell
        PROMPT_COMMAND='prmcmd=`__git_ps1 "(%s)"`'
        PS1='\[\033[0m\033[32m\]∃!\[\033[33m\]\u\[\033[32m\]Ⓐ\[\033[36m\]\h\[\033[32m\]:\[\033[33m\]$prmcmd\w\[\033[31m\] ∴ \[\033[0m'
    fi
else
    PS1='\[\u@\h:\w\]\$ '
fi

## load the longer prompt
function lengthen () {
    if [ $(id -u) != "0" ]; then
        PROMPT_COMMAND='prmcmd=`__git_ps1 "(%s)"`'
        PS1='\[\033[0m\033[32m\]∃!\[\033[33m\]\u\[\033[32m\]Ⓐ\[\033[36m\]\h\[\033[32m\]:\[\033[33m\]$prmcmd\w\[\033[32m\] ∴ \[\033[0m'
    else
        PROMPT_COMMAND='prmcmd=`__git_ps1 "(%s)"`'
        PS1='\[\033[0m\033[32m\]∃!\[\033[33m\]\u\[\033[32m\]Ⓐ\[\033[36m\]\h\[\033[32m\]:\[\033[33m\]$prmcmd\w\[\033[31m\] ∴ \[\033[0m'
    fi
}

function shorten () {
    if [ $(id -u) != "0" ]; then
        PROMPT_COMMAND='prmcmd=`__git_ps1 "(%s)"`'
        PS1='\[\033[0m\033[32m\]∃!\[\033[33m\]\u\[\033[32m\]Ⓐ\[\033[36m\]\h\[\033[32m\]:\[\033[33m\]$prmcmd\W\[\033[32m\] ∴ \[\033[0m'
    else
        PROMPT_COMMAND='prmcmd=`__git_ps1 "(%s)"`'
        PS1='\[\033[0m\033[32m\]∃!\[\033[33m\]\u\[\033[32m\]Ⓐ\[\033[36m\]\h\[\033[32m\]:\[\033[33m\]$prmcmd\W\[\033[31m\] ∴ \[\033[0m'
    fi
}

PS2='… '
PS3='… '
PS4='… '
unset color_prompt force_color_prompt
