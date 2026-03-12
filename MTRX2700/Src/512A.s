.syntax unified
.thumb

.global Q512A

.type Q512A, %function


.data
@ define variables
ascii_string: .asciz "Group3" @ Define a null-terminated string



.text
@ define text


@ this is the entry function called from the startup file

Q512A:

	LDR R1, =ascii_string  @ the address of the string
	LDR R2, =0x00 	@ counter to the current place in the string

	B string_loop

string_loop:
	LDRB R3, [R0, R2]	@ load letter in the string at index R2
	CMP R3, #0	@ Test to see whether this byte is zero (for null terminated)
	BEQ finished_string  @ if it was null (0) then jump out of the loop
	ADD R2, #1  @ increment the offset R2

	B string_loop  @ loop to the next byte

finished_string:
	BX LR
