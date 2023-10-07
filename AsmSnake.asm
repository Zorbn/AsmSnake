bits 64
default rel

segment .data
    windowTitle db "AsmSnake", 0
    segmentSize dd 16.0
    mapSizeInSegments dd 32
    mapSize dd 0.0 ; Gets set to mapSizeInSegments * segmentSize at runtime.
    halfMapSize dd 0.0
    zero dd 0.0
    negativeOne dd -1.0
    two dd 2.0

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
extern GetRandomValue

KeyRight equ 262
KeyLeft equ 263
KeyDown equ 264
KeyUp equ 265

DefaultSnakeSegmentCount equ 3

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
    ; rsp + 40 = dword apple x
    ; rsp + 44 = dword apple y

    ; Scale the map size by the snake's segment size.
    cvtsi2ss xmm0, [mapSizeInSegments]
    mulss xmm0, [segmentSize]
    movss [mapSize], xmm0

    movss xmm0, [mapSize]
    divss xmm0, [two]
    movss [halfMapSize], xmm0

    ; Start-up and create the window.
    sub rsp, 32
    call _CRT_INIT
    add rsp, 32

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

    ; Create the snake.
    mov qword [rsp + 16], DefaultSnakeSegmentCount
    mov qword [rsp + 24], 4

    mov rax, 16
    mov rcx, [rsp + 24]
    mul rcx
    mov rcx, rax
    sub rsp, 32
    call malloc
    add rsp, 32
    mov [rsp + 8], rax

    mov rcx, [rsp + 8]
    mov rdx, [rsp + 16]
    call PopulateSnakeSegments

    movss xmm0, [segmentSize]
    movss [rsp + 32], xmm0
    movss xmm0, [zero]
    movss [rsp + 36], xmm0

    lea rcx, [rsp + 40]
    lea rdx, [rsp + 44]
    call RandomizeApplePosition

.GameLoopBegin:
    sub rsp, 32
    call WindowShouldClose
    add rsp, 32

    cmp rax, 0
    jne .GameLoopEnd

    ;; Update:
    mov rax, [rsp + 8]
    movss xmm0, [rax]
    comiss xmm0, [rsp + 40]
    jne .ExpandSnakeEnd
    movss xmm0, [rax + 4]
    comiss xmm0, [rsp + 44]
    jne .ExpandSnakeEnd

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
    movss [rax + rdi + 2 * 4], xmm0
    movss [rax + rdi + 3 * 4], xmm0

    ; Move the apple to a new location.
    lea rcx, [rsp + 40]
    lea rdx, [rsp + 44]
    call RandomizeApplePosition

.ExpandSnakeEnd:
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

    mov qword [rsp + 16], DefaultSnakeSegmentCount
    mov rcx, [rsp + 8]
    mov rdx, [rsp + 16]
    call PopulateSnakeSegments

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
    comiss xmm0, [zero]
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

    ;; Draw:
    sub rsp, 32
    call BeginDrawing
    add rsp, 32

    sub rsp, 32
    mov rcx, 0xff228822
    call ClearBackground
    add rsp, 32

    mov rdi, 0

    mov rax, [rsp + 16]
    mov r10, 16
    mul r10
    mov r10, rax

    ; Draw the apple.
    movss xmm0, [rsp + 40]
    movss xmm1, [rsp + 44]
    sub rsp, 32 + 16
    movss [rsp + 32], xmm0
    movss [rsp + 32 + 1 * 4], xmm1
    movss xmm0, [segmentSize]
    movss [rsp + 32 + 2 * 4], xmm0
    movss [rsp + 32 + 3 * 4], xmm0
    lea rcx, [rsp + 32]
    mov rdx, 0xff0000ff
    call DrawRectangleRec
    add rsp, 32 + 16

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
    mov rdx, 0xff00ff00
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

; rcx = pointer to apple x, rdx = pointer to apple y
RandomizeApplePosition:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov [rsp], rcx
    mov [rsp + 8], rdx

    sub rsp, 32
    mov rcx, 0
    mov rdx, [mapSizeInSegments]
    dec rdx
    call GetRandomValue
    add rsp, 32
    cvtsi2ss xmm0, rax
    mulss xmm0, [segmentSize]
    mov rax, [rsp]
    movss [rax], xmm0

    sub rsp, 32
    mov rcx, 0
    mov rdx, [mapSizeInSegments]
    dec rdx
    call GetRandomValue
    add rsp, 32
    cvtsi2ss xmm0, rax
    mulss xmm0, [segmentSize]
    mov rax, [rsp + 8]
    movss [rax], xmm0

    mov rsp, rbp
    pop rbp
    ret

; rcx = snake segments, rdx = snake segment count
PopulateSnakeSegments:
    push rbp
    mov rbp, rsp

    movss xmm0, [halfMapSize] ; Segment x.
    movss xmm1, [segmentSize] ; Segment size.
    movss xmm3, [halfMapSize] ; Segment y.
    mov rdi, 0

.PopulateSnakeBegin:
    cmp rdi, rdx
    jge .PopulateSnakeEnd

    movss [rcx], xmm0
    movss [rcx + 1 * 4], xmm3
    movss [rcx + 2 * 4], xmm1
    movss [rcx + 3 * 4], xmm1

    inc rdi
    add rcx, 16
    subss xmm0, [segmentSize]

    jmp .PopulateSnakeBegin

.PopulateSnakeEnd:
    mov rsp, rbp
    pop rbp
    ret