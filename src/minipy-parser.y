%{
	#include <stdio.h>
	#include <unistd.h>
	#include <stdlib.h>
	#include <string.h>
	#include <stdarg.h>
	#include <ctype.h>

	#include "../src/symbol-table.h"

	int yylex();
	int yyerror(char*);

	int is_int(char*);
	int is_float(char*);
	int is_bool_type(char*);
	int is_numeric_type(char*);

	char* type_of(char*);
	char* format_string(char*, ...);
	char* get_bigger_numeric_type(char*, char*);

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

%token <lexem_string> COLON COMMA SQUARE_BRACKET_OPEN SQUARE_BRACKET_CLOSE ROUND_BRACKET_OPEN ROUND_BRACKET_CLOSE SINGLE_QUOTION_MARK ASSIGNMENT

%token <lexem_string> IF ELSE WHILE FOR IN RANGE

%token <lexem_string> INDENT DEDENT

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
%type <lexem_string> more_variables_dec variable_to_assign_to

%type <lexem_string> factor
%type <lexem_string> variable
%type <lexem_string> expression 


%%
program: statement_list { }
	;

statement_list: statement_list statement
		| /* epsilon */ { }
	;

block: INDENT statement_list DEDENT { } 
	;

statement:
		  declaration_with_type
		| assign
		| if_statement
		| while_statement
		| for_statement	
		| block
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
		  	{ $$ = format_string("%s,%s", $1, $2); }
	;

variable_dec: 
		  IDENTIFIER
		  	{
				if(is_declared($1))
					throw_symantique_error(format_string("variable '%s' already declared", $1));
				
				insert($1, NULL);

				$$ = $1;
			}
		| IDENTIFIER SQUARE_BRACKET_OPEN INTEGER SQUARE_BRACKET_CLOSE 
			{
				if(is_declared($1))
					throw_symantique_error(format_string("variable '%s' already declared", $1));
				
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
				Identifier *target_variable = get($1);
				char *expression_type = $3;

				if (target_variable->type == NULL)
					target_variable->type = expression_type;

				else if (strcmp(target_variable->type, expression_type) != 0)
					throw_symantique_error(
						format_string("cannot assign type %s to variable '%s' of type %s", expression_type, target_variable->name, target_variable->type)
					);
			}
	;

variable_to_assign_to: 
		  IDENTIFIER
		  	{
				if(!is_declared($1))
					insert($1, NULL);
				
				$$ = $1;
			}

		| IDENTIFIER SQUARE_BRACKET_OPEN INTEGER SQUARE_BRACKET_CLOSE 
			{
				Identifier *id = get($1);
				int index = $3;

				if(id == NULL) 
					throw_symantique_error(format_string("variable '%s' not declared", $1));
				
				if (!id->is_array)
					throw_symantique_error(format_string("variable '%s' is not an array", id->name));
				
				if (index >= id->array_size)
					throw_symantique_error(format_string("index %d out of array '%s' bounds", index, id->name));
				
				$$ = $1;
			}
	;

if_statement:
		  IF ROUND_BRACKET_OPEN expression ROUND_BRACKET_CLOSE COLON block
			{
				if (!is_bool_type($3))
					throw_symantique_error(format_string("if condition must be of type boolean but got %s", $3));
			}
		| IF ROUND_BRACKET_OPEN expression ROUND_BRACKET_CLOSE COLON block ELSE COLON block
			{
				if (!is_bool_type($3))
					throw_symantique_error(format_string("if condition must be of type boolean but got %s", $3));
			}
	;

while_statement:
		  WHILE ROUND_BRACKET_OPEN expression ROUND_BRACKET_CLOSE COLON block
			{
				if (!is_bool_type($3))
					throw_symantique_error(format_string("while condition must be of type boolean but got %s", $3));
			}
	;

for_statement:
		  FOR IDENTIFIER IN IDENTIFIER COLON block
			{
				Identifier *target_array = get($4);

				if (target_array == NULL)
					throw_symantique_error(format_string("variable '%s' not declared", $4));

				if (!target_array->is_array)
					throw_symantique_error(format_string("variable '%s' is not an array", $4));
			}
		| FOR IDENTIFIER IN RANGE ROUND_BRACKET_OPEN INTEGER COMMA INTEGER ROUND_BRACKET_CLOSE COLON block
			{
				if ($6 >= $8)
					throw_symantique_error(format_string("range start '%d' must be less than range end '%d'", $6, $8));
			}
	;

expression: 
		  expression MUL expression
			{
				if (!is_numeric_type($1) || !is_numeric_type($3))
					throw_symantique_error(
						format_string("Operator '*' expect operands to have numeric type but got : %s * %s", $1, $3)
					);
				
				$$ = get_bigger_numeric_type($1, $3);
			}

		| expression DIVIDE expression
			{
				if (!is_numeric_type($1) || !is_numeric_type($3))
					throw_symantique_error(
						format_string("Operator '/' expect operands to have numeric type but got : %s / %s", $1, $3)
					);
				
				$$ = get_bigger_numeric_type($1, $3);
			}
		
		| expression PLUS expression
			{
				if (!is_numeric_type($1) || !is_numeric_type($3))
					throw_symantique_error(
						format_string("Operator '+' expect operands to have numeric type but got : %s + %s", $1, $3)
					);
				
				$$ = get_bigger_numeric_type($1, $3);
			}

		| expression MINUS expression 
			{
				if (!is_numeric_type($1) || !is_numeric_type($3))
					throw_symantique_error(
						format_string("Operator '-' expect operands to have numeric type but got : %s - %s", $1, $3)
					);
				
				$$ = get_bigger_numeric_type($1, $3);
			}

		| expression AND expression
			{
				if (!is_bool_type($1) || !is_bool_type($3))
					throw_symantique_error(
						format_string("Operator 'and' expect operands to have boolean type but got : %s and %s", $1, $3)
					);

				$$ = "bool";
			}
		| expression OR expression 
			{
				if (!is_bool_type($1) || !is_bool_type($3))
					throw_symantique_error(
						format_string("Operator 'or' expect operands to have boolean type but got : %s or %s", $1, $3)
					);

				$$ = "bool";
			}

		| NOT expression 
			{
				if (!is_bool_type($2))
					throw_symantique_error(
						format_string("Operator 'not' expect operand to have bool type but got : not %s", $2)
					);

				$$ = "bool";
			}

		| expression GE expression 
			{
				if (!is_numeric_type($1) || !is_numeric_type($3))
					throw_symantique_error(
						format_string("Operator '>=' expect operands to have numeric type but got : %s >= %s", $1, $3)
					);

				$$ = "bool";
			}

		| expression LE expression 
			{
				if (!is_numeric_type($1) || !is_numeric_type($3))
					throw_symantique_error(
						format_string("Operator '<=' expect operands to have numeric type but got : %s <= %s", $1, $3)
					);

				$$ = "bool";
			}

		| expression EQ expression
			{
				if (strcmp($1, $3) != 0)
					if (!is_numeric_type($1) || !is_numeric_type($3))
						throw_symantique_error(
							format_string("Operator '==' expect operands to have the same type but got : %s == %s", $1, $3)
						);

				$$ = "bool";
			}

		| expression NE expression
			{
				if (strcmp($1, $3) != 0)
					if (!is_numeric_type($1) || !is_numeric_type($3))
						throw_symantique_error(
							format_string("Operator '!=' expect operands to have the same type but got : %s != %s", $1, $3)
						);

				$$ = "bool";
			}

		| expression GT expression
			{
				if (!is_numeric_type($1) || !is_numeric_type($3))
					throw_symantique_error(
						format_string("Operator '>' expect operands to have numeric type but got : %s > %s", $1, $3)
					);

				$$ = "bool";
			}

		| expression LT expression 
			{
				if (!is_numeric_type($1) || !is_numeric_type($3))
					throw_symantique_error(
						format_string("Operator '<' expect operands to have numeric type but got : %s < %s", $1, $3)
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
			{ $$ = format_string("%d", $1); }
		| ROUND_BRACKET_OPEN MINUS INTEGER ROUND_BRACKET_CLOSE 
			{ $$ = format_string("%s%d", $2, $3); }
		
		| FLOATING_POINT 
			{ $$ = format_string("%f", $1); }
		| ROUND_BRACKET_OPEN MINUS FLOATING_POINT ROUND_BRACKET_CLOSE 
			{ $$ = format_string("%s%f", $2, $3); }

		| BOOLEAN 
			{ $$ = $1; }

		| SINGLE_QUOTION_MARK CHARACTER SINGLE_QUOTION_MARK 
			{ $$ = format_string("'%c'", $2); }

		| ROUND_BRACKET_OPEN expression ROUND_BRACKET_CLOSE 
			{ $$ = $2; }
	;

variable: 
		  IDENTIFIER
			{
				if(!is_declared($1)) 
					throw_symantique_error(format_string("variable '%s' not declared", $1));
				
				$$ = $1;
			} 

		| IDENTIFIER SQUARE_BRACKET_OPEN INTEGER SQUARE_BRACKET_CLOSE
			{
				Identifier *id = get($1);
				int index = $3;

				if(id == NULL) 
					throw_symantique_error(format_string("array %s not declared", $1));
				
				if (!id->is_array)
					throw_symantique_error(format_string("variable '%s' is not an array", $1));
				
				if (index >= id->array_size)
					throw_symantique_error(format_string("index %d out of array %s bounds", index, id->name));
				
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


char *format_string(char* format, ...) 
{
	va_list args;
	va_start(args, format);

	char* str = (char*) malloc(100);
	vsprintf(str, format, args);

	va_end(args);

	return str;
}

char *type_of(char* str)
{
	if (strcmp(str, "true") == 0 || strcmp(str, "false") == 0)
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
	return strcmp(str, "int") == 0 || strcmp(str, "float") == 0;
}

int is_bool_type(char* str)
{
	return strcmp(str, "bool") == 0;
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

char *get_bigger_numeric_type(char* type1, char* type2)
{
	if (strcmp(type1, "float") == 0 || strcmp(type2, "float") == 0)
		return "float";

	return "int";
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
