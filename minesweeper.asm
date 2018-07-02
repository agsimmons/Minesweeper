TITLE Minesweeper By Andrew Simmons, Brendan Sileo, Ethan Smith
INCLUDE irvine32.inc
.data

	; Width of game board
	boardWidth dd 1 DUP(?)

	;Text messages
	widthRequest db "Choose your board width. It can be any number between 1 and 20.",0

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

.code
main proc
	; Code Here
	exit

main endp

<<<<<<< HEAD
;Inputs:
;	None
;Outputs:
;	boardWidth: Width of the Game Board
inputBoardWidth proc 
	push eax
	push edx
	mov edx, offset widthRequest
	call WriteString
	call Crlf
	call ReadInt
	mov boardwidth, eax
	pop edx
	pop eax
	ret
inputBoardWidth endp

;Inputs:
;	eax: Y Coordinate
;	ebx: X Coordinate
;	boardWidth: Width of Game Board
;Outputs:
;	eax: Array index
=======
; Inputs:
;     eax: Y Coordinate
;     ebx: X Coordinate
;     boardWidth: Width of Game Board
; Outputs:
;     eax: Array index
>>>>>>> 4e9374da237d9bc693c0c1556fd605891a4fd7b9
xyToIndex proc
	mul boardWidth
	add eax, ebx
	ret
xyToIndex endp

end main
