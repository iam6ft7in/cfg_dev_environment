; macros.inc — Shared macros for {{REPO_NAME}}
; Include in source files with: %include "include/macros.inc"

; PRINT_STRING macro — write a null-terminated string to stdout
; Usage: PRINT_STRING msg, msg_len
%macro PRINT_STRING 2
    mov     rax, 1          ; sys_write syscall number
    mov     rdi, 1          ; file descriptor 1 = stdout
    mov     rsi, %1         ; pointer to the string
    mov     rdx, %2         ; length of the string
    syscall
%endmacro

; EXIT macro — terminate the program with a given exit code
; Usage: EXIT 0
%macro EXIT 1
    mov     rax, 60         ; sys_exit syscall number
    mov     rdi, %1         ; exit code
    syscall
%endmacro
