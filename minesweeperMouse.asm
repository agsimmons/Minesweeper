TITLE Minesweeper By Andrew Simmons, Brendan Sileo, Ethan Smith
.386
.MODEL FLAT, STDCALL
OPTION CASEMAP:none
INCLUDE \masm32\include\Irvine32.inc
INCLUDE \masm32\include\windows.inc
INCLUDE \masm32\include\user32.inc
INCLUDE \masm32\include\kernel32.inc
INCLUDELIB \masm32\lib\user32.lib
INCLUDELIB \masm32\lib\kernel32.lib
INCLUDELIB \masm32\lib\Irvine32.lib

.data
	rHnd HANDLE ?
	numEventsRead DWORD ?
	numEventsOccurred DWORD ?
	eventBuffer INPUT_RECORD 128 DUP(<>)
	coordString BYTE "(", 0
	clickType db ?
	xLoc db ?
	yLoc db ?

	xCoord db ?
	yCoord db ?

	; Width of game board
	boardWidth dd ?

	; Number of mines on game board
	numMines db ?

	;Text messages
	widthRequest db "Choose your board size: (1) Small, (2) Medium, or (3) Large:",0
	sizeInputError db "Please input 1, 2 or 3.", 0
	playAgainMessage db "Would you like to play again? (1 for yes, 0 for no): ", 0

	; Base state array
	; Possible values:
	;     0: Empty
	;     1-8: # of adjacent mines
	;     9: Mine
	baseState db 400 DUP(0)

	; Cover state array
	; Possible values:
	;     0: Uncovered
	;     1: Covered
	;     2: Covered, Flagged
	;     3: Covered, Question Mark
	coverState db 400 DUP(1)

	; Mine location array
	; Possible values:
	;	0 to boardWidth^2
	; Length:
	;	numMines
	mineLocations dd 41 DUP(0)

	; === Constants ============================================================
	welcomeMenuLayout db "                  _____ _", 0dh, 0ah, \
	                     "                 |     |_|___ ___ ___ _ _ _ ___ ___ ___ ___ ___", 0dh, 0ah, \
	                     "                 | | | | |   | -_|_ -| | | | -_| -_| . | -_|  _|", 0dh, 0ah, \
	                     "                 |_|_|_|_|_|_|___|___|_____|___|___|  _|___|_|", 0dh, 0ah, \
	                     "                                                   |_|", 0dh, 0ah, 0

	creditsMessage db "               By. Andrew Simmons, Brendan Sileo, and Ethan Smith", 0dh, 0ah, 0

	space db " "
	leftClick db "Left Click", 0
	rightClick db "Right Click", 0

.code
main proc

	call Randomize
	call welcomeMenu
	call inputBoardWidth
	call generateMines
	call placeMines
	call printBoardDebug
	call populateAdjacencies
	;call Clrscr
	call printBoardDebug
	;call mouseLoop
	invoke ExitProcess, 0

main endp

; TODO: Test this. I couldn't test it without the functionality to uncover the board
redrawBoard proc
	pushad ; Push register states

	mov esi, offset baseState
	mov edi, offset coverState

	mov ecx, 0 ; outerRedrawLoopCounter
	mov ebx, 0 ; innerRedrawLoopCounter

	outerRedrawLoop:
		mov al, '|'
		call WriteChar

		mov ebx, 0 ; Reset innerPopulateLoopCount for each iteration of outer loop
		innerRedrawLoop:
			; Do work
			mov al, [edi] ; Move nth value of coverState into al
			cmp al, 0 ; If location is uncovered
			je uncoveredState ; Jump to uncoveredState
			; Otherwise, if location is covered
			; Draw as covered
			mov al, '#'
			call WriteChar
			jmp afterCharacter

			uncoveredState:
				mov al, [esi] ; Move baseState value into al
				cmp al, 0
				je drawSpace


				drawSpace:
					mov al, ' '
					call WriteChar
					jmp afterCharacter
				drawAdjacency:
					add al, 48 ; Convert number to ascii character
					call WriteChar
					jmp afterCharacter
				drawMine:
					mov al, '*'
					call WriteChar
					jmp afterCharacter

			afterCharacter:
				mov al, '|'
				call WriteChar

			inc esi
			inc edi
			; End work

			inc ebx ; Increment innerPopulateLoopCounter
			cmp ebx, boardWidth ; If innerPopulateLoopCounter != boardWidth
			jne innerRedrawLoop ; Repeat inner loop
		; <Post Outer Loop>
		call Crlf ; Move cursor to new line
		; </Post Outer Loop>
		inc ecx ; Increment outerRedrawLoopCounter
		cmp ecx, boardWidth ; If outerRedrawLoopCounter != boardWidth
		jne outerRedrawLoop ; Repeat outer loop

	popad ; Pop register states
	ret
redrawBoard endp

; Inputs:
;	None
; Outputs:
;	xLoc
;	yLoc
mouseLoop proc
	mLoop:
		call mouseLoc
		jmp mLoop
mouseLoop endp

; Inputs:
;	xLoc
;	yLoc
; Outputs:
;	xCoord
;	yCoord
coordToGrid proc
	pusha
	cmp clickType, 1
	jne right
	mov edx, offset leftClick
	jmp cont
right:
	cmp clickType, 2
	jne cont
	mov edx, offset rightClick
cont:
	call Crlf
	call WriteString
	call Crlf
	mov dx,0
	mov eax,0
	mov al,xLoc
	mov cx,2
	div cx
	mov xCoord, al
	call WriteInt

	mov eax, 0
	mov al, yLoc
	sub al, 1
	mov yCoord, al
	call WriteInt
	popa
	ret
coordToGrid endp

; Inputs:
;	boardWidth
; Outputs:
;	xLoc
;	yLoc
mouseLoc proc
	pusha
	invoke GetStdHandle, STD_INPUT_HANDLE
	mov rHnd, eax
	invoke SetConsoleMode, rHnd, ENABLE_LINE_INPUT OR ENABLE_MOUSE_INPUT OR ENABLE_EXTENDED_FLAGS
	appContinue:
		invoke GetNumberOfConsoleInputEvents, rHnd, OFFSET numEventsOccurred
		cmp numEventsOccurred, 0
		je appContinue
		invoke ReadConsoleInput, rHnd, OFFSET eventBuffer, numEventsOccurred, OFFSET numEventsRead
		mov ecx, numEventsRead
		mov esi, OFFSET eventBuffer
	loopOverEvents:
		;ignore if >= 3x board width
		cmp (INPUT_RECORD PTR [esi]).EventType, MOUSE_EVENT
		jne notMouse
		test (INPUT_RECORD PTR [esi]).MouseEvent.dwButtonState, FROM_LEFT_1ST_BUTTON_PRESSED
		jz checkRight
		mov clickType, 1
	getMouseLoc:
		mov eax, boardWidth
		mov ebx, 3
		mul ebx
		cmp (INPUT_RECORD PTR [esi]).MouseEvent.dwMousePosition.x, ax
		jge notMouse
		mov eax, boardWidth
		add eax, 1
		cmp (INPUT_RECORD PTR [esi]).MouseEvent.dwMousePosition.y, ax
		jge notMouse
		movzx eax, (INPUT_RECORD PTR [esi]).MouseEvent.dwMousePosition.x
		mov xLoc, al
		movzx eax, (INPUT_RECORD PTR [esi]).MouseEvent.dwMousePosition.y
		mov yLoc, al
		jmp clicked
	notMouse:
		add esi, TYPE INPUT_RECORD
		loop loopOverEvents
		jmp appContinue
	clicked:
		call coordToGrid
	popa
	ret
	
	checkRight:
		test (INPUT_RECORD PTR [esi]).MouseEvent.dwButtonState, RIGHTMOST_BUTTON_PRESSED
		jz notMouse
		mov clickType, 2
		jmp getMouseLoc
mouseLoc ENDP

; Inputs:
;	boardWidth
;	numMines
;	mineLocations
; Outputs:
;	mineLocations
generateMines proc
	push eax
	push ecx
	push edx

	mov eax, boardWidth
	mul eax
	mov ecx, 0
	mov cl, numMines
	mov edi, offset mineLocations

	gen:
		push eax
		call RandomRange
		mov [edi], eax
		add edi, 4
		pop eax
		loop gen

	pop edx
	pop ecx
	pop eax
	ret
generateMines endp

; Inputs:
;	mineLocations
;	baseState
;	numMines
; Outputs:
;	baseState
placeMines proc
	push ecx
	push edx

	mov esi, offset mineLocations
	mov edi, offset baseState
	mov edx, 9d
	mov ecx, 0
	mov cl, numMines

	place:
		push edi
		add edi, [esi]
		mov [edi], dl
		add esi, 4
		pop edi
		loop place

	pop edx
	pop ecx
	ret
placeMines endp

; Inputs:
;     baseState
; Outputs:
;     baseState
populateAdjacencies proc
	; Store register state
	push eax
	push ebx
	push ecx
	push esi

	mov esi, offset baseState

	mov eax, 0
	mov ecx, 0 ; outerPopulateLoopCounter
	mov ebx, 0 ; innerPopulateLoopCounter

	; Nested for  loop
	outerPopulateLoop:
		mov ebx, 0 ; Reset innerPopulateLoopCount for each iteration of outer loop
		innerPopulateLoop:
			; Do work
			mov eax, 0
			mov al, [esi]
			cmp eax, 9 ; Is it a mine?
			jne skip ; If not, skip this tile

			; If it is a mine
			; Top-Left Check
			sub ebx, 1
			sub ecx, 1
			call checkAdjacency

			; Top Check
			add ebx, 1
			call checkAdjacency

			; Top Right Check
			add ebx, 1
			call checkAdjacency

			; Left Check
			add ecx, 1
			sub ebx, 2
			call checkAdjacency

			; Right Check
			add ebx, 2
			call checkAdjacency

			; Bottom Left Check
			add ecx, 1
			sub ebx, 2
			call checkAdjacency

			; Bottom Check
			add ebx, 1
			call checkAdjacency

			; Bottom Right Check
			add ebx, 1
			call checkAdjacency

			; Return loop counters to normal values
			sub ecx, 1
			sub ebx, 1

			skip:
				add esi, type baseState
			; End work

			inc ebx ; Increment innerPopulateLoopCounter
			cmp ebx, boardWidth ; If innerPopulateLoopCounter != boardWidth
			jne innerPopulateLoop ; Repeat inner loop
		inc ecx ; Increment outerPopulateLoopCounter
		cmp ecx, boardWidth ; If outerPopulateLoopCounter != boardWidth
		jne outerPopulateLoop ; Repeat outer loop

	; Restore register state
	pop esi
	pop ecx
	pop ebx
	pop eax

	ret
populateAdjacencies endp

checkAdjacency proc
	cmp ebx, 0 ; If x < 0
	jl checkAdjacencyDone ; Skip checkAdjacencyDone
	cmp ebx, boardWidth ; If x >= boardWidth
	jge checkAdjacencyDone ; Skip checkAdjacencyDone
	cmp ecx, 0 ; If y < 0
	jl checkAdjacencyDone ; Skip to checkAdjacencyDone
	cmp ecx, boardWidth ; If y >= boardWidth
	jge checkAdjacencyDone ; Skip to checkAdjacencyDone


	; If it is a valid coordinate
	mov eax, ecx ; Move y coordinate to eax (x is already in ebx)
	call xyToIndex ; Convert x,y to index
	mov edi, offset baseState ; Get offset of baseState in edi
	add edi, eax ; Move offset to specified element

	mov eax, 9
	cmp [edi], al ; If value at index is a mine
	je checkAdjacencyDone ; Skip this tile

	mov eax, 1
	add [edi], al ; Increment by one

	checkAdjacencyDone:
	ret
checkAdjacency endp

; TODO: Correctly handle non-integer input
;Inputs:
;	None
;Outputs:
;	eax: Play again response
;     0: No
;     1: Yes
askPlayAgain proc
	push edx

	askPlayAgainQuestion:
		mov edx, offset playAgainMessage
		call WriteString

		call ReadInt

		cmp eax, 1
		je doneAskPlayAgain
		cmp eax, 0
		je doneAskPlayAgain

		jmp askPlayAgainQuestion

	doneAskPlayAgain:
		pop edx
		ret
askPlayAgain endp

; Inputs:
;	coverState
;	baseState
;	boardWidth
;	space
; Outputs:
;	none
printBoardDebug proc
	push eax
	push ebx
	push ecx
	push edx

	mov esi, offset coverState
	mov edi, offset baseState

	mov eax, boardWidth	;set loop counter to boardWidth^2
	mul eax
	mov ecx, eax		;move count to ecx

	mov eax, 0
	mov edx, offset space
	nl:
		cmp ecx, 0		;print newline & end proc when ecx 0
		jle done		;
		call Crlf		;
		mov ebx, boardWidth	;
	print:
		mov al, [esi]		;print coverState
		call WriteDec		;
		mov al, [edi]		;print baseState
		call WriteDec		;
		mov al, 32
		call WriteChar		;print space
		inc esi			;
		inc edi			;
		dec ebx			;
		dec ecx			;

		cmp ebx, 0
		jle nl

		cmp ecx, 0
		jge print
	done:
		call Crlf
		pop edx
		pop ecx
		pop ebx
		pop eax
	ret
printBoardDebug endp

; Inputs:
;     None
; Outputs:
;     None
welcomeMenu proc
	push eax
	push edx

	call Clrscr

	call Crlf
	call Crlf
	call Crlf
	call Crlf

	mov edx, offset welcomeMenuLayout
	call WriteString

	call Crlf
	call Crlf
	call Crlf
	call Crlf

	mov edx, offset creditsMessage
	call WriteString

	mov eax, 5000
	call Delay

	call Clrscr

	pop edx
	pop eax

	ret
welcomeMenu endp

;Inputs:
;	None
;Outputs:
;	boardWidth: Width of the Game Board
inputBoardWidth proc
	push eax
	push edx
	getInput:
		mov edx, offset widthRequest
		call WriteString
		call Crlf
		call ReadInt

		cmp eax, 1
		JE small
		cmp eax, 2
		JE medium
		cmp eax, 3
		JE large
		jmp error
	done:
		pop edx
		pop eax
		ret
	small:
		mov boardWidth, 10
		mov numMines, 10
		jmp done
	medium:
		mov boardWidth, 15
		mov numMines, 23
		jmp done
	large:
		mov boardWidth, 20
		mov numMines, 40
		jmp done
	error:
		mov edx, offset sizeInputError
		call WriteString
		call Crlf
		jmp getInput
inputBoardWidth endp

;Inputs:
;	eax: Y Coordinate
;	ebx: X Coordinate
;	boardWidth: Width of Game Board
;Outputs:
;	eax: Array index
xyToIndex proc
	mul boardWidth
	add eax, ebx
	ret
xyToIndex endp

end main
