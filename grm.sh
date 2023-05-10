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
