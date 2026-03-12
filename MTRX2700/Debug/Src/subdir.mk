################################################################################
# Automatically-generated file. Do not edit!
# Toolchain: GNU Tools for STM32 (14.3.rel1)
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
S_SRCS += \
../Src/512A.s \
../Src/512B.s \
../Src/Q512D.s \
../Src/Q513E.s \
../Src/definitions.s \
../Src/initialise.s \
../Src/main_file.s 

S_UPPER_SRCS += \
../Src/512C.S 

OBJS += \
./Src/512A.o \
./Src/512B.o \
./Src/512C.o \
./Src/Q512D.o \
./Src/Q513E.o \
./Src/definitions.o \
./Src/initialise.o \
./Src/main_file.o 

S_DEPS += \
./Src/512A.d \
./Src/512B.d \
./Src/Q512D.d \
./Src/Q513E.d \
./Src/definitions.d \
./Src/initialise.d \
./Src/main_file.d 

S_UPPER_DEPS += \
./Src/512C.d 


# Each subdirectory must supply rules for building sources it contributes
Src/%.o: ../Src/%.s Src/subdir.mk
	arm-none-eabi-gcc -mcpu=cortex-m4 -g3 -DDEBUG -c -x assembler-with-cpp -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" --specs=nano.specs -mfpu=fpv4-sp-d16 -mfloat-abi=hard -mthumb -o "$@" "$<"
Src/%.o: ../Src/%.S Src/subdir.mk
	arm-none-eabi-gcc -mcpu=cortex-m4 -g3 -DDEBUG -c -x assembler-with-cpp -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" --specs=nano.specs -mfpu=fpv4-sp-d16 -mfloat-abi=hard -mthumb -o "$@" "$<"

clean: clean-Src

clean-Src:
	-$(RM) ./Src/512A.d ./Src/512A.o ./Src/512B.d ./Src/512B.o ./Src/512C.d ./Src/512C.o ./Src/Q512D.d ./Src/Q512D.o ./Src/Q513E.d ./Src/Q513E.o ./Src/definitions.d ./Src/definitions.o ./Src/initialise.d ./Src/initialise.o ./Src/main_file.d ./Src/main_file.o

.PHONY: clean-Src

