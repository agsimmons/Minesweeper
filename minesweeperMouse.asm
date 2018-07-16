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
	coordString BYTE "Coordinate change: (", 0
	buttonString BYTE "Left Button Pressed!", 0Ah, 0
	
	; Width of game board
	boardWidth dd 1 DUP(?)
	numMines db ?

	;Text messages
	widthRequest db "Choose your board size: (1) Small, (2) Medium, or (3) Large:",0
	sizeInputError db "Please input 1, 2 or 3.", 0

	; Base state array
	; Possible values:
	;     0: Empty
	;     1-8: # of adjacent mines
	;     9: Mines
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
	; Code Here

	call welcomeMenu
	call inputBoardWidth
	call printBoardDebug
	call populateBoard
	call printBoardDebug
	labell:
	call mouseLoc
	push eax
	mov eax, 500
	call Delay
	pop eax
	jmp labell
	;exit

main endp

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
	;cmp (INPUT_RECORD PTR [esi]).MouseEvent.dwEventFlags, MOUSE_MOVED
	;jne continue
	mov edx, OFFSET coordString
	call WriteString
	movzx eax, (INPUT_RECORD PTR [esi]).MouseEvent.dwMousePosition.x
	call WriteInt
	mov al, ','
	call WriteChar
	movzx eax, (INPUT_RECORD PTR [esi]).MouseEvent.dwMousePosition.y
	call WriteInt
	mov al, ')'
	call WriteChar
	call Crlf
	continue:
	test (INPUT_RECORD PTR [esi]).MouseEvent.dwButtonState, 	FROM_LEFT_1ST_BUTTON_PRESSED
	jz notMouse
	mov edx, OFFSET buttonString
	call WriteString
	notMouse:
	add esi, TYPE INPUT_RECORD
		loop loopOverEvents
	jmp appContinue
	done:
	invoke ExitProcess, 0
	ret
mouseLoc ENDP
; Inputs:
;	boardWidth
;	baseState
;	numMines
; Outputs:
;	baseState
populateBoard proc
	push eax
	push ebx
	push ecx
	push edx

	call Randomize

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
	call WriteDec
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
populateBoard endp

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
	mov ebx, boardWidth	;
	mul ebx			;
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
