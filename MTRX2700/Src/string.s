.syntax unified
.thumb
#include "definitions.s"


.data
@ define variables


.text
@ define code
@ All functions in this module are prefixed with "str_" for clarity
@ when used alongside functions from other modules (e.g. uart_, led_, gpio_)


@ ========== Helper Functions ==========

@ Reset the counter register R2 back to 0
@ Should be called before any string operation that uses R2 as a counter
@   + Input: None
@   + Output: R2 = 0
str_reset_counter:
	MOV R2, #0
	BX LR


@ Common return point for all string functions
@   + Input: None
@   + Output: None, returns to caller
str_done:
	BX LR


@ ========== String Length ==========

@ Count the number of characters in a NULL-terminated string
@   + Input: R1 = address of the string, R2 = counter (set to 0 before calling)
@   + Output: R2 = length of the string (not including the NULL terminator)
str_count:
	LDRB R3, [R1, R2] @ Load the character at index R2

	CMP  R3, #0x0 @ Is it a NULL character - meaning is it the end of the string?
	BEQ str_done

	ADDS R2, R2, #1 @ Move to the next character
	B str_count


@ ========== Case Conversion ==========

@ Convert all upper case characters in a string to lower case
@   + Input: R1 = address of the string, R3 = counter (set to 0 before calling)
@   + Output: None, the string is modified in place
str_lower_case:
	LDRB R4, [R1, R3] @ Load the character at index R3

	CMP R4, #0x0 @ Is it the end of the string ?
	BEQ str_done

	CMP R4, #MIN_UPPER_CASE
	BLT str_lc_next @ Not an upper case character -> skip conversion

	CMP R4, #MAX_UPPER_CASE
	BGT str_lc_next @ Not an upper case character -> skip conversion

	ADDS R4, R4, #0x20 @ Adding 0x20 converts upper case -> lower case
	STRB R4, [R1, R3] @ Store the converted character back into the string

	ADDS R3, R3, #1 @ Move to the next character
	B str_lower_case

str_lc_next:
	ADDS R3, R3, #1
	B str_lower_case


@ Convert all lower case characters in a string to upper case
@   + Input: R1 = address of the string, R3 = counter (set to 0 before calling)
@   + Output: None, the string is modified in place
str_upper_case:
	LDRB R4, [R1, R3] @ Load the character at index R3

	CMP R4, #0x0 @ Is it the end of the string ?
	BEQ str_done

	CMP R4, #MIN_LOWER_CASE
	BLT str_uc_next @ Not a lower case character -> skip conversion

	CMP R4, #MAX_LOWER_CASE
	BGT str_uc_next @ Not a lower case character -> skip conversion

	SUBS R4, R4, #0x20 @ Subtracting 0x20 converts lower case -> upper case
	STRB R4, [R1, R3] @ Store the converted character back into the string

	ADDS R3, R3, #1 @ Move to the next character
	B str_upper_case

str_uc_next:
	ADDS R3, R3, #1
	B str_upper_case


@ ========== UART Packet Formatting ==========

@ Format a string into a UART packet with the structure: [STX][Length][String Body][ETX]
@ Length = number of string characters + UART_OVERHEAD (STX + Length byte + ETX)
@   + Input:  R0 = address of source string, R1 = address of destination buffer, R2 = counter (set to 0)
@   + Output: R2 = total packet length, buffer at R1 filled with the formatted packet
@   + Modifies: R2, R3, R4
str_concat:
	LDRB R3, [R0, R2]

	CMP R3, #0x00 @ Is it the NULL terminator ?
	BEQ end_concat

	ADD  R4, R2, #UART_BODY_OFFSET @ Compute destination index = R2 + offset (skip STX and Length byte)
	STRB R3, [R1, R4] @ Store the character into the buffer body
	ADDS R2, R2, #1 @ Move to the next character
	B str_concat

end_concat:
	MOV  R3, #STX
	STRB R3, [R1] @ Store STX at index 0

	@ Store NULL terminator right after the string body
	ADD  R4, R2, #UART_BODY_OFFSET
	MOV  R3, #0x0
	STRB R3, [R1, R4] @ Store NULL after string body
	ADDS R2, R2, #1 @ Advance past the NULL byte

	@ Store ETX one position after NULL
	MOV  R3, #ETX
	ADD  R4, R2, #UART_BODY_OFFSET
	STRB R3, [R1, R4] @ Store ETX after NULL

	ADDS R2, R2, #UART_OVERHEAD @ Add overhead to get total packet length
	STRB R2, [R1, #LENGTH_BYTE_IDX] @ Store total length at index 1
	B str_done


@ ========== Checksum Functions ==========

@ Compute a BCC checksum by XORing all bytes in the buffer, then append it to the packet
@   + Input:  R1 = address of buffer, R2 = total packet length (NOT including checksum byte)
@   + Output: R2 = updated total packet length (now including checksum byte)
@             R3 = final checksum value, stored at the end of the packet
@   + Modifies: R2, R3, R4, R5, R6, R9
str_checksum:
	MOV R5, #0x0 @ Set counter to 0
	MOV R3, #0x0 @ Set initial checksum value to zero
	MOV R4, R2 @ Save the current length as the index where checksum will be stored
	ADDS R2, R2, #1 @ Increment length to include the checksum byte
	STRB R2, [R1, #LENGTH_BYTE_IDX] @ Update the length byte in the packet

str_checksum_loop:
	CMP R5, R4 @ Have we reached the checksum storage index ?
	BEQ end_checksum

	LDRB R6, [R1, R5]

	EOR R3, R3, R6 @ XOR byte into checksum accumulator
	ADDS R5, R5, #1 @ Move to the next byte

	B str_checksum_loop

end_checksum:
	STRB R3, [R1, R4] @ Store checksum byte at the end of the packet
	ADD  R4, R4, #1 @ Move index past the checksum byte
	MOV  R9, #0x0
	STRB R9, [R1, R4] @ Store NULL terminator after checksum

	B str_done


@ Verify the BCC checksum of a received UART packet
@ XORing all bytes including the checksum should produce 0 if the packet is valid
@   + Input:  R1 = address of buffer, R2 = total packet length (including checksum byte)
@   + Output: R3 = 0x00 if valid, non-zero if corrupted
@   + Modifies: R3, R5, R6
str_verify_checksum:
	MOV R5, #0x0 @ Set counter to 0
	MOV R3, #0x0 @ Set initial XOR accumulator to 0

str_verify_loop:
	CMP R5, R2 @ Have we passed the checksum byte ?
	BEQ str_done

	LDRB R6, [R1, R5]

	EOR R3, R3, R6 @ XOR byte into checksum accumulator
	ADDS R5, R5, #1 @ Move to the next byte

	B str_verify_loop
