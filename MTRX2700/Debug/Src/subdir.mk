################################################################################
# Automatically-generated file. Do not edit!
# Toolchain: GNU Tools for STM32 (14.3.rel1)
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
S_SRCS += \
../Src/definitions.s \
../Src/gpio.s \
../Src/initialise.s \
../Src/led.s \
../Src/main.s \
../Src/string.s \
../Src/uart.s 

C_SRCS += \
../Src/syscalls.c \
../Src/sysmem.c 

OBJS += \
./Src/definitions.o \
./Src/gpio.o \
./Src/initialise.o \
./Src/led.o \
./Src/main.o \
./Src/string.o \
./Src/syscalls.o \
./Src/sysmem.o \
./Src/uart.o 

S_DEPS += \
./Src/definitions.d \
./Src/gpio.d \
./Src/initialise.d \
./Src/led.d \
./Src/main.d \
./Src/string.d \
./Src/uart.d 

C_DEPS += \
./Src/syscalls.d \
./Src/sysmem.d 


# Each subdirectory must supply rules for building sources it contributes
Src/%.o: ../Src/%.s Src/subdir.mk
	arm-none-eabi-gcc -mcpu=cortex-m4 -g3 -DDEBUG -c -x assembler-with-cpp -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" --specs=nano.specs -mfpu=fpv4-sp-d16 -mfloat-abi=hard -mthumb -o "$@" "$<"
Src/%.o Src/%.su Src/%.cyclo: ../Src/%.c Src/subdir.mk
	arm-none-eabi-gcc "$<" -mcpu=cortex-m4 -std=gnu11 -g3 -DDEBUG -DSTM32F303VCTx -DSTM32 -DSTM32F3 -DSTM32F3DISCOVERY -c -I../Inc -O0 -ffunction-sections -fdata-sections -Wall -fstack-usage -fcyclomatic-complexity -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" --specs=nano.specs -mfpu=fpv4-sp-d16 -mfloat-abi=hard -mthumb -o "$@"

clean: clean-Src

clean-Src:
	-$(RM) ./Src/definitions.d ./Src/definitions.o ./Src/gpio.d ./Src/gpio.o ./Src/initialise.d ./Src/initialise.o ./Src/led.d ./Src/led.o ./Src/main.d ./Src/main.o ./Src/string.d ./Src/string.o ./Src/syscalls.cyclo ./Src/syscalls.d ./Src/syscalls.o ./Src/syscalls.su ./Src/sysmem.cyclo ./Src/sysmem.d ./Src/sysmem.o ./Src/sysmem.su ./Src/uart.d ./Src/uart.o

.PHONY: clean-Src

