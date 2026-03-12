.syntax unified
.thumb

.global main

.type main, %function

.extern 512A.s
.extern 512B.s
.extern 512C.s
.extern 512D.s



.data
@ define variables


.text
@ define text


@ this is the entry function called from the startup file
main:
	@ ATTENTION: Please uncomment which module you want to use when debug, and comment the rest to avoid same function name
	@ being re-defined multiple times across the module files.

	@ When you are debugging, plase step into BLQ512_ for _ in range (A, B, C, D, E) and then you can use step over.


	BL Q512A
	@BL Q512B
	@BL Q512C
	@BL Q512D
	@BL Q512E


	B end

end:
	@ End here
	B end
