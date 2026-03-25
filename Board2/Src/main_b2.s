.syntax unified
.thumb

#include "definitions.s"
#include "initialise.s"
#include "string.s"
#include "uart.s"
#include "gpio.s"
#include "led.s"
#include "timer.s"
#include "ex5_combine_b2.s"

.global main
.type main, %function

main:
    BL enable_gpio_clocks
    BL initialise_io
    BL enable_uart
    BL enable_timer

    BL ex5_board2_run_demo

end:
    B end
