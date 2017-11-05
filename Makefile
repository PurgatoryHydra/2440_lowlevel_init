all:start.S
	arm-linux-gcc -g -o start.bin start.S -c
	arm-linux-objdump -d start.bin > dis

clean:
	rm -f *.o
