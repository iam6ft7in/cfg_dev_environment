; {{REPO_NAME}} — {{DESCRIPTION}}
; Platform: x86/x64 NASM Assembly
; Assembler: NASM 2.16+
; Build: make

; Define the data segment — holds initialized data (strings, constants)
section .data
    msg     db "{{REPO_NAME}} running", 10, 0
    msg_len equ $ - msg

; Define the BSS segment — holds uninitialized data (variables)
section .bss

; Define the text (code) segment — holds executable instructions
section .text
    global main         ; Export main symbol for the linker

main:
    ; Function prologue — save the base pointer and establish stack frame
    push    rbp
    mov     rbp, rsp

    ; TODO: Add your code here

    ; Function epilogue — restore stack frame and return
    mov     rax, 0      ; Return value 0 (success)
    pop     rbp
    ret
