#!/bin/bash

# Script to generate llms-full.txt and update the Docs section in llms.txt

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Output files
FULL_OUTPUT="llms-full.txt"
LLMS_TXT="llms.txt"

# Temporary files
TEMP_FILE=$(mktemp)
TEMP_DOCS=$(mktemp)

echo -e "${YELLOW}Generating LLM documentation files...${NC}"

# Function to extract nav_order from a markdown file
get_nav_order() {
    local file=$1
    # Extract nav_order from frontmatter
    awk '/^---$/ { if (++count == 1) next } /^---$/ { if (count == 1) exit } count == 1 && /^nav_order:/ { gsub(/nav_order:[ ]*/, ""); print; exit }' "$file"
}

# Function to extract title from a markdown file
get_title() {
    local file=$1
    # Extract title from frontmatter
    awk '/^---$/ { if (++count == 1) next } /^---$/ { if (count == 1) exit } count == 1 && /^title:/ { gsub(/title:[ ]*/, ""); gsub(/^["'\'']|["'\'']$/, ""); print; exit }' "$file"
}

# Function to extract permalink from a markdown file
get_permalink() {
    local file=$1
    # Extract permalink from frontmatter
    awk '/^---$/ { if (++count == 1) next } /^---$/ { if (count == 1) exit } count == 1 && /^permalink:/ { gsub(/permalink:[ ]*/, ""); gsub(/^["'\'']|["'\'']$/, ""); print; exit }' "$file"
}

# Function to extract first paragraph after H1 header
get_description() {
    local file=$1
    # Skip frontmatter, find first H1, then get the next non-empty paragraph
    awk '
        /^---$/ { if (++fm == 2) ready = 1; next }
        ready && /^# / { found_h1 = 1; next }
        found_h1 && /^$/ { next }
        found_h1 && /^[^#]/ { 
            # This is the first paragraph after H1
            print $0
            exit
        }
    ' "$file"
}

# Function to extract content without frontmatter
get_content() {
    local file=$1
    # Skip content between first two --- markers
    awk '/^---$/ { if (++count == 2) { getline; skip = 0 } else skip = 1; next } !skip { print }' "$file"
}

# Clear the temp files
> "$TEMP_FILE"
> "$TEMP_DOCS"

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
for file in docs/*.md docs/**/*.md; do
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

# Generate llms-full.txt
echo -e "${GREEN}Generating $FULL_OUTPUT...${NC}"

# Clear the output file before writing
> "$FULL_OUTPUT"

# Sort numerically by nav_order and process each file
first=true
sort -n -t':' -k1 "$TEMP_FILE" | while IFS=':' read -r order file; do
    echo -e "  Processing: $file (nav_order: $order)"
    
    # Add newline between files (but not before the first one)
    if [ "$first" = true ]; then
        first=false
    else
        echo >> "$FULL_OUTPUT"
    fi
    
    # Add content to output file
    get_content "$file" >> "$FULL_OUTPUT"
done

# Generate Docs section for llms.txt
echo -e "${GREEN}Generating Docs section for $LLMS_TXT...${NC}"

# Sort by nav_order and generate docs entries
sort -n -t':' -k1 "$TEMP_FILE" | while IFS=':' read -r order file; do
    # Skip index.md for docs section
    if [[ "$file" == "index.md" ]]; then
        continue
    fi
    
    title=$(get_title "$file")
    permalink=$(get_permalink "$file")
    description=$(get_description "$file")
    
    if [ -n "$title" ] && [ -n "$permalink" ]; then
        # Build the full URL
        base_url="https://cfchase.github.io/rhoai-api-docs"
        full_url="${base_url}${permalink%/}"
        
        # Don't truncate description - use full text
        
        # Write to temp docs file
        echo "- [${title}](${full_url}): ${description}" >> "$TEMP_DOCS"
        echo -e "  Added: $title"
    fi
done

# Update llms.txt with new Docs section
echo -e "${BLUE}Updating $LLMS_TXT...${NC}"

if [ -f "$LLMS_TXT" ]; then
    # Create a backup
    cp "$LLMS_TXT" "${LLMS_TXT}.bak"
    
    # Extract content before and after Docs section
    awk '
        /^## Docs$/ { 
            print
            print ""
            # Skip old docs content until next section or EOF
            while (getline > 0 && !/^##/ && !/^#[^#]/) { }
            # Print the new docs content
            while ((getline line < "'$TEMP_DOCS'") > 0) {
                print line
            }
            close("'$TEMP_DOCS'")
            print ""
            if (/^##/ || /^#[^#]/) print
            next
        }
        { print }
    ' "${LLMS_TXT}.bak" > "$LLMS_TXT"
    
    echo -e "${GREEN}✓ Updated Docs section in $LLMS_TXT${NC}"
else
    echo -e "${RED}✗ $LLMS_TXT not found${NC}"
    exit 1
fi

# Clean up
rm -f "$TEMP_FILE" "$TEMP_DOCS" "${LLMS_TXT}.bak"

# Remove trailing newlines from llms-full.txt
perl -i -0777 -pe 's/\n+$/\n/' "$FULL_OUTPUT" 2>/dev/null || true

# Report results
echo -e "${GREEN}✓ Generation complete!${NC}"

if [ -f "$FULL_OUTPUT" ]; then
    line_count=$(wc -l < "$FULL_OUTPUT")
    file_size=$(du -h "$FULL_OUTPUT" | cut -f1)
    echo -e "  $FULL_OUTPUT: $line_count lines, $file_size"
fi

if [ -f "$LLMS_TXT" ]; then
    docs_count=$(grep -c "^- \[" "$LLMS_TXT" || true)
    echo -e "  $LLMS_TXT: Updated with $docs_count documentation links"
fi