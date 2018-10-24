#!/bin/bash

# Stage a txt file containing a URL for a vendor-hosted software installer file

# Stage URL passed in as $4
/bin/echo "$4" > /Library/Application\ Support/JAMF/.installFromURL.txt

exit 0
