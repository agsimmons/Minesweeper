TITLE Minesweeper By Andrew Simmons, Brendan Sileo, Ethan Smith
.386
.MODEL FLAT, STDCALL
OPTION CASEMAP:none
INCLUDE C:\Irvine\Irvine32mine.inc
INCLUDE C:\masm32\include\windows.inc
INCLUDE C:\masm32\include\user32.inc
INCLUDE C:\masm32\include\kernel32.inc

INCLUDELIB C:\masm32\lib\user32.lib
INCLUDELIB C:\masm32\lib\kernel32.lib
INCLUDELIB C:\Irvine\Irvine32.lib

.data
	rHnd HANDLE ?
	numEventsRead DWORD ?
	numEventsOccurred DWORD ?
	eventBuffer INPUT_RECORD 128 DUP(<>)
	coordString BYTE "(", 0
	xLoc db ?
	yLoc db ?

	; 1: Left Click
	; 2: Right Click
	clickType db ?

	xCoord db ?
	yCoord db ?

	; 0: Ongoing
	; 1: Loss
	; 2: Win
	gameState db ?

	; Width of game board
	boardWidth dd ?

	; Number of mines on game board
	numMines db ?

	;Text messages
	widthRequest db "Choose your board size: (1) Small, (2) Medium, or (3) Large:",0
	sizeInputError db "Please input 1, 2 or 3.", 0
	playAgainMessage db "Would you like to play again? (1 for yes, 2 for no): ", 0

	; Base state array
	; Possible values:
	;     0: Empty
	;     1-8: # of adjacent mines
	;     9: Mine
	baseState db 400 DUP(?)

	; Cover state array
	; Possible values:
	;     0: Uncovered
	;     1: Covered
	;     2: Covered, Flagged
	;     3: Covered, Question Mark
	coverState db 400 DUP(?)

	; Mine location array
	; Possible values:
	;	0 to boardWidth^2
	; Length:
	;	numMines
	mineLocations dd 41 DUP(?)

	; === Constants ============================================================
	welcomeMenuLayout db "                  _____ _", 0dh, 0ah, \
	                     "                 |     |_|___ ___ ___ _ _ _ ___ ___ ___ ___ ___", 0dh, 0ah, \
	                     "                 | | | | |   | -_|_ -| | | | -_| -_| . | -_|  _|", 0dh, 0ah, \
	                     "                 |_|_|_|_|_|_|___|___|_____|___|___|  _|___|_|", 0dh, 0ah, \
	                     "                                                   |_|", 0dh, 0ah, 0

	creditsMessage db "               By: Andrew Simmons, Brendan Sileo, and Ethan Smith", 0dh, 0ah, 0

	space db " "
	leftClick db "Left Click", 0
	rightClick db "Right Click", 0
	loseMessage db "You Lose!", 0dh, 0ah, 0
	winMessage db "You Win!", 0dh, 0ah, 0

.code
main proc

	call Randomize

	call welcomeMenu

	outerGameLoop:

		; Reset variable values
		call initialize

		; Generate Board
		call inputBoardWidth
		call generateMines
		call placeMines
		call populateAdjacencies

		innerGameLoop:
			; Draw current board state
			call Clrscr
			call redrawBoard
			; Get mouse location and click type
			call mouseLoc

			; Check click type
			mov dl, 1
			cmp clickType, dl ; If click type is not Left Click
			jne isRightClick ; Jump to isRightClick
			jmp isLeftClick ; Otherwise, jump to isLeftClick

			isLeftClick:
				mov eax, 0
				mov al, yCoord
				mov ebx, 0
				mov bl, xCoord
				call handleLeftClick

				; Check for a loss
				call lossCheck
				mov gameState, al
				mov al, 1
				cmp gameState, al ; If gameState is LOSS
				je handleLoss ; Jump to handleLoss

				; Check for a win
				call winCheck
				mov gameState, al ; Move result from winCheck to gameState
				mov al, 2
				cmp gameState, al ; If gameState is WIN
				je handleWin ; Jump to handleWin

				jmp innerGameLoop

			isRightClick:
				call handleRightClick

				jmp innerGameLoop

			handleWin:
				call flagAllMines
				call Clrscr
				call redrawBoard

				mov edx, offset winMessage
				call WriteString

				jmp playAgain

			handleLoss:
				call uncoverAllMines
				call Clrscr
				call redrawBoard

				mov edx, offset loseMessage
				call WriteString

				jmp playAgain

			playAgain:
				call askPlayAgain
				cmp eax, 1 ; If player DOES NOT want to play again
				jne quit ; Jump to quit

				; If player DOES want to play again
				call Clrscr
				jmp outerGameLoop ; Restart game

			quit:
				invoke ExitProcess, 0

main endp

initialize proc
	pushad

	; Initialize values of baseState
	mov esi, offset baseState
	mov ecx, lengthof baseState
	initializeBaseState:
		mov al, 0
		mov [esi], al
		inc esi
		loop initializeBaseState

	; Initialize values of coverState
	mov esi, offset coverState
	mov ecx, lengthof coverState
	initializeCoverState:
		mov al, 1
		mov [esi], al
		inc esi
		loop initializeCoverState

	; Initialize values of mineLocations
	mov esi, offset mineLocations
	mov ecx, lengthof mineLocations
	initializeMineLocations:
		mov al, 0
		mov [esi], al
		inc esi
		loop initializeMineLocations

	; Initialize gameState
	mov gameState, 0

	popad
	ret
initialize endp

flagAllMines proc
	pushad

	mov esi, offset baseState
	mov edi, offset coverState

	mov ecx, 0 ; outerFlagAllMinesLoopCount
	mov ebx, 0 ; innerFlagAllMinesLoopCount

	outerFlagAllMinesLoop:
		mov ebx, 0 ; Reset innerFlagAllMinesLoopCount for each iteration of outer loop
		innerFlagAllMinesLoop:
			; Do work
			mov al, [esi] ; Move base state value into al
			cmp al, 9 ; If there is NOT a mine here
			jne skipFlagAllMinesLoop
			; If there IS a mine here
			mov al, 2 ; Put FLAGGED value into al
			mov [edi], al ; Set cover state to FLAGGED

			skipFlagAllMinesLoop:

			inc esi
			inc edi
			; End work

			inc ebx ; Increment innerFlagAllMinesLoop
			cmp ebx, boardWidth ; If innerFlagAllMinesLoop != boardWidth
			jne innerFlagAllMinesLoop ; Repeat inner loop
		inc ecx ; Increment outerFlagAllMinesLoopCount
		cmp ecx, boardWidth ; If outerFlagAllMinesLoopCount != boardWidth
		jne outerFlagAllMinesLoop ; Repeat outer loop

	popad
	ret
flagAllMines endp

uncoverAllMines proc
	pushad

	mov esi, offset baseState
	mov edi, offset coverState

	mov ecx, 0 ; innerUncoverAllMinesLoopCount
	mov ebx, 0 ; innerUncoverAllMinesLoopCount

	outerFlagAllMinesLoop:
		mov ebx, 0 ; Reset innerUncoverAllMinesLoopCount for each iteration of outer loop
		innerUncoverAllMinesLoop:
			; Do work
			mov al, [esi] ; Move base state value into al
			cmp al, 9 ; If there is NOT a mine here
			jne skipUncoverAllMinesLoop
			; If there IS a mine here
			mov al, 0 ; Put uncovered value into al
			mov [edi], al ; Set cover state to uncovered

			skipUncoverAllMinesLoop:

			inc esi
			inc edi
			; End work

			inc ebx ; Increment innerUncoverAllMinesLoop
			cmp ebx, boardWidth ; If innerUncoverAllMinesLoop != boardWidth
			jne innerUncoverAllMinesLoop ; Repeat inner loop
		inc ecx ; Increment outerUncoverAllMinesLoopCounter
		cmp ecx, boardWidth ; If outerUncoverAllMinesLoopCounter != boardWidth
		jne outerFlagAllMinesLoop ; Repeat outer loop

	popad
	ret
uncoverAllMines endp

redrawBoard proc
	pushad ; Push register states

	mov esi, offset baseState
	mov edi, offset coverState

	mov ecx, 0 ; outerRedrawLoopCounter
	mov ebx, 0 ; innerRedrawLoopCounter

	outerRedrawLoop:
		; Change text color
		push eax
		mov eax, white + (black * 16)
		call SetTextColor
		pop eax

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
			cmp al, 1
			jne check2
			mov al, '#'
			jmp drawCover
		check2:
			cmp al, 2
			jne check3

			; Change text color
			push eax
			mov eax, yellow + (black * 16)
			call SetTextColor
			pop eax

			mov al, 'F'
			jmp drawCover
		check3:
			; Change text color
			push eax
			mov eax, yellow + (black * 16)
			call SetTextColor
			pop eax

			mov al, '?'
		drawCover:
			call WriteChar

			jmp afterCharacter

			uncoveredState:
				mov al, [esi] ; Move baseState value into al
				cmp al, 0
				je drawSpace

				cmp al, 9
				je drawMine

				jmp drawAdjacency

				drawSpace:
					; Change text color
					push eax
					mov eax, white + (black * 16)
					call SetTextColor
					pop eax

					mov al, ' '
					call WriteChar
					jmp afterCharacter
				drawMine:
					; Change text color
					push eax
					mov eax, lightRed + (black * 16)
					call SetTextColor
					pop eax

					mov al, '*'
					call WriteChar
					jmp afterCharacter
				drawAdjacency:
					; Change text color
					push eax
					mov eax, lightGreen + (black * 16)
					call SetTextColor
					pop eax

					add al, 48 ; Convert number to ascii character
					call WriteChar
					jmp afterCharacter

			afterCharacter:
				; Change text color
				push eax
				mov eax, white + (black * 16)
				call SetTextColor
				pop eax

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

	; Change text color
	push eax
	mov eax, white + (black * 16)
	call SetTextColor
	pop eax

	popad ; Pop register states
	ret
redrawBoard endp

; Inputs:
;	None
; Outputs:
;	xLoc
;	yLoc
handleInput proc
	mLoop:
		call mouseLoc
		call clickEvent
		jmp mLoop
handleInput endp

clickEvent proc
	mov dl, 1
	cmp clickType, dl
	jne right
	call handleLeftClick
	jmp doneWithCE
	right:
		call handleRightClick
	doneWithCE:
	ret
clickEvent endp

; If you left click on a covered location, uncover it
; If you left click on an uncovered, flagged, or question marked location, do nothing
handleLeftClick proc
	pushad
	cmp eax, 0
	jl handleLeftClickDone
	cmp eax, boardWidth
	jge handleLeftClickDone
	cmp ebx, 0
	jl handleLeftClickDone
	cmp ebx, boardWidth
	jge handleLeftClickDone
	;push eax
	;mov eax, ebx
	;call WriteInt
	;pop eax
	;call WriteInt
	;call Crlf
	mov esi, offset coverState
	mov edi, offset baseState

	push eax
	push ebx
	call xyToIndex

	add esi, eax ; Move offset to location of click
	add edi, eax
	pop ebx
	pop eax

	mov edx, 0
	mov dl, [esi]
	cmp dl, 1 ; If cover state is not 1 (covered, no flag or question mark)
	jne handleLeftClickDone ; Skip the following code

	; If cover state is 1 (covered, no flag or question mark)
	mov edx, 0
	mov [esi], dl ; Uncover spot

	cmp [edi], dl
	jne handleLeftClickDone
	; Top-Left Check
	sub ebx, 1
	sub eax, 1
	call handleLeftClick

	; Top Check
	add ebx, 1
	call handleLeftClick

	; Top Right Check
	add ebx, 1
	call handleLeftClick

	; Left Check
	add eax, 1
	sub ebx, 2
	call handleLeftClick

	; Right Check
	add ebx, 2
	call handleLeftClick

	; Bottom Left Check
	add eax, 1
	sub ebx, 2
	call handleLeftClick

	; Bottom Check
	add ebx, 1
	call handleLeftClick

	; Bottom Right Check
	add ebx, 1
	call handleLeftClick

	handleLeftClickDone:

	popad
	ret
handleLeftClick endp

; Inputs:
;	xLoc
;	yLoc
; Outputs:
;	xCoord
;	yCoord
coordToGrid proc
	pushad
	mov dx,0
	mov eax,0
	mov al,xLoc
	mov cx,2
	div cx
	mov xCoord, al

	mov eax, 0
	mov al, yLoc
	mov yCoord, al
	popad
	ret
coordToGrid endp

; Inputs:
;	boardWidth
; Outputs:
;	xLoc
;	yLoc
mouseLoc proc
	pushad
	invoke GetStdHandle, STD_INPUT_HANDLE
	mov rHnd, eax
	invoke SetConsoleMode, rHnd, ENABLE_MOUSE_INPUT OR ENABLE_EXTENDED_FLAGS
	appContinue:
		invoke GetNumberOfConsoleInputEvents, rHnd, OFFSET numEventsOccurred
		cmp numEventsOccurred, 0
		je appContinue
		invoke ReadConsoleInput, rHnd, OFFSET eventBuffer, numEventsOccurred, OFFSET numEventsRead
		mov ecx, numEventsRead
		mov esi, OFFSET eventBuffer
	loopOverEvents:
		cmp (INPUT_RECORD PTR [esi]).EventType, MOUSE_EVENT
		jne notMouse
		test (INPUT_RECORD PTR [esi]).MouseEvent.dwButtonState, FROM_LEFT_1ST_BUTTON_PRESSED
		jz checkRight
		mov clickType, 1
	getMouseLoc:
		mov eax, boardWidth
		mov ebx, 2
		mul ebx
		add eax, 2
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
	popad
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

		;check if eax is in array
		push ecx
		push edi
		check:
			sub edi, 4
			cmp eax, [edi]
			je duplicate
			loop check
			jmp nodup

		duplicate:
			pop edi
			pop ecx
			inc ecx
			inc ecx
			jmp ex

	nodup:	pop edi
		pop ecx

		mov [edi], eax
		add edi, 4
	ex:	pop eax
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
; 	1: yes
; 	2: no
askPlayAgain proc
	push edx
	askPlayAgainQuestion:
		mov edx, offset playAgainMessage
		call WriteString

		call ReadInt
		cmp eax, 1
		je doneAskPlayAgain
		cmp eax, 2
		je doneAskPlayAgain
		call Crlf
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
		jle done1		;
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
	done1:
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
;	baseState
;	xCoord
;	yCoord
;Outputs:
;	eax: 1 if lose, 0 if not
lossCheck PROC
	pushad
	mov eax, 0
	mov al, yCoord
	mov ebx, 0
	mov bl, xCoord
	call xyToIndex
	mov esi, offset baseState
	mov edi, offset coverState
	add esi, eax
	add edi, eax
	mov edx, 9
	mov eax, 0
	mov ebx, [edi]
	cmp bl, al
	jne didntLose
	
	mov al, [esi]
	cmp [esi], dl
	jne didntLose
	popad
	mov eax, 1
	jmp finishLossCheck
	didntLose:
		popad
		mov eax, 0

	finishLossCheck:
	ret
lossCheck ENDP

;Inputs:
;	baseState
;	coverState
;	boardWidth
;Outputs:
;	eax: 2 if win, 0 if not
winCheck PROC
	push esi
	push edi
	push ebx
	push ecx

	mov esi, offset baseState
	mov edi, offset coverState

	mov eax, boardWidth
	mul eax
	mov ecx, eax

	mov eax, 2 ; Set default return value to WIN

	winCheckLoop:
		mov bl, [esi] ; Move baseState value into bl
		cmp bl, 9 ; If it is a mine
		je endOfWinCheckLoop ; Jump to endOfWinCheckLoop

		; If it is not a mine
		mov bl, [edi] ; Move coverState value into bl
		cmp bl, 0 ; If it is uncovered
		je endOfWinCheckLoop ; Jump to endOfWinCheckLoop

		; If if it covered
		mov eax, 0 ; Set return value to ONGOING
		jmp afterWinCheckLoop ; Break from loop

		endOfWinCheckLoop:
			inc esi
			inc edi

		loop winCheckLoop

	afterWinCheckLoop:

	pop ecx
	pop ebx
	pop edi
	pop esi
	ret
winCheck ENDP

; Inputs:
;	yCoord
;	xCoord
;	coverState
; Outputs:
;	coverState
handleRightClick proc
	pushad

	mov eax, 0
	mov al, yCoord
	mov ebx, 0
	mov bl, xCoord
	call xyToIndex

	mov esi, offset coverState
	add esi, eax

	mov al, [esi]
	cmp al, 1 ; If cover state is COVERED
	je handleRightClickCovered ; Jump to handleRightClickCovered
	cmp al, 2 ; If cover state is FLAGGED
	je handleRightClickFlagged ; Jump to handleRightClickFlagged
	cmp al, 3 ; If cover state is QUESTIONMARKED
	je handleRightClickQuestionMarked ; Jump to handleRightClickQuestionMarked

	; Else, if cover state is UNCOVERED
	jmp afterHandleRightClick ; Jump to afterHandleRightClick

	handleRightClickCovered:
		mov al, 2
		mov [esi], al
		jmp afterHandleRightClick

	handleRightClickFlagged:
		mov al, 3
		mov [esi], al
		jmp afterHandleRightClick

	handleRightClickQuestionMarked:
		mov al, 1
		mov [esi], al
		jmp afterHandleRightClick

	afterHandleRightClick:
		popad
		ret
handleRightClick endp

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
