.syntax unified
.thumb


.data
.equ RCC,       0x40021000
.equ AHBENR,    0x14
.equ APB1ENR,   0x1C

.equ GPIOC,     0x48000800
.equ MODER,     0x00
.equ AFRH,      0x24
.equ OSPEEDR,   0x08

.equ UART4,     0x40004C00
.equ CR1,       0x00
.equ BRR,       0x0C
.equ ISR,       0x1C
.equ TDR,       0x28

.text

main:
    /* Enable GPIOC clock (AHBENR bit 19) */
    LDR  R0, =RCC
    LDR  R1, [R0, #AHBENR]
    ORR  R1, R1, #(1 << 19)
    STR  R1, [R0, #AHBENR]

    /* Enable UART4 clock (APB1ENR bit 19) */
    LDR  R1, [R0, #APB1ENR]
    ORR  R1, R1, #(1 << 19)
    STR  R1, [R0, #APB1ENR]

    /* PC10, PC11 AF5 (UART4): AFRH bits foR pins 8..15.
       Pin10 -> AFRH[11:8], Pin11 -> AFRH[15:12], so wRite 0x55 into that byte. */
    LDR  R0, =GPIOC
    LDR  R1, [R0, #AFRH]
    BIC  R1, R1, #(0xFF << 8)
    ORR  R1, R1, #(0x55 << 8)
    STR  R1, [R0, #AFRH]

    /* PC10, PC11 mode = AlteRnate Function (10b peR pin) */
    LDR  R1, [R0, #MODER]
    /* CleaR MODER10[21:20] and MODER11[23:22] */
    BIC  R1, R1, #(0xF << 20)
    /* Set both to 10b => 0b1010 in that nibble */
    ORR  R1, R1, #(0xA << 20)
    STR  R1, [R0, #MODER]

    /* Optional: high speed foR PC10/11 */
    LDR  R1, [R0, #OSPEEDR]
    BIC  R1, R1, #(0xF << 20)
    ORR  R1, R1, #(0xF << 20)   /* 11b,11b */
    STR  R1, [R0, #OSPEEDR]

    /* UART4 BRR = 0x0457 foR 8MHz, 115200, oveRsampling16 */
    LDR  R0, =UART4
    LDR  R1, =0x0457
    STR  R1, [R0, #BRR]

    /* CR1: UE=1, RE=1, TE=1 => 0x0D */
    LDR  R1, [R0, #CR1]
    ORR  R1, R1, #0x0D
    STR  R1, [R0, #CR1]

tx_loop:
    /* wait TXE (bit 7) */
wait_txe:
    LDR  R1, [R0, #ISR]
    TST  R1, #(1 << 7)
    BEQ  wait_txe

    /* send byte 0xA5 */
    MOV  R2, #0xA5
    STR  R2, [R0, #TDR]

    B    tx_loop
