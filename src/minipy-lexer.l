%{
#include <string.h>
#include "parser.tab.h"
extern YYSTYPE yylval;
int line=1,colo=1;
%}

%option noyywrap

chiffre [0-9]
lettre [a-zA-Z]
entier {chiffre}+
reel {chiffre}+"."{chiffre}+
idf {lettre}+
space ("\t"|" ")+
saut "\n"+

%%
{idf} {colo+=yyleng; printf ("%s IDF \n",yytext); yylval.nom = strdup(yytext);return(IDF);}
{reel} {colo+=yyleng; printf ("%s reel \n",yytext); yylval.nom = strdup(yytext);return(REEL);}
{entier} {colo+=yyleng; printf ("%s entier \n",yytext); yylval.nom =strdup(yytext);return(ENTIER);}
"=" {colo+=yyleng; printf ("%s operateur \n",yytext); yylval.nom = strdup(yytext);return (AFF);}
"+" {colo+=yyleng; printf ("%s operateur \n",yytext); yylval.nom = strdup(yytext);return(ADD);}
"-" {colo+=yyleng; printf ("%s operateur \n",yytext); yylval.nom = strdup(yytext);return(SUB);}
"/" {colo+=yyleng; printf ("%s operateur \n",yytext); yylval.nom = strdup(yytext);return(DIV);}
"*" {colo+=yyleng; printf ("%s operateur \n",yytext); yylval.nom = strdup(yytext);return(MUL);}
";" {colo+=yyleng; printf ("%s separateur \n",yytext); yylval.nom = strdup(yytext);return';';}
{space} {colo=+yyleng;}
{saut} {colo=1; line+=yyleng;}
. {printf ("erreur lexicale entite %s ligne %d colonne %d \n",yytext,line,colo);}
%%

