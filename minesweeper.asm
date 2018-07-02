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
	baseState db 400 DUP(?)

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

.code
main proc
	; Code Here
	exit

main endp

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
