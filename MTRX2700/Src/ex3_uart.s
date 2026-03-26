.syntax unified
.thumb
.thumb_func

#include "definitions.s"

@ =============================================
@ Exercise 3 — Serial Communication (5.3.2)
@ =============================================
@ Demonstrates UART packet transmission on button press,
@ packet reception and validation with ACK/NAK response,
@ and baud rate reconfiguration for the clock speed demo.
@ Uses the uart_, str_, and gpio_ helper modules.

@ Baud rate values for the clock speed demo (5.3.2c)
@ Change the active .equ in definitions.s to switch baud rates
.equ EX3_BAUD_9600,   833   @ 9600 baud at 8MHz:   8,000,000 / 9600   = 833
.equ EX3_BAUD_115200,  69   @ 115200 baud at 8MHz: 8,000,000 / 115200 = 69


.data
ex3_msg:    .asciz "GROUP 3"    @ message string to transmit in 5.3.2a
ex3_tx_buf: .space 128          @ formatted packet buffer for transmission
ex3_rx_buf: .space 128          @ buffer for incoming UART data (5.3.2b)


.text


@ ========== Demo Entry Point ==========

@ Run Exercise 3 sub-tasks in sequence
@ 5.3.2a: Build a UART packet from ex3_msg, then send it each time the button is pressed
@         Pull PA1 HIGH to exit the button loop and move to 5.3.2b
@ 5.3.2b: Validate the locally built packet with uart_read_check and reply ACK or NAK
@         For two-board comms: fill ex3_rx_buf from the UART first, then call this
@ 5.3.2c: Baud rate reconfiguration — see comment below
@   + Input: None
@   + Output: None
@   + Modifies: R0-R3, R8, R11
@ Register map:
@   R0  = source string pointer (str_concat input)
@   R1  = transmit buffer pointer (str_concat / uart_transmit input)
@   R2  = packet length counter (str_concat / str_checksum output)
@   R3  = checksum accumulator
@   R8  = task function pointer passed to gpio_do_task_pa0
@   R11 = task mode flag passed to gpio_do_task_pa0
.type ex3_run_demo, %function
ex3_run_demo:
    PUSH {LR}

    @ ===== Task 5.3.2a — build packet, transmit on button press =====
    @ Build the formatted packet once so ex3_task_transmit has something to send
    LDR R0, =ex3_msg            @ R0 = source string
    LDR R1, =ex3_tx_buf         @ R1 = destination buffer
    BL str_reset_counter        @ R2 = 0
    BL str_concat               @ format [STX][Len][Body][ETX] -> R2 = packet length
    BL str_checksum             @ append checksum -> R2 = full packet length

    @ Each button press sends the complete packet over UART4
    LDR R8, =ex3_task_transmit  @ R8 = transmit wrapper
    MOV R11, #TASK_MODE_ONCE    @ one transmission per tap
    BL gpio_do_task_pa0         @ blocks until PA1 goes HIGH to exit

    @ ===== Task 5.3.2b — receive and validate a UART packet =====
    @ R1 points to ex3_tx_buf (the packet we just built) as a single-board test
    @ For two-board comms: point R1 at a buffer filled by polling RXNE first
    LDR R1, =ex3_tx_buf         @ R1 = packet to validate
    LDR R2, =ex3_rx_buf         @ R2 = destination buffer for the extracted string body
    BL uart_read_check          @ validates packet, copies body to R2, sends ACK or NAK

    @ ===== Task 5.3.2c — clock speed / baud rate demo =====
    @ To demonstrate: change BAUD_RATE in definitions.s to EX3_BAUD_9600 (833)
    @ then rebuild and confirm comms still work at 9600 baud on both boards.
    @ Switching back to EX3_BAUD_115200 (69) restores normal operation.
    @ The calculation is: BRR = f_PCLK / baud_rate (integer division, no oversampling)

    POP {PC}


@ ========== Transmit Task Wrapper ==========

@ Wrapper so gpio_do_task_pa0 can invoke uart_transmit via R8
@ Reads the packet length from the packet header to avoid needing
@ R2 to survive across the gpio polling loop
@   + Input:  None (reads packet from ex3_tx_buf directly)
@   + Output: None
@   + Modifies: R0, R1, R2
.type ex3_task_transmit, %function
ex3_task_transmit:
    PUSH {LR}
    LDR R1, =ex3_tx_buf                 @ point R1 to the packet buffer
    LDRB R2, [R1, #LENGTH_BYTE_IDX]    @ read packet length from the header byte
    BL uart_transmit
    POP {PC}
