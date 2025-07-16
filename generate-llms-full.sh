#!/bin/bash

# Script to generate docs/llms-full.txt by concatenating markdown files in nav_order sequence

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Output file
OUTPUT_FILE="docs/llms-full.txt"

# Temporary file for sorting
TEMP_FILE=$(mktemp)

echo -e "${YELLOW}Generating llms-full.txt...${NC}"

# Function to extract nav_order from a markdown file
get_nav_order() {
    local file=$1
    # Extract nav_order from frontmatter
    # Look for nav_order between --- markers
    awk '/^---$/ { if (++count == 1) next } /^---$/ { if (count == 1) exit } count == 1 && /^nav_order:/ { gsub(/nav_order:[ ]*/, ""); print; exit }' "$file"
}

# Function to extract content without frontmatter
get_content() {
    local file=$1
    # Skip content between first two --- markers
    awk '/^---$/ { if (++count == 2) { getline; skip = 0 } else skip = 1; next } !skip { print }' "$file"
}

# Clear the temp file
> "$TEMP_FILE"

# Find all markdown files and their nav_order
echo -e "${GREEN}Finding markdown files...${NC}"

# Process index.md first if it exists
if [ -f "index.md" ]; then
    nav_order=$(get_nav_order "index.md")
    if [ -n "$nav_order" ]; then
        echo -e "${nav_order}:index.md" >> "$TEMP_FILE"
        echo "  Found: index.md (nav_order: $nav_order)"
    fi
fi

# Process all .md files in docs directory
for file in docs/*.md; do
    # Skip llms.txt and llms-full.txt
    if [[ "$file" == "docs/llms.txt" ]] || [[ "$file" == "docs/llms-full.txt" ]]; then
        continue
    fi
    
    if [ -f "$file" ]; then
        nav_order=$(get_nav_order "$file")
        if [ -n "$nav_order" ]; then
            echo -e "${nav_order}:${file}" >> "$TEMP_FILE"
            echo "  Found: $file (nav_order: $nav_order)"
        else
            echo -e "${YELLOW}  Warning: No nav_order found in $file, skipping${NC}"
        fi
    fi
done

# Sort by nav_order and concatenate content
echo -e "${GREEN}Concatenating files in nav_order sequence...${NC}"

# Clear the output file before writing
> "$OUTPUT_FILE"

# Sort numerically by nav_order and process each file
first=true
sort -n -t':' -k1 "$TEMP_FILE" | while IFS=':' read -r order file; do
    echo -e "  Processing: $file (nav_order: $order)"
    
    # Add newline between files (but not before the first one)
    if [ "$first" = true ]; then
        first=false
    else
        echo >> "$OUTPUT_FILE"
    fi
    
    # Add content to output file
    get_content "$file" >> "$OUTPUT_FILE"
done

# Remove trailing newlines
# Use a more portable approach
perl -i -0777 -pe 's/\n+$/\n/' "$OUTPUT_FILE" 2>/dev/null || true

# Clean up
rm -f "$TEMP_FILE"

# Report results
if [ -f "$OUTPUT_FILE" ]; then
    line_count=$(wc -l < "$OUTPUT_FILE")
    file_size=$(du -h "$OUTPUT_FILE" | cut -f1)
    echo -e "${GREEN}✓ Successfully generated $OUTPUT_FILE${NC}"
    echo -e "  Lines: $line_count"
    echo -e "  Size: $file_size"
else
    echo -e "${RED}✗ Failed to generate $OUTPUT_FILE${NC}"
    exit 1
fi