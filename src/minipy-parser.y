%{
	#include <stdio.h>
	#include <stdlib.h>
	#include <string.h>
	#include <ctype.h>

	#include "../src/symbol-table.h"

	int yylex();
	int yyerror(char*);

	int is_int(char*);
	int is_float(char*);
	int is_numeric_type(char*);
	int is_bool_type(char*);

	char* float_to_string(float);
	char* int_to_string(int);
	char* concat_strings(char*, char*);
	char* remove_last_character(char*);
	char* type_of(char*);
	

	void throw_symantique_error(char*);

	extern FILE* yyin;
	extern int line_number, column_number;
%}

%union {
	char* lexem_string;
	int lexem_int;
	float lexem_float;
}


%token <lexem_string> IDENTIFIER 
%token <lexem_string> INT FLOAT CHAR BOOL
%token <lexem_string> PLUS DIVIDE MUL MINUS
%token <lexem_string> GE LE EQ NE GT LT
%token <lexem_string> AND OR NOT

%token <lexem_string> COMMA SQUARE_BRACKET_OPEN SQUARE_BRACKET_CLOSE ROUND_BRACKET_OPEN ROUND_BRACKET_CLOSE SINGLE_QUOTION_MARK ASSIGNMENT

%token <lexem_string> CHARACTER BOOLEAN 
%token <lexem_int> INTEGER
%token <lexem_float> FLOATING_POINT


%left OR
%left AND
%right NOT

%left GE LE EQ NE GT LT 

%left PLUS MINUS 
%left MUL DIVIDE


%type <lexem_string> type

%type <lexem_string> variable_dec
%type <lexem_string> variables_dec_list
%type <lexem_string> more_variables_dec

%type <lexem_string> factor
%type <lexem_string> variable
%type <lexem_string> expression


%%
program: statement_list { } 
	;

statement_list: /* epsilon */  { }
		| statement statement_list { }
	;

statement:
		  declaration_with_type
		| assign { }
	;

declaration_with_type: 
		  type variables_dec_list 
			{
				char *variable = strtok($2, ",");

				while(variable != NULL) {
					get(variable)->type = $1;
			
					variable = strtok(NULL, ",");
				}
			}
	;

type: 
		  INT
		| FLOAT
		| CHAR
		| BOOL
	;

variables_dec_list: 
		  variable_dec more_variables_dec 
		  	{ $$ = concat_strings($1, concat_strings(",", $2)); }
	;

variable_dec: 
		  IDENTIFIER
		  	{
				if(is_declared($1))
					throw_symantique_error(concat_strings(concat_strings("variable ", $1), " already declared"));
				
				insert($1, NULL);

				$$ = $1;
			}
		| IDENTIFIER SQUARE_BRACKET_OPEN INTEGER SQUARE_BRACKET_CLOSE 
			{
				if(is_declared($1))
					throw_symantique_error(concat_strings(concat_strings("variable ", $1), " already declared"));
				
				insert_array($1, NULL, $3);

				$$ = $1;
			}
	;

more_variables_dec: 
		  COMMA variables_dec_list
			{ $$ = $2; }
		| /* epsilon */  
			{ $$ = ""; }
	;

assign: 
		  variable_to_assign_to ASSIGNMENT expression 
			{
				printf("expression type : %s\n", $3);
				/*
					verify if variable_to_assign_to have a type, if it has, verify if it's the same as expression type,
					if it doesn't have a type, set it's type to expression type
					also verify if variable_to_assign_to is an array element, verify if its type is the same as expression type
				 */
			}
	;

variable_to_assign_to: 
		  IDENTIFIER
		  	{
				if(!is_declared($1))
					insert($1, NULL);
			}

		| IDENTIFIER SQUARE_BRACKET_OPEN INTEGER SQUARE_BRACKET_CLOSE 
			{ 
				Identifier *id = get($1);
				int index = $3;

				if(id == NULL) 
					throw_symantique_error(concat_strings(concat_strings("array ", $1), " not declared"));
				
				if (!id->is_array)
					throw_symantique_error(concat_strings(concat_strings("variable ", $1), " is not an array"));
				
				if (index >= id->array_size)
					throw_symantique_error(
						concat_strings(
							concat_strings("index ", int_to_string(index)),
							concat_strings(
								concat_strings(" out of array ", id->name), " bounds"
							)
						)
					);
			}
	;

expression: 
		  expression MUL expression { printf("arithmetic expression MUL: %s / %s \n", $1, $3); }
		| expression DIVIDE expression { printf("arithmetic expression DIVIDE: %s / %s \n", $1, $3); }
		| expression PLUS expression { printf("arithmetic expression PLUS: %s / %s \n", $1, $3); }
		| expression MINUS expression { printf("arithmetic expression MINUS: %s / %s \n", $1, $3); }

		| expression AND expression { printf("logical expression and: %s / %s \n", $1, $3); }
		| expression OR expression { printf("logical expression or: %s / %s \n", $1, $3); }
		| NOT expression { printf("logical expression not: %s \n", $2); }

		| expression GE expression 
			{
				if (!is_numeric_type($1) || !is_numeric_type($3))
					throw_symantique_error(
						concat_strings(
							concat_strings("Operator '>=' expect operators to be numeric type but got : ", $1),
							concat_strings(" >= ", $3)
						)
					);

				$$ = "bool";
			}

		| expression LE expression 
			{
				if (!is_numeric_type($1) || !is_numeric_type($3))
					throw_symantique_error(
						concat_strings(
							concat_strings("Operator '<=' expect operators to be numeric type but got : ", $1),
							concat_strings(" <= ", $3)
						)
					);

				$$ = "bool";
			}

		| expression EQ expression
			{
				if (strcpr($1, $3) != 0)
					throw_symantique_error(
						concat_strings(
							concat_strings("Operator '==' expect operators to have the same type but got : ", $1),
							concat_strings(" == ", $3)
						)
					);

				$$ = "bool";
			}

		| expression NE expression
			{
				if (strcpr($1, $3) != 0)
					throw_symantique_error(
						concat_strings(
							concat_strings("Operator '!=' expect operators to have the same type but got : ", $1),
							concat_strings(" != ", $3)
						)
					);

				$$ = "bool";
			}

		| expression GT expression
			{
				if (!is_numeric_type($1) || !is_numeric_type($3))
					throw_symantique_error(
						concat_strings(
							concat_strings("Operator '>' expect operators to be numeric type but got : ", $1),
							concat_strings(" > ", $3)
						)
					);

				$$ = "bool";
			}

		| expression LT expression 
			{
				if (!is_numeric_type($1) || !is_numeric_type($3))
					throw_symantique_error(
						concat_strings(
							concat_strings("Operator '<' expect operators to be numeric type but got : ", $1),
							concat_strings(" < ", $3)
						)
					);

				$$ = "bool";
			}

		| factor 
			{ $$ = type_of($1); }
	;

factor:
		  variable
		  	{ $$ = $1; }

		| INTEGER
			{ $$ = int_to_string($1); }
		| ROUND_BRACKET_OPEN MINUS INTEGER ROUND_BRACKET_CLOSE 
			{ $$ = concat_strings($2, int_to_string($3)); }
		
		| FLOATING_POINT 
			{ $$ = float_to_string($1); }
		| ROUND_BRACKET_OPEN MINUS FLOATING_POINT ROUND_BRACKET_CLOSE 
			{ $$ = concat_strings($2, float_to_string($3)); }

		| BOOLEAN 
			{ $$ = $1; }

		| SINGLE_QUOTION_MARK CHARACTER SINGLE_QUOTION_MARK 
			{ $$ = concat_strings($1, concat_strings($2, $3)); }

		| ROUND_BRACKET_OPEN expression ROUND_BRACKET_CLOSE 
			{ $$ = $2; }
	;

variable: 
		  IDENTIFIER
			{
				if(!is_declared($1)) 
					throw_symantique_error(concat_strings(concat_strings("variable ", $1), " not declared"));
				
				$$ = $1;
			} 

		| IDENTIFIER SQUARE_BRACKET_OPEN INTEGER SQUARE_BRACKET_CLOSE
			{
				Identifier *id = get($1);
				int index = $3;

				if(id == NULL) 
					throw_symantique_error(concat_strings(concat_strings("array ", $1), " not declared"));
				
				if (!id->is_array)
					throw_symantique_error(concat_strings(concat_strings("variable ", $1), " is not an array"));
				
				if (index >= id->array_size)
					throw_symantique_error(
						concat_strings(
							concat_strings("index ", int_to_string(index)),
							concat_strings(
								concat_strings(" out of array ", id->name), " bounds"
							)
						)
					);
				
				$$ = $1;
			}
	;
%%

int yyerror(char* msg) 
{
	printf("Syntax Error: %s, Line %d, column %d, Token (%s) \n", msg, line_number, column_number, yylval.lexem_string);

	return 1;
}

void throw_symantique_error(char* message)
{
	printf("Symantique Error: %s\nLine %d\ncolumn %d \n", message, line_number, column_number);

	exit(1);
}

char* float_to_string(float f) 
{
	char* str = (char*) malloc(100);
	sprintf(str, "%f", f);
	return str;
}

char* int_to_string(int i) 
{
	char* str = (char*) malloc(100);
	sprintf(str, "%d", i);
	return str;
}

char* concat_strings(char* str1, char* str2) 
{
	char* str = (char*) malloc(strlen(str1) + strlen(str2) + 1);

	strcpy(str, str1);
	strcat(str, str2);

	return str;
}

char *type_of(char* str)
{
	if (str == "true" || str == "false")
		return "bool";

	if (str[0] == '\'' && str[2] == '\'')
		return "char";

	if (str[0] == '-' && is_int(str) || is_int(str))
		return "int";

	if (str[0] == '-' && is_float(str) || is_float(str))
		return "float";

	return get(str)->type;
}

int is_numeric_type(char* str)
{
	return str == "int" || str == "float";
}

int is_bool_type(char* str)
{
	return str == "bool";
}

int is_float(char *str) 
{
    char *endptr;

    strtod(str, &endptr);

    if (endptr == str || *endptr != '\0')
        return 0;
    
    return 1;
}

int is_int(char *str)
{
	char *endptr;

    strtol(str, &endptr, 10);

    if (endptr == str || *endptr != '\0')
        return 0;
    
    return 1;
}

int main (int argc, char** argv) 
{ 	
	yyin = fopen("in.minipy", "r");

	create_new_scope();

	yyparse();

	display();
	fclose (yyin);

	return 0;
}
