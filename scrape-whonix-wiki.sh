#!/bin/bash

if ! command -v webpage2html &>/dev/null ; then
    echo "$0: error webpage2html not available" >&2
    exit 1
fi

sudo apt install --no-install-recommends python3-bs4 python3-termcolor python3-lxml

# sudo pip3 install webpage2htm

OUTPUT_DIR="/tmp/whonix-wiki-html"
mkdir -p "$OUTPUT_DIR"

# The main map is a sitemap listing other 'sub' sitemaps
MAINMAP="https://www.whonix.org/wiki/sitemap/sitemap-index-wiki.xml"
MAINXML="$(wget -O - --quiet "$MAINMAP")"

# Get the list of sitemaps from the main map
SITEMAPS="$(echo "$MAINXML" | egrep -o "<loc>[^<>]*</loc>" | sed -e 's:</*loc>::g')"

builtin cd "$OUTPUT_DIR"

# Fetch each sitemap and scrape the URLs contained therein
for MAP in $(echo "$SITEMAPS" | tr '' '\n'); do
  XML="$(wget -O - --quiet "$MAP")"
  URLS="$(echo "$XML" | egrep -o "<loc>[^<>]*</loc>" | sed -e 's:</*loc>::g')"
  # Iterate over each URL and fetch it, along with its assets
  for URL in $(echo "$URLS" | tr ' ' '\n'); do
    # Get the name of the file (or directory structure) sans the domain name/wiki path
    SHORTNAME=$(echo "$URL" | sed -e s/'https:\/\/www.whonix.org\/wiki\/'//g)
    # We don't want 'special' pages of no real value
    if ! [[ "$SHORTNAME" =~ ^(File|Module|User|Talk|MediaWiki|Template|Template_talk|Special:Badtitle/NS1198|Widget|Category|User_talk|Module): ]]; then
      if [[ "$SHORTNAME" =~ "/" ]]; then
        # Sometimes a wiki page falls under a pseudo 'directory' structure.
        # Need to create this structure and then write the content into that structure.
        DIR="$(echo "$SHORTNAME" | cut -d/ -f1)"
        FILENAME="${SHORTNAME##*/}"
        mkdir -p "$OUTPUT_DIR/$DIR"
        # Convert the page to html, and strip the nav off altogether
        webpage2html -q "$URL" | perl -0777 -pe 's/<nav.*?<\/nav>//gs' | perl -0777 -pe 's/<style data.*?<\/style>//gs' > "$OUTPUT_DIR/$DIR/$FILENAME.html"
        # Adjust absolute links to relative links
        sed -i s/'https:\/\/www.whonix.org\/wiki'/'..'/g "$OUTPUT_DIR/$DIR/$FILENAME.html"
        # Add .html suffix to links
        sed -i s/'" title'/'.html" title'/g "$OUTPUT_DIR/$DIR/$FILENAME.html"
        sed -i '/<title>/ r style.css.subdir.template' "$OUTPUT_DIR/$DIR/$FILENAME.html"
      else
        # Same as above, but regular top-level content
        webpage2html -q "$URL" | perl -0777 -pe 's/<nav.*?<\/nav>//gs' | perl -0777 -pe 's/<style data.*?<\/style>//gs' > "$OUTPUT_DIR/$SHORTNAME.html"
        sed -i s/'https:\/\/www.whonix.org\/wiki'/'.'/g "$OUTPUT_DIR/$SHORTNAME.html"
        sed -i s/'" title'/'.html" title'/g "$OUTPUT_DIR/$SHORTNAME.html"
        sed -i '/<title>/ r style.css.template' "$OUTPUT_DIR/$SHORTNAME.html"
      fi
    fi
  done
done

