" SYNTAX HIGHLIGHTING
:syntax on


" LINE NUMBER
:set number


" INDENTATION
" 1) autoindent  = maintain the indentation of the current line when pressing
"                  <Enter>
" 2) smartindent = maintain indentation from the current source file, should be
"                  be used in combination with the `autoindent` module
" 3) expandtab   = insert spaces instead of the tab (\t) character
:set autoindent
:set smartindent
:set expandtab

" LINE WIDTH RECOMENTATION
" Source lines should be less than 80 characters in width, a red vertical line
" will be drawn in the editor to visualize this recomentation.
:set colorcolumn=80

" CURSOR
" Highlight the current line of source being edited with a horizontal
" underline.
:set cursorline

