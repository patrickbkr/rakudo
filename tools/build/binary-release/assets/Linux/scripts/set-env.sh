#!/bin/sh

# Sourced from https://stackoverflow.com/a/29835459/1975049
rreadlink() (
  target=$1 fname= targetDir= CDPATH=
  { \unalias command; \unset -f command; } >/dev/null 2>&1
  [ -n "$ZSH_VERSION" ] && options[POSIX_BUILTINS]=on
  while :; do
      [ -L "$target" ] || [ -e "$target" ] || { command printf '%s\n' "ERROR: '$target' does not exist." >&2; return 1; }
      command cd "$(command dirname -- "$target")" || exit 1
      fname=$(command basename -- "$target")
      [ "$fname" = '/' ] && fname=''
      if [ -L "$fname" ]; then
        target=$(command ls -l "$fname")
        target=${target#* -> }
        continue
      fi
      break
  done
  targetDir=$(command pwd -P)
  if [ "$fname" = '.' ]; then
    command printf '%s\n' "${targetDir%/}"
  elif  [ "$fname" = '..' ]; then
    command printf '%s\n' "$(command dirname -- "${targetDir}")"
  else
    command printf '%s\n' "${targetDir%/}/$fname"
  fi
)

# Taken from https://unix.stackexchange.com/a/10065/396163
# The script is meant to be evaled. So no TTY connected. Thus
# disable the TTY check.
#if test -t 1; then
    ncolors=$(tput colors)
    if test -n "$ncolors" && test $ncolors -ge 8; then
        normal="$(tput sgr0)"
        black="$(tput setaf 0)"
        red="$(tput setaf 1)"
        green="$(tput setaf 2)"
        yellow="$(tput setaf 3)"
        blue="$(tput setaf 4)"
        magenta="$(tput setaf 5)"
        cyan="$(tput setaf 6)"
        white="$(tput setaf 7)"
    fi
#fi

EXEC=$(rreadlink "$0")
DIR=$(dirname $(dirname "$EXEC"))

echo "echo '                             ${cyan}Adding Rakudo to PATH';"
echo "echo '                            =======================${normal}';"
echo "echo '';"

NEW_PATH=$PATH
RAKUDO_PATH0="$DIR/bin"
RAKUDO_PATH1="$DIR/share/perl6/site/bin"
STUFF_DONE=false
for RPATH in $RAKUDO_PATH1 $RAKUDO_PATH0 ; do
    if echo "$NEW_PATH" | /bin/grep -vEq "(^|:)$RPATH($|:)" ; then
        NEW_PATH="$RPATH:$NEW_PATH"
        STUFF_DONE=true
    fi
done

if $STUFF_DONE ; then
    if [ "$1" = "--fish" ] ; then
        NEW_PATH=$(echo "$NEW_PATH" | sed "s/:/ /g")
        echo "set -x PATH $NEW_PATH;"
    else
        echo "export PATH='$NEW_PATH';"
    fi
    echo "echo 'Paths successfully added.';"
else
    echo "echo 'Paths already set. Nothing to do.';"
fi

echo "echo '';
echo '${cyan}================================================================================${normal}';
echo ' =========               ${cyan}                             ${normal}                 __   __';
echo '  ||_|_||                ${cyan}=============================${normal}                (  \,/  )';
echo '  || # ||                ${cyan} Welcome to the ${green}R${red}a${yellow}k${blue}u${cyan} Console ${normal}                 \_ O _/';
echo '  || # ||                ${cyan}=============================${normal}                 (_/ \_)';
echo '';
echo 'This console has all the tools available you need to get started using Raku.';
echo '';
echo 'Rakudo provides an interactive command line interpreter (a so called Read Eval';
echo 'Print Loop, REPL for short) you can use to quickly try out pieces of Raku code.';
echo 'Start it by typing:';
echo '';
echo '    ${green}raku.exe${normal}';
echo '';
echo 'If you already have a Raku program in a file, you can run it by typing:';
echo '';
echo '    ${green}raku.exe path\to\my\program.raku${normal}';
echo '';
echo 'To install additional modules you can use the Zef module manager:';
echo '';
echo '    ${green}zef install Some::Module${normal}';
echo '';
echo '${magenta}https://rakudo.org/${normal}           - The home of this implementation of Raku.';
echo '${magenta}https://raku.land/${normal}            - Go here to browse for Raku modules.';
echo '${magenta}https://docs.raku.org/${normal}        - The Raku documentation.';
echo '${magenta}https://web.libera.chat/#raku${normal} - The Raku user chat. Talk to us!';
echo '';
echo '                              Happy hacking!';
echo '';
echo '${cyan}================================================================================${normal}';
echo '';
"
