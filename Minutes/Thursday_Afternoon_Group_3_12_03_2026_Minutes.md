# Gosh Dang Meeting Minutes

**MTRX Group #? – "Gosh Dang"**
**Date:** 12/03/2026

---

## Attendees
- Kieran
- Josh
- Milly
- Dang *(sends apologies for the first hour of the tutorial)*

---

## Meeting Purpose
MTRX lab session – continuing work on lab tasks 5.1.2 and 5.2.2, including LED pattern control, button incrementing, debouncing, and bidirectional counting.

---

## Previous Actions
- Complete any pre-work before the next lab session.
- Familiarise with each new software.

---

## Current Items
- The group decided to skip 5.1.2 d) and e) initially, as the required code had not yet been uploaded to GitHub by Dang.
- The group began reading through 5.2.2 and worked on the first task. The example code was identified as closely relevant, so the group analysed it to understand how it could be adapted.
- Josh discovered that removing the delay on the lights prevented them from flashing, causing the code to loop quickly enough to make all LEDs appear constantly on.
- The group identified the need to stop the code from looping. After adjusting the code, they were able to create custom LED patterns by changing the value loaded into R4.
- The group moved on to task 5.2.2 b) and encountered difficulty using the button to increment through the LEDs.
- Milly suggested incorporating code from the previous week as a counter and integrating the button with it.
- Josh worked out how to load a number (rather than a bitmask) into R4 and incorporate the increment logic.
- The group noticed the button was registering but not incrementing through. Milly suggested placing the button function before the program loop so it executes once per button press.
- Dang arrived and worked on resolving his GitHub access, which had not worked in the previous session.
- The group decided to complete 5.2.2 b) before returning to 5.1.2 d) and e).
- Josh and Milly identified that a single line of code (a left shift logic by 8) was preventing the LEDs from incrementing correctly. Once removed, the button press began working.
- The group encountered a new issue: holding the button caused the LEDs to keep incrementing. A function was needed to wait for the button to be released before allowing another increment.
- Dang explained that the STM32 was reading the user input as continuously HIGH, causing repeated increments. A function was needed to hold the increment register until the input returned LOW.
- Josh created this function, but it was not working as expected. Milly suggested placing the "wait for release" function inside the counter function.
- The group worked through 5.1.2 d) and e) relatively quickly, having thought about the tasks at home. Dang contributed innovative ideas and was a great help.
- Kieran had read ahead through the next sections and briefed the group on what the code needed to do.
- For 5.2.2 c), Milly suggested modifying the code to compare whether the count had reached 8 or returned to 0, and creating a "compare" function that calls either "counter_up" or "counter_down" as appropriate.
- The group worked on the code together. Milly noted the importance of ensuring the code does not default to counting up, but instead continues in the current direction.
- Dang suggested setting a variable to track the current state (counting up or counting down).
- During further work, the group encountered a problem where all LEDs briefly turned off after reaching the fully-on state. Dang identified the cause: the value 256 had been entered instead of 255.
- The group celebrated with applause.
- The group worked through part d), noting that a debouncing function had already been created. They adjusted the debounce value to demonstrate its effect.
- For part e), the group determined it could be run similarly to part a), with a dedicated function created for it. The group worked on this code accordingly.
- Kieran came up with the group name "Gosh Dang." Milly subsequently updated the titles on the previous meeting minutes.

---

## New Items
- No new items raised.

---

## Action Items
- To get back on the tutor-provided time schedule, all members to work through parts 5.3.2 and 5.4.2 at home and come prepared to discuss in the next tutorial.

---

## Next Meeting Date
19/03/2026
