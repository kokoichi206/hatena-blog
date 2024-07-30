#!/bin/bash
#
# Description:
#   Upload a blog entry to Hatena Blog.
#
# Usage:
#   $ ./upload.sh <api_key> <content_file>

set -euo pipefail

HATENA_ID="kokoichi206"
BLOG_ID="koko206.hatenablog.com"

AUTHOR="kokoichi206"
UPDATED_DATE="$(date +"%Y-%m-%dT%H:%M:%S")"
DRAFT="yes"
PREVIEW="yes"

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <api_key> <content_file>"
    exit 1
fi

# API Key: https://blog.hatena.ne.jp/-/config
API_TOKEN="$1"
CONTENT_FILE="$2"

# check if the file exists.
if [ ! -f "$CONTENT_FILE" ]; then
    echo "File not found: $CONTENT_FILE"
    exit 1
fi

# Assuming the following format.
# # Title
# (empty line)
# Content
TITLE=$(awk 'NR==1 {if ($0 ~ /^# /) {sub(/^# /, ""); print} else {print ""}}' "$CONTENT_FILE")
# convert the image URL to the one that can be served from GitHub.
CONTENT=$(awk 'NR>2' "$CONTENT_FILE" | sed -E 's@./img/(.*)\)@https://github.com/kokoichi206/hatena-blog/blob/main/articles/img/\1?raw=true\)@')

if [ -z "$TITLE" ]; then
    echo "Title is empty."
    cat << '#TITLE_ERROR'
We assume that the blog file follows the format below:

1. # Title
2. (empty line)
3. Content
#TITLE_ERROR
    exit 1
fi

# see: https://developer.hatena.ne.jp/ja/documents/blog/apis/atom/#%E3%83%96%E3%83%AD%E3%82%B0%E3%82%A8%E3%83%B3%E3%83%88%E3%83%AA%E3%81%AE%E6%8A%95%E7%A8%BF
curl -X POST "https://blog.hatena.ne.jp/${HATENA_ID}/${BLOG_ID}/atom/entry" \
    -u "${HATENA_ID}:${API_TOKEN}" \
    -H "Content-Type: application/atom+xml" \
    -d "<?xml version=\"1.0\" encoding=\"utf-8\"?>
<entry xmlns=\"http://www.w3.org/2005/Atom\"
       xmlns:app=\"http://www.w3.org/2007/app\">
  <title>${TITLE}</title>
  <author><name>${AUTHOR}</name></author>
  <content type=\"text/plain\">
    ${CONTENT}
  </content>
  <updated>${UPDATED_DATE}</updated>
  <app:control>
    <app:draft>${DRAFT}</app:draft>
    <app:preview>${PREVIEW}</app:preview>
  </app:control>
</entry>"
