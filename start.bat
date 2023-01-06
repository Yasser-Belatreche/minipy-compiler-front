flex -o out/lex.yy.c src/minipy-lexer.l

bison -o out/parser.tab.c -d src/minipy-parser.y

gcc out/lex.yy.c out/parser.tab.c src/symbol-table.c -o out/minipy.exe

"out/minipy.exe"