#include "scope_table.h"

class symbol_table
{
private:
    scope_table *current_scope;
    int bucket_count;
    int current_scope_id;

public:
    symbol_table(int bucket_count)
    {
        this->bucket_count = bucket_count;
        this->current_scope_id = 1;
        current_scope = new scope_table(bucket_count, current_scope_id, NULL);
    }

    ~symbol_table()
    {
        while (current_scope != NULL)
        {
            scope_table *parent = current_scope->get_parent_scope();
            delete current_scope;
            current_scope = parent;
        }
    }

    int get_current_id()
    {
        return current_scope->get_unique_id();
    }

    void enter_scope()
    {
        current_scope_id++;
        current_scope = new scope_table(bucket_count, current_scope_id, current_scope);
    }

    void exit_scope()
    {
        if (current_scope == NULL) return;
        scope_table *parent = current_scope->get_parent_scope();
        delete current_scope;
        current_scope = parent;
    }

    bool insert(symbol_info *symbol)
    {
        return current_scope->insert_in_scope(symbol);
    }

    bool remove(symbol_info *symbol)
    {
        return current_scope->delete_from_scope(symbol);
    }

    symbol_info *lookup(string name)
    {
        scope_table *temp = current_scope;
        while (temp != NULL)
        {
            symbol_info *found = temp->lookup_in_scope(name);
            if (found != NULL) return found;
            temp = temp->get_parent_scope();
        }
        return NULL;
    }

    void print_current_scope(ofstream &outlog)
    {
        current_scope->print_scope_table(outlog);
    }

    void print_all_scopes(ofstream &outlog)
    {
        outlog << "################################" << endl << endl;
        scope_table *temp = current_scope;
        while (temp != NULL)
        {
            temp->print_scope_table(outlog);
            temp = temp->get_parent_scope();
        }
        outlog << "################################" << endl << endl;
    }
};