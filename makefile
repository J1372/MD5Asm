EXECUTABLE = md5hash
OBJECTS = main.o md5_hash_x86-64.o

$(EXECUTABLE): $(OBJECTS)
	gcc -o $(EXECUTABLE) $(OBJECTS) -lm

# Build object files from C source.
%.o: %.c
	gcc -c -Wall -Werror $^ -o $@

# Assemble object files from .asm files with nasm.
%.o: %.asm
	nasm -f elf64 $^ -o $@

clean:
	rm -f $(EXECUTABLE) $(OBJECTS)
