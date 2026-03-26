# Gosh Dang Meeting Minutes

**MTRX Group 3 – "Gosh Dang"**
**Date:** 19/03/2026

---

## Attendees
- Kieran
- Josh
- Dang
- Milly

---

## Meeting Purpose
MTRX lab session – working on tasks 5.3.2 (UART transmission with oscilloscope verification) and 5.3.2 b) (checksum/verification code).

---

## Previous Actions
- All members to work through parts 5.3.2 and 5.4.2 at home and come prepared to discuss.

---

## Current Items
- The group began working on 5.3.2 a), starting by reviewing the example code from lectures as a reference point.
- Milly noted the task was similar to 5.3.1. Kieran noted the button function resembled work done previously in 5.3.2.
- Dang reviewed the code and identified which functions would be needed and what required modification. The group worked through the remaining code together.
- The STM32 was connected to the computer and oscilloscope. The group encountered syntax errors, and a tutor came over to assist.
- The group identified that certain elements had not been defined in the code. It was discovered that the code was referencing functions from the lecture notes examples, requiring an additional file to be added to the project for it to run correctly.
- Once resolved, the code was run again and the oscilloscope began responding to the transmission. The display was not showing the desired view, so Kieran adjusted the oscilloscope to show a single frame, successfully displaying the string transmission.
- The group moved on to adding the button press function to the code. A brief issue arose where the code was not functioning correctly, confirmed by the oscilloscope showing no activity.
- Josh identified the incorrect code. The group resolved the issue successfully.
- The group moved on to part b). Milly broke down the question. Dang suggested producing an LED output for "ACK" or "NAK." Milly and Josh disagreed with this approach but agreed that turning on an LED would be a suitable substitute.
- Milly and Josh discussed consolidating the verification code into a single file to streamline the process.
- Kieran drew the group's session slot from a box. The group was assigned to Session 3.
- Milly and Dang worked on the verification file while Kieran and Josh worked on the receiving file. The group then realised it would be more efficient to work on all code together in a single file, and switched to a collaborative approach.
- Milly suggested loading the final checksum value (derived from an existing register) into a separate register and comparing it against the desired checksum. Dang suggested an XOR operation may be a more effective method.
- The group continued working on the code and decided to verify that transmission and reading were functioning correctly before implementing the final length verification section.
- The group encountered problems with the project failing to build and spent time troubleshooting.
- The code was run and the boards were connected together, with both connected to ground. The code began working. The connection was slightly unstable, but the group gathered enough information to be confident proceeding to the remaining verification steps.

---

## New Items
- See above.

---

## Action Items
- The group agreed to meet outside of class to continue working on the code.
- All members to individually work on parts 4 and 5 outside of the lab, then meet to consolidate.

---

## Next Meeting Date
22/03/2026
