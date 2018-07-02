TITLE Minesweeper By Andrew Simmons, Brendan Sileo, Ethan Smith
INCLUDE irvine32.inc
.data

	; Width of game board
	boardWidth dd 1 DUP(?)

	;Text messages
	widthRequest db "Choose your board width. It can be any number between 1 and 20.",0
.code
main proc
	; Code Here
	exit

main endp

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
xyToIndex proc
	mul boardWidth
	add eax, ebx
	ret
xyToIndex endp

end main
