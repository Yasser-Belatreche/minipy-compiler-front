%{
    #include <string.h>
    #include "parser.tab.h"

    #define YY_USER_INIT {  \
        BEGIN INDENT_STATE; \
    }

    extern YYSTYPE yylval;
   
    int line_number = 1, column_number = 1;

    int prev_indentation_level = 0;
    int current_indentation_level = 0;
%}

%option noyywrap

COMMA ","
COLON ":"
SINGLE_QUOTION_MARK "'"
SQUARE_BRACKET_OPEN "\["
SQUARE_BRACKET_CLOSE "\]"
ROUND_BRACKET_OPEN "\("
ROUND_BRACKET_CLOSE "\)"
ASSIGNMENT "="

SPACE " "
LINE_BREAK "\n"
INDENTATION "    "

INTEGER [0-9]+
FLOATING_POINT {INTEGER}+"."{INTEGER}+
BOOLEAN "true"|"false"
CHARACTER [a-zA-Z0-9_]

PLUS "+"
MINUS "-"
DIVIDE "/"
MUL "*"

GT ">"
LT "<"
GE ">="
LE "<="
EQ "=="
NE "!="

IF "if"
ELSE "else"
WHILE "while"
FOR "for"
IN "in"
RANGE "range"

AND "and"
OR "or"
NOT "not"

INT "int"
FLOAT "float"
CHAR "char"
BOOL "bool"

IDENTIFIER [A-Z][A-Za-z0-9]{0,7}

COMMENT "#".*\n


%x INDENT_STATE


%%

<INDENT_STATE>{INDENTATION} { current_indentation_level++; column_number += yyleng; }
<INDENT_STATE>{LINE_BREAK} { line_number++; column_number = 1; current_indentation_level = 0; }
<INDENT_STATE><<EOF>>  {
                        if (current_indentation_level < prev_indentation_level) {
                            prev_indentation_level--;
                            return DEDENT;
                        }

                        BEGIN INITIAL;
                    }
<INDENT_STATE>. {
                    unput(*yytext);

                    if (current_indentation_level > prev_indentation_level) {
                        prev_indentation_level++;
                        return INDENT;
                    }
                    if (current_indentation_level < prev_indentation_level) {
                        prev_indentation_level--;
                        return DEDENT;
                    }

                    BEGIN INITIAL;
                }
 
<<EOF>> {
            if (prev_indentation_level == 0)
                return 0;

            prev_indentation_level--;
            return DEDENT;
        }

{COMMA} { column_number += yyleng;  yylval.lexem_string = strdup(yytext); return COMMA; }
{COLON} { column_number += yyleng; yylval.lexem_string = strdup(yytext); return COLON; }
{SINGLE_QUOTION_MARK} { column_number += yyleng; yylval.lexem_string = strdup(yytext); return SINGLE_QUOTION_MARK; }
{SQUARE_BRACKET_OPEN} { column_number += yyleng; yylval.lexem_string = strdup(yytext); return SQUARE_BRACKET_OPEN; }
{SQUARE_BRACKET_CLOSE} { column_number += yyleng;  yylval.lexem_string = strdup(yytext); return SQUARE_BRACKET_CLOSE; }
{ROUND_BRACKET_OPEN} { column_number += yyleng; yylval.lexem_string = strdup(yytext); return ROUND_BRACKET_OPEN; }
{ROUND_BRACKET_CLOSE} { column_number += yyleng; yylval.lexem_string = strdup(yytext); return ROUND_BRACKET_CLOSE; }
{ASSIGNMENT} { column_number += yyleng; yylval.lexem_string = strdup(yytext); return ASSIGNMENT; }


{SPACE} { column_number += yyleng; }
{LINE_BREAK} {line_number++; column_number = 1; current_indentation_level = 0; BEGIN INDENT_STATE; }

{PLUS} { column_number += yyleng; yylval.lexem_string = strdup(yytext); return PLUS; }
{MINUS} { column_number += yyleng; yylval.lexem_string = strdup(yytext); return MINUS; }
{DIVIDE} { column_number += yyleng; yylval.lexem_string = strdup(yytext); return DIVIDE; }
{MUL} { column_number += yyleng; yylval.lexem_string = strdup(yytext); return MUL; }

{GT} { column_number += yyleng; yylval.lexem_string = strdup(yytext); return GT; }
{LT} { column_number += yyleng; yylval.lexem_string = strdup(yytext); return LT; }
{GE} { column_number += yyleng; yylval.lexem_string = strdup(yytext); return GE; }
{LE} { column_number += yyleng; yylval.lexem_string = strdup(yytext); return LE; }
{EQ} { column_number += yyleng; yylval.lexem_string = strdup(yytext); return EQ; }
{NE} { column_number += yyleng; yylval.lexem_string = strdup(yytext); return NE; }

{AND} { column_number += yyleng; yylval.lexem_string = strdup(yytext); return AND; }
{OR} { column_number += yyleng; yylval.lexem_string = strdup(yytext); return OR; }
{NOT} { column_number += yyleng; yylval.lexem_string = strdup(yytext); return NOT; }

{INT} { column_number += yyleng; yylval.lexem_string = strdup(yytext); return INT; }
{FLOAT} { column_number += yyleng; yylval.lexem_string = strdup(yytext); return FLOAT; }
{CHAR} { column_number += yyleng;  yylval.lexem_string = strdup(yytext); return CHAR; }
{BOOL} { column_number += yyleng;  yylval.lexem_string = strdup(yytext); return BOOL; }

{IF} { column_number += yyleng; yylval.lexem_string = strdup(yytext); return IF; }
{ELSE} { column_number += yyleng; yylval.lexem_string = strdup(yytext); return ELSE; }
{WHILE} { column_number += yyleng; yylval.lexem_string = strdup(yytext); return WHILE; }
{FOR} { column_number += yyleng; yylval.lexem_string = strdup(yytext); return FOR; }
{IN} { column_number += yyleng; yylval.lexem_string = strdup(yytext); return IN; }
{RANGE} { column_number += yyleng; yylval.lexem_string = strdup(yytext); return RANGE; }

{IDENTIFIER} { column_number += yyleng; yylval.lexem_string = strdup(yytext); return IDENTIFIER; }

{INTEGER} { column_number += yyleng; yylval.lexem_int = atoi(yytext); return INTEGER; }
{FLOATING_POINT} { column_number += yyleng; yylval.lexem_float = atof(yytext); return FLOATING_POINT; }
{BOOLEAN} { column_number += yyleng; yylval.lexem_string = strdup(yytext); return BOOLEAN; }
{CHARACTER} { column_number += yyleng; yylval.lexem_string = strdup(yytext); return CHARACTER; }

{COMMENT} { line_number++; column_number = 1; }

. { printf ("Lexical Error: word (%s) at Line -> %d, Column -> %d is not valid in minipy. \n", yytext, line_number, column_number); exit(0); }

%%



