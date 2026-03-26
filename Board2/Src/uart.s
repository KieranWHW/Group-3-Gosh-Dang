.syntax unified
.thumb
.thumb_func

#include "definitions.s"

@ Set to 1 to use CRC16-CCITT checksum (bonus task),
@ set to 0 to use BCC XOR checksum (original).
@ Must match USE_CRC16 in ex1_memory.s, ex3_uart.s, and ex5_combine.s.
@ Tip: consider moving this to definitions.s to have a single source of truth.
.equ USE_CRC16, 1

.data
ack_nak_src:  .space 2             @ ACK/NAK byte + NUL terminator
response_buf: .space 16            @ framed ACK/NAK response packet

.text
@ =============================================================
@ UART helper module
@ =============================================================
@ All functions in this module are prefixed with "uart_".


@ -------------------------------------------------------------
@ uart_transmit
@ -------------------------------------------------------------
@ Transmit a packet over UART4 one byte at a time.
@   + Input:  R1 = packet buffer address
@             R2 = number of bytes to send
@   + Output: none
@   + Modifies: R0, R3, R5, R6
.type uart_transmit, %function
uart_transmit:
    PUSH {R6, LR}
    LDR R0, =UART4
    MOV R6, #0

uart_transmit_loop:
    LDR R3, [R0, #UART_ISR]
    ANDS R3, R3, #(1 << TXE)
    BEQ uart_transmit_loop

    LDRB R5, [R1], #1
    STRB R5, [R0, #UART_TDR]

    ADDS R6, R6, #1
    CMP R6, R2
    BNE uart_transmit_loop

    POP {R6, PC}


@ -------------------------------------------------------------
@ uart_read_check
@ -------------------------------------------------------------
@ Validate a received UART packet and copy its string body.
@
@ Validation checks:
@   1) STX present
@   2) NUL terminator at expected index
@   3) ETX at expected index
@   4) checksum valid (BCC or CRC16 depending on USE_CRC16)
@   5) copied byte count matches packet length
@
@ Packet layout:
@   USE_CRC16 = 0 (BCC):   [STX][LEN][body][NUL][ETX][CS]        (NUL at LEN-3)
@   USE_CRC16 = 1 (CRC16): [STX][LEN][body][NUL][ETX][CHI][CLO]  (NUL at LEN-4)
@
@ A framed ACK or NAK reply is transmitted on UART4.
@   + Input:  R1 = received packet address
@             R2 = destination buffer address for string body
@   + Output: R0 = ACK if valid, NAK if invalid
@             destination buffer filled if valid
@   + Modifies: R1, R2, R3, R4, R5, R8, R9, R10
.type uart_read_check, %function
uart_read_check:
    PUSH {LR}
    MOV R10, R2                    @ save destination buffer pointer

    @ Check 1: STX must be the first byte.
    LDRB R3, [R1]
    CMP R3, #STX
    BNE uart_nak_response

    @ Read total packet length.
    LDRB R2, [R1, #1]

    @ Check 2: packet must contain a NUL terminator.
    @ BCC:   NUL is at index LEN-3 (1 checksum byte at end)
    @ CRC16: NUL is at index LEN-4 (2 checksum bytes at end)
.if USE_CRC16
    SUBS R8, R2, #4
.else
    SUBS R8, R2, #3
.endif
    LDRB R3, [R1, R8]
    CMP R3, #0x00
    BNE uart_nak_response

    @ Check 3: ETX must follow the NUL terminator (always one byte after NUL).
    ADDS R8, R8, #1
    LDRB R3, [R1, R8]
    CMP R3, #ETX
    BNE uart_nak_response

    @ Check 4: verify checksum over the whole packet.
.if USE_CRC16
    BL str_verify_crc16            @ R3 = 0 if CRC16 matches
.else
    MOV R5, #0x00
    MOV R3, #0x00
    BL str_verify_checksum         @ R3 = 0 if BCC XOR is zero
.endif
    CMP R3, #0x00
    BNE uart_nak_response

    @ Copy the string body to the destination buffer.
    MOV R9, R2                     @ preserve total length
    MOV R2, R10                    @ restore destination buffer pointer
    ADD R1, R1, #2                 @ point to body start
    MOV R4, #0x00                  @ byte counter

uart_read_loop:
    LDRB R5, [R1, R4]
    CMP R5, #ETX
    BEQ uart_read_check_count

    STRB R5, [R2], #1
    ADDS R4, R4, #1
    B uart_read_loop

uart_read_check_count:
    @ R4 = body bytes copied (including NUL).
    @ Add overhead: STX + LEN + ETX + checksum byte(s).
    @ BCC:   overhead = 4 (1 checksum byte)
    @ CRC16: overhead = 5 (2 checksum bytes)
.if USE_CRC16
    ADDS R4, R4, #5
.else
    ADDS R4, R4, #4
.endif
    CMP R4, R9
    BNE uart_nak_response

    B uart_ack_response


@ -------------------------------------------------------------
@ uart_ack_response / uart_nak_response
@ -------------------------------------------------------------
@ Build and send a framed ACK / NAK packet.
uart_ack_response:
    MOV R6, #ACK
    B uart_build_response

uart_nak_response:
    MOV R6, #NAK

uart_build_response:
    @ Build a temporary NUL-terminated 1-byte source string.
    LDR R0, =ack_nak_src
    STRB R6, [R0]
    MOV R7, #0x00
    STRB R7, [R0, #1]

    @ Frame the response packet and append checksum.
    LDR R1, =response_buf
    BL str_reset_counter
    BL str_concat
.if USE_CRC16
    BL str_crc16_checksum          @ CRC16-CCITT: appends 2 bytes
.else
    BL str_checksum                @ BCC XOR: appends 1 byte
.endif

    @ Transmit the response.
    LDR R1, =response_buf
    BL uart_transmit

    MOV R0, R6
    POP {PC}


@ -------------------------------------------------------------
@ uart_receive_packet
@ -------------------------------------------------------------
@ Receive exactly R2 bytes from UART4 RX into the buffer at R1.
@ This is a polling implementation: it blocks until each byte arrives.
@   + Input:  R1 = destination buffer address
@             R2 = number of bytes to receive
@   + Output: destination buffer filled with received bytes
@   + Modifies: R0, R3, R5, R6
.type uart_receive_packet, %function
uart_receive_packet:
    PUSH {LR}
    LDR R0, =UART4
    MOV R6, #0

uart_receive_packet_loop:
    LDR R3, [R0, #UART_ISR]
    ANDS R3, R3, #(1 << RXNE)
    BEQ uart_receive_packet_loop

    LDRB R5, [R0, #UART_RDR]
    STRB R5, [R1], #1

    ADDS R6, R6, #1
    CMP R6, R2
    BNE uart_receive_packet_loop

    POP {PC}
