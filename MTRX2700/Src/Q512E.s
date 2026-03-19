.syntax unified
.thumb

.global Q512E

.type Q512E, %function


@ Constant definition
.equ DEFAULT_CHECKSUM, 0x00 @ Incase there is only 1 byte => Check sum = byte_1 XOR DEFAULT_CHECKSUM = byte_1

.data
@ define variables
ascii_string: .asciz "\x02\x13Group3istheBEST\x03\x1D" @ where 0x02, 0x03 stands for STX, ETX and 0x13 (Dec: 19) stands
@ for the length of the string, including STX, ETX, length, CHECKSUM and body string
new_address: .space 128

.text
@ define text


@ this is the entry function called from the startup file

Q512E:
	LDR R1, =ascii_string @ Get the buffer string address
	LDRB R2, [R1, #1] @ Get the length from the buffer string
	MOV R4, #0x00 @ Set the counter used to iterate through the string
	MOV R7, #DEFAULT_CHECKSUM @ Set the default value for CHECKSUM (0x00)
	MOV R3, #0x00 @ Set the default value of the correctness to be 0 => False by default
	SUB R6, R2, #1 @ This is the CHECKSUM index, which is equal to length -1 (exclude the terminator at the end)

	B str_loop

str_loop:

	CMP R4, R6 @ This index is where the CHECKSUM is, we want to branch here to compare between the calculated and the saved value in the buffer
	BEQ cmp_checksum

	LDRB R5, [R1, R4] @ Getting the letter from buffer string at index R4


	@ Getting XOR value
	EOR R7, R7, R5

	@ Move to the next letter
	ADD R4,#1

	B str_loop

cmp_checksum:
	LDRB R5, [R1, R4]
	CMP R7, R5 @ compare the CHECKSUM value being calculated vs the one save in the string
	BNE return_main

	MOV R3, #0x01 @ Set value of R3 to 1 to indicate correct checksum

return_main:
	BX LR



