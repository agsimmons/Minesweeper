TITLE Minesweeper By Andrew Simmons, Brendan Sileo, Ethan Smith
INCLUDE irvine32.inc
.data

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

	call Randomize

	; Code Here
	exit

main endp

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

	call randomrange
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
	call crlf		;
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
	call crlf
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
	call ClrScr

	call CRLF
	call CRLF
	call CRLF
	call CRLF

	mov edx, offset welcomeMenuLayout
	call WriteString

	call CRLF
	call CRLF
	call CRLF
	call CRLF

	mov edx, offset creditsMessage
	call WriteString

	mov eax, 5000
	call Delay

	call ClrScr

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
