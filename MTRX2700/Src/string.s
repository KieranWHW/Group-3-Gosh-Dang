.syntax unified
.thumb

#include "definitions.s"

.text
@ =============================================================
@ String helper module
@ =============================================================
@ All functions in this module are prefixed with "str_".
@ They are used by the UART and exercise integration modules.


@ -------------------------------------------------------------
@ str_reset_counter
@ -------------------------------------------------------------
@ Reset register R2 to 0 before a string / packet operation.
@   + Output: R2 = 0
.type str_reset_counter, %function
str_reset_counter:
    MOV R2, #0
    BX LR


@ -------------------------------------------------------------
@ str_done
@ -------------------------------------------------------------
@ Common return label used by simple string routines.
.type str_done, %function
str_done:
    BX LR


@ -------------------------------------------------------------
@ str_count
@ -------------------------------------------------------------
@ Count characters in a NUL-terminated string.
@   + Input:  R1 = string address
@             R2 = counter (set to 0 before call)
@   + Output: R2 = length, excluding the NUL terminator
@   + Modifies: R3
.type str_count, %function
str_count:
    LDRB R3, [R1, R2]
    CMP  R3, #0x00
    BEQ  str_done

    ADDS R2, R2, #1
    B    str_count


@ -------------------------------------------------------------
@ str_lower_case
@ -------------------------------------------------------------
@ Convert all uppercase ASCII letters in a string to lowercase.
@   + Input:  R1 = string address
@             R3 = counter (set to 0 before call)
@   + Output: string modified in place
@   + Modifies: R4
.type str_lower_case, %function
str_lower_case:
    LDRB R4, [R1, R3]
    CMP  R4, #0x00
    BEQ  str_done

    CMP  R4, #MIN_UPPER_CASE
    BLT  str_lc_next
    CMP  R4, #MAX_UPPER_CASE
    BGT  str_lc_next

    ADDS R4, R4, #0x20
    STRB R4, [R1, R3]

str_lc_next:
    ADDS R3, R3, #1
    B    str_lower_case


@ -------------------------------------------------------------
@ str_upper_case
@ -------------------------------------------------------------
@ Convert all lowercase ASCII letters in a string to uppercase.
@   + Input:  R1 = string address
@             R3 = counter (set to 0 before call)
@   + Output: string modified in place
@   + Modifies: R4
.type str_upper_case, %function
str_upper_case:
    LDRB R4, [R1, R3]
    CMP  R4, #0x00
    BEQ  str_done

    CMP  R4, #MIN_LOWER_CASE
    BLT  str_uc_next
    CMP  R4, #MAX_LOWER_CASE
    BGT  str_uc_next

    SUBS R4, R4, #0x20
    STRB R4, [R1, R3]

str_uc_next:
    ADDS R3, R3, #1
    B    str_upper_case


@ -------------------------------------------------------------
@ str_concat
@ -------------------------------------------------------------
@ Build a UART packet in the form:
@   [STX][Length][String Body][NUL][ETX]
@
@ The checksum is appended later by str_checksum.
@   + Input:  R0 = source string address
@             R1 = destination buffer address
@             R2 = counter / string index (set to 0 before call)
@   + Output: R2 = packet length before checksum byte is appended
@             destination buffer filled with framed payload
@   + Modifies: R3, R4
.type str_concat, %function
str_concat:
    PUSH {R4, LR}

str_concat_loop:
    LDRB R3, [R0, R2]
    CMP  R3, #0x00
    BEQ  str_concat_finish

    ADD  R4, R2, #UART_BODY_OFFSET
    STRB R3, [R1, R4]
    ADDS R2, R2, #1
    B    str_concat_loop

str_concat_finish:
    MOV  R3, #STX
    STRB R3, [R1]

    @ Append the source string NUL terminator into the packet body.
    ADD  R4, R2, #UART_BODY_OFFSET
    MOV  R3, #0x00
    STRB R3, [R1, R4]
    ADDS R2, R2, #1

    @ Append ETX after the NUL terminator.
    MOV  R3, #ETX
    ADD  R4, R2, #UART_BODY_OFFSET
    STRB R3, [R1, R4]

    @ Store packet length before checksum is added.
    ADDS R2, R2, #UART_OVERHEAD
    STRB R2, [R1, #LENGTH_BYTE_IDX]

    POP {R4, PC}


@ -------------------------------------------------------------
@ str_checksum
@ -------------------------------------------------------------
@ Compute the 8-bit XOR BCC checksum and append it to the packet.
@   + Input:  R1 = packet buffer address
@             R2 = packet length before checksum byte is appended
@   + Output: R2 = updated packet length including checksum byte
@             R3 = checksum byte
@             checksum stored at end of packet
@   + Modifies: R4, R5, R6, R9
.type str_checksum, %function
str_checksum:
    PUSH {R4, R5, R6, R9, LR}

    MOV  R5, #0                    @ byte index
    MOV  R3, #0                    @ XOR accumulator
    MOV  R4, R2                    @ original length before checksum
    ADDS R2, R2, #1                @ new total length including checksum
    STRB R2, [R1, #LENGTH_BYTE_IDX]

str_checksum_loop:
    CMP  R5, R4
    BEQ  str_checksum_done

    LDRB R6, [R1, R5]
    EOR  R3, R3, R6
    ADDS R5, R5, #1
    B    str_checksum_loop

str_checksum_done:
    STRB R3, [R1, R4]              @ checksum byte
    ADD  R4, R4, #1
    MOV  R9, #0
    STRB R9, [R1, R4]              @ optional trailing NUL for convenience

    POP {R4, R5, R6, R9, PC}


@ -------------------------------------------------------------
@ str_verify_checksum
@ -------------------------------------------------------------
@ Verify a BCC checksum.
@ XORing every byte in a valid packet, including the checksum,
@ should produce 0.
@   + Input:  R1 = packet buffer address
@             R2 = total packet length including checksum byte
@   + Output: R3 = 0x00 if valid, non-zero if invalid
@   + Modifies: R5, R6
.type str_verify_checksum, %function
str_verify_checksum:
    MOV R5, #0x00
    MOV R3, #0x00

str_verify_loop:
    CMP R5, R2
    BEQ str_done

    LDRB R6, [R1, R5]
    EOR  R3, R3, R6
    ADDS R5, R5, #1
    B    str_verify_loop


@ -------------------------------------------------------------
@ str_crc16_checksum
@ -------------------------------------------------------------
@ Compute CRC16-CCITT checksum and append 2 bytes to the packet.
@ Appends CRC high byte then CRC low byte (big-endian).
@ The length byte is updated to include both CRC bytes.
@
@ Algorithm: CRC16-CCITT, poly=0x1021, init=0xFFFF.
@ Each byte is XORed into the high byte of the running CRC,
@ then 8 rounds of shift-and-XOR are applied.
@
@   + Input:  R1 = packet buffer address
@             R2 = packet length before CRC bytes are appended
@   + Output: R2 = updated packet length (original + 2)
@             R3 = final 16-bit CRC value
@             CRC stored big-endian at end of packet
@   + Modifies: R4, R5, R6, R7, R9
.type str_crc16_checksum, %function
str_crc16_checksum:
    PUSH {R4, R5, R6, R7, R9, LR}

    MOV  R5, #0                     @ byte index
    MOV  R4, R2                     @ original length (CRC stored here after loop)
    ADDS R2, R2, #2                 @ total length now includes 2 CRC bytes
    STRB R2, [R1, #LENGTH_BYTE_IDX]

    @ Initialise CRC = 0xFFFF
    MOV  R3, #0xFF
    ORR  R3, R3, R3, LSL #8         @ R3 = 0xFFFF

    LDR  R7, =CRC16_POLY            @ R7 = 0x1021

str_crc16_byte_loop:
    CMP  R5, R4
    BEQ  str_crc16_store

    LDRB R6, [R1, R5]               @ load next byte
    LSL  R6, R6, #8                 @ shift into high byte position
    EOR  R3, R3, R6                 @ crc ^= (byte << 8)

    MOV  R9, #8                     @ 8 bits to process

str_crc16_bit_loop:
    TST  R3, #0x8000                @ test MSB before shifting
    LSL  R3, R3, #1                 @ shift CRC left
    UXTH R3, R3                     @ mask to 16 bits
    BEQ  str_crc16_skip_poly        @ MSB was 0, no XOR needed
    EOR  R3, R3, R7                 @ crc ^= polynomial

str_crc16_skip_poly:
    SUBS R9, R9, #1
    BNE  str_crc16_bit_loop

    ADDS R5, R5, #1
    B    str_crc16_byte_loop

str_crc16_store:
    @ Append CRC big-endian: high byte first, then low byte
    LSR  R6, R3, #8
    STRB R6, [R1, R4]               @ CRC high byte
    ADDS R4, R4, #1
    STRB R3, [R1, R4]               @ CRC low byte (STRB masks to 8 bits)
    ADDS R4, R4, #1
    MOV  R9, #0
    STRB R9, [R1, R4]               @ trailing NUL for convenience

    POP  {R4, R5, R6, R7, R9, PC}


@ -------------------------------------------------------------
@ str_verify_crc16
@ -------------------------------------------------------------
@ Verify a CRC16-CCITT checksum.
@ Recomputes the CRC over the data bytes (everything except the
@ last 2 bytes) and compares against the stored CRC.
@ Uses the same algorithm as str_crc16_checksum.
@
@   + Input:  R1 = packet buffer address
@             R2 = total packet length including both CRC bytes
@   + Output: R3 = 0x00 if valid, non-zero if invalid
@   + Modifies: R4, R5, R6, R7, R9
.type str_verify_crc16, %function
str_verify_crc16:
    PUSH {R4, R5, R6, R7, R9, LR}

    SUBS R4, R2, #2                 @ R4 = data length (excludes 2 CRC bytes)

    MOV  R5, #0                     @ byte index
    MOV  R3, #0xFF
    ORR  R3, R3, R3, LSL #8         @ R3 = 0xFFFF (CRC init)

    LDR  R7, =CRC16_POLY

str_crc16v_byte_loop:
    CMP  R5, R4
    BEQ  str_crc16v_check

    LDRB R6, [R1, R5]
    LSL  R6, R6, #8
    EOR  R3, R3, R6

    MOV  R9, #8

str_crc16v_bit_loop:
    TST  R3, #0x8000
    LSL  R3, R3, #1
    UXTH R3, R3
    BEQ  str_crc16v_skip_poly
    EOR  R3, R3, R7

str_crc16v_skip_poly:
    SUBS R9, R9, #1
    BNE  str_crc16v_bit_loop

    ADDS R5, R5, #1
    B    str_crc16v_byte_loop

str_crc16v_check:
    @ Read stored CRC big-endian and reassemble into a 16-bit value
    LDRB R5, [R1, R4]               @ stored high byte
    ADDS R4, R4, #1
    LDRB R6, [R1, R4]               @ stored low byte
    ORR  R5, R6, R5, LSL #8         @ R5 = stored CRC (16-bit)

    @ Compare computed vs stored; set R3 = 0 on match, 1 on mismatch
    CMP  R3, R5
    ITE  EQ                         @ Thumb requires IT block for conditional MOV
    MOVEQ R3, #0                    @ match = valid
    MOVNE R3, #1                    @ mismatch = invalid

    POP  {R4, R5, R6, R7, R9, PC}
