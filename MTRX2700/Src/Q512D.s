.syntax unified
.thumb

.global Q512D

.type Q512D, %function


@ Constant definition
.equ DEFAULT_CHECKSUM, 0x00 @ In case there is only 1 byte => Check sum = byte_1 XOR DEFAULT_CHECKSUM = byte_1


.data
@ define variables
ascii_string: .asciz "\x02\x12Group3istheBEST\x03" @ where 0x02, 0x03 stands for STX, ETX and 0x12 (Dec: 18) stands
@ for the length of the string, including STX, ETX, length and body string
new_address: .space 128


.text
@ define text


@ this is the entry function called from the startup file

Q512D:
	LDR R1, =ascii_string @ Get the buffer string address
	LDRB R2, [R1, #1] @ Get the length from the buffer string
	MOV R4, #0x00 @ Set the counter used to iterate through the string
	MOV R3, #DEFAULT_CHECKSUM @ Set the default value for CHECKSUM (0x00)

	B str_loop

str_loop:

	CMP R4, R2 @ Check if the string end
	BEQ return_main

	LDRB R5, [R1, R4] @ Getting the letter from buffer string at index R4


	@ Getting XOR value
	EOR R3, R3, R5

	@ Move to the next letter
	ADD R4,#1

	B str_loop

return_main:
	STRB R3, [R1, R4] @ Store value of check sum at the end of the string
	ADD R2, #1 @ Add 1 to include the value of the checksum just being added
	STRB R2, [R1, #1]

	BX LR




