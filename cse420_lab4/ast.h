#ifndef AST_H
#define AST_H

#include <iostream>
#include <vector>
#include <string>
#include <fstream>
#include <map>

using namespace std;

class ASTNode {
public:
    virtual ~ASTNode() {}
    virtual string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp, int& temp_count, int& label_count) const = 0;
};

// Expression node types

class ExprNode : public ASTNode {
protected:
    string node_type; // Type information (int, float, void, etc.)
public:
    ExprNode(string type) : node_type(type) {}
    virtual string get_type() const { return node_type; }
};

// Variable node (for ID references)

class VarNode : public ExprNode {
private:
    string name;
    ExprNode* index; // For array access, nullptr for simple variables

public:
    VarNode(string name, string type, ExprNode* idx = nullptr, int scope_id = 0)
        : ExprNode(type), name(name), index(idx) {}
    
    ~VarNode() { if(index) delete index; }
    
    bool has_index() const { return index != nullptr; }
    
    string generate_index_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                              int& temp_count, int& label_count) const {
        if (!index) return "";
        
        // Generate code for the index expression
        string idx_temp = index->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        
        // Scale the index based on element type (4 bytes for int, 8 bytes for float/double)
        string scale_temp = "t" + to_string(temp_count++);
        int scale_factor = 4; // Default for int and most types
        
        if (node_type == "float" || node_type == "double") {
            scale_factor = 8; // 8 bytes
        }
        
        outcode << scale_temp << " = " << idx_temp << " * " << scale_factor << endl;
        
        return scale_temp;
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        if (has_index()) {
            string index_val = generate_index_code(outcode, symbol_to_temp, temp_count, label_count);
            string temp_var = "t" + to_string(temp_count++);
            outcode << temp_var << " = " << name << "[" << index_val << "]" << endl;
            return temp_var;
        } else {
            // Check if this is a cached variable (e.g., function parameter)
            if (symbol_to_temp.find(name) != symbol_to_temp.end()) {
                return symbol_to_temp[name];
            }
            // Extract variable to temporary (local variables)
            string temp_var = "t" + to_string(temp_count++);
            outcode << temp_var << " = " << name << endl;
            return temp_var;
        }
    }
    
    string get_name() const { return name; }
};

// Constant node

class ConstNode : public ExprNode {
private:
    string value;

public:
    ConstNode(string val, string type) : ExprNode(type), value(val) {}
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        string temp = "t" + to_string(temp_count++);
        outcode << temp << " = " << value << endl;
        return temp;
    }
};

// Binary operation node

class BinaryOpNode : public ExprNode {
private:
    string op;
    ExprNode* left;
    ExprNode* right;

public:
    BinaryOpNode(string op, ExprNode* left, ExprNode* right, string result_type)
        : ExprNode(result_type), op(op), left(left), right(right) {}
    
    ~BinaryOpNode() {
        delete left;
        delete right;
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        if (!left || !right) return "";
        
        string left_val = left->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        string right_val = right->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        
        string temp_var = "t" + to_string(temp_count);
        temp_count++;
        
        // Handle logical operators with short-circuit evaluation
        if (op == "&&" || op == "||") {
            string label_true = "L" + to_string(label_count++);
            string label_false = "L" + to_string(label_count++);
            string label_end = "L" + to_string(label_count++);
            
            outcode << "// Logical operation: " << op << endl;
            if (op == "&&") {
                outcode << "if " << left_val << " == 0 goto " << label_false << endl;
                outcode << "if " << right_val << " == 0 goto " << label_false << endl;
                outcode << "goto " << label_true << endl;
                outcode << label_false << ":" << endl;
                outcode << temp_var << " = 0" << endl;
                outcode << "goto " << label_end << endl;
                outcode << label_true << ":" << endl;
                outcode << temp_var << " = 1" << endl;
                outcode << label_end << ":" << endl;
            } else { // ||
                outcode << "if " << left_val << " != 0 goto " << label_true << endl;
                outcode << "if " << right_val << " != 0 goto " << label_true << endl;
                outcode << "goto " << label_false << endl;
                outcode << label_true << ":" << endl;
                outcode << temp_var << " = 1" << endl;
                outcode << "goto " << label_end << endl;
                outcode << label_false << ":" << endl;
                outcode << temp_var << " = 0" << endl;
                outcode << label_end << ":" << endl;
            }
        } else {
            outcode << temp_var << " = " << left_val << " " << op << " " << right_val << endl;
        }
        
        return temp_var;
    }
};

// Unary operation node

class UnaryOpNode : public ExprNode {
private:
    string op;
    ExprNode* expr;

public:
    UnaryOpNode(string op, ExprNode* expr, string result_type)
        : ExprNode(result_type), op(op), expr(expr) {}
    
    ~UnaryOpNode() { delete expr; }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        if (!expr) return "error";
        
        string operand_val = expr->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        string temp_var = "t" + to_string(temp_count++);
        
        if (op == "!") {
            string label_true = "L" + to_string(label_count++);
            string label_false = "L" + to_string(label_count++);
            string label_end = "L" + to_string(label_count++);
            
            outcode << "if " << operand_val << " == 0 goto " << label_true << endl;
            outcode << temp_var << " = 0" << endl;
            outcode << "goto " << label_end << endl;
            outcode << label_true << ":" << endl;
            outcode << temp_var << " = 1" << endl;
            outcode << label_end << ":" << endl;
        } else {
            outcode << temp_var << " = " << op << operand_val << endl;
        }
        
        return temp_var;
    }
};

// Assignment node

class AssignNode : public ExprNode {
private:
    VarNode* lhs;
    ExprNode* rhs;

public:
    AssignNode(VarNode* lhs, ExprNode* rhs, string result_type)
        : ExprNode(result_type), lhs(lhs), rhs(rhs) {}
    
    ~AssignNode() {
        if (lhs) delete lhs;
        if (rhs) delete rhs;
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        if (!rhs) return "error";
        
        string rhs_val = rhs->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        
        if (lhs && lhs->has_index()) {
            string index_val = lhs->generate_index_code(outcode, symbol_to_temp, temp_count, label_count);
            outcode << lhs->get_name() << "[" << index_val << "] = " << rhs_val << endl;
        } else if (lhs) {
            outcode << lhs->get_name() << " = " << rhs_val << endl;
        }
        
        return rhs_val;
    }
};

// Statement node types

class StmtNode : public ASTNode {
public:
    virtual string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                                int& temp_count, int& label_count) const = 0;
};

// Expression statement node

class ExprStmtNode : public StmtNode {
private:
    ExprNode* expr;

public:
    ExprStmtNode(ExprNode* e) : expr(e) {}
    ~ExprStmtNode() { if(expr) delete expr; }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        if (expr) {
            return expr->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        }
        return "";
    }
};

// Block (compound statement) node

class BlockNode : public StmtNode {
private:
    vector<StmtNode*> statements;

public:
    ~BlockNode() {
        for (auto stmt : statements) {
            delete stmt;
        }
    }
    
    void add_statement(StmtNode* stmt) {
        if (stmt) statements.push_back(stmt);
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        for (auto stmt : statements) {
            if (stmt) {
                stmt->generate_code(outcode, symbol_to_temp, temp_count, label_count);
            }
        }
        return "";
    }
};

// If statement node

class IfNode : public StmtNode {
private:
    ExprNode* condition;
    StmtNode* then_block;
    StmtNode* else_block; // nullptr if no else part

public:
    IfNode(ExprNode* cond, StmtNode* then_stmt, StmtNode* else_stmt = nullptr)
        : condition(cond), then_block(then_stmt), else_block(else_stmt) {}
    
    ~IfNode() {
        if (condition) delete condition;
        if (then_block) delete then_block;
        if (else_block) delete else_block;
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        if (!condition || !then_block) return "";
        
        string cond_val = condition->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        string label_true = "L" + to_string(label_count++);
        string label_end = "L" + to_string(label_count++);
        
        outcode << "if " << cond_val << " goto " << label_true << endl;
        outcode << "goto " << label_end << endl;
        outcode << label_true << ":" << endl;
        
        then_block->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        
        outcode << "goto " << label_end << endl;
        
        if (else_block) {
            else_block->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        }
        
        outcode << label_end << ":" << endl;
        
        return "";
    }
};

// While statement node

class WhileNode : public StmtNode {
private:
    ExprNode* condition;
    StmtNode* body;

public:
    WhileNode(ExprNode* cond, StmtNode* body_stmt)
        : condition(cond), body(body_stmt) {}
    
    ~WhileNode() {
        if (condition) delete condition;
        if (body) delete body;
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        if (!condition || !body) return "";
        
        string label_start = "L" + to_string(label_count++);
        string label_body = "L" + to_string(label_count++);
        string label_end = "L" + to_string(label_count++);
        
        outcode << label_start << ":" << endl;
        
        string cond_val = condition->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        outcode << "if " << cond_val << " goto " << label_body << endl;
        outcode << "goto " << label_end << endl;
        outcode << label_body << ":" << endl;
        
        body->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        
        outcode << "goto " << label_start << endl;
        outcode << label_end << ":" << endl;
        
        return "";
    }
};

// For statement node

class ForNode : public StmtNode {
private:
    ExprNode* init;
    ExprNode* condition;
    ExprNode* update;
    StmtNode* body;

public:
    ForNode(ExprNode* init_expr, ExprNode* cond_expr, ExprNode* update_expr, StmtNode* body_stmt)
        : init(init_expr), condition(cond_expr), update(update_expr), body(body_stmt) {}
    
    ~ForNode() {
        if (init) delete init;
        if (condition) delete condition;
        if (update) delete update;
        if (body) delete body;
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        string label_start = "L" + to_string(label_count++);
        string label_body = "L" + to_string(label_count++);
        string label_end = "L" + to_string(label_count++);
        
        if (init) {
            init->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        }
        
        outcode << label_start << ":" << endl;
        
        if (condition) {
            string cond_val = condition->generate_code(outcode, symbol_to_temp, temp_count, label_count);
            outcode << "if " << cond_val << " goto " << label_body << endl;
            outcode << "goto " << label_end << endl;
            outcode << label_body << ":" << endl;
        }
        
        if (body) {
            body->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        }
        
        if (update) {
            update->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        }
        
        outcode << "goto " << label_start << endl;
        outcode << label_end << ":" << endl;
        
        return "";
    }
};

// Return statement node

class ReturnNode : public StmtNode {
private:
    ExprNode* expr;

public:
    ReturnNode(ExprNode* e) : expr(e) {}
    ~ReturnNode() { if (expr) delete expr; }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        if (expr) {
            string ret_val = expr->generate_code(outcode, symbol_to_temp, temp_count, label_count);
            outcode << "return " << ret_val << endl;
        } else {
            outcode << "return" << endl;
        }
        return "";
    }
};

// Declaration node

class DeclNode : public StmtNode {
private:
    string type;
    vector<pair<string, int>> vars; // Variable name and array size (0 for regular vars)

public:
    DeclNode(string t) : type(t) {}
    
    void add_var(string name, int array_size = 0) {
        vars.push_back(make_pair(name, array_size));
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        // Each variable gets its own declaration line
        for (const auto& var : vars) {
            outcode << "// Declaration: " << type << " " << var.first;
            if (var.second > 0) {
                outcode << "[" << var.second << "]";
            }
            outcode << endl;
        }
        return "";
    }
    
    string get_type() const { return type; }
    const vector<pair<string, int>>& get_vars() const { return vars; }
};

// Function declaration node

class FuncDeclNode : public ASTNode {
private:
    string return_type;
    string name;
    vector<pair<string, string>> params; // Parameter type and name
    BlockNode* body;

public:
    FuncDeclNode(string ret_type, string n) : return_type(ret_type), name(n), body(nullptr) {}
    ~FuncDeclNode() { if (body) delete body; }
    
    void add_param(string type, string name) {
        params.push_back(make_pair(type, name));
    }
    
    void set_body(BlockNode* b) {
        body = b;
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        outcode << "// Function: " << return_type << " " << name << "(";
        for (size_t i = 0; i < params.size(); i++) {
            outcode << params[i].first << " " << params[i].second;
            if (i < params.size() - 1) outcode << ", ";
        }
        outcode << ")" << endl;
        
        // Create local symbol map for this function scope
        map<string, string> local_symbol_to_temp = symbol_to_temp;
        
        // Extract parameters to temporaries and cache them
        for (const auto& param : params) {
            string temp_var = "t" + to_string(temp_count++);
            outcode << temp_var << " = " << param.second << endl;
            local_symbol_to_temp[param.second] = temp_var;  // Cache for reuse in function
        }
        
        if (body) {
            body->generate_code(outcode, local_symbol_to_temp, temp_count, label_count);
        }
        
        return "";
    }
};

// Helper class for function arguments

class ArgumentsNode : public ASTNode {
private:
    vector<ExprNode*> args;

public:
    ~ArgumentsNode() {
        // Arguments are transferred to FuncCallNode, do NOT delete them here
        // Just clear the vector without deleting contents
        args.clear();
    }
    
    void add_argument(ExprNode* arg) {
        if (arg) args.push_back(arg);
    }
    
    ExprNode* get_argument(int index) const {
        if (index >= 0 && index < args.size()) {
            return args[index];
        }
        return nullptr;
    }
    
    size_t size() const {
        return args.size();
    }
    
    const vector<ExprNode*>& get_arguments() const {
        return args;
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        // This node doesn't generate code directly
        return "";
    }
};

// Function call node

class FuncCallNode : public ExprNode {
private:
    string func_name;
    vector<ExprNode*> arguments;

public:
    FuncCallNode(string name, string result_type)
        : ExprNode(result_type), func_name(name) {}
    
    ~FuncCallNode() {
        for (auto arg : arguments) {
            delete arg;
        }
    }
    
    void add_argument(ExprNode* arg) {
        if (arg) arguments.push_back(arg);
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        if (arguments.empty()) {
            // Call function with no arguments
            string temp_var = "t" + to_string(temp_count++);
            outcode << temp_var << " = call " << func_name << ", 0" << endl;
            return temp_var;
        }
        
        // Pass arguments using param
        for (size_t i = 0; i < arguments.size(); i++) {
            if (arguments[i]) {
                string arg_val = arguments[i]->generate_code(outcode, symbol_to_temp, temp_count, label_count);
                outcode << "param " << arg_val << endl;
            }
        }
        
        // Call function
        string temp_var = "t" + to_string(temp_count++);
        outcode << temp_var << " = call " << func_name << ", " << arguments.size() << endl;
        
        return temp_var;
    }
};

// Program node (root of AST)

class ProgramNode : public ASTNode {
private:
    vector<ASTNode*> units;

public:
    ~ProgramNode() {
        for (auto unit : units) {
            delete unit;
        }
    }
    
    void add_unit(ASTNode* unit) {
        if (unit) units.push_back(unit);
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        outcode << "// ===== Three-Address Code Generation =====" << endl;
        outcode << "// Program Start" << endl << endl;
        
        for (auto unit : units) {
            if (unit) {
                unit->generate_code(outcode, symbol_to_temp, temp_count, label_count);
                outcode << endl;
            }
        }
        
        outcode << "// Program End" << endl;
        return "";
    }
};

#endif // AST_H