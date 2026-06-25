#!/usr/bin/env bash
# check-close-ready.sh <index.md>
#
# Thin read-only close-readiness check for an epic index.md.
# Asserts ALL of:
#   - frontmatter opens on line 1 and has a closing --- delimiter (A3)
#   - ## Phases section exists in the BODY (not inside frontmatter — C1)
#   - exactly one ## Phases section in the body
#   - >= 1 phase row with numeric first column (A2)
#   - every phase row Status cell == done (column located by header label, not index)
#   - in-table non-| rows fail loud, not silently skipped (A2)
#   - epic frontmatter status EQUALS 'done' (not just in-enum — A1)
#   - epic frontmatter started is present
#   - epic frontmatter landed is present, valid YYYY-MM-DD, and calendar-shaped (A4)
#   - required frontmatter keys (slug/status/started) present and not duplicated
#   - no duplicate frontmatter keys overall
#   - no duplicate ## Phases section
#
# Prints its result (evidence) and exits non-zero on any violation, naming the fault.
# Usage: bash check-close-ready.sh path/to/index.md
# Requires: bash 3.2+, awk, grep, sed (all standard on macOS/Linux)
set -uo pipefail

FILE="${1:-}"
if [[ -z "$FILE" ]]; then
    echo "ERROR: usage: check-close-ready.sh <index.md>" >&2
    exit 1
fi
if [[ ! -f "$FILE" ]]; then
    echo "ERROR: file not found: $FILE" >&2
    exit 1
fi

ERRORS=()

fail() {
    ERRORS+=("$1")
}

content=$(<"$FILE")

# ---------------------------------------------------------------------------
# 1. Extract YAML frontmatter (lines between first pair of --- delimiters)
#    and document body (everything AFTER the closing --- delimiter).
#    C1 fix: ## Phases must be located only in the BODY, not in the frontmatter.
# ---------------------------------------------------------------------------
frontmatter=$(awk '
    /^---$/ { if (depth==0) { depth=1; next } else { exit } }
    depth==1 { print }
' "$FILE")

# body = lines after the closing --- (skip opening --- on line 1, the frontmatter
# content, and the closing ---; print everything that follows)
body=$(awk '
    /^---$/ {
        count++
        if (count == 2) { in_body=1; next }
        next
    }
    in_body { print }
' "$FILE")

if [[ -z "$frontmatter" ]]; then
    fail "No YAML frontmatter block found"
fi

# A3: Require frontmatter to open on line 1 AND have a closing ---
# A missing closing --- means the frontmatter block is unclosed (malformed).
_first_line=$(head -1 "$FILE")
if [[ "$_first_line" != "---" ]]; then
    fail "Frontmatter must open on line 1 (first line must be '---', got: '$_first_line')"
fi
# Check that there is a closing --- after line 1 (the frontmatter terminator)
_has_close_delim=$(awk 'NR==1{next} /^---$/{found=1; exit} END{print found+0}' "$FILE")
if [[ "$_has_close_delim" -lt 1 ]]; then
    fail "Frontmatter has no closing '---' delimiter"
fi

# ---------------------------------------------------------------------------
# 2. Check for duplicate frontmatter keys
# ---------------------------------------------------------------------------
# Extract key names from frontmatter — require proper YAML "key: value" syntax
# (key followed by optional spaces then ": " with whitespace/EOL after the colon).
# "key:value" (no space) is a plain scalar in YAML, not a mapping — ignore it.
dup_keys=$(echo "$frontmatter" | grep -E '^[a-zA-Z_][a-zA-Z0-9_]*[ \t]*:([ \t]|$)' \
    | sed 's/[ \t]*:.*//' \
    | sort | uniq -d)
if [[ -n "$dup_keys" ]]; then
    while IFS= read -r k; do
        fail "Duplicate frontmatter key: $k"
    done <<< "$dup_keys"
fi

# ---------------------------------------------------------------------------
# 3. Required frontmatter keys: slug, status, started, landed
# ---------------------------------------------------------------------------
# Require proper YAML key: value syntax — the colon must be followed by
# whitespace or EOL. "key:value" (no space after colon) is a plain scalar
# in YAML, not a mapping entry, so it must not match.
_get_fm_value() {
    local k="$1"
    echo "$frontmatter" | grep -E "^${k}[ \t]*:([ \t]|$)" \
        | sed "s/^${k}[ \t]*:[ \t]*//" \
        | tr -d '\r' \
        | head -1
}

slug_val=$(_get_fm_value "slug")
status_val=$(_get_fm_value "status")
started_val=$(_get_fm_value "started")
landed_val=$(_get_fm_value "landed")

if [[ -z "$slug_val" ]]; then
    fail "Missing required frontmatter key: slug"
fi
if [[ -z "$status_val" ]]; then
    fail "Missing required frontmatter key: status"
fi
# Shared date validator: check YYYY-MM-DD shape, then real calendar validity via python3.
# Usage: _validate_date <field_name> <value>
# Calls fail() on any violation; returns 0 on a real date.
_validate_date() {
    local field="$1" value="$2"
    if ! echo "$value" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
        fail "Invalid $field date format: '$value' (required: YYYY-MM-DD)"
        return
    fi
    if ! python3 -c \
        'import sys,datetime; y,m,d=map(int,sys.argv[1].split("-")); datetime.date(y,m,d)' \
        "$value" 2>/dev/null; then
        fail "Invalid $field date (not a real calendar date): '$value'"
    fi
}

if [[ -z "$started_val" ]]; then
    fail "Missing required frontmatter key: started"
else
    _validate_date "started" "$started_val"
fi

# ---------------------------------------------------------------------------
# 4. Status must equal 'done' (A1: not just in-enum; the close-check runs
#    after the agent stamps status=done, so its job is to catch a missing stamp)
# ---------------------------------------------------------------------------
if [[ -n "$status_val" ]]; then
    if [[ "$status_val" != "done" ]]; then
        fail "Epic status must be 'done' at close, got: '$status_val'"
    fi
fi

# ---------------------------------------------------------------------------
# 5. landed present and YYYY-MM-DD with real calendar validity (A4)
# ---------------------------------------------------------------------------
# Check if landed key exists at all (even if empty) — require proper YAML syntax
landed_line=$(echo "$frontmatter" | grep -E "^landed[ \t]*:([ \t]|$)" | head -1 || true)
if [[ -z "$landed_line" ]]; then
    fail "Missing required frontmatter key: landed"
elif [[ -z "$landed_val" ]]; then
    fail "Missing required frontmatter key: landed (key exists but value is empty)"
else
    _validate_date "landed" "$landed_val"
fi

# ---------------------------------------------------------------------------
# 6. Exactly one ## Phases section — scanned in BODY only (C1: not frontmatter)
# ---------------------------------------------------------------------------
phases_count=$(echo "$body" | grep -cE '^## Phases[[:space:]]*$' || true)
if [[ "$phases_count" -eq 0 ]]; then
    fail "No '## Phases' section found"
elif [[ "$phases_count" -gt 1 ]]; then
    fail "Duplicate '## Phases' sections found: $phases_count"
fi

# ---------------------------------------------------------------------------
# 7. Extract and validate the Phases table (only if exactly one ## Phases section)
# ---------------------------------------------------------------------------
data_rows_count=0

if [[ "$phases_count" -eq 1 ]]; then
    # Extract lines from ## Phases to next ## heading (or EOF) — from BODY only
    phases_block=$(echo "$body" | awk '
        /^## Phases[[:space:]]*$/ { in_phases=1; next }
        in_phases && /^## / { exit }
        in_phases { print }
    ')

    # A2: parse ONE contiguous table.
    # Find the first | line (header start). Once the table has started (after
    # the first | line), any non-| non-blank line inside the contiguous table
    # region is a malformed in-table row — fail loud (do NOT silently skip).
    # The table ends at the first blank line (or non-| non-blank) after the header.
    table_rows=""
    in_table=0
    table_ended=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^\| ]]; then
            if [[ "$table_ended" -eq 1 ]]; then
                # A second table block after a gap — not expected, treat as stray
                fail "Unexpected '|'-line after Phases table ended (possible malformed second table): $line"
                break
            fi
            in_table=1
            if [[ -n "$table_rows" ]]; then
                table_rows="${table_rows}"$'\n'"${line}"
            else
                table_rows="$line"
            fi
        elif [[ -n "$line" ]]; then
            # Non-empty, non-| line
            if [[ "$in_table" -eq 1 && "$table_ended" -eq 0 ]]; then
                # We are inside the table — this is a malformed in-table row (A2)
                fail "Malformed in-table row (not '|'-delimited) in '## Phases': $line"
            fi
        else
            # Blank line: if we were in the table, mark it as ended
            if [[ "$in_table" -eq 1 ]]; then
                table_ended=1
            fi
        fi
    done <<< "$phases_block"

    if [[ -z "$table_rows" ]]; then
        fail "No table found in '## Phases' section"
    else
        # Count table rows
        total_rows=$(echo "$table_rows" | wc -l | tr -d ' ')

        if [[ "$total_rows" -lt 1 ]]; then
            fail "No table found in '## Phases' section"
        else
            # Parse header row (first line of table_rows)
            header_row=$(echo "$table_rows" | head -1)

            # Parse header cells using awk
            # Split on |, trim, collect non-empty
            header_cells=$(echo "$header_row" | awk -F'|' '{
                for (i=2; i<=NF-1; i++) {
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i)
                    if ($i != "") print $i
                }
            }')

            header_width=$(echo "$header_cells" | grep -c '.' || true)

            # Find Status column (1-based index among non-empty header cells)
            status_col=0
            status_col_count=0
            col_idx=0
            while IFS= read -r cell; do
                col_idx=$((col_idx + 1))
                if [[ "$cell" == "Status" ]]; then
                    status_col=$col_idx
                    status_col_count=$((status_col_count + 1))
                fi
            done <<< "$header_cells"

            if [[ $status_col_count -eq 0 ]]; then
                fail "No 'Status' header found in Phases table"
            elif [[ $status_col_count -gt 1 ]]; then
                fail "Duplicate 'Status' header found in Phases table"
            fi

            # Process data rows: skip header (row 1) and separator row(s) (lines with only ---|)
            data_row_num=0
            row_num=0
            while IFS= read -r row; do
                row_num=$((row_num + 1))
                if [[ $row_num -eq 1 ]]; then
                    continue  # skip header row
                fi
                # Skip separator rows (contain only dashes, pipes, spaces, colons)
                if echo "$row" | grep -qE '^\|[-| :]+\|?$'; then
                    continue
                fi
                data_row_num=$((data_row_num + 1))

                # A2: first column (phase number) must be numeric
                phase_num_cell=$(echo "$row" | awk -F'|' '{
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
                    print $2
                }')
                if ! echo "$phase_num_cell" | grep -qE '^[0-9]+$'; then
                    fail "Phase row first column must be a number, got: '$phase_num_cell' in row: $row"
                fi

                # Count cells (including possible empty cells between pipes)
                row_width=$(echo "$row" | awk -F'|' '{print NF-2}')

                if [[ "$row_width" -ne "$header_width" ]]; then
                    fail "Phase row width ($row_width) does not match header width ($header_width): $row"
                elif [[ $status_col -gt 0 ]]; then
                    # Get the status_col-th cell (1-based)
                    phase_status=$(echo "$row" | awk -F'|' -v col="$((status_col + 1))" '{
                        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $col)
                        print $col
                    }')
                    if [[ "$phase_status" != "done" ]]; then
                        fail "Phase row Status is not 'done': '$phase_status' in row: $row"
                    fi
                fi
            done <<< "$table_rows"

            data_rows_count=$data_row_num

            if [[ $data_rows_count -eq 0 ]]; then
                fail "Phases table has zero data rows (empty table must not pass as 'all done')"
            fi
        fi
    fi
fi

# ---------------------------------------------------------------------------
# Print result (evidence)
# ---------------------------------------------------------------------------
echo "=== check-close-ready: $FILE ==="
echo "  slug:    ${slug_val:-<missing>}"
echo "  status:  ${status_val:-<missing>}"
echo "  started: ${started_val:-<missing>}"
echo "  landed:  ${landed_val:-<missing>}"
echo "  phases_sections: $phases_count"
echo "  data_rows: $data_rows_count"

if [[ ${#ERRORS[@]} -gt 0 ]]; then
    echo ""
    echo "FAIL — close-readiness check failed (${#ERRORS[@]} fault(s)):"
    for e in "${ERRORS[@]}"; do
        echo "  - $e"
    done
    exit 1
else
    echo ""
    echo "PASS — all close-readiness checks passed."
    exit 0
fi
