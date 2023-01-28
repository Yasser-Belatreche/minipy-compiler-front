%{
	#include <stdio.h>
	#include <stdlib.h>
	#include <string.h>
	#include <stdarg.h>

	#include "../src/symbol-table/symbol-table.h"
	#include "../src/data-structures/stack/stack.c"
	#include "../src/intermediate-code/quadruplet/quadruplet.c"

	int yylex();
	int yyerror(char*);

	int is_int(char*);
	int is_float(char*);
	int is_bool_type(char*);
	int is_numeric_type(char*);

	char* format_string(char*, ...);
	char* get_bigger_numeric_type(char*, char*);

	void throw_symantique_error(char*);

	extern FILE* yyin;
	extern int line_number, column_number;

	Stack *if_false_branching_stack, *if_end_branching_stack;
	Stack *while_start_quads_stack, *while_end_branching_stack;
	Stack *for_start_quads_stack, *for_end_branching_stack;
%}

%union {
	int lexem_int;
	float lexem_float;
	char* lexem_string;

	struct expr {
		char* type;
		char* result;
	} expr;

	struct range {
		char* start;
		char* end;
	} range;
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


%type <lexem_string> variable_dec variables_dec_list more_variables_dec 
%type <lexem_string> for_iterator array_reference 
%type <lexem_string> type for_in_range for_in_array
%type <expr> expression condition variable factor simple_variable_to_assign_to array_variable_to_assign_to
%type <range> range

%%
program: 
		  statement_list { }
	;

statement_list: 
		  statement_list statement
		| /* epsilon */ { }
	;

block: 
		  block_start statement_list block_end { } 
	;

block_start: 
		  INDENT { create_new_scope(); }
	;

block_end: 
		  DEDENT { destroy_most_inner_scope(); }
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
				if(is_declared_in_current_scope($1))
					throw_symantique_error(format_string("variable '%s' already declared", $1));
				
				insert($1, NULL);

				$$ = $1;
			}
		| IDENTIFIER SQUARE_BRACKET_OPEN INTEGER SQUARE_BRACKET_CLOSE 
			{
				if(is_declared_in_current_scope($1))
					throw_symantique_error(format_string("variable '%s' already declared", $1));
				
				insert_array($1, NULL, $3);

				insert_quadruplet("ADEC", $1, format_string("%d", $3), "");

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
		  assing_to_simple_variable
		| assign_to_array_variable
	;

assing_to_simple_variable: 
		  simple_variable_to_assign_to ASSIGNMENT expression
		  	{
				Identifier *target_variable = get($1.result);
				char *expression_type = $3.type;

				if (target_variable->type == NULL)
					target_variable->type = expression_type;

				else if (strcmp(target_variable->type, expression_type) != 0)
					throw_symantique_error(
						format_string("cannot assign type %s to variable '%s' of type %s", expression_type, target_variable->name, target_variable->type)
					);

				insert_quadruplet("=", $3.result, "", target_variable->name);
			}
	;

simple_variable_to_assign_to:
		  IDENTIFIER
		  	{
				if(!is_declared_in_current_scope($1))
					insert($1, NULL);
				
				Identifier *id = get($1);
				
				$$.type = id->type;
				$$.result = id->name;
			}
	;

assign_to_array_variable: 
		  array_variable_to_assign_to SQUARE_BRACKET_OPEN INTEGER SQUARE_BRACKET_CLOSE ASSIGNMENT expression 
			{
				Identifier *id = get($1.result);
				int index = $3;

				if (index >= id->array_size)
					throw_symantique_error(format_string("index %d out of array '%s' bounds", index, id->name));

				char *expression_type = $6.type;
				if (strcmp(id->type, expression_type) != 0)
					throw_symantique_error(
						format_string("cannot assign type %s to variable '%s' of type %s", expression_type, id->name, id->type)
					);

				char *temp = next_temp();

				insert_quadruplet("SUBS", id->name, format_string("%d", index), temp);
				insert_quadruplet("=", $6.result, "", temp);
			}
	;

array_variable_to_assign_to:
		  IDENTIFIER
		  	{
				Identifier *id = get($1);

				if(id == NULL)
					throw_symantique_error(format_string("array '%s' not declared", $1));

				if (!id->is_array)
					throw_symantique_error(format_string("variable '%s' is not an array", id->name));

				$$.type = id->type;
				$$.result = id->name;
			}
	;


if_statement:
		  if_without_else
		| if_with_else
	;

if_without_else:
		  if_start block
			{
				Quadruplet *jump = get_quadruplet(pop(if_false_branching_stack));

				jump->arg1 = format_string("%d", get_current_quadruplet_index());
			}
	;

if_with_else:
		  if_start block else_start block
			{
				Quadruplet *q = get_quadruplet(pop(if_end_branching_stack));

				q->arg1 = format_string("%d", get_current_quadruplet_index());
			}
	;

if_start:
		  IF ROUND_BRACKET_OPEN condition ROUND_BRACKET_CLOSE COLON
			{
				int index = insert_quadruplet("BZ", "", $3.result, "");

				push(if_false_branching_stack, index);
			}
	;

else_start:
		  ELSE COLON
			{
				int index = insert_quadruplet("BR", "", "", "");
				push(if_end_branching_stack, index);

				Quadruplet *q = get_quadruplet(pop(if_false_branching_stack));
				q->arg1 = format_string("%d", get_current_quadruplet_index());
			}
	;


while_statement:
		  while_start block
			{
				int index = insert_quadruplet("BR", format_string("%d", pop(while_start_quads_stack)), "", "");

				Quadruplet *q = get_quadruplet(pop(while_end_branching_stack));
				q->arg1 = format_string("%d", index + 1);
			}
	;

while_start: 
		WHILE ROUND_BRACKET_OPEN condition ROUND_BRACKET_CLOSE COLON
			{
				int index = insert_quadruplet("BZ", "", $3.result, "");

				push(while_end_branching_stack, index);
				push(while_start_quads_stack, index);
			}
	;

condition:
		  expression
			{
				if (!is_bool_type($1.type))
					throw_symantique_error(format_string("condition must be of type boolean but got %s", $1.type));
			}
	;

for_statement:
		  for_in_array COLON for_block
		  	{
				char *iterator = $1;
				insert_quadruplet("+", iterator, "1", iterator);
	
				int index = insert_quadruplet("BR", format_string("%d", pop(for_start_quads_stack)), "", "");

				Quadruplet *q = get_quadruplet(pop(for_end_branching_stack));
				q->arg1 = format_string("%d", index + 1);
			}
		| for_in_range COLON for_block
			{
				char *iterator = $1;
				insert_quadruplet("+", iterator, "1", iterator);
	
				int index = insert_quadruplet("BR", format_string("%d", pop(for_start_quads_stack)), "", "");

				Quadruplet *q = get_quadruplet(pop(for_end_branching_stack));
				q->arg1 = format_string("%d", index + 1);
			}
	;


for_in_array:
		  for_start for_iterator IN array_reference
			{
				Identifier *array = get($4);
				Identifier *iterator = get($2);

				iterator->type = array->type;

				char *temp = next_temp();
				insert_quadruplet("=", "0", "", temp);

				int index = insert_quadruplet("BGE", "", temp, format_string("%d", array->array_size));

				insert_quadruplet("SUBS", array->name, temp, iterator->name);

				push(for_end_branching_stack, index);
				push(for_start_quads_stack, index);

				$$ = temp;
			}
	;

for_in_range: 
		  for_start for_iterator IN range
			{
				Identifier *iterator = get($2);
				iterator->type = "int";

				insert_quadruplet("=", $4.start, "", iterator->name);

				int index = insert_quadruplet("BG", "", iterator->name, $4.end);

				push(for_end_branching_stack, index);
				push(for_start_quads_stack, index);

				$$ = iterator->name;
			}
	;

for_start:
		  FOR
		  	{ create_new_scope(); }
	;

for_block:
		  INDENT statement_list DEDENT 
		  	{ destroy_most_inner_scope(); }
	;

for_iterator: 
		  IDENTIFIER
			{
				insert($1, NULL);
				$$ = $1;
			}
	;


array_reference:
		  IDENTIFIER
			{		
				Identifier *id = get($1);

				if (id == NULL)
					throw_symantique_error(format_string("variable '%s' not declared", $1));

				if (!id->is_array)
					throw_symantique_error(format_string("variable '%s' is not an array", $1));
				
				$$ = $1;
			}
	;


range: 
		  RANGE ROUND_BRACKET_OPEN INTEGER COMMA INTEGER ROUND_BRACKET_CLOSE
			{
				if ($3 >= $5)
					throw_symantique_error(format_string("range start '%d' must be less than range end '%d'", $3, $5));

				$$.start = format_string("%d", $3);
				$$.end = format_string("%d", $5);
			}
	;

expression:
		  expression MUL expression
			{
				if (!is_numeric_type($1.type) || !is_numeric_type($3.type))
					throw_symantique_error(
						format_string("Operator '*' expect operands to have numeric type but got : %s * %s", $1.type, $3.type)
					);
		
				char *temp = next_temp();

				insert_quadruplet("*", $1.result, $3.result, temp);

				$$.result = temp;
				$$.type = get_bigger_numeric_type($1.type, $3.type);
			}

		| expression DIVIDE expression
			{
				if (!is_numeric_type($1.type) || !is_numeric_type($3.type))
					throw_symantique_error(
						format_string("Operator '/' expect operands to have numeric type but got : %s / %s", $1.type, $3.type)
					);
				
				char *temp = next_temp();

				insert_quadruplet("/", $1.result, $3.result, temp);

				$$.result = temp;
				$$.type = get_bigger_numeric_type($1.type, $3.type);
			}
		
		| expression PLUS expression
			{
				if (!is_numeric_type($1.type) || !is_numeric_type($3.type))
					throw_symantique_error(
						format_string("Operator '+' expect operands to have numeric type but got : %s + %s", $1.type, $3.type)
					);
				
				char *temp = next_temp();

				insert_quadruplet("+", $1.result, $3.result, temp);

				$$.result = temp;
				$$.type = get_bigger_numeric_type($1.type, $3.type);
			}

		| expression MINUS expression 
			{
				if (!is_numeric_type($1.type) || !is_numeric_type($3.type))
					throw_symantique_error(
						format_string("Operator '-' expect operands to have numeric type but got : %s - %s", $1.type, $3.type)
					);

				char *temp = next_temp();

				insert_quadruplet("-", $1.result, $3.result, temp);

				$$.result = temp;
				$$.type = get_bigger_numeric_type($1.type, $3.type);
			}

		| expression AND expression
			{
				if (!is_bool_type($1.type) || !is_bool_type($3.type))
					throw_symantique_error(
						format_string("Operator 'and' expect operands to have boolean type but got : %s and %s", $1.type, $3.type)
					);

				char *temp = next_temp();

				insert_quadruplet("BZ", format_string("%d", get_current_quadruplet_index() + 4), $1.result, "");
				insert_quadruplet("BZ", format_string("%d", get_current_quadruplet_index() + 3), $3.result, "");

				insert_quadruplet("=", "1", "", temp);
				insert_quadruplet("BR", format_string("%d", get_current_quadruplet_index() + 2) , "", "");

				insert_quadruplet("=", "0", "", temp);

				$$.result = temp;
				$$.type = "bool";
			}
		| expression OR expression 
			{
				if (!is_bool_type($1.type) || !is_bool_type($3.type))
					throw_symantique_error(
						format_string("Operator 'or' expect operands to have boolean type but got : %s or %s", $1.type, $3.type)
					);

				char *temp = next_temp();

				insert_quadruplet("BNZ", format_string("%d", get_current_quadruplet_index() + 4), $1.result, "");
				insert_quadruplet("BNZ", format_string("%d", get_current_quadruplet_index() + 3), $3.result, "");

				insert_quadruplet("=", "0", "", temp);
				insert_quadruplet("BR", format_string("%d", get_current_quadruplet_index() + 2) , "", "");

				insert_quadruplet("=", "1", "", temp);

				$$.result = temp;
				$$.type = "bool";
			}

		| NOT expression 
			{
				if (!is_bool_type($2.type))
					throw_symantique_error(
						format_string("Operator 'not' expect operand to have bool type but got : not %s", $2.type)
					);

				char *temp = next_temp();

				insert_quadruplet("BZ", format_string("%d", get_current_quadruplet_index() + 3), $2.result, "");

				insert_quadruplet("=", "0", "", temp);
				insert_quadruplet("BR", format_string("%d", get_current_quadruplet_index() + 2) , "", "");

				insert_quadruplet("=", "1", "", temp);

				$$.result = temp;
				$$.type = "bool";
			}

		| expression GE expression 
			{
				if (!is_numeric_type($1.type) || !is_numeric_type($3.type))
					throw_symantique_error(
						format_string("Operator '>=' expect operands to have numeric type but got : %s >= %s", $1.type, $3.type)
					);

				char *temp = next_temp();

				insert_quadruplet("BGE", format_string("%d", get_current_quadruplet_index() + 3), $1.result, $3.result);

				insert_quadruplet("=", "0", "", temp);
				insert_quadruplet("BR", format_string("%d", get_current_quadruplet_index() + 2) , "", "");

				insert_quadruplet("=", "1", "", temp);

				$$.result = temp;
				$$.type = "bool";
			}

		| expression LE expression 
			{
				if (!is_numeric_type($1.type) || !is_numeric_type($3.type))
					throw_symantique_error(
						format_string("Operator '<=' expect operands to have numeric type but got : %s <= %s", $1.type, $3.type)
					);

				char *temp = next_temp();

				insert_quadruplet("BLE", format_string("%d", get_current_quadruplet_index() + 3), $1.result, $3.result);

				insert_quadruplet("=", "0", "", temp);
				insert_quadruplet("BR", format_string("%d", get_current_quadruplet_index() + 2) , "", "");

				insert_quadruplet("=", "1", "", temp);

				$$.result = temp;
				$$.type = "bool";
			}

		| expression EQ expression
			{
				if (strcmp($1.type, $3.type) != 0)
					if (!is_numeric_type($1.type) || !is_numeric_type($3.type))
						throw_symantique_error(
							format_string("Operator '==' expect operands to have the same type but got : %s == %s", $1.type, $3.type)
						);

				char *temp = next_temp();

				insert_quadruplet("BE", format_string("%d", get_current_quadruplet_index() + 3), $1.result, $3.result);

				insert_quadruplet("=", "0", "", temp);
				insert_quadruplet("BR", format_string("%d", get_current_quadruplet_index() + 2) , "", "");

				insert_quadruplet("=", "1", "", temp);

				$$.result = temp;
				$$.type = "bool";
			}

		| expression NE expression
			{
				if (strcmp($1.type, $3.type) != 0)
					if (!is_numeric_type($1.type) || !is_numeric_type($3.type))
						throw_symantique_error(
							format_string("Operator '!=' expect operands to have the same type but got : %s != %s", $1.type, $3.type)
						);

				char *temp = next_temp();

				insert_quadruplet("BNE", format_string("%d", get_current_quadruplet_index() + 3), $1.result, $3.result);

				insert_quadruplet("=", "0", "", temp);
				insert_quadruplet("BR", format_string("%d", get_current_quadruplet_index() + 2) , "", "");

				insert_quadruplet("=", "1", "", temp);

				$$.result = temp;
				$$.type = "bool";
			}

		| expression GT expression
			{
				if (!is_numeric_type($1.type) || !is_numeric_type($3.type))
					throw_symantique_error(
						format_string("Operator '>' expect operands to have numeric type but got : %s > %s", $1.type, $3.type)
					);

				char *temp = next_temp();

				insert_quadruplet("BG", format_string("%d", get_current_quadruplet_index() + 3), $1.result, $3.result);

				insert_quadruplet("=", "0", "", temp);
				insert_quadruplet("BR", format_string("%d", get_current_quadruplet_index() + 2) , "", "");

				insert_quadruplet("=", "1", "", temp);

				$$.result = temp;
				$$.type = "bool";
			}

		| expression LT expression 
			{
				if (!is_numeric_type($1.type) || !is_numeric_type($3.type))
					throw_symantique_error(
						format_string("Operator '<' expect operands to have numeric type but got : %s < %s", $1.type, $3.type)
					);


				char *temp = next_temp();

				insert_quadruplet("BL", format_string("%d", get_current_quadruplet_index() + 3), $1.result, $3.result);

				insert_quadruplet("=", "0", "", temp);
				insert_quadruplet("BR", format_string("%d", get_current_quadruplet_index() + 2) , "", "");

				insert_quadruplet("=", "1", "", temp);

				$$.result = temp;
				$$.type = "bool";
			}

		| factor 
			{ $$ = $1; }
	;

factor:
		  variable
 			{ $$ = $1; }

		| INTEGER
			{
				$$.type = "int";
				$$.result = format_string("%d", $1);
			}

		| ROUND_BRACKET_OPEN MINUS INTEGER ROUND_BRACKET_CLOSE 
			{
				$$.type = "int";
				$$.result = format_string("%s%d", $2, $3);
			}

		| FLOATING_POINT 
			{
				$$.type = "float";
				$$.result = format_string("%f", $1);
			}

		| ROUND_BRACKET_OPEN MINUS FLOATING_POINT ROUND_BRACKET_CLOSE 
			{
				$$.type = "float";
				$$.result = format_string("%s%f", $2, $3);
			}

		| BOOLEAN 
			{
				$$.type = "bool";

				if (strcmp($1, "true") == 0)
					$$.result = "1";
				else if (strcmp($1, "false") == 0)
					$$.result = "0";
			}

		| SINGLE_QUOTION_MARK CHARACTER SINGLE_QUOTION_MARK 
			{ 
				$$.type = "char";
				$$.result = format_string("'%c'", $2);
			}

		| ROUND_BRACKET_OPEN expression ROUND_BRACKET_CLOSE 
			{ $$ = $2; }
	;

variable: 
		  IDENTIFIER
			{
				Identifier *id = get($1);
				
				if (id == NULL) 
					throw_symantique_error(format_string("variable '%s' not declared", $1));
				
				if (id->is_array)
					throw_symantique_error(format_string("variable '%s' is an array, you can only reference his elements", $1));

				$$.type = id->type;
				$$.result = id->name;
			}

		| IDENTIFIER SQUARE_BRACKET_OPEN INTEGER SQUARE_BRACKET_CLOSE
			{
				Identifier *id = get($1);
				int index = $3;

				if (id == NULL)
					throw_symantique_error(format_string("array %s not declared", $1));

				if (!id->is_array)
					throw_symantique_error(format_string("variable '%s' is not an array", $1));

				if (index >= id->array_size)
					throw_symantique_error(format_string("index %d out of array %s bounds", index, id->name));

				char *temp = next_temp();

				insert_quadruplet("SUBS", id->name, format_string("%d", index), temp);

				$$.type = id->type;
				$$.result = temp;
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

	if_false_branching_stack = create_stack();
	if_end_branching_stack = create_stack();

	while_start_quads_stack = create_stack();
	while_end_branching_stack = create_stack();

	for_start_quads_stack = create_stack();
	for_end_branching_stack = create_stack();

	create_new_scope();

	yyparse();

	display_symbol_table();
	display_quadruplets();

	fclose (yyin);

	return 0;
}
