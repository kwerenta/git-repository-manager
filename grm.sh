#!/bin/bash
# Name             : Git Repository Manager
# Author           : Kamil Wenta (193437)
# Created On       : 10.05.2023r.
# Last Modified By : Kamil Wenta (193437)
# Last Modified On : 10.05.2023r. 
# Version          : 0.1.2
#
# Description      :
# GUI to manage git repositories and more
while getopts "hv" OPT; do
  case $OPT in
    v)
      echo "Author   : Kamil Wenta"
      echo "Version  : 0.1.2"
      exit 0
      ;;
    h)
      echo "usage $0:"
      echo "  -v # Display author and version"
      exit 0
      ;;
  esac
done

ROOT_FOLDER=$(dirname -- "$0")
DATA_FILE="$ROOT_FOLDER/data.txt"
APP_NAME="Git Repository Manager"

# Create data.txt file if doesn't exist
touch -a "$DATA_FILE"

displayError () {
  if [[ ! -z $1 ]]
  then
    zenity --title "$APP_NAME" --error --text="$1"
  fi
}

while [[ true ]]; do
  OPTION=$(zenity --list --column=Menu List Import Create)
  if [[ $? -eq 1 ]]
  then
    exit 0
  fi

  case $OPTION in
    "List")
      while read LINE; do
        DATA+=("$LINE")
        DATA+=($(echo $LINE | grep -o '[^/]*$'))
        DATA+=($(git -C "$LINE" branch --show-current))
        DATA+=($(git -C "$LINE" status -s | wc -l))
        DATA+=($(du -hs "$LINE" | grep -o '[0-9]*[K,M,G,T,P,E,Z,Y]'))
      done < $DATA_FILE

      SELECTED=$(zenity --list --column=Path --print-column=1 --hide-column=1 --column=Name --column=Branch --column="Uncommited files" --column=Size ${DATA[@]})
      
      if [[ $? -eq 0 ]]
      then
        cd "$SELECTED"
        $SHELL
      fi
      ;;

    "Import")
      DIR=$(zenity --title "$APP_NAME" --file-selection --directory)
      if [[ ! -z $DIR && $? -eq 0 ]]
      then
        # Check if git repository exists and silence output
        git -C $DIR status &> /dev/null
        if [[ $? -ne 0 ]]
        then
          displayError "$DIR does not contain git repository."
        elif grep -q $DIR $DATA_FILE
        then
          displayError "$DIR is already imported."
        else
          echo $DIR >> $DATA_FILE
        fi
      fi
      ;;

      "Create")
        DIR=$(zenity --title "$APP_NAME" --file-selection --directory)
        NAME=$(zenity --title "$APP_NAME" --entry --text "Enter repository name:")

        # TODO: Add input validation and check for permissions
        if [[ ! -z $NAME && $? -eq 0 ]]
        then
          DIR="$DIR/$NAME"
          mkdir $DIR
          git -C $DIR init &> /dev/null
          echo $DIR >> $DATA_FILE
        fi
      ;;
  esac
done
