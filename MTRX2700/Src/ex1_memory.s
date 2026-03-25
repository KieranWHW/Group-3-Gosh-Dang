.syntax unified
.thumb

@ =============================================
@ Exercise 1 — Memory and Pointers (5.1.2)
@ =============================================
@ Demonstrates string length, case conversion,
@ packet framing (STX/ETX), BCC checksum, and
@ checksum verification using str_ helper functions.

@ Task mode constants for case conversion (5.1.2b)
.equ LOWER_MODE, 0x00   @ convert all letters to lower case
.equ UPPER_MODE, 0x01   @ convert all letters to upper case

@ Change this to UPPER_MODE to demonstrate the other direction in 5.1.2b
.equ EX1_CASE_MODE, LOWER_MODE


.data
string1: .asciz "GROUP 3"   @ source string for all Exercise 1 tasks
buffer:  .space 128         @ working buffer for packet framing


.text


@ ========== Demo Entry Point ==========

@ Run all Exercise 1 sub-tasks in sequence
@ Demonstrates string length, case conversion, packet framing,
@ checksum computation and checksum verification
@   + Input: None
@   + Output: None
@   + Modifies: R0-R4 (R4 saved/restored)
@ Register map:
@   R0 = source string pointer  (input to str_concat)
@   R1 = destination buffer pointer (set once, reused across str_ calls)
@   R2 = counter / length       (str_ functions use R2 as counter)
@   R3 = checksum accumulator   (str_checksum / str_verify_checksum output)
@   R4 = saved mode flag for case selection (caller-saved register)
.type ex1_run_demo, %function
ex1_run_demo:
    PUSH {R4, LR}

    @ ===== Task 5.1.2a — calculate string length =====
    LDR R1, =string1
    BL str_reset_counter        @ R2 = 0
    BL str_count                @ R2 = length of string1 (not including NULL)

    @ ===== Task 5.1.2b — convert string case based on mode =====
    MOV R4, #EX1_CASE_MODE      @ R4 = chosen mode (change .equ above to switch)
    MOV R3, #0x0                @ R3 = index counter, start at 0

    CMP R4, #LOWER_MODE
    BEQ ex1_do_lower
    BL str_upper_case           @ convert all letters to upper case in place
    B ex1_case_done

ex1_do_lower:
    BL str_lower_case           @ convert all letters to lower case in place

ex1_case_done:
    @ ===== Task 5.1.2c — format packet [STX][Len][Body][ETX] =====
    LDR R0, =string1            @ R0 = source string
    LDR R1, =buffer             @ R1 = destination buffer
    BL str_reset_counter        @ R2 = 0
    BL str_concat               @ R2 = total packet length

    @ ===== Task 5.1.2d — compute and append BCC checksum =====
    BL str_checksum             @ R3 = checksum value, appended to buffer
                                @ R2 = updated length (now includes checksum byte)

    @ ===== Task 5.1.2e — verify the checksum (R3 = 0x00 if valid) =====
    @ R1 = buffer, R2 = full packet length (set by str_checksum above)
    BL str_verify_checksum      @ R3 = 0x00 means packet is intact

    POP {R4, PC}
