#!/bin/bash

# Install software from vendor-hosted software installer file

# -------------------------------------------------------------------------------------------------
# Definitions

# if staged .installFromURL.txt file exists
if [ -e /Library/Application\ Support/JAMF/.installFromURL.txt ]; then
  # define vendor-hosted installer file url we want to download and install
  url=$(/bin/cat /Library/Application\ Support/JAMF/.installFromURL.txt)
  /bin/echo "Staged URL file found at /Library/Application\ Support/JAMF/.installFromURL.txt"
  /bin/echo "Staged URL is $url"
  # un-stage the .installFromURL.txt file to avoid future collisions
  /bin/rm /Library/Application\ Support/JAMF/.installFromURL.txt
# otherwise report error and exit
else
  echo "No staged file at /Library/Application\ Support/JAMF/.installFromURL.txt"
  echo "Aborting..."
  exit 1
fi

# get the full filename from a remote server via curl
getUriFilename() {
  header="$(curl -sIL "$1" | tr -d '\r')"

  filename="$(echo "$header" | grep -o -i -E 'filename=.*$')"
  if [[ -n "$filename" ]]; then
    echo "${filename#filename=}"
    return
  fi

  filename="$(echo "$header" | grep -o -i -E 'location:.*$')"
  if [[ -n "$filename" ]]; then
    basename "${filename#location\:}"
    return
  fi

  return 1
}

# install an app directly from its vendor-hosted installer file
installFromURL() {

  # define the vendor-hosted installer file url (passed in as $1) and a local downloadPath to store it
  url="$1"
  downloadPath=$(/usr/bin/mktemp -d /tmp/downloadPath.XXXX)

  # find the remote fileName if applicable
  fileName=$(getUriFilename "$url")
  # download the remote file to the to $downloadPath/$fileName if $fileName is known
  if [ -n "$fileName" ]; then
    /usr/bin/curl -o "$downloadPath/$fileName" -L "$url"
  # otherwise use the end of the supplied $url in place of a known remote $fileName
  else
    /usr/bin/curl -o "$downloadPath/${url##*/}" -L "$url"
  fi

  # if the downloaded file is a dmg, mount it as a disk image at mountPoint
  if [ -e "$downloadPath"/*.dmg ]; then
    mountPoint=$(/usr/bin/mktemp -d /tmp/mountPoint.XXXX)
    /usr/bin/hdiutil attach "$downloadPath"/*.dmg -mountpoint "$mountPoint" -noverify -nobrowse -noautoopen

    # overwrite downloadPath with mountPoint to process contents of mounted disk image
    originalDownloadPath="$downloadPath"
    downloadPath="$mountPoint"
  fi

  # install the downloaded app, zip, or pkg
  if [ -e "$downloadPath"/*.app ]; then
    /bin/cp -R "$downloadPath"/*.app /Applications 2>/dev/null
  elif [ -e "$downloadPath"/*.zip ]; then
    /usr/bin/unzip "$downloadPath"/*.zip -d /Applications
  elif [ -e "$downloadPath"/*.pkg ]; then
    /usr/sbin/installer -pkg "$downloadPath"/*.pkg -target / 2>/dev/null
  fi

  # clean up, including mounted disk image if applicable
  if [ -e "$originalDownloadPath" ]; then
    /bin/rm -rf "$originalDownloadPath"
    /usr/bin/hdiutil detach "$mountPoint"
    /bin/rm -rf "$mountPoint"
  fi
  /bin/rm -rf "$downloadPath"

}

# -------------------------------------------------------------------------------------------------
# Software Installation

# install app via vendor-hosted installer file
installFromURL "$url"

exit 0
