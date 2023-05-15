#!/bin/bash
# Name             : Git Repository Manager
# Author           : Kamil Wenta (193437)
# Created On       : 10.05.2023
# Last Modified By : Kamil Wenta (193437)
# Last Modified On : 15.05.2023 
# Version          : 0.3.0
#
# Description      :
# GUI to manage git repositories and more
while getopts "hv" OPT; do
  case $OPT in
    v)
      echo "Author   : Kamil Wenta"
      echo "Version  : 0.3.0"
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

while [[ true ]]; do
  OPTION=$(zenity --list --column=Menu List Import Create "Edit global config")
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
      SOURCE=$(zenity --list --title "$APP_NAME" --radiolist --column "ID" --column="Name" 1 Local 2 Remote)
      if [ "$SOURCE" = "Local" ]
      then
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
      elif [ "$SOURCE" = "Remote" ]
      then
        URL=$(zenity --title "$APP_NAME" --entry --text "Enter remote repository URL:")
        if echo "$URL" | grep -Eq "[A-Za-z0-9][A-Za-z0-9+.-]*"
        then
          DIR=$(zenity --title "$APP_NAME" --file-selection --directory)
          if [[ ! -z $DIR && $? -eq 0 ]]
          then
            # Check if git repository exists and silence output
            git -C $DIR status &> /dev/null
            if [[ $? -ne 0 ]]
            then
              git clone "$URL" "$DIR" &> /dev/null
              if [[ $? -ne 0 ]]
              then
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
        if [[ ! -z $NAME && $? -eq 0 ]]
        then
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
            OPERATION=$(zenity --list --title "$APP_NAME" --radiolist --column "ID" --column="Operation" 1 Edit 2 Unset)
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
