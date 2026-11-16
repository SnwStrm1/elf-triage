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
    lea rsi, [rip + machine_label]
    call print_string
    movzx ebx, word ptr [r13 + 18]     # e_machine
    lea rsi, [rip + x86_64_name]
    cmp ebx, 62
    je print_machine_name
    lea rsi, [rip + aarch64_name]
    cmp ebx, 183
    je print_machine_name
    lea rsi, [rip + riscv_name]
    cmp ebx, 243
    jne print_machine_code

print_machine_name:
    call print_string

print_machine_code:
    mov eax, ebx
    call print_hex_line

    mov edi, 1
    lea rsi, [rip + type_label]
    call print_string
    movzx ebx, word ptr [r13 + 16]     # e_type
    cmp ebx, 4
    ja print_type_code
    lea rsi, [rip + type_names]
    mov rsi, [rsi + rbx * 8]
    call print_string

print_type_code:
    mov eax, ebx
    call print_hex_line

    mov edi, 1
    lea rsi, [rip + entry_label]
    call print_string
    mov rax, [r13 + 24]               # e_entry
    call print_hex_line

    xor edi, edi
    jmp exit_program

wrong_arguments:
    lea rsi, [rip + usage]
    mov ebx, 2
    jmp report_error

cannot_open:
    lea rsi, [rip + open_error]
    jmp file_error

cannot_read:
    mov eax, SYS_CLOSE
    mov rdi, r12
    syscall
    lea rsi, [rip + read_error]
    jmp file_error

truncated:
    lea rsi, [rip + short_header]
    jmp file_error

not_elf:
    lea rsi, [rip + bad_magic]
    jmp file_error

invalid_format:
    lea rsi, [rip + unsupported]
    jmp file_error

invalid_size:
    lea rsi, [rip + bad_size]

file_error:
    mov ebx, 1

report_error:
    mov edi, 2
    call print_string
    mov edi, ebx

exit_program:
    mov eax, SYS_EXIT
    syscall

# EDI = descripteur, RSI = adresse de la chaine terminee par NUL.
print_string:
    xor edx, edx
string_length:
    cmp byte ptr [rsi + rdx], 0
    je write_buffer
    inc rdx
    jmp string_length

# RAX = valeur a afficher sur stdout, avec prefixe 0x et saut de ligne.
print_hex_line:
    lea rsi, [rip + hex_buffer]
    lea r8, [rip + hex_digits]
    mov word ptr [rsi], 0x7830        # '0', 'x'
    mov byte ptr [rsi + 18], 10
    mov ecx, 17

hex_digit:
    mov edx, eax
    and edx, 0xf
    mov dl, [r8 + rdx]
    mov [rsi + rcx], dl
    shr rax, 4
    dec ecx
    cmp ecx, 2
    jae hex_digit

    mov edi, 1
    mov edx, 19

# EDI = descripteur, RSI = tampon, RDX = octets restants.
write_buffer:
    mov eax, SYS_WRITE
    syscall
    cmp rax, -EINTR
    je write_buffer
    test rax, rax
    jle write_failed
    add rsi, rax
    sub rdx, rax
    jnz write_buffer
    ret

write_failed:
    mov edi, 1
    jmp exit_program

.section .note.GNU-stack,"",@progbits
