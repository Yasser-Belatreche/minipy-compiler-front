#ifndef SYMBOL_TABLE_H
#define SYMBOL_TABLE_H

typedef struct Identifier
{
    char *name;
    char *type;

    int is_array;
    int array_size;
} Identifier;

int is_declared(char *);

int is_declared_in_current_scope(char *);

Identifier *get(char *);

void create_new_scope();

void destroy_most_inner_scope();

void insert(char *, char *);

void insert_array(char *, char *, int);

void display_symbol_table();

#endif // SYMBOL_TABLE_H
