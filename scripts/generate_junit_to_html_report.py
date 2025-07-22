# -------------------------------------------------------
# Copyright (c) 2025 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: Apache-2.0
# -------------------------------------------------------

"""
Cross-Platform Test Report Generator

This script parses JUnit-style XML test result files from multiple platforms,
aggregates their outcomes, and generates a unified HTML report with visual
indicators (emojis) for pass, fail, skipped, or missing test statuses.

Key Features:
- Parses XML test result files recursively from a specified directory
- Groups test results by class and test case
- Collates results from different platforms into a pivot table
- Generates an easy-to-read HTML report

Usage:
    python cross_platform_report.py \
        --test_report_dir path/to/test-results \
        --report_header "My Project Tests" \
        --output_file results.html

Arguments:
- --test_report_dir: Root directory containing platform-specific test result XML files.
                     The script expects subdirectories named like 'test-results-linux',
                     'test-results-windows', etc.
- --report_header:   (Optional) Custom title for the HTML report. Defaults to 'Cross-Platform Test'.
- --output_file:     (Optional) Output HTML file name. Defaults to 'cross_platform_report.html'.
"""

import os
import sys
import glob
import argparse
import xml.etree.ElementTree as ET
import pandas as pd

# -------------------------
# Emoji legend
# -------------------------
EMOJI_MAP = {
    "PASS": "✅",
    "FAIL": "❌",
    "SKIPPED": "⚠️",
    "MISSING": "🚫"
}

# -------------------------
# Argument parsing
# -------------------------
def parse_args():
    parser = argparse.ArgumentParser(
        description="Generate a cross-platform HTML test report."
    )
    parser.add_argument(
        "--test_report_dir", required=True,
        help="Directory containing test result XML files"
    )
    parser.add_argument(
        "--report_header", default="Cross-Platform Test",
        help="Title for the HTML report"
    )
    parser.add_argument(
        "--output_file", default="cross_platform_report.html",
        help="Filename for the HTML output"
    )
    return parser.parse_args()

# -------------------------
# XML parsing & result collection
# -------------------------
def collect_results(input_folder: str) -> pd.DataFrame:
    if not os.path.isdir(input_folder):
        raise NotADirectoryError(f"'{input_folder}' is not a directory.")

    xml_files = glob.glob(os.path.join(input_folder, "**", "*.xml"), recursive=True)
    if not xml_files:
        raise FileNotFoundError(f"No XML files found in '{input_folder}'.")

    records = []
    for path in xml_files:
        platform = os.path.basename(os.path.dirname(path)).replace("test-results-", "")
        try:
            tree = ET.parse(path)
            for tc in tree.findall(".//testcase"):
                classname = tc.attrib.get("classname", "unknown.class")
                name = tc.attrib.get("name", "unknown.test")
                if tc.find("failure") is not None:
                    status = "FAIL"
                elif tc.find("skipped") is not None:
                    status = "SKIPPED"
                else:
                    status = "PASS"
                records.append({
                    "classname": classname,
                    "testcase": name,
                    "platform": platform,
                    "status": status
                })
        except ET.ParseError as e:
            print(f"Warning: Could not parse XML: {path} — {e}")
        except Exception as e:
            print(f"Error processing '{path}': {e}")

    if not records:
        raise ValueError("No valid test results found.")

    return pd.DataFrame(records)

# -------------------------
# Pivot & formatting
# -------------------------
def build_pivot(df: pd.DataFrame) -> pd.DataFrame:
    pivot = df.pivot_table(
        index=["classname", "testcase"],
        columns="platform",
        values="status",
        aggfunc="first",
        fill_value="MISSING"
    ).reset_index()

    # Remove the column index name to avoid extra header cell
    pivot.columns.name = None

    # Replace statuses with emojis
    for col in pivot.columns[2:]:
        pivot[col] = pivot[col].map(EMOJI_MAP).fillna(EMOJI_MAP["MISSING"])

    pivot.insert(0, "S.No", range(1, len(pivot) + 1))
    return pivot

# -------------------------
# HTML report generation
# -------------------------
def generate_html(pivot: pd.DataFrame, title: str) -> str:
    html_table = pivot.to_html(
        index=False, header=True, border=0, escape=False
    )
    html = f"""
<html>
<head>
    <meta charset=\"utf-8\">
    <title>{title}</title>
    <style>
        body {{ font-family: sans-serif; padding: 2em; }}
        table {{ border-collapse: collapse; width: 100%; }}
        th {{ border: 1px solid #ccc; padding: 6px 12px; background-color: #f8f8f8; text-align: center; }}
        td {{ border: 1px solid #ccc; padding: 6px 12px; }}
        th:nth-child(1), th:nth-child(2), th:nth-child(3),
        td:nth-child(1), td:nth-child(2), td:nth-child(3) {{ text-align: left; }}
        th:nth-child(n+4), td:nth-child(n+4) {{ text-align: center; }}
        .legend {{ margin: 1em 0; }}
    </style>
</head>
<body>
    <h1>{title}</h1>
    <div class=\"legend\"><strong>Legend:</strong> ✅ = Pass, ❌ = Fail, ⚠️ = Skipped, 🚫 = Missing</div>
    {html_table}
</body>
</html>
"""
    return html

# -------------------------
# Main entrypoint
# -------------------------
def main():
    args = parse_args()
    title = args.report_header.strip().title() + " Report"
    try:
        df = collect_results(args.test_report_dir)
        pivot = build_pivot(df)
        html = generate_html(pivot, title)
        with open(args.output_file, "w", encoding="utf-8") as f:
            f.write(html)
        print(f"✅ Report generated: {args.output_file}")
    except (NotADirectoryError, FileNotFoundError, ValueError) as e:
        print(f"Error: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error: {e}")
        sys.exit(2)

if __name__ == "__main__":
    main()
