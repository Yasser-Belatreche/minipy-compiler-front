%{
	#include <stdio.h>
	#include <string.h>

	int yylex();
	int yyerror(char*);

	extern FILE* yyin;
	extern int line_number, column_number;
%}

%union {
	char* lexem;
}


%token <lexem> IDENTIFIER 
%token <lexem> INT FLOAT CHAR BOOL
%token <lexem> PLUS DIVIDE MUL MINUS
%token <lexem> GE LE EQ NE GT LT
%token <lexem> AND OR NOT

%token <lexem> COMMA SQUARE_BRACKET_OPEN SQUARE_BRACKET_CLOSE ROUND_BRACKET_OPEN ROUND_BRACKET_CLOSE SINGLE_QUOTION_MARK ASSIGNMENT

%token <lexem> INTEGER FLOATING_POINT CHARACTER BOOLEAN 


%left OR
%left AND
%right NOT

%left GE LE EQ NE GT LT 

%left PLUS MINUS 
%left MUL DIVIDE


%type <lexem> type
%type <lexem> factor
%type <lexem> variable
%type <lexem> expression


%%
program: statement_list { } 
	;

statement_list: statement statement_list { }
		| /* epsilon */  { }
	;

statement: declaration { }
	;

declaration: type variables_list { }
		| assing
	;

type: INT
		| FLOAT
		| CHAR
		| BOOL
	;

variables_list: variable more_variables { } 
	;

variable: IDENTIFIER { printf("declaring simple variable: %s \n", $1); } 
		| IDENTIFIER SQUARE_BRACKET_OPEN INTEGER SQUARE_BRACKET_CLOSE { printf("declaring array variable: %s[%s] \n", $1, $3); }
	;

more_variables: COMMA variables_list {}
		| /* epsilon */  {}
	;

assing: variable ASSIGNMENT expression { printf("declaration with assign\n"); }
	;

expression: expression MUL expression { printf("arithmetic expression MUL: %s / %s \n", $1, $3); }
		| expression DIVIDE expression { printf("arithmetic expression DIVIDE: %s / %s \n", $1, $3); }
		| expression PLUS expression { printf("arithmetic expression PLUS: %s / %s \n", $1, $3); }
		| expression MINUS expression { printf("arithmetic expression MINUS: %s / %s \n", $1, $3); }

		| expression AND expression { printf("logical expression and: %s / %s \n", $1, $3); }
		| expression OR expression { printf("logical expression or: %s / %s \n", $1, $3); }
		| NOT expression { printf("logical expression not: %s \n", $2); }

		| expression GE expression { printf("relational expression ge: %s / %s \n", $1, $3); }
		| expression LE expression { printf("relational expression le: %s / %s \n", $1, $3); }
		| expression EQ expression { printf("relational expression eq: %s / %s \n", $1, $3); }
		| expression NE expression { printf("relational expression ne: %s / %s \n", $1, $3); }
		| expression GT expression { printf("relational expression gt: %s / %s \n", $1, $3); }
		| expression LT expression { printf("relational expression lt: %s / %s \n", $1, $3); }

		| factor
	;

factor: variable { printf("using variable: %s \n", $1); }
		| INTEGER { printf("integer: %s \n", $1); }
		| ROUND_BRACKET_OPEN MINUS INTEGER ROUND_BRACKET_CLOSE { printf("negative integer: %s \n", $3); }
		| FLOATING_POINT { printf("float: %s \n", $1); }
		| ROUND_BRACKET_OPEN MINUS FLOATING_POINT ROUND_BRACKET_CLOSE { printf("negative float: %s \n", $3); }
		| SINGLE_QUOTION_MARK CHARACTER SINGLE_QUOTION_MARK { printf("character: %s \n", $2); }
		| BOOLEAN { printf("boolean: %s \n", $1); }
		| ROUND_BRACKET_OPEN expression ROUND_BRACKET_CLOSE { printf("expression: %s \n", $2); }
	;
%%

int yyerror(char* msg) {
	printf("\nWrong Syntax: Token (%s), at Line -> %d column -> %d \n", yylval.lexem, line_number, column_number);

	return 1;
}

int main (int argc, char** argv) { 	
	yyin = fopen("in.minipy", "r");

	yyparse();
	fclose (yyin);

	return 0;
}
