.syntax unified
.thumb

.global Q512B

.type Q512B, %function

@ Constants definition
.equ LOWER_MIN, 0x61
.equ LOWER_MAX, 0x7A
.equ UPPER_MIN, 0x41
.equ UPPER_MAX, 0x5A
.equ MODE, 1 @ 0 for all lower case, 1 for all upper case

.data
@ define variables
ascii_string: .asciz "GROup3" @ Define a null-terminated string



.text
@ define text


@ this is the entry function called from the startup file

Q512B:

	LDR R1, =ascii_string  @ the address of the string
	MOV R2, #MODE @ Load the value of the MODE into R2
	LDR R3, =0x00

	CMP R2, #0x00
	BEQ lowercase_loop

	CMP R2, #0x01
	BEQ uppercase_loop

lowercase_loop:
	LDRB R4, [R1, R3] @ Get the letter in the string at index R3
	ADD R3, #1		@ Increase the index by 1

	@ Check for string end
	CMP R4, #0x00
	BEQ return_main

	@ Check if letter is within the range for Uppper Case characters or not.
	@ If yes, turn them into lower case characters
	@ Skip that and go to the next letter
	CMP R4, #UPPER_MAX
	BGT lowercase_loop

	CMP R4, #UPPER_MIN
	BLT lowercase_loop

	ADD R4, #0x20 @ Turn the uppercase letter into lowercase
	SUB R5, R3, #1
	STRB R4, [R1, R5] @ Store it back into the string

	B lowercase_loop

uppercase_loop:
	LDRB R4, [R1, R3] @ Get the letter in the string at index R3
	ADD R3, #1		@ Increase the index by 1

	@ Check for string end
	CMP R4, #0x00
	BEQ return_main

	@ Check if letter is within the range for Lower Case characters or not.
	@ If yes, turn them into upper case characters
	@ Skip that and go to the next letter
	CMP R4, #LOWER_MAX
	BGT uppercase_loop

	CMP R4, #LOWER_MIN
	BLT uppercase_loop

	SUB R4, #0x20 @ Turn the lower case letter into upper case
	SUB R5, R3, #1
	STRB R4, [R1, R5] @ Store it back into the string

	B uppercase_loop

return_main:
	BX LR
