# -------------------------------------------------------
# Copyright (c) 2025 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: Apache-2.0
# -------------------------------------------------------

"""
Checks the presence of copyright notice in the files
"""

from typing import Optional, Sequence
import argparse
import os
import sys
import re
import magic
import logging
from comment_parser import comment_parser

LICENSE_TEXT = "SPDX-License-Identifier: Apache-2.0"

def check_file(filename: str, copyright_reg_exp: re.Pattern) -> int:
    """
    Checks a file for the presence of a copyright and license notice.
    Returns 0 if both are found, 1 otherwise.
    """
    if os.path.getsize(filename) == 0:
        logging.info(f"Skipping empty file: {filename}")
        return 0

    try:
        mime_type = magic.from_file(filename, mime=True)
    except Exception as e:
        logging.error(f"Could not determine MIME type for {filename}: {e}")
        return 1

    if mime_type == "text/plain":
        mime_type = "text/x-go"

    copyrightfound = False
    licensefound = False
    comments = ""
    try:
        for comment in comment_parser.extract_comments(filename, mime=mime_type):
            comments += comment.text() + '\n'
    except Exception as e:
        logging.error(f"Failed to parse comments in {filename}: {e}")
        return 1

    if copyright_reg_exp.search(comments):
        copyrightfound = True
    if LICENSE_TEXT in comments:
        licensefound = True

    if copyrightfound and licensefound:
        return 0

    errstr = ""
    if not copyrightfound:
        errstr += "\n\t # Missing or invalid copyright text."
    if not licensefound:
        errstr += "\n\t # Missing or invalid license text. Please write : " + LICENSE_TEXT

    logging.error(f"Copyright check error(s) in : {filename} {errstr}")
    return 1

def main(argv: Optional[Sequence[str]] = None) -> int:
    """
    Checks all files supplied on the command-line for copyright notices.
    Returns non-zero if any file is missing a valid notice.
    """
    parser = argparse.ArgumentParser(description="Check copyright and license headers in files.")
    parser.add_argument('--copyright-text', type=str, help="Copyright text to check")
    parser.add_argument('filenames', nargs='*', help="Files to check")
    args = parser.parse_args(argv)

    logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
    logging.info("Checking copyright headers...")

    if not args.copyright_text:
      logging.error("No copyright text provided. Please set the copyright-text input in the workflow.")
      return 1

    ret = 0
    copyright_reg_exp = re.compile(re.escape(args.copyright_text))
    # copyright_reg_exp = re.compile(r"Copyright\s\(c\)\s(19|20)\d{2}\b")

    checked_files = 0
    for filename in args.filenames:
        checked_files += 1
        ret |= check_file(filename, copyright_reg_exp)

    logging.info(f"Checked {checked_files} file(s).")
    if ret != 0:
        logging.error(">> error: One or more files are missing a valid copyright header")

    return ret

if __name__ == '__main__':
    sys.exit(main())
