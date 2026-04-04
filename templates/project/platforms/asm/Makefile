# Makefile for {{REPO_NAME}}
# Assembler: NASM (x86/x64)
# Build: make
# Clean: make clean
# Run: make run

# Use curly braces for all variables as per project standards
NASM    := nasm
LD      := ld
TARGET  := bin/main
SRC     := src/main.asm
OBJ     := obj/main.o
FORMAT  := elf64

.PHONY: all clean run

all: ${TARGET}

# Assemble: convert .asm source to .o object file
${OBJ}: ${SRC}
	@mkdir -p obj
	${NASM} -f ${FORMAT} -o ${OBJ} ${SRC}

# Link: combine object file into executable
${TARGET}: ${OBJ}
	@mkdir -p bin
	${LD} -o ${TARGET} ${OBJ}

# Run the compiled binary
run: ${TARGET}
	./${TARGET}

# Remove all build artifacts
clean:
	rm -f ${OBJ} ${TARGET}
