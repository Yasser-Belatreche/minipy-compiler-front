#ifndef SYMBOL_TABLE_H
#define SYMBOL_TABLE_H

#define taille 100

typedef struct
{
    char *nom;
    int type;
} elem;

elem TS[taille];

int recherche(char *);
void inserer(char *, int);
void afficher();

#endif // SYMBOL_TABLE_H
