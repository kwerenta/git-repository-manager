#!/bin/bash
# Name             : Git Repository Manager
# Author           : Kamil Wenta (193437)
# Created On       : 10.05.2023r.
# Last Modified By : Kamil Wenta (193437)
# Last Modified On : 10.05.2023r. 
# Version          : 0.1.0
#
# Description      :
# GUI to manage git repositories and more
while getopts "hv" OPT; do
  case $OPT in
    v)
      echo "Author   : Kamil Wenta"
      echo "Version  : 0.1.0"
      exit 0
      ;;
    h)
      echo "usage $0:"
      echo "  -v # Display author and version"
      exit 0
      ;;
  esac
done

DATA_FILE="./data.txt"
# Create data.txt file if doesn't exist
touch -a "$DATA_FILE"

while [[ true ]]; do
  OPTION=$(zenity --list --column=Menu "List")
  if [[ $? -eq 1 ]]
  then
    exit 0
  fi

  case $OPTION in
    "List")
      zenity --list --column=Repositories $(grep -o '[^/]*$' $DATA_FILE)
      ;;
  esac
done
