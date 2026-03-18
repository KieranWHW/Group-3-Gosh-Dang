.syntax unified
.thumb

.data
@ This is where we define constants
.equ MIN_LOWER_CASE, 0x61 @ Minimum hex value of a lower case character (a)
.equ MAX_LOWER_CASE, 0x7A @ Maximum hex value of a lower case character (z)
.equ MIN_UPPER_CASE, 0x41 @ Minimum hex value of a upper case character (A)
.equ MAX_UPPER_CASE, 0x5A @ Maximum hex value of a upper case character (Z)

.equ STX, 0x02 @ Hex value of the starting character in UART comm
.equ ETX, 0x03 @ Hex value of the ending character in UART comm
.equ UART_OVERHEAD, 3 @ Total overhead bytes added to packet: STX + Length byte + ETX
.equ UART_BODY_OFFSET, 2 @ String body starts 2 bytes into buffer: [STX][Length][String Body...][ETX]
.equ LENGTH_BYTE_IDX, 1 @ Index of the length byte in the buffer: [STX][Length byte here][...]
.text
/*
This is where we define code

Any functions defined in this module should be pre-fixed with "str_" for better clarification
when using them at the same time with functions from other modules, e.g. uart_, timer_, .etc
*/



/* This is a helper-function to reset the counter value, which is R2 in the Lab Task.
This should be called before doing any operations with the string.
	+ Input: None
	+ Output: None, change value of R2 back to 0
*/
str_reset_counter:
	MOV R2, #0
	BX LR @ Finished, go to back to where this function is called



/*
This function is used to count the number of characters inside a string
	+ Input: address to a string, pointed by R1
	+ Output: Set register R2 to the value of the length of the string
*/
str_count:
	LDRB R3, [R1, R2] @ Load the character at index R2

	CMP  R3, #0x0 @ Is it a NULL Character - meaning is it the end of the string?
	BEQ str_done

	ADDS R2, R2, #1 @ Move to the next character
	B str_count @ Finished, go to back to where this function is called



/* This function is used to convert all upper case characters in a string to lower case
	+ Input: address to a string, pointed by R1, R3 as the counter value
	+ Output: None, the string is modified in place
*/
str_lower_case:
	LDRB R4, [R1, R3] @ Load the character at index R3

	CMP R4, #0x0 @ Is the end of the string ?
	BEQ str_done

	CMP R4, #MIN_UPPER_CASE
	BLT str_lc_next @ This is not an upper case character -> no need to convert to lower case

	CMP R4, #MAX_UPPER_CASE
	BGT str_lc_next @ This is not an upper case character -> no need to convert to lower case

	ADDS R4, R4, #0x20 @ By adding 0x20, we can convert an upper case letter -> lower case
    STRB R4, [R1, R3] @ Store the converted character back into the string

	ADDS R3, R3, #1 @ Move to the next character
	B str_lower_case

str_lc_next:
	ADDS R3, R3, #1
	B str_lower_case




/* This function is used to convert all lower characters in a string to upper case
	+ Input: address to a string, pointed by R1, R3 as the counter value
	+ Output: None, the string is modified in place
*/
str_upper_case:
	LDRB R4, [R1, R3] @ Load the character at index R3

	CMP R4, #0x0 @ Is the end of the string ?
	BEQ str_done

	CMP R4, #MIN_LOWER_CASE
	BLT str_uc_next @ This is not an lower case character -> no need to convert to upper case

	CMP R4, #MAX_LOWER_CASE
	BGT str_uc_next @ This is not an lower case character -> no need to convert to upper case

	SUBS R4, R4, #0x20 @ By substracting 0x20, we can convert an lower case letter -> upper case
    STRB R4, [R1, R3] @ Store the converted character back into the string

	ADDS R3, R3, #1 @ Move to the next character
	B str_upper_case

str_uc_next:
	ADDS R3, R3, #1
	B str_upper_case



/* This function formats a string into a UART packet with the structure:
   [STX] [Length] [String Body] [ETX]
   Where Length = number of string characters + LENGTH_ADD (STX + Length byte + ETX)
      + Input:  R0 = address of source string, R1 = address of destination buffer, R2 = counter (set to 0)
      + Output: R2 = total packet length, buffer at R1 filled with the formatted UART packet
      + Modifies: R2, R3, R4
*/
str_concat:
	LDRB R3, [R0, R2]

	CMP R3, #0x00 @ Is it the ending character?
	BEQ end_concat

	ADD  R4, R2, #UART_BODY_OFFSET  @ Compute index = R2 + OFFSET
    STRB R3, [R1, R4]  @ Store the character of the string body into the buffer string body
	ADDS R2, R2, #1 @ Move to the next character
	B str_concat


end_concat:
    MOV  R3, #STX
    STRB R3, [R1] @ Store STX at the start of the buffer at index 0

    MOV  R3, #ETX
    ADD  R4, R2, #UART_BODY_OFFSET  @ Compute buffer index = R2 + OFFSET (skip STX and Length byte)
    STRB R3, [R1, R4]  @ Store ETX at the end of the string body

    ADDS R2, R2, #UART_OVERHEAD  @ Add overhead count (STX + Length byte + ETX) to get total packet length
    STRB R2, [R1, #LENGTH_BYTE_IDX] @ Store the total packet length into the Length byte slot in the buffer

    B str_done



/* This function computes a BCC checksum by XORing all bytes in the buffer up to (not including) the checksum byte, then stores the result
      + Input:  R1 = address of buffer, R4 = index where checksum byte will be stored, R5 = counter (set to 0), R3 = initial checksum value (set to 0x00)
      + Output: R3 = final checksum value, stored at buffer[R4]
      + Modifies: R3, R5, R6
*/
str_checksum:
	CMP R5, R4 @ If this equal to the index where we want to store the checksum byte -> we have finished going through every bytes before the checksum
	BEQ end_checksum

	LDRB R6, [R1, R5]

	EOR R3, R3, R6 @ XOR byte into checksum accumulator
	ADDS R5, R5, #1 @ Move to the byte

	B str_checksum

end_checksum:
	STRB R3, [R1, R4]
	B str_done


/* This function verifies the BCC checksum of a received UART packet by XORing all bytes including the checksum byte
      + Input:  R1 = address of buffer, R2 = total packet length (including checksum byte), R5 = counter (set to 0), R3 = initial value (set to 0x00)
      + Output: R3 = 0x00 if packet is valid, non-zero if packet is corrupted
      + Modifies: R3, R5, R6
*/
str_verify_checksum:
	CMP R5, R2 @ when the index = length -> we have passed the checksum byte -> we can stop the loop
	BEQ str_done

	LDRB R6, [R1, R5]

	EOR R3, R3, R6 @ XOR byte into checksum accumulator
	ADDS R5, R5, #1 @ Move to the byte

	B str_verify_checksum


/* This is a helper-function to return to the main function
	+ Input: None
	+ Output: None, return to main
*/
str_done:
	BX LR
