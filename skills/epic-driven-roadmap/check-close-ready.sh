#!/usr/bin/env bash
# check-close-ready.sh <index.md>
#
# Thin read-only close-readiness check for an epic index.md.
# Asserts ALL of:
#   - exactly one ## Phases section
#   - >= 1 phase row
#   - every phase row Status cell == done (column located by header label, not index)
#   - epic frontmatter status in {proposed,active,paused,done,cancelled}
#   - epic frontmatter started is present
#   - epic frontmatter landed is present and valid YYYY-MM-DD
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
# ---------------------------------------------------------------------------
frontmatter=$(awk '
    /^---$/ { if (depth==0) { depth=1; next } else { exit } }
    depth==1 { print }
' "$FILE")

if [[ -z "$frontmatter" ]]; then
    fail "No YAML frontmatter block found"
fi

# ---------------------------------------------------------------------------
# 2. Check for duplicate frontmatter keys
# ---------------------------------------------------------------------------
# Extract key names from frontmatter (lines like "key: value")
dup_keys=$(echo "$frontmatter" | grep -E '^[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*:' \
    | sed 's/[[:space:]]*:.*//' \
    | sort | uniq -d)
if [[ -n "$dup_keys" ]]; then
    while IFS= read -r k; do
        fail "Duplicate frontmatter key: $k"
    done <<< "$dup_keys"
fi

# ---------------------------------------------------------------------------
# 3. Required frontmatter keys: slug, status, started, landed
# ---------------------------------------------------------------------------
_get_fm_value() {
    local k="$1"
    echo "$frontmatter" | grep -E "^${k}[[:space:]]*:" \
        | sed "s/^${k}[[:space:]]*:[[:space:]]*//" \
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
if [[ -z "$started_val" ]]; then
    fail "Missing required frontmatter key: started"
fi

# ---------------------------------------------------------------------------
# 4. Status enum check
# ---------------------------------------------------------------------------
if [[ -n "$status_val" ]]; then
    case "$status_val" in
        proposed|active|paused|done|cancelled) ;;
        *)
            fail "Invalid epic status enum value: '$status_val' (allowed: proposed|active|paused|done|cancelled)"
            ;;
    esac
fi

# ---------------------------------------------------------------------------
# 5. landed present and YYYY-MM-DD
# ---------------------------------------------------------------------------
# Check if landed key exists at all (even if empty)
landed_line=$(echo "$frontmatter" | grep -E "^landed[[:space:]]*:" | head -1 || true)
if [[ -z "$landed_line" ]]; then
    fail "Missing required frontmatter key: landed"
elif [[ -z "$landed_val" ]]; then
    fail "Missing required frontmatter key: landed (key exists but value is empty)"
elif ! echo "$landed_val" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
    fail "Invalid landed date format: '$landed_val' (required: YYYY-MM-DD)"
fi

# ---------------------------------------------------------------------------
# 6. Exactly one ## Phases section
# ---------------------------------------------------------------------------
phases_count=$(echo "$content" | grep -cE '^## Phases[[:space:]]*$' || true)
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
    # Extract lines from ## Phases to next ## heading (or EOF)
    phases_block=$(awk '
        /^## Phases[[:space:]]*$/ { in_phases=1; next }
        in_phases && /^## / { exit }
        in_phases { print }
    ' "$FILE")

    # Filter to table rows (lines starting with |)
    table_rows=$(echo "$phases_block" | grep -E '^\|' || true)

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

                # Parse data cells
                row_cells=$(echo "$row" | awk -F'|' '{
                    for (i=2; i<=NF-1; i++) {
                        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i)
                        print $i
                    }
                }')
                # Count non-empty from original parse (include empty cells to get width)
                # Actually we need the count of cells (including possible empty cells between pipes)
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
