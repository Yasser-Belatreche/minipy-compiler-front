#ifndef QUADRUPLET_H
#define QUADRUPLET_H

typedef struct Quadruplet
{
    char *op;
    char *arg1;
    char *arg2;
    char *result;
} Quadruplet;

int insert_quadruplet(char *op, char *arg1, char *arg2, char *result);

char *next_temp();

void display_quadruplets();

int get_current_quadruplet_index();

Quadruplet *get_quadruplet(int index);

#endif // QUADRUPLET_H
