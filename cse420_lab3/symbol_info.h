
#include<bits/stdc++.h>
using namespace std;

class symbol_info
{
private:
    string name;
    string type;
    string symbol_kind;   // "variable", "array", "function"
    string data_type;     // "int", "float", "void", ...
    int array_size;
    vector<string> param_types; // for functions
    bool is_array_access;  // whether expression is used with array index
    bool error_reported;   // whether an error has already been reported for this symbol
    vector<int> error_arg_indices; // which argument indices had errors (for function calls)

public:
    symbol_info(string name, string type)
    {
        this->name = name;
        this->type = type;
        this->symbol_kind = "";
        this->data_type = "";
        this->array_size = 0;
        this->is_array_access = false;
        this->error_reported = false;
    }

    string getname() { return name; }
    string gettype() { return type; }
    string get_name() { return name; }
    string get_type() { return type; }

    void set_name(string name) { this->name = name; }
    void set_type(string type) { this->type = type; }

    void set_symbol_kind(string kind) { this->symbol_kind = kind; }
    string get_symbol_kind() { return symbol_kind; }

    void set_data_type(string dt) { this->data_type = dt; }
    string get_data_type() { return data_type; }

    void set_array_size(int size) { this->array_size = size; }
    int get_array_size() { return array_size; }

    void add_param_type(string pt) { param_types.push_back(pt); }
    vector<string> get_param_types() { return param_types; }

    void set_is_array_access(bool val) { this->is_array_access = val; }
    bool get_is_array_access() { return this->is_array_access; }

    void set_error_reported(bool val) { this->error_reported = val; }
    bool get_error_reported() { return this->error_reported; }

    void add_error_arg_index(int idx) { error_arg_indices.push_back(idx); }
    vector<int> get_error_arg_indices() { return error_arg_indices; }
    bool has_error_at_arg(int idx) {
        for(int i : error_arg_indices) {
            if(i == idx) return true;
        }
        return false;
    }

    ~symbol_info() {}
};