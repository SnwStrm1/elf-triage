.intel_syntax noprefix
.global _start

.equ HEADER_SIZE, 64
.equ SYS_READ, 0
.equ SYS_WRITE, 1
.equ SYS_OPEN, 2
.equ SYS_CLOSE, 3
.equ SYS_EXIT, 60
.equ EINTR, 4

.section .rodata
hex_digits: .ascii "0123456789abcdef"
usage: .asciz "Usage: elf-triage FICHIER\n"
open_error: .asciz "Erreur : ouverture du fichier impossible.\n"
read_error: .asciz "Erreur : lecture du fichier impossible.\n"
short_header: .asciz "Erreur : en-tete ELF tronque.\n"
bad_magic: .asciz "Erreur : signature ELF absente.\n"
unsupported: .asciz "Erreur : seuls les ELF64 little-endian (version 1) sont pris en charge.\n"
bad_size: .asciz "Erreur : taille d'en-tete ELF64 invalide.\n"
machine_label: .asciz "Architecture : "
type_label: .asciz "Type ELF     : "
entry_label: .asciz "Point entree : "
x86_64_name: .asciz "x86-64 "
aarch64_name: .asciz "AArch64 "
riscv_name: .asciz "RISC-V "
type_none: .asciz "ET_NONE "
type_rel: .asciz "ET_REL "
type_exec: .asciz "ET_EXEC "
type_dyn: .asciz "ET_DYN "
type_core: .asciz "ET_CORE "
.align 8
type_names: .quad type_none, type_rel, type_exec, type_dyn, type_core

.section .bss
header: .skip HEADER_SIZE
hex_buffer: .skip 19

.section .text
_start:
    cmp qword ptr [rsp], 2
    jne wrong_arguments

    mov rdi, [rsp + 16]
    xor esi, esi
    xor edx, edx
    mov eax, SYS_OPEN
    syscall
    test rax, rax
    js cannot_open

    mov r12, rax
    lea r13, [rip + header]
    xor r14d, r14d

read_header:
    mov eax, SYS_READ
    mov rdi, r12
    lea rsi, [r13 + r14]
    mov edx, HEADER_SIZE
    sub rdx, r14
    syscall
    cmp rax, -EINTR
    je read_header
    test rax, rax
    js cannot_read
    jz close_input
    add r14, rax
    cmp r14, HEADER_SIZE
    jb read_header

close_input:
    mov eax, SYS_CLOSE
    mov rdi, r12
    syscall

    cmp r14, 4
    jb truncated
    cmp dword ptr [r13], 0x464c457f
    jne not_elf
    cmp r14, 16
    jb truncated
    cmp byte ptr [r13 + 4], 2
    jne invalid_format
    cmp byte ptr [r13 + 5], 1
    jne invalid_format
    cmp byte ptr [r13 + 6], 1
    jne invalid_format
    cmp r14, HEADER_SIZE
    jb truncated
    cmp dword ptr [r13 + 20], 1
    jne invalid_format
    cmp word ptr [r13 + 52], HEADER_SIZE
    jne invalid_size

    mov edi, 1