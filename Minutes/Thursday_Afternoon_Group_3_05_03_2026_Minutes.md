# Gosh Dang Meeting Minutes

**MTRX Group 3 – "Gosh Dang"**
**Date:** 05/03/2026

---

## Attendees
- Kieran
- Dang
- Josh
- Milly

---

## Meeting Purpose
MTRX lab session – working through assignment tasks (string manipulation, ASCII/Hex case conversion, and structured message encoding).

---

## Previous Actions
- See minutes from 26/02.

---

## Current Items
- Milly suggested completing tasks based on knowledge availability rather than a fixed weekly delegation. The group agreed.
- The group reviewed the strings example and identified it contained much of the required tasks, noting it would need to be worked on and analysed.
- The group worked on Task B: iterating through a string and determining case using ASCII values. Discussed that subtracting 0x20 from a hex value changes a lowercase letter to uppercase (and vice versa).
- Dang proposed a solution to iterate through each character, check whether it falls within the uppercase or lowercase ASCII range, and adjust accordingly based on the desired output mode.
- Josh suggested each part of the assignment be stored as a separate file in the GitHub repository. The group agreed.
- The group updated the given example code to fit the task requirements.
- The code was run and encountered a brief error. Dang identified and fixed it.
- Code was confirmed to run successfully.
- Dang uploaded Part A to the GitHub repository.
- The group determined the minimum and maximum ASCII/hex values for uppercase and lowercase regions and incorporated them into the code.
- The group successfully wrote the lowercase conversion code.
- Discussed how to view the ASCII/Hex value table. Dang demonstrated how to determine the hex value of an address to find this table.
- Updated the code to include both uppercase and lowercase loops. The code now determines the desired mode and calls the corresponding loop to normalise case throughout the string.
- Both uppercase and lowercase modes were tested and confirmed to work successfully. The group celebrated.
- Began working on Part C of 5.1.2. Milly suggested using the Part A code to find the message length, then "sewing together" (term coined by Kieran) each part – using the message length added to index 2 to determine where to place ETX.
- Josh proposed using two loops: the first to determine the string length, and the second to assign characters into the defined space.
- The group realised a simpler approach: detecting where the message ends (reads nothing) and inserting ETX at that point.
- Josh noted that STX and ETX cannot be added to the original string. Instead, R2 (message length) should default to 3 (accounting for STX, length byte, and ETX), and the full framed buffer should be stored in a new memory location.
- Kieran and Dang explained the use of R2 as a pointer to the final message length value.
- The group reviewed each line of the code to ensure understanding.
- Recognised that iterating through the string and copying it to the new memory location closely mirrors the Part B code.
- Encountered issues with the string termination. Adjusted relevant parts of the code and resolved the problem.
- Dang identified the solution. The group celebrated.

---

## New Items
- See above.

---

## Action Items
- Continue working through the remaining assignment tasks in the next lab session.
- Upload all completed code files to the GitHub repository.
- All members to read through the next 3–4 tasks before the next meeting and come prepared with an understanding of the approach.

---

## Next Meeting Date
12/03/2026
