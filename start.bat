flex -o out/lex.yy.c src/minipy-lexer.l

bison -o out/parser.tab.c -d src/minipy-parser.y

gcc -o out/minipy.exe out/lex.yy.c out/parser.tab.c 

"out/minipy.exe"