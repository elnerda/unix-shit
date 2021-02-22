#!/bin/bash

# commands common to all interactive invocations of bash:

_TimeStamp_="Mittwoch, 19.9.2018 15:05:00"

_debug=1
unset _debug

# fuer den ESX-Server
# Source global definitions
if [ -f /etc/bashrc ]; then
        . /etc/bashrc
fi

#fuer den VIO-Server (AIX LPAR)
test "$USER" = "padmin" &&  test -r ~/.profile && . ~/.profile
test "$USER" = "root" && { 
	eval HOME=~$USER; 
	test -n "$SUDO_USER" && eval /bin/cp -f ~$SUDO_USER/.Xauthority $HOME/;
	cd $HOME;
}

# Funktion zum Setzen von Variablen im Stil von PATH mittels einer Liste
# ein Element pro Zeile
# Zeile kann leer, eingerueckt oder auskommentiert sein
#
# erhaelt zwei Parameter
# - Name der Variablen
# - optional eine "1", wenn die Existenz des Elements als Directory getestet werden soll

function _addtopath () {
local pathvar="$1"
local check="$2"		# check existence in case of a path
local item;

	function _isvalid () {
        test $# -gt 0 && echo $@ | grep -v '^[ \t]*#\|^$' >/dev/null;
	}

	while read item; do
		_isvalid "$item" || continue	# if it's a comment or a blank line
		test "$check" = "1" && test -d "$item" || continue	# if path does not exist
		if eval test -n \"\$$pathvar\"; then
			eval echo \$$pathvar | tr ':' '\n' | grep "^$item$" >/dev/null || eval $pathvar=\$$pathvar:"$item";
		else
			eval $pathvar="$item";
		fi
	done 
}


_addtopath PATH 1 <<-EOF
	/usr/bin
	/usr/sbin
	/opt/bin
	/opt/sfw/bin
	/opt/freeware/bin
	/opt/freeware/sbin
	/usr/openwin/bin
	/usr/local/bin
	/usr/local/sbin
	/usr/dt/bin
	/usr/sysadm/bin
	/usr/ccs/bin
	/usr/lib/qt3/bin
	/opt/kde3/bin
	/usr/ucb
	$HOME/bin
EOF

export LESSOPEN=${LESSOPEN:-lessopen.sh %s}
export LESSCLOSE=${LESSCLOSE:-lessclose.sh %s %s}

OSname=`/bin/uname -s`
OSversion=`/bin/uname -r`

case "$OSname" in

	AIX)	TAPE=/dev/rmt0.1; export TAPE
		alias top='top $(($LINES - 6))'
		OSversion=`/bin/uname -v`."$OSversion"
		function _lsallvg () {
			for vg in $(lsvg); do
				echo ---- $vg -----;
				/usr/sbin/lsvg $vg; echo;
				/usr/sbin/lsvg -p $vg; echo;
				/usr/sbin/lsvg -l $vg; echo;
			done
		}
		;;

	HP-UX)	_addtopath SHLIB_PATH 1 <<-EOF
			/usr/local/prostep/HPU/bin
EOF
		TAPE=/dev/rmt/0n; export TAPE
		;;

	IRIX*)	alias hostname='hostname -s'
		;;

	Linux|CYGWIN*)	test -z "$PROFILEREAD" && . /etc/profile

		# try to set DISPLAY smart
		if test -z "$DISPLAY" -a "$TERM" = "xterm" -a -x /bin/hostname; then
			HOST="$(/bin/hostname -f)"
			_DISPLAY="${HOST}:0.0"
			if [ "${_DISPLAY}" == ":0:0.0" -o "${_DISPLAY}" == " :0.0" ]; then
				_DISPLAY=":0.0"
			fi
			DISPLAY="$_DISPLAY"
			export DISPLAY
			unset HOST _DISPLAY
		fi
		TAPE=/dev/nst0; export TAPE

#		# Virtuelle Maschinen brauchen keinen Bildschirmschoner
#  gibt eine Fehlermeldung ab SLES12
#		tty -s && test -x /sbin/lspci && /sbin/lspci | grep -qi vmware && setterm -blank 0

		export QT_GRAPHICSSYSTEM=native

 		;;

	SunOS)	TAPE=/dev/rmt/0n; export TAPE
		alias df='/usr/ucb/df'
		alias top='top $(($LINES - 6))'
		_addtopath MANPATH 1 <<-EOF
			/usr/share/man
			/usr/dt/share/man
			/usr/openwin/share/man
			/usr/local/man
			/usr/local/ssl/man
			/opt/sfw/man
			"$HOME"/man
			/opt/SUNWconn/HSIP/man
			/opt/SUNWconn/atm/man
			/opt/SUNWconn/man
			/opt/SUNWrtvc/man
			/opt/SUNWvts/man
			/usr/apache/man
			/usr/java1.2/man
			/usr/perl5/5.00503/man
			/usr/perl5/5.6.1/man
			/usr/sfw/share/man
EOF
		export MANPATH
		;;
esac


# Das folgende wird nur fuer nicht-lokale, also NIS-Benutzer ausgefuehrt.
# unter anderem, damit ein root-Login nicht daran scheitert, dass die
# NFS-Shares nicht verfuegbar sind...

grep "^$LOGNAME:" /etc/passwd >/dev/null || { 

UsePSPath=1
#unset UsePSPath

case "$OSname" in

	AIX)	v=`/bin/uname -v`
		case "$v" in
		4)
			PSPath=/usr/local/prostep/AIX/bin
			;;
		5|6|7)
			PSPath=/usr/local/prostep/AIX${v}/bin
			;;
		*)
			PSPath=/usr/local/prostep/AIX/bin
			echo -e "Fehler: Unbekannte Version \"$v\"! Erkannt werden: 4.x, 5.x, 6.x, 7.x\nPSPath wird gesetzt auf \"$PSPath\"" 1>&2
			;;
		esac
		;;
	
	HP-UX)
		v=`echo $OSversion | /usr/bin/cut -d "." -f 2`
	
		case "$v" in
		10|11)
			PSPath="/usr/local/prostep/HPU/bin"
			;;
		*)
			echo -e "Fehler: Unbekannte Version \"$OSversion\"! Erkannt werden: 10.x, 11.x" 1>&2
			;;
		esac
		;;
	
	IRIX*)
		alias hostname='hostname -s'
		PSPath=/usr/local/prostep/IRIX/bin
		;;
	
	Linux|CYGWIN*)
		PSPath=/usr/local/prostep/Linux/bin
	
		function _anwesend () {
			pushd "$HOME" >/dev/null
			local AWLOGFILE=".anwesend.log"
			if [ -z "$DISPLAY" -a -w "$AWLOGFILE" ] ; then
				local AWDONE=`find . -maxdepth 1 -name $AWLOGFILE -daystart -mtime 0`
				if [ ! "$AWDONE" ]; then
					while true ; do
						unset REPLY;
						read -p "Eintrag in Logfile? [j/n] " $REPLY;
						REPLY=`echo $REPLY | tr "jJyYnN" "yyyynn"`;
						if [ "$REPLY" == "y" -o "$REPLY" == "n" ]; then
							break;
						fi
					done
					if [ "$REPLY" == "y" ]; then
						date >>"$AWLOGFILE";
					fi
					unset REPLY
				fi
			fi
			popd >/dev/null
		}

# _anwesend blockiert scp, wenn Loginshell bash ist.
#		_anwesend;
		;;
	
	SunOS)
		v=`echo $OSversion | /usr/bin/cut -d "." -f 1`
		case "$v" in
		5)
			PSPath=/usr/local/prostep/SOL/bin
			;;
		*)
			PSPath=/usr/local/prostep/SOL/bin
			echo -e "Fehler: Unbekannte Version \"$OSversion\"! Erkannt wird: 5.x\nPSPath gesetzt auf \"$PSPath\"" 1>&2
			;;
		esac
		;;
	
	*)
		echo "Unbekannte Plattform \"$OSname\"! Erkannt werden: AIX, HP-UX, IRIX, Linux, SunOS"
		status=1
		[ "$_debug" ] || exit 1
		;;
	esac

if [ -d "$PSPath" ]; then
	export PSPath;
	[ "$UsePSPath" ] && [ "$UID" != "0" ] && _addtopath PATH 1 <<-EOF
		$PSPath
EOF
else
	[ "$_debug" ] && echo \"$PSPath\" existiert nicht.
	unset PSPath
fi

}

function _debuginfo () {
	/bin/uname -a
	echo "OSname: $OSname Version: $OSversion  bashrc-Version: $_TimeStamp_"
	case "$OSname" in
		Linux)
		find -L /etc/products.d/baseproduct -type f -exec sed -ne '/<shortsummary>.*[vV][mM]ware/s/<[/]*shortsummary>//gp;' {} \; 2> /dev/null;
		LinuxVersion=$(find -L /etc/ -maxdepth 1 -name "*release" ! -name "lsb-release" ! -name "os-release" ! -name "vma-release" -type f -exec egrep -v '(^#)|(^$)|(ANSI)|(URL)|((CPE_)|(CODE)NAME)|(ID)|(^VERSION)|(^NAME)|(^PRETTY_NAME)|^(CENTOS)|^(REDHAT)' {} \;)
		test -z "$LinuxVersion" && LinuxVersion=$(find -L /etc/ -maxdepth 1 -name issue -type f -exec sed -e "s/\\\r/name -r/g; s/\\\m/name -m/g; s/\\\[ln]//g" {} \; 2> /dev/null)
		test -f /etc/os-release && { source /etc/os-release; LinuxVersion=$PRETTY_NAME; }
		echo "$LinuxVersion"
		;;
	esac
	if  [ "$UsePSPath"X = "1"X ]; then echo PSPath: $PSPath; fi
}

[ "$_debug" ] && _debuginfo

#[ -n "TEMP" ] && [ -w /tmp/ ] && TEMP=/tmp; export TEMP

HISTCONTROL=ignoreboth; export HISTCONTROL
HISTSIZE=30000; export HISTSIZE
HISTFILESIZE=$HISTSIZE
HISTTIMEFORMAT='%F %H:%M:%S '; export HISTTIMEFORMAT;

test ${BASH_VERSINFO[0]} -gt 4 && {
	test ${BASH_VERSINFO[0]} -eq 4 -a ${BASH_VERSINFO[1]} -eq 2 || shopt -s direxpand
}

[ -d /usr/local/doc/.TeX ] && {
TEXINPUTS="$TEXINPUTS:/usr/local/doc/.TeX"; export TEXINPUTS
}


function _sshsetup {
	ssh-add -L 2>/dev/null || {
		type -p ssh-agent && eval $(ssh-agent);
		test -f ~/.ssh/id_dsa -o -f ~/.ssh/id_rsa && ssh-add;
	}
}

if type -p less >/dev/null 2>&1; then
	LESS="-iaqSMj20"; export LESS
	LESSBINFMT='*d[%x]'; export LESSBINFMT
	case $LANG in
		*UTF8) LESSCHARSET=utf-8; export LESSCHARSET;
		;;
	esac
	PAGER=less;
else
	PAGER=more;
fi
export PAGER;

# Redefine F11 and F12 for readline library (used by bash and gnu tools!),
# but don't overwrite existing .inputrc

INPUTRC="$HOME"/.inputrc

[ -f "$INPUTRC" ] || {
cat <<-EOF
################################################################################
## /etc/inputrc
##
## Attempt to put different TERMs together in one readline init file.
## Copyright (c) 1997,2000,2002 SuSE Linux AG, Nuernberg, Germany.
##
## Author: Werner Fink,  <feedback@suse.de>
##
################################################################################
#
# Eight bit compatible: Umlaute
#
set meta-flag on
set output-meta on
set convert-meta off
#set term xy
#
# VI line editing
#
\$if mode=vi
set editing-mode vi
set keymap vi
\$endif
#
# Common standard keypad and cursor
#
"\e[1~":	beginning-of-line
"\e[2~":	yank
"\e[3~":	delete-char
"\e[4~":	end-of-line
"\e[5~":	history-search-backward
"\e[6~":	history-search-forward
\$if term=xterm
"\e[2;2~":	yank
"\e[3;2~":	delete-char
"\e[5;2~":	history-search-backward
"\e[6;2~":	history-search-forward
"\e[2;5~":	yank
"\e[3;5~":	delete-char
"\e[5;5~":	history-search-backward
"\e[6;5~":	history-search-forward
\$endif
"\e[C":		forward-char
"\e[D":		backward-char
"\e[A":		previous-history
"\e[B":		next-history
\$if term=xterm
"\e[E":		re-read-init-file
"\e[2C":	forward-word
"\e[2D":	backward-word
"\e[2A":	history-search-backward
"\e[2B":	history-search-forward
"\e[5C":	forward-word
"\e[5D":	backward-word
"\e[5A":	history-search-backward
"\e[5B":	history-search-forward
\$else
"\e[G":		re-read-init-file
\$endif
#
# Avoid network problems
#   ... \177 (ASCII-DEL) and \010 (ASCII-BS)
#       do 'backward-delete-char'
# Note: 'delete-char' is mapped to \033[3~
#       Therefore xterm's response on pressing
#       key Delete or KP-Delete should be
#       \033[3~ ... NOT \177
#
"\C-?":		backward-delete-char
"\C-H":		backward-delete-char
#
# Home and End
#
\$if term=xterm
#
# Normal keypad and cursor of xterm
"\e[1~":	history-search-backward
"\e[4~":	set-mark
"\e[H":		beginning-of-line
"\e[F":		end-of-line
"\e[2H":	beginning-of-line
"\e[2F":	end-of-line
"\e[5H":	beginning-of-line
"\e[5F":	end-of-line
# Home and End of application keypad and cursor of xterm
"\eOH":		beginning-of-line
"\eOF":		end-of-line
"\eO2H":	beginning-of-line
"\eO2F":	end-of-line
"\eO5H":	beginning-of-line
"\eO5F":	end-of-line
\$else
\$if term=kvt
"\e[1~":	history-search-backward
"\e[4~":	set-mark
"\eOH":		beginning-of-line
"\eOF":		end-of-line
\$endif
#
# TERM=linux or console or gnome
#
"\e[1~":	beginning-of-line
"\e[4~":	end-of-line
\$endif
#
# Application keypad and cursor of xterm
#
\$if term=xterm
"\eOD":         backward-char
"\eOC":         forward-char
"\eOA":         previous-history
"\eOB":         next-history
"\eOE":         re-read-init-file
"\eO2D":        backward-word
"\eO2C":        forward-word
"\eO2A":        history-search-backward
"\eO2B":        history-search-forward
"\eO5D":        backward-word
"\eO5C":        forward-word
"\eO5A":        history-search-backward
"\eO5B":        history-search-forward
# DEC keyboard KP_F1 - KP_F4 or
# XTerm of XFree86 in VT220 mode F1 - F4
"\eOP":		prefix-meta
"\eOQ":		undo
"\eOR":		""  
"\eOS":		kill-line
\$endif
\$if term=gnome
# or gnome terminal F1 - F4
"\eOP":		prefix-meta
"\eOQ":		undo
"\eOR":		""
"\eOS":		kill-line
\$endif
#
# Function keys F1 - F12
#
\$if term=linux
#
# On console the first five function keys
#
"\e[[A":	prefix-meta
"\e[[B":	undo
"\e[[C":	""
"\e[[D":	kill-line
"\e[[E":	""
\$else
#
# The first five standard function keys
#
"\e[11~":	prefix-meta
"\e[12~":	undo
"\e[13~":	""
"\e[14~":	kill-line
"\e[15~":	""
\$endif
"\e[17~":	""
"\e[18~":	""
"\e[19~":	""
"\e[20~":	""
"\e[21~":	" | column -t "
# Note: F11, F12 are identical with Shift_F1 and Shift_F2
"\e[23~":	" 2>&1 | \$PAGER;"
"\e[24~":	" 2>/dev/null "
#
# Shift Function keys F1  - F12
#      identical with F11 - F22
#
#"\e[23~":	""
#"\e[24~":	""
"\e[25~":	" >/dev/console 2>&1 & "
"\e[26~":	" 2>&1 | logger & "
# DEC keyboard: F15=\e[28~ is Help
"\e[28~":	""
# DEC keyboard: F16=\e[29~ is Menu
"\e[29~":	""
"\e[31~":	""
"\e[32~":	""
"\e[33~":	""
"\e[34~":	""
\$if term=xterm
# Not common
"\e[35~":	""
"\e[36~":	""
\$endif
#
\$if term=xterm
#
# Application keypad and cursor of xterm
# with NumLock ON
#
# Operators
"\eOo":		"/"
"\eOj":		"*"
"\eOm":		"-"
"\eOk":		"+"
"\eOl":		","
"\eOM":		accept-line
"\eOn":		"."
# Numbers
"\eOp":		"0"
"\eOq":		"1"
"\eOr":		"2"
"\eOs":		"3"
"\eOt":		"4"
"\eOu":		"5"
"\eOv":		"6"
"\eOw":		"7"
"\eOx":		"8"
"\eOy":		"9"
\$endif
#
#  EMACS line editing
#
\$if mode=emacs
#
# ... xterm application cursor
#
\$if term=xterm
"\e\eOD":	backward-word
"\e\eOC":	forward-word
"\e\eOA":	up-history
"\e\eOB":	down-history
"\C-\eOD":	backward-char
"\C-\eOC":	forward-char
"\C-\eOA":	up-history
"\C-\eOB":	down-history
\$endif
#
# Standard cursor
#
"\e\e[D":	backward-word
"\e\e[C":	forward-word
"\e\e[A":	up-history
"\e\e[B":	down-history
"\C-\e[D":	backward-char
"\C-\e[C":	forward-char
"\C-\e[A":	up-history
"\C-\e[B":	down-history
\$endif
#
# end
#
EOF
} >"$INPUTRC"
unset INPUTRC

alias which='type -p'
alias rehash='hash -r'
alias beep='echo -en "\x07"'
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias dir='ls -l'
alias ll='ls -l'
alias la='ls -la'
alias l='ls -alF --color=auto'
alias ls-l='ls -l'
alias rd=rmdir
alias md='mkdir -p'
type -p recode >/dev/null 2>&1 && alias unix2dos='recode lat1..ibmpc'
type -p recode >/dev/null 2>&1 && alias dos2unix='recode ibmpc..lat1'
type -p glocate >/dev/null 2>&1 && alias locate=glocate
type -p mysql-workbench >/dev/null 2>&1 && alias mysql-workbench='LANG=C mysql-workbench'
alias loacte=locate
alias loact=locate
alias locaet=locate
alias loctae=locate
alias printnev=printenv
alias printnv=printenv
alias printev=printenv
alias _lscnf=_lsconf
alias temp=' vcgencmd measure_temp'
alias nano='nano -l'
alias OS='grep -i 'pretty' /etc/os-release'
alias du='du . --max-depth=1 | sort -nr | cut -f2 | xargs -n 1 du -hs'
if [ -r ~/.alias ]; then
	. ~/.alias
else
# hier wird nur eine Funktion erzeugt, die man von Hand aufrufen kann - wenn man moechte.
# Diese Aliase sind nicht allgemeingueltig und eventuell sogar "schaedlich" (a2ps)!
	function _my_alias () {
		{ cat <<-EOF
			alias a2ps='a2ps -1 -o- --margin=35 --media=a4dj --font-size=8 --left-footer="" --footer="" --right-footer=""'
			alias logbuch='$EDITOR "$HOME"/doc/System-changes/changes'
			alias disc-cover='disc-cover -sansserif -noemph -leadingblank'
			alias calend='gcal ..'
EOF
		} >~/.alias
		. ~/.alias
	}
fi

_addtopath CDPATH 1 <<-EOF
	.
	$HOME
	$HOME/photos
	/data
	/usr
	/usr/src
	/usr/local
	/usr/local/nobackup
	/usr/X11R6/lib/X11
	/opt
	/opt/confluence/confluence
	/opt/confluence
	/opt/jira/atlassian-jira
	/opt/jira
        /opt/atlassian
        /opt/atlassian/confluence/confluence
        /opt/atlassian/confluence
        /opt/atlassian/jira/atlassian-jira
        /opt/atlassian/jira
        /opt/crowd/crowd-webapp
        /opt/crowd/apache-tomcat
        /opt/crowd
	/opt/stash/atlassian-stash
	/opt/stash
	/opt/bamboo/atlassian-bamboo
	/opt/bamboo
EOF
export CDPATH

EDITOR="vi" 
if [ "$UID" != "0" ] ; then 
	if type joe >/dev/null 2>&1 ; then
		EDITOR="joe"
	elif type nedit >/dev/null 2>&1; then
		EDITOR="nedit"
	fi
fi
export EDITOR
VISUAL=$EDITOR; export VISUAL

function _shortprompt () {
local maxlen=$1
local host=`hostname`
local hostlen=${#host}
local cwd=`pwd`

	if [ $hostlen -gt $maxlen ]; then
		echo ${host:0:$((maxlen-1))}~
		return;
	elif [ $hostlen -eq $maxlen ]; then
		echo ${host}
		return;
	else
		local url=$host:$cwd
		local len=${#url}
		if [ $len -le $maxlen ]; then
			echo $url
			return;
		fi
	fi

	local glue=':..';
	local url=$host$glue$cwd
	local len=${#url}
	echo $host$glue${cwd:$((len-maxlen+1))}
}

function _build_ps1 () {
#set -u

function _xtermtitle () {
local    Title="\[\e]2;"
local     Icon="\[\e]1;"
local   TtlCls="\a\]"
	echo -n $Title'\u@\h $(pwd -P)'$TtlCls$Icon'$(_shortprompt 23)'$TtlCls
}

function _ansiprompt () {
local   NoAttr="\[\e[m\]"
	if test "$UID" = 0; then
		em=$2;
	else
		em=""
	fi
	echo -n "$1\t $em\u$1@\h "'$(pwd -P)'"$NoAttr\n\$ "
}

#TERM=vt100
#TERM=dumb
local RedOnBlk="\[\e[31;40m\]"
local  CyOnBlk="\[\e[36;40m\]"
local  RedOnCy="\[\e[31;46m\]"
local  BlkOnCy="\[\e[30;46m\]"
local   BlkOnY="\[\e[30;43m\]"
local   RedOnY="\[\e[31;43m\]"

	case "$TERM" in
		xterm*|kvt|rxvt|dtterm|iris-ansi|cygwin|kterm)
			_xtermtitle
			_ansiprompt $BlkOnY $RedOnY
			;;
		linux|vt*|AT386|sun)
			_ansiprompt $CyOnBlk $RedOnBlk
			;;
		*)
			echo -n '\t \u@\h $(pwd -P)\n\$ ';
			;;
	esac
set +u
}

PS1=$(_build_ps1)
unset -f _build_ps1 _xtermtitle _ansiprompt


########### Shell Functions


function __lspath () {
	eval echo \$$1 | tr ':' '\n' | sed 's/^/[/; s/$/]/';
}

function _lspath () {
	__lspath PATH;
}

function _lsmanpath () {
	__lspath MANPATH;
}

function _lscdpath () {
	__lspath CDPATH;
}

function _lsconf () {
        egrep -v '^(([[:space:]]*#)|($))' $@
}

if type -a resize >/dev/null 2>&1 ; then

	function tailmsg () {
	
		unset OPTIONS;
		
		while true; do
		  case $1 in
		    -*) OPTIONS="$OPTIONS $1"
			shift 1;
		    ;;
		    *)	break
		    ;;
		  esac		
		done
		
		local PATTERN=${1:-"."}

		case "$OSname" in
		HP-UX)	
			local LOGFILE=${2:-/var/adm/syslog/syslog.log}
			;;

		IRIX*)	
			local LOGFILE=${2:-/var/adm/SYSLOG}
			;;

		AIX|SunOS)	
			local LOGFILE=${2:-/var/adm/messages}
			;;

		*)	
			local LOGFILE=${2:-/var/log/messages}
			;;
		esac

		tmpfile=/tmp/tmp$$
		touch "$tmpfile" || { echo "Kann $tmpfile nicht anlegen"; exit 2; }
		chmod go-rwx $tmpfile

		while true; do
			eval `resize`;
			LC_TIME=de_DE date +"%x, %X    Suchmuster=\"$PATTERN\"" >"$tmpfile"
			echo >>"$tmpfile"
			case "$PATTERN" in
			".")
				LC_TIME=de_DE date +"%x, %X" >"$tmpfile"
				echo >>"$tmpfile"
				tail -$((LINES-3)) <"$LOGFILE" | cut -b -"$COLUMNS" >>"$tmpfile"
				;;
			*)
				LC_TIME=de_DE date +"%x, %X    Suchmuster=\"$PATTERN\" options=\"$OPTIONS\"" >"$tmpfile"
				echo >>"$tmpfile"
				egrep $OPTIONS "$PATTERN" <"$LOGFILE"  | tail -$((LINES-3)) | cut -b -"$COLUMNS" >>"$tmpfile"
				;;
			esac
			clear;
			cat "$tmpfile"
			/bin/rm -f "$tmpfile"
			sleep 2;
		done
	}
fi


function mksavfile () {
	if [ $# -eq 0 ]; then
		for f in $(find . -xdev -maxdepth 1 -type f \( -name ".*.sav" -o -name "*.sav" \));
		do
			diff $(basename $f .sav) $f >/dev/null 2>&1 || { 
				if [ -f $(basename $f .sav) ]; then
					echo -e "Source: $(ls -l $(basename $f .sav))\nTarget: $(ls -l $f) ?";
					cp -pi $(basename $f .sav) $f;
				fi
			};
		done
	else
		while [ $# -gt 0 ]; do
			if [ -r $1 ]; then
				local Target
				Target=$(ls -l $1.sav 2>/dev/null) || Target=$1.sav
				echo -e "Source: $(ls -l $1)\nTarget: $Target";
				cp -pi $1 $1.sav;
				shift;
			fi
		done
	fi
}


function indir () {
	pushd "$1" >/dev/null
	shift
	eval $@
	popd    >/dev/null
}


function where () {
	type -all $1;
}

if type -a resize >/dev/null 2>&1 ; then
	type -a watch >/dev/null 2>&1 || function watch () {
		if [ $# -ge 1 ]; then
			clear
			echo "$(date) -- every 2s \"$@\""; echo;
			while eval `resize`; $@ | head -$((LINES-3)) | cut -b -$COLUMNS; do
				sleep 2
				clear
				echo "$(date) -- every 2s \"$@\""; echo;
			done
		fi
	}
fi

test "$OSname" = "Linux" && {

	function realexe () {
		type -all $1 | grep "^$1.* /" | head -1 | sed -e "s#.* /#/#"
	}

#	type -p xfig >/dev/null 2>&1 && {
#		function xfig () {
#			if [ "$DISPLAY" ]; then
#				$(realexe xfig) -startgrid 1 -metric -portrait -ph 20 -pw 27 -but_ 2 $@
#			fi
#		}
#	}


#	type -p lyx >/dev/null 2>&1 && {
#		function lyx () {
#			if [ "$DISPLAY" ]; then
#				$(realexe lyx) -geometry 800x820+8+8 $@;
#			fi
#		}
#	}


#	type -p xdvi >/dev/null 2>&1 && {
#		function xdvi () {
#			if [ "$DISPLAY" ]; then
#				$(realexe xdvi) -s 3 -geometry 800x740+30+0 -margins 1.5cm $@;
#			fi
#		}
#	}

#	test $(realexe gcal 2>/dev/null) && {
#		function gcal ()
#		{
#			LANG=de_DE $(realexe gcal) -K -q DE_HS $@
#		}
#	}

#	test $(realexe kate 2>/dev/null) && {
#		function kate ()
#		{
#			export $(dbus-launch)
#			$(realexe kate) --graphicssystem native $@ 2>/dev/null
#		}
#	}

export PTLENS_PROFILE=$HOME/.ptlens/profile.txt

}


function prettyfind () {
	find $1 -printf "%Td.%Tm.%TY   %TT  %s\t%h/%f\n";
}


function tolower () {
	awk '{ print tolower($0); }'
}


function toupper () {
	awk '{ gsub( /[=ß=]/, "SS", $0); print toupper($0); }'
}


type -p perl >/dev/null 2>&1 && {
	function plcalc () {
		perl -mMath::Trig -l -e "print ($*);"
	};
}

#
