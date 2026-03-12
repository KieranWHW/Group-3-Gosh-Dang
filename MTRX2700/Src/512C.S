.syntax unified
.thumb

.global Q512C

.type Q512C, %function


@ Constant definition
.equ STX, 0x02
.equ ETX, 0x03
.equ DEFAULT_START, 0x02 @ The string body would always start at index 2 (index 0, 1 are for STX and LENGTH)

.data
@ define variables
ascii_string: .asciz "Group3" @ Define a null-terminated string
new_address: .space 128


.text
@ define text


@ this is the entry function called from the startup file

Q512C:

	LDR R0, =ascii_string  @ the address of the string
	LDR R1, =new_address @ the new address
	MOV R2, #DEFAULT_START @ Counter at the new address
	MOV R3, #0x00 @ Index at the old address

	MOV R4, #STX
	STRB R4, [R1] @ Store the STX character into the new string

	B string_loop

string_loop:
	LDRB R4, [R0, R3] @ Getting letter at the old adress at index R3
	CMP R4, #0x00 @ If the string ends, go to finished_string to add ETX and the total length into the new address
	BEQ finished_string

	STRB R4, [R1, R2] @ Store the copied letter into the new address
	@ Move the index by 1 => Get the next character
	ADD R2, #1
	ADD R3, #1

	B string_loop


finished_string:
	MOV R4, #ETX @ Load the ETX character
	STRB R4, [R1, R2] @ Store that into the new address
	ADD R2, #1 @ We add 1 here to account for the ETX just being added
	STRB R2, [R1, #1] @ Store the total length into the second byte

	BX LR
