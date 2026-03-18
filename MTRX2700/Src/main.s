.syntax unified
.thumb

#include "string.s"

.global main

.type main, %function

@ Task 5.1.2 Constants
.equ LOWER_MODE, 0x00 @ Turning all letters to lower case
.equ UPPER_MODE, 0x01 @ Turning all letters to upper case



.data
@ define variables
string1: .asciz "GROUP 3"
buffer: .space 128 @ Free space in the memory for temporary used


.text
@ define text


main:
	LDR R1, =string1

	@ Task 5.1.2a
	BL str_reset_counter
	BL str_count

	@ Task 5.1.2b
	MOV R2, #LOWER_MODE @ Choose a mode for the task here
	MOV R3, #0x0 @ Let R3 now be the counter value in this task, set it to be 0 initially

	CMP R2, #LOWER_MODE
	BEQ _call_lower @ If you choose lower case mode, branch to this function
	CMP R2, #UPPER_MODE
	BEQ _call_upper @ If you choose upper case mode, branch to this function
	B  continue_from_512b  @ No matching mode, skip task 5.1.2b

continue_from_512b:

	@ Task 5.1.2c
	LDR R0, =string1 @ Let R0 point to the string
	LDR R1, =buffer @ Let R1 point to the new address

	BL str_reset_counter @ Let use R2 as counter for string letters, hence, we need to reset its value to 0
	BL str_concat

	@ Task 5.1.2d
	@ Assuming that the value of length from part c) is not adjusted yet
	MOV R4, R2 @ Checksum byte goes at index R2 (right after ETX)
	ADDS R2, R2, #1 @ Increase total length by 1 to include checksum byte
	MOV R5, #0x00 @ Let use R5 as the counter to loop through the buffer string this time
	MOV R3, #0x00 @ Set the default value of the checksum to be 0, so it won't affect the final value after a series of XOR

	BL str_checksum

	@ Task 5.1.2e
	MOV R5, #0x00 @ Reset the counter value to be 0
	MOV R3, #0x00 @ Reset the value of R3 to be 0, if the checksum is correct, it should stay at zero after function
	BL str_verify_checksum

	B end

_call_lower:
    BL str_lower_case
    B  continue_from_512b

_call_upper:
    BL str_upper_case
    B  continue_from_512b

end:
	@ End here, inf loop
	B end



