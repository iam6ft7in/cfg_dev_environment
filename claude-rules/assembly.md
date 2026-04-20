---
description: NASM x86/x64 Assembly rules for Windows
paths: ["**/*.asm", "**/*.inc", "**/Makefile"]
---

# Assembly Language Rules (NASM x86/x64)

## Assembler
- NASM 2.16+ for all assembly files
- Target: x86/x64 (64-bit unless explicitly 32-bit)
- Output format: elf64 for Linux, win64 for Windows PE executables
- Debugger: x64dbg

## Comment Style
- Teaching style is especially important in Assembly, comment every non-obvious instruction
- Comment the PURPOSE of a block before the block, not just what each instruction does
- Document register usage at the top of each function/procedure
- Explain syscall numbers: `mov rax, 1  ; sys_write, write to file descriptor`
- Explain addressing modes: `mov rax, [rbx]  ; dereference: load the value that rbx points to`

## Code Structure
- Always use: section .data, section .bss, section .text
- Function prologue: `push rbp` / `mov rbp, rsp`
- Function epilogue: `pop rbp` / `ret`
- Use macros for repeated patterns (keep them in include/macros.inc)
- Register conventions (x86-64 Linux):
  - Arguments: rdi, rsi, rdx, rcx, r8, r9
  - Return value: rax
  - Caller-saved: rax, rcx, rdx, rsi, rdi, r8, r9, r10, r11
  - Callee-saved: rbx, rbp, r12, r13, r14, r15

## Build System
- Always use a Makefile with targets: all, clean, run
- Use ${variable} syntax in Makefile
- Build artifacts go in obj/ and bin/ (both gitignored)

## Safety
- Document any code that modifies system state or makes syscalls
- Never commit executables (*.exe, *.elf), only source files
