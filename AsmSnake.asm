bits 64
default rel

segment .data
    msg db "Hello, World! %d", 0xd, 0xa, 0
    allocationMsg db "Current snake segment allocations: %llu", 0xd, 0xa, 0
    positionMsg db "Current snake segment position: %f", 0xd, 0xa, 0
    windowTitle db "raylib window", 0
    segmentSize dd 16.0
    mapSize dd 32.0 ; Gets multiplied by segment size at runtime.
    zero dd 0.0
    negativeOne dd -1.0
    testFloat dq 777.0

segment .text
global Main

extern _CRT_INIT
extern ExitProcess
extern printf
extern malloc
extern realloc

extern InitWindow
extern SetTargetFPS
extern WindowShouldClose
extern CloseWindow
extern BeginDrawing
extern ClearBackground
extern DrawText
extern EndDrawing
extern DrawRectangle
extern DrawRectangleRec
extern IsKeyDown

KeyRight equ 262
KeyLeft equ 263
KeyDown equ 264
KeyUp equ 265

Main:
    ; Pushing rbp onto the stack aligns it to an increment of 16
    ; because rbp is 8 bytes.
    push rbp
    mov rbp, rsp
    sub rsp, 64 ; Reverse space for local variables.
    ; rsp + 8 = qword snake segments
    ; rsp + 16 = qword snake segment count
    ; rsp + 24 = qword snake segment capacity
    ; rsp + 32 = dword snake direction x
    ; rsp + 36 = dword snake direction y
    ; rsp + 40 = qword is first move

    ; Scale the map size by the snake's segment size.
    movss xmm0, [mapSize]
    mulss xmm0, [segmentSize]
    movss [mapSize], xmm0

    sub rsp, 32
    call _CRT_INIT
    add rsp, 32

    mov rax, 22
    call PrintMsg
    call PrintMsg

    sub rsp, 32
    cvtss2si rcx, [mapSize]
    mov rdx, rcx
    lea r8, [windowTitle]
    call InitWindow
    add rsp, 32

    sub rsp, 32
    mov rcx, 10
    call SetTargetFPS
    add rsp, 32

    mov qword [rsp + 16], 1
    mov qword [rsp + 24], 4

    mov rax, 16
    mov rcx, [rsp + 24]
    mul rcx
    mov rcx, rax
    sub rsp, 32
    call malloc
    add rsp, 32

    mov [rsp + 8], rax
    mov rax, [rsp + 8]
    mov dword [rax], __float32__(0.0)
    mov dword [rax + 1 * 4], __float32__(0.0)
    movss xmm0, [segmentSize]
    movss dword [rax + 2 * 4], xmm0
    movss dword [rax + 3 * 4], xmm0

    movss xmm0, [segmentSize]
    movss [rsp + 32], xmm0
    movss xmm0, [zero]
    movss [rsp + 36], xmm0

    mov qword [rsp + 40], 1 ; This is the first move.

.GameLoopBegin:
    sub rsp, 32
    call WindowShouldClose
    add rsp, 32

    cmp rax, 0
    jne .GameLoopEnd

    ;; Update:

    ; Expand snake.
    mov rax, [rsp + 16]
    inc rax
    mov [rsp + 16], rax

    lea rcx, [rsp + 8]
    mov rdx, [rsp + 16]
    mov r8, [rsp + 24]
    call EnsureSnakeCapacity
    mov [rsp + 24], rax

    ; Get position of the second to last segment.
    mov rdi, [rsp + 16]
    dec rdi
    mov rax, 16
    mul rdi
    mov rdi, rax
    mov rax, [rsp + 8]

    movss xmm0, [rax + rdi - 16]
    movss xmm1, [rax + rdi - 16 + 1 * 4]

    ; Set the position of the new segment to match the second to last segment.
    movss [rax + rdi], xmm0
    movss [rax + rdi + 1 * 4], xmm1
    movss xmm0, [segmentSize]
    movss dword [rax + rdi + 2 * 4], xmm0
    movss dword [rax + rdi + 3 * 4], xmm0

    ; Move snake.
    ; First move every segment to the position of the segment ahead of it.
    mov rdi, [rsp + 16]
    dec rdi
    mov rax, 16
    mul rdi
    mov rdi, rax
    mov rax, [rsp + 8]

.MoveSegmentsBegin:
    cmp rdi, 16
    jl .MoveSegmentsEnd

    ; Don't check for collisions on the first move (before the head has a chance to move).
    cmp qword [rsp + 40], 1
    je .NoSegmentCollision

    movss xmm0, [rax + rdi]
    comiss xmm0, [rax]
    jne .NoSegmentCollision
    movss xmm0, [rax + rdi + 4]
    comiss xmm0, [rax + 4]
    jne .NoSegmentCollision

    ; If we reach this point, then this segment is colliding with the head.
    ; So, reset the snake.
    movss xmm0, [zero]
    movss [rax], xmm0
    movss [rax + 4], xmm0
    movss [rsp + 36], xmm0
    movss xmm0, [segmentSize]
    movss [rsp + 32], xmm0

    mov qword [rsp + 16], 1
    mov qword [rsp + 40], 1 ; The snake is back on its first move.
    jmp .GameLoopBegin

.NoSegmentCollision:
    movss xmm0, [rax + rdi - 16]
    movss xmm1, [rax + rdi - 16 + 1 * 4]
    movss [rax + rdi], xmm0
    movss [rax + rdi + 1 * 4], xmm1

    sub rdi, 16

    jmp .MoveSegmentsBegin

.MoveSegmentsEnd:
    ; Then move the head of the snake.

    ; Move right if the right arrow is pressed.
    sub rsp, 32
    mov rcx, KeyRight
    call IsKeyDown
    add rsp, 32

    cmp al, 0
    je .MoveRightEnd
    movss xmm0, [segmentSize]
    movss [rsp + 32], xmm0
    movss xmm0, [zero]
    movss [rsp + 36], xmm0
    .MoveRightEnd:

    ; Move left if the left arrow is pressed.
    sub rsp, 32
    mov rcx, KeyLeft
    call IsKeyDown
    add rsp, 32

    cmp al, 0
    je .MoveLeftEnd
    movss xmm0, [segmentSize]
    mulss xmm0, [negativeOne]
    movss [rsp + 32], xmm0
    movss xmm0, [zero]
    movss [rsp + 36], xmm0
    .MoveLeftEnd:

    ; Move up if the up arrow is pressed.
    sub rsp, 32
    mov rcx, KeyUp
    call IsKeyDown
    add rsp, 32

    cmp al, 0
    je .MoveUpEnd
    movss xmm0, [segmentSize]
    mulss xmm0, [negativeOne]
    movss [rsp + 36], xmm0
    movss xmm0, [zero]
    movss [rsp + 32], xmm0
    .MoveUpEnd:

    ; Move down if the down arrow is pressed.
    sub rsp, 32
    mov rcx, KeyDown
    call IsKeyDown
    add rsp, 32

    cmp al, 0
    je .MoveDownEnd
    movss xmm0, [segmentSize]
    movss [rsp + 36], xmm0
    movss xmm0, [zero]
    movss [rsp + 32], xmm0
    .MoveDownEnd:

    ; Move the head based on user input.
    mov rax, [rsp + 8]

    movss xmm0, [rsp + 32]
    addss xmm0, [rax]
    movss [rax], xmm0

    movss xmm0, [rsp + 36]
    addss xmm0, [rax + 4]
    movss [rax + 4], xmm0

    ; Wrap the head around the map on the x-axis.
    movss xmm0, [rax]

.WrapBackXBegin:
    comiss xmm0, [mapSize]
    jb .WrapBackXEnd

    subss xmm0, [mapSize]
    jmp .WrapBackXBegin

.WrapBackXEnd:

.WrapForwardXBegin:
    comiss xmm0, dword [zero]
    jae .WrapForwardXEnd

    addss xmm0, [mapSize]
    jmp .WrapForwardXBegin

.WrapForwardXEnd:
    movss [rax], xmm0

    movss xmm0, [rax + 4]

    ; Wrap the head around the map on the y-axis.
.WrapBackYBegin:
    comiss xmm0, [mapSize]
    jb .WrapBackYEnd

    subss xmm0, [mapSize]
    jmp .WrapBackYBegin

.WrapBackYEnd:

.WrapForwardYBegin:
    comiss xmm0, [zero]
    jae .WrapForwardYEnd

    addss xmm0, [mapSize]
    jmp .WrapForwardYBegin

.WrapForwardYEnd:
    movss [rax + 4], xmm0

    mov qword [rsp + 40], 0 ; It is no longer the first move.

    ;; Draw:
    sub rsp, 32
    call BeginDrawing
    add rsp, 32

    sub rsp, 32
    mov rcx, 0xffffff
    call ClearBackground
    add rsp, 32

    mov rdi, 0

    mov rax, [rsp + 16]
    mov r10, 16
    mul r10
    mov r10, rax

.DrawSnakeBegin:
    cmp rdi, r10
    jge .DrawSnakeEnd

    mov rax, [rsp + 8]
    sub rsp, 32 + 16
    movss xmm0, [rax + rdi]
    movss [rsp + 32], xmm0
    movss xmm0, [rax + rdi + 1 * 4]
    movss [rsp + 32 + 1 * 4], xmm0
    movss xmm0, [rax + rdi + 2 * 4]
    movss [rsp + 32 + 2 * 4], xmm0
    movss xmm0, [rax + rdi + 3 * 4]
    movss [rsp + 32 + 3 * 4], xmm0
    lea rcx, [rsp + 32]
    mov rdx, 0xff0000ff
    call DrawRectangleRec
    add rsp, 32 + 16

    add rdi, 16

    jmp .DrawSnakeBegin

.DrawSnakeEnd:
    sub rsp, 32
    call EndDrawing
    add rsp, 32

    jmp .GameLoopBegin

.GameLoopEnd:
    sub rsp, 32
    call CloseWindow
    add rsp, 32

    mov rsp, rbp
    pop rbp

    ; The stack needs to be realigned to an increment of 16
    ; now that rbp is popped off the stack.
    sub rsp, 8

    xor rcx, rcx
    call ExitProcess

PrintMsg:
    push rbp
    mov rbp, rsp

    sub rsp, 32
    lea rcx, [msg]
    mov rdx, rax
    call printf
    add rsp, 32

    mov rax, 44

    mov rsp, rbp
    pop rbp
    ret

; rcx = pointer to snake segments (double pointer), rdx = snake segment count, r8 = snake segment capacity
; Returns new capacity.
EnsureSnakeCapacity:
    push rbp
    mov rbp, rsp
    sub rsp, 32 ; Space for local variables.
    mov [rsp], rcx
    mov [rsp + 8], rdx
    mov [rsp + 16], r8

    cmp rdx, r8
    jle .End

    ; Double the snake segment capacity.
    mov rax, [rsp + 16]
    mov rcx, 2
    mul rcx
    ; Save new capacity to return to caller.
    mov [rsp + 16], rax
    ; Convert capacity into new allocation size.
    mov rcx, 16
    mul rcx
    mov rdx, rax

    mov rcx, [rsp]
    sub rsp, 32
    mov rcx, [rcx]
    call realloc
    add rsp, 32
    mov rcx, [rsp]
    mov [rcx], rax

.End:
    mov rax, [rsp + 16]

    mov rsp, rbp
    pop rbp
    ret