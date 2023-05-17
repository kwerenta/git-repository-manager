#!/bin/bash
# Name             : Git Repository Manager
# Author           : Kamil Wenta (193437)
# Created On       : 10.05.2023
# Last Modified By : Kamil Wenta (193437)
# Last Modified On : 15.05.2023 
# Version          : 0.4.1
#
# Description      :
# GUI to manage git repositories and more
while getopts "hv" OPT; do
  case $OPT in
    v)
      echo "Author   : Kamil Wenta"
      echo "Version  : 0.4.1"
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

displayDialog () {
  if [[ ! -z $1 || ! -z $2 ]]
  then
    zenity --title "$APP_NAME" --"$1" --text="$2"
  fi
}

displayError () {
  displayDialog "error" "$1"
}

displayInfo () {
  displayDialog "info" "$1"
}

showOptionMenu () {
  MENU=()
  I=1
  for NAME in "$@"
  do
    MENU+=($I $NAME)
    I=$((I+1))
  done
  echo $(zenity --list --title "$APP_NAME" --radiolist --column "ID" --column="Name" ${MENU[@]})
}

isThereRepository () {
  return $(git -C $1 status &> /dev/null)
}

repositoryMenu () {
  local REPO=$1
  local OPTION=$(zenity --list --column=Menu "Go to directory" "Edit .gitignore")
  if [[ $? -ne 0 ]]
  then
    return
  fi

  case $OPTION in
    "Go to directory")
      cd "$REPO"
      $SHELL
    ;;

    "Edit .gitignore")
      TMP=$(mktemp)
      local GITIGNORE="$REPO/.gitignore"
      # Hide errors if .gitignore does not exist
      # Skip comments and empty lines
      cat $GITIGNORE 2> /dev/null | grep -nvE "^$|^#" 1> $TMP
      DATA=()
      while read LINE; do
        DATA+=($(echo "$LINE" | cut -d: -f1))
        DATA+=($(echo "$LINE" | cut -d: -f2))
      done < $TMP
      DATA+=("0")
      DATA+=("Add new")

      ENTRY=$(zenity --list --column=Number --hide-column=1 --column=Entry "${DATA[@]}")
      if [[ $? -eq 0 ]]; then
        if [ "$ENTRY" = "0" ]; then
          VALUE=$(zenity --entry --text="Enter .gitignore entry value:")
          if [ -z $VALUE ]; then
            displayError "Invalid entry."
            return
          fi
          if [ ! -s $TMP ]; then
            touch "$GITIGNORE"
          fi
          echo "$VALUE" >> $GITIGNORE
        else
          if zenity --question --text="Do you want to delete this entry from .gitignore?"; then
            sed -i "${ENTRY}d" "$GITIGNORE"
            if [ ! -s $GITIGNORE ]; then
              if zenity --question --text=".gitignore is now empty, do you want to delete it?"; then
                rm "$GITIGNORE"
              fi
            fi
          fi
        fi
      fi

    ;;
  esac
}

while [[ true ]]; do
  OPTION=$(zenity --list --column=Menu List Import Create "Edit global config")
  if [[ $? -ne 0 ]]
  then
    exit 0
  fi

  case $OPTION in
    "List")
      while [[ true ]]; do
        DATA=()
        while read LINE; do
          DATA+=("$LINE")
          DATA+=($(echo $LINE | grep -o '[^/]*$'))
          DATA+=($(git -C "$LINE" branch --show-current))
          DATA+=($(git -C "$LINE" status -s | wc -l))
          DATA+=($(du -hs "$LINE" | grep -o '[0-9]*[K,M,G,T,P,E,Z,Y]'))
        done < $DATA_FILE

        SELECTED=$(zenity --list --column=Path --print-column=1 --hide-column=1 --column=Name --column=Branch --column="Uncommited files" --column=Size ${DATA[@]})
        if [[ $? -ne 0 ]]
        then
          break
        fi
        
        if [[ ! -z $SELECTED && $? -eq 0 ]]
        then
          repositoryMenu $SELECTED
        fi
      done
      ;;

    "Import")
      SOURCE=$(showOptionMenu "Local" "Remote")
      if [ "$SOURCE" = "Local" ]
      then
        DIR=$(zenity --title "$APP_NAME" --file-selection --directory)
        if [[ ! -z $DIR && $? -eq 0 ]]
        then
          # Check if git repository exists
          if ! isThereRepository $DIR; then
            displayError "$DIR does not contain git repository."
          # Check if this repository is already in data file
          elif grep -q $DIR $DATA_FILE; then
            displayError "$DIR is already imported."
          else
            echo $DIR >> $DATA_FILE
            displayInfo "Successfully imported repository from $DIR."
          fi
        fi
      elif [ "$SOURCE" = "Remote" ]
      then
        URL=$(zenity --title "$APP_NAME" --entry --text "Enter remote repository URL:")
        if echo "$URL" | grep -Eq "[A-Za-z0-9][A-Za-z0-9+.-]*"; then
          DIR=$(zenity --title "$APP_NAME" --file-selection --directory)
          if [[ ! -z $DIR && $? -eq 0 ]]; then
            if ! isThereRepository $DIR; then
              if ! git clone "$URL" "$DIR" &> /dev/null; then
                displayError "Failed to import repository from $URL."
              else
                echo $DIR >> $DATA_FILE
                displayInfo "Successfully imported repository from $URL."
              fi
            else
              displayError "$DIR already contains git repository."
            fi
          fi
        else
          displayError "Invalid URL."
        fi
      fi
      ;;

      "Create")
        DIR=$(zenity --title "$APP_NAME" --file-selection --directory)
        NAME=$(zenity --title "$APP_NAME" --entry --text "Enter repository name:")

        # TODO: Add input validation and check for permissions
        if [[ ! -z $NAME && $? -eq 0 ]]; then
          DIR="$DIR/$NAME"
          mkdir $DIR
          git -C $DIR init &> /dev/null
          echo $DIR >> $DATA_FILE
          displayInfo "Successfully created repository."
        fi
      ;;

      "Edit global config")
        TMP=$(mktemp)
        git config --global -l > $TMP
        DATA=()
        while read LINE; do
          DATA+=($(echo "$LINE" | cut -d= -f1))
          DATA+=($(echo "$LINE" | cut -d= -f2))
        done < $TMP
        DATA+=("Add new")
        NAME=$(zenity --list --column=Name --column=Value ${DATA[@]})
        if [[ $? -eq 0 ]]; then
          if [ "$NAME" = "Add" ]; then
            NAME=$(zenity --title "$APP_NAME" --entry --text "Enter config variable name:")
            VALUE=$(zenity --title "$APP_NAME" --entry --text "Enter config variable value:")
            # Check if variable already exists
            if ! git config --global --get "$NAME" &> /dev/null && git config --global --add "$NAME" "$VALUE" &> /dev/null; then
              displayInfo "Successfully added new config variable."
            else
              displayError "Failed to add new config variable."
            fi
          else
            OPERATION=$(showOptionMenu "Edit" "Unset")
            if [ "$OPERATION" = "Edit" ]; then
              VALUE=$(zenity --title "$APP_NAME" --entry --text "Enter new config variable value:")
              if git config --global "$NAME" "$VALUE" &> /dev/null; then
                displayInfo "Successfully changed config variable value."
              else
                displayError "Failed to change config variable value."
              fi
            else
              if git config --global --unset "$NAME" &> /dev/null; then
                displayInfo "Successfully unsetted config variable."
              else
                displayError "Failed to unset config variable."
              fi
            fi
          fi
        fi
      ;;
  esac
done
