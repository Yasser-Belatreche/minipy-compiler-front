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
%type <lexem_string> more_variables_dec variable_to_assign_to

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
				Identifier *target_variable = get($1);
				char *expression_type = $3;

				if (target_variable->type == NULL)
					target_variable->type = expression_type;

				else if (strcmp(target_variable->type, expression_type) != 0)
					throw_symantique_error(
						concat_strings(
							concat_strings("cannot assign type ", expression_type),
							concat_strings(
								concat_strings(" to variable ", target_variable->name),
								concat_strings(" of type ", target_variable->type)
							)
						)
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
					throw_symantique_error(concat_strings(concat_strings("array ", $1), " not declared"));
				
				if (!id->is_array)
					throw_symantique_error(concat_strings(concat_strings("variable ", $1), " is not an array"));
				
				if (index >= id->array_size)
					throw_symantique_error(
						concat_strings(
							concat_strings("index ", int_to_string(index)),
							concat_strings(concat_strings(" out of array ", id->name), " bounds")
						)
					);
				
				$$ = $1;
			}
	;

expression: 
		  expression MUL expression
			{
				if (!is_numeric_type($1) || !is_numeric_type($3))
					throw_symantique_error(
						concat_strings(
							concat_strings("Operator '*' expect operands to have numeric type but got : ", $1),
							concat_strings(" * ", $3)
						)
					);
				
				$$ = get_bigger_numeric_type($1, $3);
			}

		| expression DIVIDE expression
			{
				if (!is_numeric_type($1) || !is_numeric_type($3))
					throw_symantique_error(
						concat_strings(
							concat_strings("Operator '/' expect operands to have numeric type but got : ", $1),
							concat_strings(" / ", $3)
						)
					);
				
				$$ = get_bigger_numeric_type($1, $3);
			}
		
		| expression PLUS expression
			{
				if (!is_numeric_type($1) || !is_numeric_type($3))
					throw_symantique_error(
						concat_strings(
							concat_strings("Operator '+' expect operands to have numeric type but got : ", $1),
							concat_strings(" + ", $3)
						)
					);
				
				$$ = get_bigger_numeric_type($1, $3);
			}

		| expression MINUS expression 
			{
				if (!is_numeric_type($1) || !is_numeric_type($3))
					throw_symantique_error(
						concat_strings(
							concat_strings("Operator '-' expect operands to have numeric type but got : ", $1),
							concat_strings(" - ", $3)
						)
					);
				
				$$ = get_bigger_numeric_type($1, $3);
			}

		| expression AND expression
			{
				if (!is_bool_type($1) || !is_bool_type($3))
					throw_symantique_error(
						concat_strings(
							concat_strings("Operator 'and' expect operands to have boolean type but got : ", $1),
							concat_strings(" and ", $3)
						)
					);

				$$ = "bool";
			}
		| expression OR expression 
			{
				if (!is_bool_type($1) || !is_bool_type($3))
					throw_symantique_error(
						concat_strings(
							concat_strings("Operator 'or' expect operands to have boolean type but got : ", $1),
							concat_strings(" or ", $3)
						)
					);

				$$ = "bool";
			}

		| NOT expression 
			{
				if (!is_bool_type($2))
					throw_symantique_error(
						concat_strings("Operator 'not' expect operand to have bool type but got : not", $2)
					);

				$$ = "bool";
			}

		| expression GE expression 
			{
				if (!is_numeric_type($1) || !is_numeric_type($3))
					throw_symantique_error(
						concat_strings(
							concat_strings("Operator '>=' expect operands to have numeric type but got : ", $1),
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
							concat_strings("Operator '<=' expect operands to have numeric type but got : ", $1),
							concat_strings(" <= ", $3)
						)
					);

				$$ = "bool";
			}

		| expression EQ expression
			{
				if (strcmp($1, $3) != 0)
					if (!is_numeric_type($1) || !is_numeric_type($3))
						throw_symantique_error(
							concat_strings(
								concat_strings("Operator '==' expect operands to have the same type but got : ", $1),
								concat_strings(" == ", $3)
							)
						);

				$$ = "bool";
			}

		| expression NE expression
			{
				if (strcmp($1, $3) != 0)
					if (!is_numeric_type($1) || !is_numeric_type($3))
						throw_symantique_error(
							concat_strings(
								concat_strings("Operator '!=' expect operands to have the same type but got : ", $1),
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
							concat_strings("Operator '>' expect operands to have numeric type but got : ", $1),
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
							concat_strings("Operator '<' expect operands to have numeric type but got : ", $1),
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
							concat_strings(concat_strings(" out of array ", id->name), " bounds")
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

char *float_to_string(float f) 
{
	char* str = (char*) malloc(100);
	sprintf(str, "%f", f);
	return str;
}

char *int_to_string(int i) 
{
	char* str = (char*) malloc(100);
	sprintf(str, "%d", i);
	return str;
}

char *concat_strings(char* str1, char* str2) 
{
	char* str = (char*) malloc(strlen(str1) + strlen(str2) + 1);

	strcpy(str, str1);
	strcat(str, str2);

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
