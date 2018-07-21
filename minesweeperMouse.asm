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

	; === Constants ============================================================
	welcomeMenuLayout db "                  _____ _", 0dh, 0ah, \
	                     "                 |     |_|___ ___ ___ _ _ _ ___ ___ ___ ___ ___", 0dh, 0ah, \
	                     "                 | | | | |   | -_|_ -| | | | -_| -_| . | -_|  _|", 0dh, 0ah, \
	                     "                 |_|_|_|_|_|_|___|___|_____|___|___|  _|___|_|", 0dh, 0ah, \
	                     "                                                   |_|", 0dh, 0ah, 0

	creditsMessage db "               By. Andrew Simmons, Brendan Sileo, and Ethan Smith", 0dh, 0ah, 0

	space db " "

.code
main proc

	call Randomize
	call welcomeMenu
	call inputBoardWidth
	call populateMines
	call printBoardDebug
	call populateAdjacencies
	call printBoardDebug
	invoke ExitProcess, 0


main endp

	
coordToGrid PROC
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
	ret
coordToGrid ENDP


mouseLoc PROC
	invoke GetStdHandle, STD_INPUT_HANDLE
	mov rHnd, eax
	invoke SetConsoleMode, rHnd, ENABLE_LINE_INPUT OR ENABLE_MOUSE_INPUT OR ENABLE_EXTENDED_FLAGS
	appContinue:
	invoke GetNumberOfConsoleInputEvents, rHnd, OFFSET numEventsOccurred
	cmp numEventsOccurred, 0
	je appContinue
	invoke ReadConsoleInput, rHnd, OFFSET eventBuffer, numEventsOccurred, 	OFFSET numEventsRead
	mov ecx, numEventsRead
	mov esi, OFFSET eventBuffer
	loopOverEvents:
	cmp (INPUT_RECORD PTR [esi]).EventType, MOUSE_EVENT
	jne notMouse
	test (INPUT_RECORD PTR [esi]).MouseEvent.dwButtonState, FROM_LEFT_1ST_BUTTON_PRESSED
	jz notMouse
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
	ret
mouseLoc ENDP

; Inputs:
;	boardWidth
;	baseState
;	numMines
; Outputs:
;	baseState
populateMines proc
	push eax
	push ebx
	push ecx
	push edx

	mov edi, offset baseState

	mov eax, boardWidth	;store total number of spaces into eax
	mov ebx, boardWidth	;
	mul ebx			;

	mov edx, 9

	mov ecx, 0
	mov cl, numMines	;place 9 into random squares, ecx times
place:	push eax		;
	push edi

	call RandomRange
	add edi, eax
	mov [edi], edx

	pop edi
	pop eax
	loop place

	pop edx
	pop ecx
	pop ebx
	pop eax
	ret
populateMines endp

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
			; Try top left
			topLeftCheck:
				; Store loop counters
				push ecx
				push ebx

				dec ebx
				dec ecx ; Change cooardinates to (x-1, y-1) relative to mine position

				cmp ebx, 0 ; If x < 0
				jl topCheck ; Skip topCheck
				cmp ebx, boardWidth ; If x >= boardWidth
				jge topCheck ; Skip topCheck
				cmp ecx, 0 ; If y < 0
				jl topCheck ; Skip to topCheck
				cmp ecx, boardWidth ; If y >= boardWidth
				jge topCheck ; Skip to topCheck


				; If it is a valid coordinate
				mov eax, ecx ; Move y coordinate to eax (x is already in ebx)
				call xyToIndex ; Convert x,y to index
				mov edi, offset baseState ; Get offset of baseState in edi
				add edi, eax ; Move offset to specified element

				mov eax, 9
				cmp [edi], al ; If value at index is a mine
				je topCheck ; Skip this tile

				mov eax, 1
				add [edi], al ; Increment by one

			topCheck:
				; Restore loop counters from previous check
				pop ebx
				pop ecx

				; Store loop counters
				push ecx
				push ebx

				dec ecx ; Change cooardinates to (x, y-1) relative to mine position

				cmp ebx, 0 ; If x < 0
				jl topRightCheck ; Skip topRightCheck
				cmp ebx, boardWidth ; If x >= boardWidth
				jge topRightCheck ; Skip topRightCheck
				cmp ecx, 0 ; If y < 0
				jl topRightCheck ; Skip to topRightCheck
				cmp ecx, boardWidth ; If y >= boardWidth
				jge topRightCheck ; Skip to topRightCheck


				; If it is a valid coordinate
				mov eax, ecx ; Move y coordinate to eax (x is already in ebx)
				call xyToIndex ; Convert x,y to index
				mov edi, offset baseState ; Get offset of baseState in edi
				add edi, eax ; Move offset to specified element

				mov eax, 9
				cmp [edi], al ; If value at index is a mine
				je topRightCheck ; Skip this tile

				mov eax, 1
				add [edi], al ; Increment by one

			topRightCheck:
				; Restore loop counters from previous check
				pop ebx
				pop ecx

				; Store loop counters
				push ecx
				push ebx

				inc ebx
				dec ecx ; Change cooardinates to (x+1, y-1) relative to mine position

				cmp ebx, 0 ; If x < 0
				jl leftCheck ; Skip leftCheck
				cmp ebx, boardWidth ; If x >= boardWidth
				jge leftCheck ; Skip leftCheck
				cmp ecx, 0 ; If y < 0
				jl leftCheck ; Skip to leftCheck
				cmp ecx, boardWidth ; If y >= boardWidth
				jge leftCheck ; Skip to leftCheck


				; If it is a valid coordinate
				mov eax, ecx ; Move y coordinate to eax (x is already in ebx)
				call xyToIndex ; Convert x,y to index
				mov edi, offset baseState ; Get offset of baseState in edi
				add edi, eax ; Move offset to specified element

				mov eax, 9
				cmp [edi], al ; If value at index is a mine
				je leftCheck ; Skip this tile

				mov eax, 1
				add [edi], al ; Increment by one

			leftCheck:
				; Restore loop counters from previous check
				pop ebx
				pop ecx

				; Store loop counters
				push ecx
				push ebx

				dec ebx; Change cooardinates to (x-1, y) relative to mine position

				cmp ebx, 0 ; If x < 0
				jl rightCheck ; Skip rightCheck
				cmp ebx, boardWidth ; If x >= boardWidth
				jge rightCheck ; Skip rightCheck
				cmp ecx, 0 ; If y < 0
				jl rightCheck ; Skip to rightCheck
				cmp ecx, boardWidth ; If y >= boardWidth
				jge rightCheck ; Skip to rightCheck


				; If it is a valid coordinate
				mov eax, ecx ; Move y coordinate to eax (x is already in ebx)
				call xyToIndex ; Convert x,y to index
				mov edi, offset baseState ; Get offset of baseState in edi
				add edi, eax ; Move offset to specified element

				mov eax, 9
				cmp [edi], al ; If value at index is a mine
				je rightCheck ; Skip this tile

				mov eax, 1
				add [edi], al ; Increment by one

			rightCheck:
				; Restore loop counters from previous check
				pop ebx
				pop ecx

				; Store loop counters
				push ecx
				push ebx

				inc ebx ; Change cooardinates to (x+1, y) relative to mine position

				cmp ebx, 0 ; If x < 0
				jl bottomLeftCheck ; Skip bottomLeftCheck
				cmp ebx, boardWidth ; If x >= boardWidth
				jge bottomLeftCheck ; Skip bottomLeftCheck
				cmp ecx, 0 ; If y < 0
				jl bottomLeftCheck ; Skip to bottomLeftCheck
				cmp ecx, boardWidth ; If y >= boardWidth
				jge bottomLeftCheck ; Skip to bottomLeftCheck


				; If it is a valid coordinate
				mov eax, ecx ; Move y coordinate to eax (x is already in ebx)
				call xyToIndex ; Convert x,y to index
				mov edi, offset baseState ; Get offset of baseState in edi
				add edi, eax ; Move offset to specified element

				mov eax, 9
				cmp [edi], al ; If value at index is a mine
				je bottomLeftCheck ; Skip this tile

				mov eax, 1
				add [edi], al ; Increment by one

			bottomLeftCheck:
				; Restore loop counters from previous check
				pop ebx
				pop ecx

				; Store loop counters
				push ecx
				push ebx

				dec ebx
				inc ecx ; Change cooardinates to (x-1, y+1) relative to mine position

				cmp ebx, 0 ; If x < 0
				jl bottomCheck ; Skip bottomCheck
				cmp ebx, boardWidth ; If x >= boardWidth
				jge bottomCheck ; Skip bottomCheck
				cmp ecx, 0 ; If y < 0
				jl bottomCheck ; Skip to bottomCheck
				cmp ecx, boardWidth ; If y >= boardWidth
				jge bottomCheck ; Skip to bottomCheck


				; If it is a valid coordinate
				mov eax, ecx ; Move y coordinate to eax (x is already in ebx)
				call xyToIndex ; Convert x,y to index
				mov edi, offset baseState ; Get offset of baseState in edi
				add edi, eax ; Move offset to specified element

				mov eax, 9
				cmp [edi], al ; If value at index is a mine
				je bottomCheck ; Skip this tile

				mov eax, 1
				add [edi], al ; Increment by one

			bottomCheck:
				; Restore loop counters from previous check
				pop ebx
				pop ecx

				; Store loop counters
				push ecx
				push ebx

				inc ecx ; Change cooardinates to (x, y+1) relative to mine position

				cmp ebx, 0 ; If x < 0
				jl bottomRightCheck ; Skip bottomRightCheck
				cmp ebx, boardWidth ; If x >= boardWidth
				jge bottomRightCheck ; Skip bottomRightCheck
				cmp ecx, 0 ; If y < 0
				jl bottomRightCheck ; Skip to bottomRightCheck
				cmp ecx, boardWidth ; If y >= boardWidth
				jge bottomRightCheck ; Skip to bottomRightCheck


				; If it is a valid coordinate
				mov eax, ecx ; Move y coordinate to eax (x is already in ebx)
				call xyToIndex ; Convert x,y to index
				mov edi, offset baseState ; Get offset of baseState in edi
				add edi, eax ; Move offset to specified element

				mov eax, 9
				cmp [edi], al ; If value at index is a mine
				je bottomRightCheck ; Skip this tile

				mov eax, 1
				add [edi], al ; Increment by one

			bottomRightCheck:
				; Restore loop counters from previous check
				pop ebx
				pop ecx

				; Store loop counters
				push ecx
				push ebx

				inc ebx
				inc ecx ; Change cooardinates to (x+1, y+1) relative to mine position

				cmp ebx, 0 ; If x < 0
				jl doneWithChecking ; Skip doneWithChecking
				cmp ebx, boardWidth ; If x >= boardWidth
				jge doneWithChecking ; Skip doneWithChecking
				cmp ecx, 0 ; If y < 0
				jl doneWithChecking ; Skip to doneWithChecking
				cmp ecx, boardWidth ; If y >= boardWidth
				jge doneWithChecking ; Skip to doneWithChecking


				; If it is a valid coordinate
				mov eax, ecx ; Move y coordinate to eax (x is already in ebx)
				call xyToIndex ; Convert x,y to index
				mov edi, offset baseState ; Get offset of baseState in edi
				add edi, eax ; Move offset to specified element

				mov eax, 9
				cmp [edi], al ; If value at index is a mine
				je doneWithChecking ; Skip this tile

				mov eax, 1
				add [edi], al ; Increment by one

			doneWithChecking:
				; Restore loop counters from previous check
				pop ebx
				pop ecx

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