#!/bin/bash
# Name             : Git Repository Manager
# Author           : Kamil Wenta (193437)
# Created On       : 10.05.2023
# Last Modified By : Kamil Wenta (193437)
# Last Modified On : 23.05.2023 
# Version          : 0.8.0
#
# Description      :
# GUI to manage git repositories and more
. constants.txt

while getopts "hvl" OPT; do
  case $OPT in
    v)
      echo "Author   : Kamil Wenta"
      echo "Version  : 0.8.0"
      exit 0
    ;;
    l)
      echo "List of imported repositories:"
      cat $DATA_FILE
      exit 0
    ;;
    h)
      echo "usage $0:"
      echo "  -v # Shows author and version"
      echo "  -l # Shows list of imported repositories"
      echo "  -h # Shows this help"
      exit 0
    ;;
  esac
done

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

showQuestion () {
  return $(zenity --question --text="$1")
}

showOptionMenu () {
  echo $(zenity --list --title "$APP_NAME" --column="$1" "${@:2}")
}

isThereRepository () {
  return $(git -C $1 status &> /dev/null)
}

repositoryMenu () {
  local REPO=$1
  local OPTION=$(zenity --list --column=Menu "Go to directory" "History" "Edit branch" "Sync with remote" "Edit .gitignore" "Delete repository")
  if [[ $? -ne 0 ]]
  then
    return
  fi

  case $OPTION in
    "Go to directory")
      cd "$REPO"
      $SHELL
    ;;

    "History")
      TMP=$(mktemp)
      git -C "$REPO" log --oneline --no-decorate > $TMP
      COMMITS=()
      while read LINE; do
        COMMITS+=($(echo "$LINE" | cut -d" " -f1))
        COMMITS+=("$(echo "$LINE" | cut -d" " -f 2-)")
      done < $TMP

      COMMIT=$(zenity --list --column=ID --print-column=1 --column=Message "${COMMITS[@]}")
      if [[ $? -ne 0 ]]; then
        return
      fi

      OPERATION=$(showOptionMenu "Operation" "Switch" "Revert")
      if [[ -z $OPERATION ]]; then
        return
      fi

      if [ "$OPERATION" = "Switch" ]; then
        if git -C "$REPO" checkout "$COMMIT" &> /dev/null; then
          displayInfo "Successfully switched to commit $COMMIT."
        else
          displayError "Failed to switch to commit $COMMIT."
        fi
      elif [ "$OPERATION" = "Revert" ]; then
        if git -C "$REPO" revert --no-commit "${COMMIT}..HEAD" &> /dev/null; then
          if showQuestion "Do you want to commit reverted changes?"; then
            if git -C "$REPO" commit -m "Revert to commit $COMMIT" &> /dev/null; then
              displayInfo "Successfully reverted to commit $COMMIT and commited changes."
            else
              displayError "Failed to revert to commit $COMMIT and commit changes."
            fi
          else
            displayInfo "Successfully reverted to commit $COMMIT."
          fi
        else
          displayError "Failed to revert to commit $COMMIT."
        fi
      fi
    ;;

    "Edit branch")
      OPERATION=$(showOptionMenu "Operation" "Create" "Switch" "Delete")

      TMP=$(mktemp)
      git -C "$REPO" branch > $TMP
      BRANCHES=()
      while read LINE; do
        BRANCHES+=($(echo "$LINE" | cut -d" " -f2))
      done < $TMP

      if [ "$OPERATION" = "Create" ]; then
        NAME=$(zenity --entry --text="Enter branch name:")
        if [ $? -eq 0 ]; then
          if [ ! -z $NAME ]; then
            git -C "$REPO" branch "$NAME"
            displayInfo "Successfully created $NAME branch"
          else
            displayError "Invalid branch name"
          fi
        fi
      elif [ "$OPERATION" = "Switch" ]; then
        BRANCH=$(zenity --list --column=Name "${BRANCHES[@]}")
        if [[ $? -eq 0 ]]; then
          if git -C "$REPO" checkout "$BRANCH" &> /dev/null; then
            displayInfo "Successfully switched branch to $BRANCH"
          else
            displayError "Failed to switch branch to $BRANCH"
          fi
        fi
      elif [ "$OPERATION" = "Delete" ]; then
        BRANCH=$(zenity --list --column=Name "${BRANCHES[@]}")
        if [[ $? -eq 0 ]]; then
          if git -C "$REPO" branch -D "$BRANCH" &> /dev/null; then
            displayInfo "Successfully deleted branch $BRANCH"
          else
            displayError "Failed to delete branch $BRANCH"
          fi
        fi
      fi
    ;;

    "Sync with remote")
      OPERATION=$(showOptionMenu "Operation" "Fetch" "Push")

      TMP=$(mktemp)
      git -C "$REPO" remote > $TMP
      REMOTES=()
      while read LINE; do
        REMOTES+=("$LINE")
      done < $TMP

      if [[ -z $OPERATION ]]; then
        return
      fi

      REMOTE=$(zenity --list --column=Name "${REMOTES[@]}")

      if [[ $? -ne 0 ]]; then
        return
      fi

      if [ "$OPERATION" = "Fetch" ]; then
        if git -C "$REPO" fetch "$REMOTE" &> /dev/null; then
          displayInfo "Successfully fetched changes from remote $REMOTE repository."
        else
          displayError "Failed to fetch changes from remote $REMOTE repository."
        fi
      elif [ "$OPERATION" = "Push" ]; then
        if git -C "$REPO" push "$REMOTE" &> /dev/null; then
          displayInfo "Successfully pushed changes to remote $REMOTE repository."
        else
          displayError "Failed to push changes to remote $REMOTE repository."
        fi
      fi
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
          if showQuestion "Do you want to delete this entry from .gitignore?"; then
            sed -i "${ENTRY}d" "$GITIGNORE"
            if [ ! -s $GITIGNORE ]; then
              if showQuestion ".gitignore is now empty, do you want to delete it?"; then
                rm "$GITIGNORE"
              fi
            fi
          fi
        fi
      fi
    ;;

    "Delete repository")
      if showQuestion "Are you sure you want to delete git repository?"; then
            rm -r "$REPO/.git"
            sed -i "\~${REPO}~d" "$DATA_FILE"
            if showQuestion "Do you want to delete all files in repository folder?"; then
              rm -r "$REPO"
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
          if [[ -d $LINE ]]; then
            DATA+=("$LINE")
            DATA+=($(echo $LINE | grep -o '[^/]*$'))
            DATA+=($(git -C "$LINE" branch --show-current))
            DATA+=($(git -C "$LINE" status -s | wc -l))
            DATA+=($(du -hs "$LINE" | grep -o '[0-9]*[K,M,G,T,P,E,Z,Y]'))
          else
            sed -i "\~${LINE}~d" "$DATA_FILE"
          fi
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
      SOURCE=$(showOptionMenu "Source" "Local" "Remote")
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
        if [[ $? -eq 0 ]]; then
          # Pattern found here: https://stackoverflow.com/questions/3183444/check-for-valid-link-url
          URL_PATTERN='^[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]\.[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]$'
          if [[ $URL =~ $URL_PATTERN ]]; then
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
      fi
      ;;

      "Create")
        DIR=$(zenity --title "$APP_NAME" --file-selection --directory)
        if [[ $? -eq 0 ]]; then
          NAME=$(zenity --title "$APP_NAME" --entry --text "Enter repository name:")
          if [[ $? -eq 0 ]]; then
            # Check if NAME is not empty and does not contain spaces
            if [[ ! -z $NAME && ! $NAME =~ \  ]]; then
              DIR="$DIR/$NAME"
              mkdir $DIR
              git -C $DIR init &> /dev/null
              echo $DIR >> $DATA_FILE
              displayInfo "Successfully created repository."
            else
              displayError "Invalid repository name."
            fi
          fi
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
            OPERATION=$(showOptionMenu "Operation" "Edit" "Unset")
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
