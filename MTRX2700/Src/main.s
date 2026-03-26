.syntax unified
.thumb

#include "definitions.s"
#include "initialise.s"
#include "string.s"
#include "uart.s"
#include "gpio.s"
#include "led.s"
#include "timer.s"
#include "ex1_memory.s"
#include "ex2_gpio.s"
#include "ex3_uart.s"
#include "ex4_timer.s"
#include "ex5_combine.s"

.global main
.type main, %function

main:
    BL enable_gpio_clocks
    BL initialise_io
    BL enable_uart
    BL enable_timer

    BL ex5_run_demo     @ swap this to ex1_, ex2_, ex3_, or ex4_ to select exercise

end:
    B end               @ infinite loop to prevent falling off into undefined memory
