%{
#include <stdio.h>
#include <string.h>
int yylex();
int yyerror(char *);
extern FILE* yyin;
extern int line, colo;
%}

%union {char* nom;}
%token IDF AFF ENTIER REEL ';' 
%left ADD SUB
%left MUL DIV
%type <nom> IDF  ENTIER 

%%
s: IDF AFF exp ';' { printf ("reduction affect valeur de l'idf %s \n",$1);};
exp: exp ADD exp {printf ("reduction add \n");}
	| exp SUB exp { printf ("reduction sub \n");}	
	| exp DIV exp {printf ("reduction div \n");}
	| exp MUL exp {printf ("reduction mul \n");}
	| IDF {}
	|ENTIER {printf ("reduction entier valeur de l'entier %s\n",$1);}
	|REEL {}
	;

%%

int yyerror (char* msg)
{
	printf ("erreur syntaxique %s ligne %d colonne %d \n",msg,line,colo);return 1;
}

int main (int argc, char** argv)
{ 	
	yyin = fopen("in.minipy", "r");
	yyparse ();
	fclose (yyin);
	return 0;
}
