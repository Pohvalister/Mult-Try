        section         .text

        global          _start
_start:

        sub             rsp, 2 * 128 * 8; сдвинуться на 2 ячейки (rsp - вершина стека)
        lea             rdi, [rsp +128 * 8]; поместить в rdi адрес rsp+... (поставить указатель)
        mov             rcx, 128; длина long чисел
        call            read_long; считать 1ое число
        mov             rdi, rsp; поместить в регистр rdi 1ое число
        call            read_long; считать 2ое число
        lea             rsi, [rsp + 128 * 8]; сместить указатель на 2ое число
        call            sub_long_long; вычесть число

        call            write_long; выводим

        mov             al, 0x0a; записываем в al код перевода строки (чтобы потом вывести)
        call            write_char; вывести этот символ?

        jmp             exit; return 0

; adds two long number
;    rdi -- address of summand #1 (long number)
;    rsi -- address of summand #2 (long number)
;    rcx -- length of long numbers in qwords
; result:
;    sum is written to rdi
sub_long_long:
        push            rdi; помещаем в стек
        push            rsi; ...
        push            rcx; ...

        clc
.loop:                     ;начало цикла
        mov             rax, [rdi]; берем 1 ый байт
        lea             rdi, [rdi + 8];сдвигаем его
        sbb             [rsi], rax; сложение с учетом переноса -> sbb?
        lea             rsi, [rsi + 8];cдвигаем байт суммы
        dec             rcx; уменьшение операнда на 1
        jnz             .loop; переход если содержимое аккумулятора не равно 0

        pop             rcx; извлечеие из стека
        pop             rdi; ...
        pop             rsi; ...
        ret

; adds 64-bit number to long number
;    rdi -- address of summand #1 (long number)
;    rax -- summand #2 (64-bit unsigned)
;    rcx -- length of long number in qwords
; result:
;    sum is written to rdi
add_long_short:
        push            rdi
        push            rcx
        push            rdx

        xor             rdx,rdx; rdx=0
.loop:
        add             [rdi], rax
        adc             rdx, 0;
        mov             rax, rdx;
        xor             rdx, rdx;
        add             rdi, 8; сдвигаем на 8 чтобы обратно по стеку вернуться
        dec             rcx; уменьшаем rcx на 1
        jnz             .loop

        pop             rdx
        pop             rcx
        pop             rdi
        ret

; multiplies long number by a short
;    rdi -- address of multiplier #1 (long number)
;    rbx -- multiplier #2 (64-bit unsigned)
;    rcx -- length of long number in qwords
; result:
;    product is written to rdi
mul_long_short:
        push            rax
        push            rdi
        push            rcx

        xor             rsi, rsi; rsi =0
.loop:
        mov             rax, [rdi]
        mul             rbx; mul bx --  dx:ax=ax*bx
        add             rax, rsi
        adc             rdx, 0
        mov             [rdi], rax
        add             rdi, 8
        mov             rsi, rdx
        dec             rcx
        jnz             .loop

        pop             rcx
        pop             rdi
        pop             rax
        ret

; divides long number by a short
;    rdi -- address of dividend (long number)
;    rbx -- divisor (64-bit unsigned)
;    rcx -- length of long number in qwords
; result:
;    quotient is written to rdi
;    rdx -- remainder
div_long_short:
        push            rdi
        push            rax
        push            rcx

        lea             rdi, [rdi + 8 * rcx - 8]
        xor             rdx, rdx

.loop:
        mov             rax, [rdi]
        div             rbx
        mov             [rdi], rax
        sub             rdi, 8; ax=dx:ax/bx , dx=dx:ax%bx
        dec             rcx
        jnz             .loop

        pop             rcx
        pop             rax
        pop             rdi
        ret

; assigns a zero to long number
;    rdi -- argument (long number)
;    rcx -- length of long number in qwords
set_zero:
        push            rax
        push            rdi
        push            rcx

        xor             rax, rax
        rep stosq           ; повторять пока содержимое cx не упадет до 0

        pop             rcx
        pop             rdi
        pop             rax
        ret

; checks if a long number is a zero
;    rdi -- argument (long number)
;    rcx -- length of long number in qwords
; result:
;    ZF=1 if zero
is_zero:
        push            rax
        push            rdi
        push            rcx

        xor             rax, rax
        rep scasq          ; повторять сканировать пока не найдет заданное значение (сх)

        pop             rcx
        pop             rdi
        pop             rax
        ret

; read long number from stdin
;    rdi -- location for output (long number)
;    rcx -- length of long number in qwords
read_long:
        push            rcx
        push            rdi

        call            set_zero
.loop:
        call            read_char
        or              rax, rax; логическое или
        js              exit
        cmp             rax, 0x0a; сравнить если да - число кончилось
        je              .done
        cmp             rax, '0'
        jb              .invalid_char; проверка на число
        cmp             rax, '9'
        ja              .invalid_char

        sub             rax, '0'
        mov             rbx, 10
        call            mul_long_short;rax rdx rcx
        call            add_long_short; набор цифр в число домножением и суммой всех
        jmp             .loop

.done:
        pop             rdi
        pop             rcx
        ret

.invalid_char:
        mov             rsi, invalid_char_msg
        mov             rdx, invalid_char_msg_size
        call            print_string
        call            write_char
        mov             al, 0x0a
        call            write_char

.skip_loop:
        call            read_char
        or              rax, rax
        js              exit
        cmp             rax, 0x0a
        je              exit
        jmp             .skip_loop

; write long number to stdout
;    rdi -- argument (long number)
;    rcx -- length of long number in qwords
write_long:
        push            rax
        push            rcx

        mov             rax, 20
        mul             rcx
        mov             rbp, rsp
        sub             rsp, rax

        mov             rsi, rbp

.loop:
        mov             rbx, 10
        call            div_long_short;выводим посимвольно
        add             rdx, '0'
        dec             rsi
        mov             [rsi], dl
        call            is_zero; приравниваем к 0
        jnz             .loop

        mov             rdx, rbp
        sub             rdx, rsi
        call            print_string

        mov             rsp, rbp
        pop             rcx
        pop             rax
        ret

; read one char from stdin
; result:
;    rax == -1 if error occurs
;    rax \in [0; 255] if OK
read_char:
        push            rcx
        push            rdi

        sub             rsp, 1
        xor             rax, rax
        xor             rdi, rdi
        mov             rsi, rsp
        mov             rdx, 1
        syscall

        cmp             rax, 1; сравнение rax и 1
        jne             .error; если не равно ошибка (ведь char - 1)
        xor             rax, rax
        mov             al, [rsp]
        add             rsp, 1

        pop             rdi
        pop             rcx
        ret
.error:
        mov             rax, -1
        add             rsp, 1
        pop             rdi
        pop             rcx
        ret

; write one char to stdout, errors are ignored
;    al -- char
write_char:
        sub             rsp, 1
        mov             [rsp], al; двигаем al на место

        mov             rax, 1; сдвигаем все тк al вставлен
        mov             rdi, 1
        mov             rsi, rsp
        mov             rdx, 1
        syscall
        add             rsp, 1
        ret

exit:
        mov             rax, 60; sys_exit
        xor             rdi, rdi
        syscall

; print string to stdout
;    rsi -- string
;    rdx -- size
print_string:
        push            rax

        mov             rax, 1
        mov             rdi, 1
        syscall                ; вывод строки ("1" - stdout)

        pop             rax
        ret


        section         .rodata; секция только для чтения
invalid_char_msg:
        db              "Invalid character: " ; перевод этого в набор битов
invalid_char_msg_size: equ             $ - invalid_char_msg; присвоить текущему адресу значение invalid...

