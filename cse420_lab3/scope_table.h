#include "symbol_info.h"

class scope_table
{
private:
    int bucket_count;
    int unique_id;
    scope_table *parent_scope = NULL;
    vector<list<symbol_info *>> table;

    int hash_function(string name)
    {
        int hash = 0;
        for (char c : name)
            hash = (hash * 31 + c) % bucket_count;
        return hash;
    }

public:
    scope_table() : bucket_count(10), unique_id(1)
    {
        table.resize(bucket_count);
    }

    scope_table(int bucket_count, int unique_id, scope_table *parent_scope)
    {
        this->bucket_count = bucket_count;
        this->unique_id = unique_id;
        this->parent_scope = parent_scope;
        table.resize(bucket_count);
    }

    scope_table *get_parent_scope() { return parent_scope; }
    int get_unique_id() { return unique_id; }

    // lookup by string name only in current scope
    symbol_info *lookup_in_scope(string name)
    {
        int index = hash_function(name);
        for (symbol_info *s : table[index])
        {
            if (s->get_name() == name)
                return s;
        }
        return NULL;
    }

    // lookup by string name in current scope and parent scopes
    symbol_info *lookup_in_scope_recursive(string name)
    {
        int index = hash_function(name);
        for (symbol_info *s : table[index])
        {
            if (s->get_name() == name)
                return s;
        }
        // Search in parent scope if not found
        if (parent_scope != NULL)
            return parent_scope->lookup_in_scope_recursive(name);
        return NULL;
    }

    bool insert_in_scope(symbol_info *symbol)
    {
        int index = hash_function(symbol->get_name());
        for (symbol_info *s : table[index])
        {
            if (s->get_name() == symbol->get_name())
                return false; // already exists
        }
        table[index].push_back(symbol);
        return true;
    }

    bool delete_from_scope(symbol_info *symbol)
    {
        int index = hash_function(symbol->get_name());
        auto &bucket = table[index];
        for (auto it = bucket.begin(); it != bucket.end(); it++)
        {
            if ((*it)->get_name() == symbol->get_name())
            {
                bucket.erase(it);
                return true;
            }
        }
        return false;
    }

    void print_scope_table(ofstream &outlog)
    {
        outlog << "ScopeTable # " << to_string(unique_id) << endl;
        for (int i = 0; i < bucket_count; i++)
        {
            if (!table[i].empty())
            {
                outlog << i << "--> ";
                for (symbol_info *s : table[i])
                {
                    outlog << "< " << s->get_name() << " : " << s->get_symbol_kind();
                    if (s->get_symbol_kind() == "array")
                        outlog << " " << s->get_data_type() << "[" << s->get_array_size() << "]";
                    else if (s->get_symbol_kind() == "function")
                    {
                        outlog << " " << s->get_data_type() << "(";
                        auto params = s->get_param_types();
                        for (int j = 0; j < (int)params.size(); j++)
                        {
                            outlog << params[j];
                            if (j < (int)params.size() - 1) outlog << ",";
                        }
                        outlog << ")";
                    }
                    else
                        outlog << " " << s->get_data_type();
                    outlog << " > ";
                }
                outlog << endl;
            }
        }
    }

    ~scope_table()
    {
        for (int i = 0; i < bucket_count; i++)
            for (symbol_info *s : table[i])
                delete s;
    }
};