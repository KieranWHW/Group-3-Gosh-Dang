# MTRX2700 Assembly Lab — Group 3

## Group Members

| Name | Role |
|------|------|
| [Name 1] | Exercise 1 (Memory & Strings), string.s module |
| [Name 2] | Exercise 2 (Digital I/O), gpio.s / led.s modules |
| [Name 3] | Exercise 3 (UART), uart.s module |
| [Name 4] | Exercise 4 (Timers) / Exercise 5 (Integration), timer.s module |

---

## Project Overview

This project implements all five exercises from the MTRX2700 Assembly Lab using ARM Thumb assembly for the STM32F3 Discovery Board. The codebase is structured as a set of reusable peripheral modules (`string.s`, `uart.s`, `gpio.s`, `led.s`, `timer.s`) that are composed together through a single `main.s` entry point using `#include`. Each exercise file (`ex1_` through `ex5_`) calls into these shared modules rather than reimplementing low-level hardware access.

### Repository Structure

```
├── main.s              Entry point for Board 1 — includes all modules
├── main_b2.s           Entry point for Board 2 (Exercise 5 receiver only)
├── definitions.s       All hardware addresses, register offsets and constants
├── initialise.s        Clock, GPIO pin mode, UART4 and Timer 2 initialisation
├── string.s            String utilities: str_ prefix
├── uart.s              UART transmit/receive/validate: uart_ prefix
├── gpio.s              Button polling task handler: gpio_ prefix
├── led.s               LED pattern output: led_ prefix
├── timer.s             Hardware timer delay and control: timer_ prefix
├── ex1_memory.s        Exercise 1 demo entry point
├── ex2_gpio.s          Exercise 2 demo entry point
├── ex3_uart.s          Exercise 3 demo entry point
├── ex4_timer.s         Exercise 4 demo entry point
├── ex5_combine.s       Exercise 5 Board 1 (transmitter/counter)
└── ex5_combine_b2.s    Exercise 5 Board 2 (receiver/validator)
```

To switch between exercises, change the `BL ex5_run_demo` call in `main.s` to `BL ex1_run_demo`, `BL ex2_run_demo`, etc.

### Hardware Connections (Exercise 3 and 5)

- PC10 (TX) on Board 1 → PC11 (RX) on Board 2
- PC11 (RX) on Board 1 → PC10 (TX) on Board 2
- GND on Board 1 → GND on Board 2

---

## Exercise 1 — Memory and Pointers

### Summary

Demonstrates string manipulation and packet framing using the `str_` module. The demo runs five sub-tasks in sequence on the string `"GROUP 3"`:

1. Calculate the string length (not counting the NUL terminator)
2. Convert the string to all lower or all uppercase in place
3. Frame the string as a UART packet: `[STX][LEN][body][NUL][ETX]`
4. Compute an 8-bit XOR BCC checksum and append it to the packet
5. Verify the checksum — XOR of every byte in a valid packet including the checksum byte equals zero

### Usage

Set `EX1_CASE_MODE` at the top of `ex1_memory.s` to `LOWER_MODE` or `UPPER_MODE` before building. Call `ex1_run_demo` from `main.s`. Observe results in the debugger memory view.

### Valid Inputs

| Function | Input | Valid range |
|---|---|---|
| `str_count` | R1 = string address, R2 = 0 | Any NUL-terminated string in RAM |
| `str_lower_case` / `str_upper_case` | R1 = string address, R3 = 0 | ASCII strings; non-letter bytes are skipped |
| `str_concat` | R0 = source string, R1 = dest buffer, R2 = 0 | Source must be NUL-terminated; dest buffer must be ≥ source length + 4 bytes |
| `str_checksum` | R1 = buffer, R2 = packet length before checksum | Must be called after `str_concat`; buffer must have at least 1 byte spare |
| `str_verify_checksum` | R1 = buffer, R2 = total packet length | Must include the checksum byte in R2 |

### Functions and Modularity

All string helpers live in `string.s` and use the `str_` prefix. They are stateless apart from the buffer pointer passed in via registers, which means they can be safely reused across exercises.

**`str_count`** — Walks the string byte by byte comparing against NUL, incrementing R2 on each pass. No bound checking; if the string has no NUL terminator, the function will read past the end of the buffer.

**`str_lower_case` / `str_upper_case`** — Steps through the string using R3 as an index, checking each byte against the ASCII range for letters (`0x41–0x5A` for upper, `0x61–0x7A` for lower). Conversion is a single ADD or SUB of `0x20`, which is the fixed offset between upper and lower case in ASCII.

**`str_concat`** — Builds the UART frame: writes STX at index 0, copies the source body starting at index 2, appends a NUL terminator, then ETX. The final packet length (before checksum) is stored at index 1.

**`str_checksum`** — XORs every byte from index 0 up to the current end of the packet and appends the result. Updates the length byte at index 1 to include the checksum byte. After this call the packet is ready to transmit.

**`str_verify_checksum`** — XORs all bytes including the checksum. Returns R3 = 0x00 if intact, non-zero otherwise.

### Testing

**Planned inputs and expected outputs:**

| Input string | Expected length | Case result (LOWER) | Frame structure |
|---|---|---|---|
| `"GROUP 3"` | 7 | `"group 3"` | `[02][0D][group 3][00][03][CS]` |
| `"A"` | 1 | `"a"` | `[02][07][a][00][03][CS]` |
| `""` (empty) | 0 | `""` | `[02][06][][00][03][CS]` |

**Edge cases considered:**
- Empty string: `str_count` returns R2 = 0 immediately; `str_concat` still produces a valid frame with an empty body
- All digits or punctuation: `str_lower_case` / `str_upper_case` skip non-letter characters unchanged
- Single character string

**Checksum verification:** Build a known packet, manually flip one byte in the buffer, and confirm `str_verify_checksum` returns R3 ≠ 0. Restore the byte and confirm R3 = 0.

**Constraints and limitations:**
- No overflow protection: if the source string is longer than the destination buffer minus 4 bytes, the packet framing will write past the end of the buffer
- `str_count` assumes the string is NUL-terminated; a string without a NUL will cause an infinite loop
- BCC checksum does not detect transposed bytes or even numbers of identical bit errors

---

## Exercise 2 — Digital I/O

### Summary

Demonstrates LED output and button-driven binary counting using the `gpio_`, `led_` and `timer_` modules.

- **5.2.2a:** Sets a fixed LED pattern (`LED_PATTERN` from `definitions.s`)
- **5.2.2b–d:** Button-driven binary counter (0 → 255 → 0) with direction reversal and debounce. The counter increments on each press; at 255 the direction reverses to decrement; at 0 it reverses back to increment
- **5.2.2e:** Timed auto-counter — steps at a configurable interval without requiring button presses. Set `EX2_AUTO_MODE` to 1 to use this mode

Pull PA1 HIGH to exit the button loop and return from `ex2_run_demo`.

### Usage

Set `EX2_AUTO_MODE` to `0` for button mode or `1` for timed mode. Set `EX2_AUTO_DELAY_US` in `ex2_gpio.s` to change the auto-step period. Call `ex2_run_demo` from `main.s`.

### Valid Inputs

| Function | Input | Valid range |
|---|---|---|
| `led_set_pattern` | R7 = bitmask | 0x00 (all off) to 0xFF (all on); each bit maps to PE8–PE15 |
| `gpio_do_task_pa0` | R8 = function address, R11 = mode flag | R11 = 0 (TASK_MODE_ONCE) or 1 (TASK_MODE_HOLD) |
| `ex2_led_step` | R7 = current counter value | 0x00–0xFF |

### Functions and Modularity

**`led_set_pattern`** (`led.s`) — Writes R7 directly to the upper byte of GPIOE ODR, which maps to PE8–PE15. Uses `STRB` to avoid disturbing lower pins.

**`gpio_do_task_pa0`** (`gpio.s`) — A general-purpose button task dispatcher. Takes a function pointer in R8 and a mode flag in R11. In `TASK_MODE_ONCE` mode, executes the task once per press and waits for release before accepting the next press (debounce). In `TASK_MODE_HOLD` mode, executes the task repeatedly while the button is held with a software delay between executions. Polls PA1 as an exit signal on every iteration.

**`ex2_led_step`** (`ex2_gpio.s`) — Steps R7 in the current direction, updates the LEDs, then flips the direction flag in `led_dir` memory if the count has reached a boundary (0x00 or 0xFF). Direction state is stored in a `.data` variable so it persists across calls.

### Testing

**Planned inputs and expected outputs:**

| Starting counter | Direction | After one step | Display |
|---|---|---|---|
| 0x00 | up | 0x01 | `00000001` on LEDs |
| 0xFE | up | 0xFF | all LEDs on; direction flips to down |
| 0xFF | down | 0xFE | `11111110` on LEDs |
| 0x01 | down | 0x00 | all LEDs off; direction flips to up |

**Debounce test:** Press and hold the button and confirm only one increment occurs per press in `TASK_MODE_ONCE`. Rapidly tap the button multiple times and confirm no double-increments.

**Auto-mode test:** Set `EX2_AUTO_DELAY_US` to 500,000 (0.5 s). Verify the counter visually steps at approximately 0.5 s intervals. Use an oscilloscope on PE8 to confirm the step period.

**Constraints and limitations:**
- `gpio_do_task_pa0` debounce in `TASK_MODE_ONCE` is release-based, not time-based — very fast mechanical bounces on the press event are not filtered. For the assessment demonstration this is sufficient
- PA1 is pulled down internally so it reads LOW when floating; requires active HIGH signal to exit

---

## Exercise 3 — Serial Communication

### Summary

Demonstrates UART4 packet transmission and reception using the `uart_` and `str_` modules.

- **5.3.2a:** Builds a UART packet from the string `"GROUP 3"` and transmits it each time PA0 is pressed. Pull PA1 HIGH to exit the transmit loop
- **5.3.2b:** Validates the received packet structure and checksum, copies the body to a destination buffer, and replies with a framed ACK or NAK
- **5.3.2c:** Baud rate reconfiguration — change `BAUD_RATE` in `definitions.s` to `833` for 9600 baud or `69` for 115200 baud. Rebuild and confirm communication still works at the new rate

### Usage

Call `ex3_run_demo` from `main.s`. Connect UART4 TX/RX to a second board or serial terminal configured for 115200 baud, 8N1.

### Valid Inputs

| Function | Input | Valid range |
|---|---|---|
| `uart_transmit` | R1 = buffer, R2 = byte count | R2 must match the actual number of bytes in the buffer |
| `uart_read_check` | R1 = packet buffer, R2 = destination buffer | Packet must include STX, LEN, body, NUL, ETX, checksum |
| `uart_receive_packet` | R1 = destination, R2 = byte count | Blocks until exactly R2 bytes are received |

### Functions and Modularity

**`uart_transmit`** (`uart.s`) — Polls the TXE flag before writing each byte to TDR. Transmits exactly R2 bytes. Does not add framing; the packet must already be formatted by `str_concat` / `str_checksum` before calling.

**`uart_read_check`** (`uart.s`) — Validates a received packet in five steps: STX check, NUL terminator position, ETX position, XOR checksum, and byte count. Copies the body to R2 on success. Sends a framed ACK or NAK reply in both cases.

**`uart_receive_packet`** (`uart.s`) — Low-level polling receiver. Blocks on the RXNE flag for each byte. Used by Exercise 5 to receive packet bytes in two phases (header first, body second) without requiring a fixed maximum packet size.

**Baud rate calculation:**
```
BRR = f_PCLK / baud_rate
9600 baud:   8,000,000 / 9,600   = 833
115200 baud: 8,000,000 / 115,200 = 69
```
The value is set once in `initialise.s` via `set_baud_rate`. Both boards must use the same value.

### Testing

**Planned inputs and expected outputs:**

| Scenario | Expected result |
|---|---|
| Valid `"GROUP 3"` packet with correct checksum | `uart_read_check` returns ACK, body copied to destination |
| Packet with one byte flipped | Checksum fails, NAK returned |
| STX byte missing (replaced with 0x00) | First check fails, NAK returned immediately |
| ETX byte replaced | Third check fails, NAK returned |
| Length byte reduced by 1 | NUL terminator check fails, NAK returned |

**Oscilloscope test:** Probe PC10 (TX) while transmitting. Verify the baud period matches the configured rate. At 115200 baud each bit should be approximately 8.68 µs wide.

**Baud rate demo (5.3.2c):** Change `BAUD_RATE` to 833, rebuild both boards. Confirm ACK/NAK exchange still works. Change back to 69 and confirm again.

**Constraints and limitations:**
- Polling-based: the CPU is blocked during both transmit and receive; no other tasks can run concurrently
- No timeout in `uart_receive_packet` — if the sender stops mid-packet the receiver will hang indefinitely
- Maximum safe packet size is limited by the buffer sizes declared in each exercise file (128 bytes for Exercise 3)

---

## Exercise 4 — Hardware Timers

### Summary

Demonstrates hardware timer usage through four sub-tasks using the `timer_` module with Timer 2.

- **5.4.2a:** Output compare delay — lights an LED pattern, waits 5 seconds using CC1 compare match, then clears the LEDs
- **5.4.2b:** Prescaler justification — uses PSC = 799 (0.1 ms/tick) and counts 10,000 periods to confirm 1 second elapses
- **5.4.2c:** ARR preload (ARPE = 1) delay — an entirely hardware-managed 1-second delay using the buffered auto-reload register
- **5.4.2d:** Two LEDs blinking at independent frequencies from a shared 1 ms tick — PE8 at 1 Hz (500 ms half-period), PE9 at 5 Hz (100 ms half-period)

### Usage

Call `ex4_run_demo` from `main.s`. The sub-tasks run in sequence and do not require user input. Change `LED1_HALF_PERIOD` and `LED2_HALF_PERIOD` in `definitions.s` to adjust the blink frequencies for 5.4.2d.

### Valid Inputs

| Function | Input | Valid range |
|---|---|---|
| `timer_delay` | R1 = ticks | 1 to 2^32-1; actual time = R1 × (1/f_tick) where f_tick depends on PSC |
| `timer_set_psc` | R0 = prescaler value | 0 to 65535 for 16-bit PSC; actual divisor = PSC + 1 |
| `timer_delay_arr` | R0 = ticks | 1 to 2^32-1; ARPE = 1, delay is fully hardware-managed |

### Functions and Modularity

**`timer_delay`** (`timer.s`) — Writes R1 to CCR1, resets the counter to 0, clears any stale CC1F flag, then polls CC1F until the counter reaches the compare value. Uses output compare channel 1.

**`timer_set_psc`** (`timer.s`) — Writes the prescaler value and forces an immediate update event via `TIM_EGR` (UG = 1) so the shadow register loads without waiting for the next overflow.

**`timer_delay_arr`** (`timer.s`) — Writes R0 to ARR, sets ARPE = 1 in CR1, forces a UG update event to reload the shadow register, clears the resulting UIF flag, then polls UIF until the counter overflows. The hardware manages the reload entirely; there is no software jitter on the period.

### Prescaler Justification (5.4.2b)

| Target resolution | PSC value | Tick period | Max period (32-bit TIM2) |
|---|---|---|---|
| 1 µs | 7 | 1 µs | ~4295 s (71 min) |
| 0.1 ms | 799 | 100 µs | ~429,496 s (119 h) |
| 1 ms | 7999 | 1 ms | ~4,294,967 s (49 days) |
| 1 hour | 35999 | 4.5 µs | 4,294,967,295 × 4.5 µs ≈ 5.4 h (fits) |

For a 1-hour delay, PSC = 35999 (4.5 µs/tick) and ARR = 800,000,000 fits within TIM2's 32-bit counter.

### Testing

**5.4.2a:** Set a known LED pattern, trigger the delay, and measure the time between the LEDs turning on and turning off using a stopwatch or oscilloscope on any PE8–PE15 pin.

**5.4.2b:** The `ex4_psc_demo_loop` counts 10,000 iterations of `timer_delay(1)` with PSC = 799. Each call waits 1 tick = 0.1 ms, so 10,000 × 0.1 ms = 1 second. Toggle an LED at the end and time it with a stopwatch.

**5.4.2c:** Use an oscilloscope on any LED pin. The ARR preload delay should produce a cleaner edge than a software-polled delay because there is no jitter from the poll loop.

**5.4.2d:** Use an oscilloscope on PE8 and PE9 simultaneously. PE8 should toggle at 500 ms intervals (1 Hz), PE9 at 100 ms intervals (5 Hz). Verify the two channels remain independent over multiple minutes.

**Constraints and limitations:**
- `timer_delay` resets `TIM_CNT` to zero on every call, so any background use of the counter will be disrupted
- `timer_delay_arr` requires the timer to be running (`timer_start` called first)
- Two LEDs in 5.4.2d share the same 1 ms tick but are counted independently in software; for true hardware independence, two separate timers would be needed

---

## Exercise 5 — Integration

### Summary

Connects two STM32F3 Discovery boards over UART4 and exercises all previous modules together.

**Board 1** (`main.s` / `ex5_combine.s`):
- Increments a counter (0–255, wrapping) every 1 second
- Builds a `"COUNTER = XXX"` string, frames it as a UART packet, clears any UART errors, then transmits
- Waits up to 5 seconds for a framed ACK or NAK reply
- ACK → increment counter and continue
- NAK or timeout → flash all LEDs 3 times at 0.5 s intervals, reset counter to 0

**Board 2** (`main_b2.s` / `ex5_combine_b2.s`):
- Clears UART errors at the top of every receive loop to prevent lockup after bad packets
- Waits for a framed packet, validates structure, checksum, prefix and digit content
- Displays the counter value as a binary number on the LEDs
- Sends a framed ACK on success; sends NAK and flashes LEDs 3 times on failure

### Usage

Flash `main.s` to Board 1 and `main_b2.s` to Board 2. Connect TX→RX and RX→TX between the boards and connect GND. Both boards will wait 500 ms on startup before the first transfer. No user input is required; the loop runs continuously.

To run individual exercises instead of Exercise 5, change `BL ex5_run_demo` in `main.s` to `BL ex1_run_demo`, `BL ex2_run_demo`, `BL ex3_run_demo`, or `BL ex4_run_demo`.

### Valid Inputs

| Function | Input | Valid range |
|---|---|---|
| `int_to_str` | R0 = unsigned integer, R1 = destination buffer | 0–999 produces at most 3 digits; buffer must be ≥ 5 bytes |
| `str_to_int` | R1 = NUL-terminated ASCII decimal string | Digits '0'–'9' only; no sign, no overflow protection beyond 32-bit |
| `ex5_wait_ack` | none | Returns ACK (0x06), NAK (0x15), or 0xFF on timeout/bad reply |
| `ex5_b2_validate_counter_packet` | none (reads `rx_buf` directly) | Returns 1 if valid, 0 if any check fails |

### Functions and Modularity

**`int_to_str`** (`ex5_combine.s`) — Converts an unsigned integer to a NUL-terminated ASCII decimal string using stack-based digit reversal. The `UDIV` / `MLS` pair extracts digits least-significant first; they are pushed onto the stack then popped in reverse to write most-significant first. Handles the special case of zero directly.

**`str_to_int`** (`ex5_combine_b2.s`) — Parses a NUL-terminated decimal string into an integer using the standard multiply-and-add approach: `result = result × 10 + (byte − 0x30)` per digit.

**`ex5_wait_ack`** (`ex5_combine.s`) — Starts a fresh 5-second timeout window on TIM2 by writing `ACK_WAIT_MS` to ARR and forcing a UG update event. Polls both RXNE (byte arrived) and UIF (timeout). On a byte arriving, reads the packet header in two phases and returns the payload byte at index 2.

**`ex5_b2_validate_counter_packet`** (`ex5_combine_b2.s`) — Validates seven properties of the received packet in order: STX, NUL position, ETX position, checksum, `"COUNTER = "` prefix, at least one digit, and all-digit remainder. Returns 1 only if all seven pass.

**`ex5_uart_clear_errors` / `ex5_b2_uart_clear_errors`** — Clear the ORE (overrun error) flag via ICR and drain any residual bytes from RDR. Called before every transmit window on Board 1 and at the top of every receive loop on Board 2. This prevents the UART from locking up after a bad packet corrupts the receive state.

### Testing

**Board 1 only (loopback test):** Connect PC10 to PC11 on the same board. Board 1 will receive its own transmission and attempt to decode it as an ACK. The packet format will not match an ACK reply, so it will time out and flash the LEDs, then reset the counter. This confirms the transmit path and timeout logic work.

**Two-board normal operation:**
- Confirm the LEDs on Board 2 display the binary value of the counter and increment each second
- Confirm Board 2 sends ACK and Board 1 increments without flashing

**Corrupt packet test:** Briefly disconnect the TX wire while a packet is mid-transmission. Board 2 should detect a malformed packet, send NAK, and flash its LEDs. Board 1 should receive the NAK (or time out), flash its LEDs, and reset the counter to 0.

**UART lockup regression test:** After a NAK event, confirm Board 2 resumes receiving cleanly on the next packet without requiring a reset. This validates the `ex5_b2_uart_clear_errors` fix.

**Constraints and limitations:**
- Counter wraps at 255 back to 0 (single byte; the LED display is also 8-bit)
- `int_to_str` supports values 0–999 within the buffer allocation; values ≥ 1000 would overflow the 6-byte `counter_buf` space
- Board 1's 5-second ACK window is shared with the 3-second LED flash (3 × 1 s); after a NAK the total cycle time is approximately 4 seconds before the next transmission
- Both boards must be flashed and reset before the first packet exchange to ensure the 500 ms startup delays overlap cleanly