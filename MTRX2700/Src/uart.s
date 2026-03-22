.syntax unified
.thumb
.thumb_func

#include "definitions.s"

.data
@ define variables
ack_nak_src: .space 2   @ 1 byte for ACK/NAK + 1 byte for NULL terminator
response_buf: .space 16 @ Buffer for the full formatted response packet

.text
@ define text


@ This function transmits a single packet over UART4 TX (PC10)
@ R1 = address of packet buffer, R2 = total packet length
uart_transmit:
    PUSH {LR}
    LDR R0, =UART4
    MOV R6, #0 @ Set R6 as the byte counter, starting at 0


uart_transmit_loop:
    LDR R3, [R0, #ISR]
    ANDS R3, R3, #(1 << TXE) @ Is the transmit register empty and ready ?
    BEQ uart_transmit_loop @ No -> Wait

    LDRB R5, [R1], #1 @ Load current byte and advance R1
    STRB R5, [R0, #TDR] @ Send the byte

    ADDS R6, R6, #1 @ Increment the byte counter
    CMP R6, R2  @ Have we sent all bytes up to the checksum ?
    BEQ uart_transmit_done @ Yes -> Finished transmitting

    B uart_transmit_loop

uart_transmit_done:
    POP {PC} @ Return to caller


@ This function receives the incoming buffer of characters pointed by R1 and stores the resulting string in buffer address R2
@ R1 = address of received packet, R2 = address of destination buffer
uart_read_check:
    MOV R10, R2 @ Save the destination buffer address in R10 so we can free R2 for str_verify_checksum

    LDRB R3, [R1] @ Load the first character from R1, it should be STX if the message is not corrupted
    CMP R3, #STX
    BNE nak_response @ No STX -> Corrupted -> NAK

    LDRB R2, [R1, #1] @ Load the length byte value for later checking

    SUBS R8, R2, #3 @ Compute the index of the NULL terminator in the string body
                    @ NULL is at length - 3 (before ETX and checksum)
    LDRB R3, [R1, R8]
    CMP R3, #0x0 @ Is there a NULL terminator at this index ?
    BNE nak_response @ No -> Corrupted -> NAK

    ADDS R8, R8, #1 @ Move to the next index, ETX should be here
    LDRB R3, [R1, R8]
    CMP R3, #ETX @ Is there an ETX at this index ?
    BNE nak_response @ No -> Corrupted -> NAK

    MOV R5, #0x0 @ Reset the counter for str_verify_checksum
    MOV R3, #0x0 @ Reset the initial checksum value to 0
    BL str_verify_checksum @ XOR all bytes including checksum, result should be 0 if valid
    CMP R3, #0x0
    BNE nak_response @ Non-zero result -> Checksum mismatch -> NAK

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

uart_read_check_count:
    @ R4 now holds the number of bytes copied (string body + NULL terminator)
    @ Adding 4 accounts for STX + Length byte + ETX + Checksum
    ADDS R4, R4, #4 @ Compute the expected total packet length
    CMP R4, R2 @ Does it match the Length byte ?
    BNE nak_response @ No -> Character count mismatch -> NAK

    B ack_response


@ This function sends an ACK response over UART to confirm the transmission was received correctly
ack_response:
    PUSH {LR} @ Save LR as we will be calling multiple subroutines

    MOV R6, #ACK @ Load the ACK hex value
    B build_response @ Build and send the response packet


@ This function sends a NAK response over UART to indicate the transmission was corrupted
nak_response:
    PUSH {LR} @ Save LR as we will be calling multiple subroutines

    MOV R6, #NAK @ Load the NAK hex value


@ This helper builds and sends the response packet using R6 as the response byte (ACK or NAK)
build_response:
    @ Build a null-terminated source string from the single response byte in R6
    LDR R0, =ack_nak_src
    STRB R6, [R0] @ Store ACK or NAK byte at index 0
    MOV R7, #0x0
    STRB R7, [R0, #1]  @ Store NULL terminator at index 1

    @ Set up R1 to point to the response buffer and reset the counter
    LDR R1, =response_buf
    BL str_reset_counter @ Reset R2 to 0
    BL str_concat  @ Format the packet: [STX][Length][ACK/NAK][0x00][ETX]

    @ Set up and compute the checksum
    MOV R4, R2  @ R4 = index where checksum byte will be stored
    ADDS R2, R2, #1  @ Increase total length to include checksum byte
    MOV R5, #0x0 @ Reset counter for str_checksum
    MOV R3, #0x0 @ Reset initial checksum value
    BL str_checksum @ Compute and store checksum, also updates Length byte

    @ Transmit the response packet
    LDR R1, =response_buf @ Reset R1 back to the start of the response buffer
    BL uart_transmit_loop

    POP {PC} @ Return to caller


@ This function receives incoming bytes from UART4 RX (PC11) into a buffer
@ R1 = address of destination buffer, R2 = total expected length from Length byte
uart_receive:
    PUSH {LR}
    LDR R0, =UART4
    MOV R6, #0 @ Set R6 as the byte counter, starting at 0

uart_receive_loop:
    LDR R3, [R0, #ISR]
    ANDS R3, R3, #(1 << RXNE) @ Is the receive register not empty and ready ?
    BEQ uart_receive_loop  @ No -> Wait

    LDRB R5, [R0, #RDR]  @ Read the incoming byte from the receive data register
    STRB R5, [R1], #1  @ Store it into the buffer and advance R1

    ADDS R6, R6, #1 @ Increment the byte counter
    CMP R6, R2 @ Have we received all expected bytes ?
    BEQ uart_receive_done @ Yes -> Finished receiving

    B uart_receive_loop

uart_receive_done:
    POP {PC} @ Return to caller

