.syntax unified
.thumb
.thumb_func

#include "definitions.s"

.data
@ define variables
ack_nak_src: .space 2 @ 1 byte for ACK/NAK + 1 byte for NULL terminator
response_buf: .space 16 @ Buffer for the full formatted response packet

.text
@ define code
@ All functions in this module are prefixed with "uart_" for clarity
@ when used alongside functions from other modules (e.g. str_, led_, gpio_)


@ ========== Transmit ==========

@ Transmit a packet over UART4 TX (PC10) one byte at a time
@ Polls the TXE flag in the ISR to wait until the transmit register is ready
@   + Input: R1 = address of packet buffer, R2 = total packet length
@   + Output: Sends ACK or NAK response over UART, string body copied to R2 buffer if valid
@             R0 = ACK (0x06) if valid, NAK (0x15) if any check failed
@   + Modifies: R0, R3, R5, R6
uart_transmit:
	PUSH {R6, LR}
	LDR R0, =UART4
	MOV R6, #0 @ Set R6 as the byte counter, starting at 0

uart_transmit_loop:
	LDR R3, [R0, #UART_ISR]
	ANDS R3, R3, #(1 << TXE) @ Is the transmit register empty and ready ?
	BEQ uart_transmit_loop @ No -> Wait

	LDRB R5, [R1], #1 @ Load current byte and advance R1
	STRB R5, [R0, #UART_TDR] @ Send the byte

	ADDS R6, R6, #1 @ Increment the byte counter
	CMP R6, R2 @ Have we sent all bytes ?
	BEQ uart_transmit_done @ Yes -> Finished transmitting

	B uart_transmit_loop

uart_transmit_done:
	POP {R6, PC} @ Return to caller


@ ========== Receive and Validate ==========

@ Receive and validate an incoming UART packet, then copy the string body to a destination buffer
@ Checks: STX present, NULL terminator in correct position, ETX present,
@         checksum valid, and character count matches the length byte
@ Sends ACK if all checks pass, NAK if any check fails
@   + Input: R1 = address of received packet, R2 = address of destination buffer
@   + Output: Sends ACK or NAK response over UART, string body copied to R2 buffer if valid
@   + Modifies: R1, R2, R3, R4, R5, R8, R9, R10
uart_read_check:
	PUSH {LR}
	MOV R10, R2 @ Save the destination buffer address in R10 so we can free R2

	@ Check 1: Verify STX is present at the start of the packet
	LDRB R3, [R1] @ Load the first byte from the packet
	CMP R3, #STX
	BNE nak_response @ No STX -> Corrupted -> NAK

	@ Load the length byte for later verification
	LDRB R2, [R1, #1]

	@ Check 2: Verify NULL terminator is at the expected position (length - 3)
	SUBS R8, R2, #3 @ Compute index of the NULL terminator in the string body
	LDRB R3, [R1, R8]
	CMP R3, #0x0 @ Is there a NULL terminator at this index ?
	BNE nak_response @ No -> Corrupted -> NAK

	@ Check 3: Verify ETX is right after the NULL terminator
	ADDS R8, R8, #1 @ Move to the next index
	LDRB R3, [R1, R8]
	CMP R3, #ETX @ Is there an ETX at this index ?
	BNE nak_response @ No -> Corrupted -> NAK

	@ Check 4: Verify BCC checksum (XOR of all bytes including checksum should be 0)
	MOV R5, #0x0 @ Reset the counter for str_verify_checksum
	MOV R3, #0x0 @ Reset the initial checksum value to 0
	BL str_verify_checksum
	CMP R3, #0x0
	BNE nak_response @ Non-zero result -> Checksum mismatch -> NAK

	@ All checks passed, now copy the string body to the destination buffer
	MOV R9, R2 @ Save the length value since R2 will be reused
	MOV R2, R10 @ Restore destination buffer address back to R2
	ADD R1, R1, #2 @ Point R1 to the start of the string body (skip STX and Length byte)
	MOV R4, #0x0 @ Set R4 as the counter to loop through the string body

uart_read_loop:
	LDRB R5, [R1, R4]
	CMP R5, #ETX @ Have we reached the end of the string body ?
	BEQ uart_read_check_count @ Yes -> Stop copying and verify the character count

	STRB R5, [R2], #1 @ Store the character into the destination buffer and advance the pointer
	ADDS R4, R4, #1 @ Move to the next character
	B uart_read_loop

@ Check 5: Verify that the number of bytes copied matches the length byte
uart_read_check_count:
	@ R4 = bytes copied (string body + NULL terminator)
	@ Adding 4 accounts for STX + Length byte + ETX + Checksum
	ADDS R4, R4, #4 @ Compute the expected total packet length
	CMP R4, R9 @ Does it match the Length byte ?
	BNE nak_response @ No -> Character count mismatch -> NAK

	B ack_response


@ ========== ACK / NAK Response ==========

@ Send an ACK response over UART to confirm the packet was received correctly
ack_response:
	MOV R6, #ACK @ Load the ACK hex value
	B build_response @ Build and send the response packet


@ Send a NAK response over UART to indicate the packet was corrupted
nak_response:
	MOV R6, #NAK @ Load the NAK hex value


@ Build and transmit a response packet using R6 as the response byte (ACK or NAK)
@ Packet structure: [STX][Length][ACK or NAK][0x00][ETX][Checksum]
build_response:
	@ Build a null-terminated source string from the single response byte
		LDR R0, =ack_nak_src
	STRB R6, [R0] @ Store ACK or NAK byte at index 0
	MOV R7, #0x0
	STRB R7, [R0, #1] @ Store NULL terminator at index 1

	@ Format the response into a UART packet
	LDR R1, =response_buf
	BL str_reset_counter @ Reset R2 to 0
	BL str_concat @ Build packet: [STX][Length][ACK/NAK][0x00][ETX]

	@ Compute and append the checksum
	MOV R5, #0x0 @ Reset counter for str_checksum
	MOV R3, #0x0 @ Reset initial checksum value
	BL str_checksum

	@ Transmit the complete response packet
	LDR R1, =response_buf @ Reset R1 back to the start of the response buffer
	BL uart_transmit

	MOV R0, R6
	POP {PC} @ Return to caller


@ ========== Receive Packet (Polling) ==========

@ Receive exactly R2 bytes from UART4 RX into the buffer at R1
@ Polls RXNE for each byte — blocks per byte but not for the whole packet
@ Used by Board 2 to read an incoming packet, and by Board 1 inside ex5_wait_ack
@   + Input:  R1 = address of destination buffer
@             R2 = number of bytes to receive
@   + Output: buffer at R1 filled with received bytes
@   + Modifies: R0, R3, R5, R6
.type uart_receive_packet, %function
uart_receive_packet:
    PUSH {LR}
    LDR R0, =UART4
    MOV R6, #0                  @ R6 = byte counter, starting at 0

uart_receive_packet_loop:
    LDR R3, [R0, #UART_ISR]
    ANDS R3, R3, #(1 << RXNE)  @ Is a byte ready in the receive register ?
    BEQ uart_receive_packet_loop @ No -> keep polling

    LDRB R5, [R0, #UART_RDR]   @ Read the byte from RDR
    STRB R5, [R1], #1           @ Store into buffer, advance pointer

    ADDS R6, R6, #1             @ Increment byte counter
    CMP R6, R2                  @ Have we received all expected bytes ?
    BNE uart_receive_packet_loop @ No -> keep reading

    POP {PC}
