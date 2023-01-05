#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "symbol-table.h"

int indexTS = 0;

int recherche(char *el)
{
    int i = 0;
    while (i < indexTS && strcmp(TS[i].nom, el))
        i++;
    if (i == indexTS)
        return 0;
    return 1;
}

void inserer(char *el, int typ)
{
    TS[indexTS].nom = el;
    TS[indexTS].type = typ;
    indexTS++;
}

void afficher()
{
    int i = 0;
    for (i = 0; i < indexTS; i++)
        printf("idf %s type %d\n", TS[i].nom, TS[i].type);
}
