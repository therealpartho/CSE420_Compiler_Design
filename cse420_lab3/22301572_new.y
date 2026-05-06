%{

#include "symbol_table.h"

#define YYSTYPE symbol_info*

extern FILE *yyin;
int yyparse(void);
int yylex(void);
extern YYSTYPE yylval;
bool func_scope_entered = false;
int lines = 1;
int error_count = 0;

ofstream outlog;
ofstream errlog;

symbol_table *sym_table;
string current_type = "";
vector<pair<string,string>> param_list_store;

void log_error(string msg)
{
    errlog << "At line no: " << lines << " " << msg << endl;
    error_count++;
}

void yyerror(char *s)
{
    outlog<<"At line "<<lines<<" "<<s<<endl<<endl;
    current_type = "";
    param_list_store.clear();
}

// Helper function to get the type of an expression
string get_expr_type(symbol_info* expr)
{
    // For now, we track type in the data_type field when used with expressions
    if (expr->get_data_type() != "")
        return expr->get_data_type();
    return "";
}

// Helper function to check if two types are compatible
bool types_compatible(string type1, string type2)
{
    if (type1 == type2) return true;
    // Allow implicit conversions between numeric types
    if ((type1 == "int" || type1 == "float") && (type2 == "int" || type2 == "float"))
        return true;
    return false;
}

%}

%token IF ELSE FOR WHILE DO BREAK INT CHAR FLOAT DOUBLE VOID RETURN SWITCH CASE DEFAULT CONTINUE PRINTLN ADDOP MULOP INCOP DECOP RELOP ASSIGNOP LOGICOP NOT LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COMMA SEMICOLON CONST_INT CONST_FLOAT ID

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%%

start : program
        {
                outlog<<"At line no: "<<lines<<" start : program "<<endl<<endl;
                outlog<<"Symbol Table"<<endl<<endl;
                sym_table->print_all_scopes(outlog);
        }
        ;

program : program unit
        {
                outlog<<"At line no: "<<lines<<" program : program unit "<<endl<<endl;
                outlog<<$1->getname()+"\n"+$2->getname()<<endl<<endl;
                $$ = new symbol_info($1->getname()+"\n"+$2->getname(),"program");
        }
        | unit
        {
                outlog<<"At line no: "<<lines<<" program : unit "<<endl<<endl;
                outlog<<$1->getname()<<endl<<endl;
                $$ = new symbol_info($1->getname(),"program");
        }
        ;

unit : var_declaration
        {
                outlog<<"At line no: "<<lines<<" unit : var_declaration "<<endl<<endl;
                outlog<<$1->getname()<<endl<<endl;
                $$ = new symbol_info($1->getname(),"unit");
        }
        | func_definition
        {
                outlog<<"At line no: "<<lines<<" unit : func_definition "<<endl<<endl;
                outlog<<$1->getname()<<endl<<endl;
                $$ = new symbol_info($1->getname(),"unit");
        }
        ;

func_definition : type_specifier ID LPAREN parameter_list RPAREN
        {
                symbol_info *func_sym = new symbol_info($2->getname(), "ID");
                func_sym->set_symbol_kind("function");
                func_sym->set_data_type($1->getname());
                for(auto &p : param_list_store)
                    func_sym->add_param_type(p.first);

                if(!sym_table->insert(func_sym))
                    log_error("Multiple declaration of function " + $2->getname());

                sym_table->enter_scope();
                outlog<<"New ScopeTable with id "<<sym_table->get_current_id()<<" created"<<endl<<endl;

                for(auto &p : param_list_store)
                {
                    if(p.second != "")
                    {
                        symbol_info *param_sym = new symbol_info(p.second, "ID");
                        param_sym->set_symbol_kind("variable");
                        param_sym->set_data_type(p.first);
                        if(!sym_table->insert(param_sym))
                            log_error("Multiple declaration of variable " + p.second + " in parameter of " + $2->getname());
                    }
                }
                param_list_store.clear();
                func_scope_entered = true;  // set flag
        }
        compound_statement
        {
                outlog<<"At line no: "<<lines<<" func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement "<<endl<<endl;
                outlog<<$1->getname()<<" "<<$2->getname()<<"("+$4->getname()+")\n"<<$7->getname()<<endl<<endl;
                $$ = new symbol_info($1->getname()+" "+$2->getname()+"("+$4->getname()+")\n"+$7->getname(),"func_def");
        }
        | type_specifier ID LPAREN RPAREN
        {
                symbol_info *func_sym = new symbol_info($2->getname(), "ID");
                func_sym->set_symbol_kind("function");
                func_sym->set_data_type($1->getname());

                if(!sym_table->insert(func_sym))
                    log_error("Multiple declaration of function " + $2->getname());

                sym_table->enter_scope();
                outlog<<"New ScopeTable with id "<<sym_table->get_current_id()<<" created"<<endl<<endl;
                param_list_store.clear();
                func_scope_entered = true;  // set flag
        }
        compound_statement
        {
                outlog<<"At line no: "<<lines<<" func_definition : type_specifier ID LPAREN RPAREN compound_statement "<<endl<<endl;
                outlog<<$1->getname()<<" "<<$2->getname()<<"()\n"<<$6->getname()<<endl<<endl;
                $$ = new symbol_info($1->getname()+" "+$2->getname()+"()\n"+$6->getname(),"func_def");
        }
        ;

parameter_list : parameter_list COMMA type_specifier ID
        {
                outlog<<"At line no: "<<lines<<" parameter_list : parameter_list COMMA type_specifier ID "<<endl<<endl;
                outlog<<$1->getname()<<","<<$3->getname()<<" "<<$4->getname()<<endl<<endl;
                $$ = new symbol_info($1->getname()+","+$3->getname()+" "+$4->getname(),"param_list");
                param_list_store.push_back({$3->getname(), $4->getname()});
        }
        | parameter_list COMMA type_specifier
        {
                outlog<<"At line no: "<<lines<<" parameter_list : parameter_list COMMA type_specifier "<<endl<<endl;
                outlog<<$1->getname()<<","<<$3->getname()<<endl<<endl;
                $$ = new symbol_info($1->getname()+","+$3->getname(),"param_list");
                param_list_store.push_back({$3->getname(), ""});
        }
        | type_specifier ID
        {
                outlog<<"At line no: "<<lines<<" parameter_list : type_specifier ID "<<endl<<endl;
                outlog<<$1->getname()<<" "<<$2->getname()<<endl<<endl;
                $$ = new symbol_info($1->getname()+" "+$2->getname(),"param_list");
                param_list_store.clear();
                param_list_store.push_back({$1->getname(), $2->getname()});
        }
        | type_specifier
        {
                outlog<<"At line no: "<<lines<<" parameter_list : type_specifier "<<endl<<endl;
                outlog<<$1->getname()<<endl<<endl;
                $$ = new symbol_info($1->getname(),"param_list");
                param_list_store.clear();
                param_list_store.push_back({$1->getname(), ""});
        }
        ;

compound_statement : LCURL
        {
                if(!func_scope_entered)
                {
                        // standalone block: if/while/for
                        sym_table->enter_scope();
                        outlog<<"New ScopeTable with id "<<sym_table->get_current_id()<<" created"<<endl<<endl;
                }
                func_scope_entered = false; // reset flag either way
        }
        statements RCURL
        {
                outlog<<"At line no: "<<lines<<" compound_statement : LCURL statements RCURL "<<endl<<endl;
                outlog<<"{\n"+$3->getname()+"\n}"<<endl<<endl;
                $$ = new symbol_info("{\n"+$3->getname()+"\n}","comp_stmnt");

                outlog<<"ScopeTable with id "<<sym_table->get_current_id()<<" removed"<<endl<<endl;
                sym_table->print_all_scopes(outlog);
                sym_table->exit_scope();
        }
        | LCURL RCURL
        {
                if(!func_scope_entered)
                {
                        sym_table->enter_scope();
                        outlog<<"New ScopeTable with id "<<sym_table->get_current_id()<<" created"<<endl<<endl;
                }
                func_scope_entered = false; // reset flag either way

                outlog<<"At line no: "<<lines<<" compound_statement : LCURL RCURL "<<endl<<endl;
                outlog<<"{\n}"<<endl<<endl;
                $$ = new symbol_info("{\n}","comp_stmnt");

                outlog<<"ScopeTable with id "<<sym_table->get_current_id()<<" removed"<<endl<<endl;
                sym_table->print_all_scopes(outlog);
                sym_table->exit_scope();
        }
        ;

var_declaration : type_specifier declaration_list SEMICOLON
        {
                outlog<<"At line no: "<<lines<<" var_declaration : type_specifier declaration_list SEMICOLON "<<endl<<endl;
                outlog<<$1->getname()<<" "<<$2->getname()<<";"<<endl<<endl;
                $$ = new symbol_info($1->getname()+" "+$2->getname()+";","var_dec");
                current_type = "";
        }
        ;

type_specifier : INT
        {
                outlog<<"At line no: "<<lines<<" type_specifier : INT "<<endl<<endl;
                outlog<<"int"<<endl<<endl;
                $$ = new symbol_info("int","type");
                current_type = "int";
        }
        | FLOAT
        {
                outlog<<"At line no: "<<lines<<" type_specifier : FLOAT "<<endl<<endl;
                outlog<<"float"<<endl<<endl;
                $$ = new symbol_info("float","type");
                current_type = "float";
        }
        | VOID
        {
                outlog<<"At line no: "<<lines<<" type_specifier : VOID "<<endl<<endl;
                outlog<<"void"<<endl<<endl;
                $$ = new symbol_info("void","type");
                current_type = "void";
        }
        ;

declaration_list : declaration_list COMMA ID
        {
                outlog<<"At line no: "<<lines<<" declaration_list : declaration_list COMMA ID "<<endl<<endl;
                outlog<<$1->getname()+","<<$3->getname()<<endl<<endl;
                $$ = new symbol_info($1->getname()+","+$3->getname(),"dec_list");

                // Check if void type variable
                if(current_type == "void")
                {
                    log_error("variable type can not be void");
                }

                symbol_info *var = new symbol_info($3->getname(), "ID");
                var->set_symbol_kind("variable");
                var->set_data_type(current_type);
                if(!sym_table->insert(var))
                    log_error("Multiple declaration of variable " + $3->getname());
        }
        | declaration_list COMMA ID LTHIRD CONST_INT RTHIRD
        {
                outlog<<"At line no: "<<lines<<" declaration_list : declaration_list COMMA ID LTHIRD CONST_INT RTHIRD "<<endl<<endl;
                outlog<<$1->getname()+","<<$3->getname()<<"["<<$5->getname()<<"]"<<endl<<endl;
                $$ = new symbol_info($1->getname()+","+$3->getname()+"["+$5->getname()+"]","dec_list");

                // Check if void type array
                if(current_type == "void")
                {
                    log_error("variable type can not be void");
                }

                symbol_info *arr = new symbol_info($3->getname(), "ID");
                arr->set_symbol_kind("array");
                arr->set_data_type(current_type);
                arr->set_array_size(stoi($5->getname()));
                if(!sym_table->insert(arr))
                    log_error("Multiple declaration of variable " + $3->getname());
        }
        | ID
        {
                outlog<<"At line no: "<<lines<<" declaration_list : ID "<<endl<<endl;
                outlog<<$1->getname()<<endl<<endl;
                $$ = new symbol_info($1->getname(),"dec_list");

                // Check if void type variable
                if(current_type == "void")
                {
                    log_error("variable type can not be void");
                }

                symbol_info *var = new symbol_info($1->getname(), "ID");
                var->set_symbol_kind("variable");
                var->set_data_type(current_type);
                if(!sym_table->insert(var))
                    log_error("Multiple declaration of variable " + $1->getname());
        }
        | ID LTHIRD CONST_INT RTHIRD
        {
                outlog<<"At line no: "<<lines<<" declaration_list : ID LTHIRD CONST_INT RTHIRD "<<endl<<endl;
                outlog<<$1->getname()<<"["<<$3->getname()<<"]"<<endl<<endl;
                $$ = new symbol_info($1->getname()+"["+$3->getname()+"]","dec_list");

                // Check if void type array
                if(current_type == "void")
                {
                    log_error("variable type can not be void");
                }

                symbol_info *arr = new symbol_info($1->getname(), "ID");
                arr->set_symbol_kind("array");
                arr->set_data_type(current_type);
                arr->set_array_size(stoi($3->getname()));
                if(!sym_table->insert(arr))
                    log_error("Multiple declaration of variable " + $1->getname());
        }
        ;

statements : statement
        {
                outlog<<"At line no: "<<lines<<" statements : statement "<<endl<<endl;
                outlog<<$1->getname()<<endl<<endl;
                $$ = new symbol_info($1->getname(),"stmnts");
        }
        | statements statement
        {
                outlog<<"At line no: "<<lines<<" statements : statements statement "<<endl<<endl;
                outlog<<$1->getname()<<"\n"<<$2->getname()<<endl<<endl;
                $$ = new symbol_info($1->getname()+"\n"+$2->getname(),"stmnts");
        }
        ;

statement : var_declaration
        {
                outlog<<"At line no: "<<lines<<" statement : var_declaration "<<endl<<endl;
                outlog<<$1->getname()<<endl<<endl;
                $$ = new symbol_info($1->getname(),"stmnt");
        }
        | func_definition
        {
                outlog<<"At line no: "<<lines<<" statement : func_definition "<<endl<<endl;
                outlog<<$1->getname()<<endl<<endl;
                $$ = new symbol_info($1->getname(),"stmnt");
        }
        | expression_statement
        {
                outlog<<"At line no: "<<lines<<" statement : expression_statement "<<endl<<endl;
                outlog<<$1->getname()<<endl<<endl;
                $$ = new symbol_info($1->getname(),"stmnt");
        }
        | compound_statement
        {
                outlog<<"At line no: "<<lines<<" statement : compound_statement "<<endl<<endl;
                outlog<<$1->getname()<<endl<<endl;
                $$ = new symbol_info($1->getname(),"stmnt");
        }
        | FOR LPAREN expression_statement expression_statement expression RPAREN statement
        {
                outlog<<"At line no: "<<lines<<" statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement "<<endl<<endl;
                outlog<<"for("<<$3->getname()<<$4->getname()<<$5->getname()<<")\n"<<$7->getname()<<endl<<endl;
                $$ = new symbol_info("for("+$3->getname()+$4->getname()+$5->getname()+")\n"+$7->getname(),"stmnt");
        }
        | IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE
        {
                outlog<<"At line no: "<<lines<<" statement : IF LPAREN expression RPAREN statement "<<endl<<endl;
                outlog<<"if("<<$3->getname()<<")\n"<<$5->getname()<<endl<<endl;
                $$ = new symbol_info("if("+$3->getname()+")\n"+$5->getname(),"stmnt");
        }
        | IF LPAREN expression RPAREN statement ELSE statement
        {
                outlog<<"At line no: "<<lines<<" statement : IF LPAREN expression RPAREN statement ELSE statement "<<endl<<endl;
                outlog<<"if("<<$3->getname()<<")\n"<<$5->getname()<<"\nelse\n"<<$7->getname()<<endl<<endl;
                $$ = new symbol_info("if("+$3->getname()+")\n"+$5->getname()+"\nelse\n"+$7->getname(),"stmnt");
        }
        | WHILE LPAREN expression RPAREN statement
        {
                outlog<<"At line no: "<<lines<<" statement : WHILE LPAREN expression RPAREN statement "<<endl<<endl;
                outlog<<"while("<<$3->getname()<<")\n"<<$5->getname()<<endl<<endl;
                $$ = new symbol_info("while("+$3->getname()+")\n"+$5->getname(),"stmnt");
        }
        | PRINTLN LPAREN ID RPAREN SEMICOLON
        {
                outlog<<"At line no: "<<lines<<" statement : PRINTLN LPAREN ID RPAREN SEMICOLON "<<endl<<endl;
                outlog<<"printf("<<$3->getname()<<");"<<endl<<endl;
                $$ = new symbol_info("printf("+$3->getname()+");","stmnt");
        }
        | RETURN expression SEMICOLON
        {
                outlog<<"At line no: "<<lines<<" statement : RETURN expression SEMICOLON "<<endl<<endl;
                outlog<<"return "<<$2->getname()<<";"<<endl<<endl;
                
                // Check if return expression is void
                if($2->get_data_type() == "void")
                {
                    log_error("operation on void type");
                }
                
                $$ = new symbol_info("return "+$2->getname()+";","stmnt");
        }
        ;

expression_statement : SEMICOLON
        {
                outlog<<"At line no: "<<lines<<" expression_statement : SEMICOLON "<<endl<<endl;
                outlog<<";"<<endl<<endl;
                $$ = new symbol_info(";","expr_stmt");
        }
        | expression SEMICOLON
        {
                outlog<<"At line no: "<<lines<<" expression_statement : expression SEMICOLON "<<endl<<endl;
                outlog<<$1->getname()<<";"<<endl<<endl;
                $$ = new symbol_info($1->getname()+";","expr_stmt");
        }
        ;

variable : ID
        {
                outlog<<"At line no: "<<lines<<" variable : ID "<<endl<<endl;
                outlog<<$1->getname()<<endl<<endl;
                
                // Check if variable is declared
                symbol_info *var = sym_table->lookup($1->getname());
                if(var == NULL)
                {
                    log_error("Undeclared variable " + $1->getname());
                    $$ = new symbol_info($1->getname(),"varbl");
                    $$->set_data_type("int"); // default type
                }
                else
                {
                    $$ = new symbol_info($1->getname(),"varbl");
                    $$->set_data_type(var->get_data_type());
                    $$->set_symbol_kind(var->get_symbol_kind());
                }
        }
        | ID LTHIRD expression RTHIRD
        {
                outlog<<"At line no: "<<lines<<" variable : ID LTHIRD expression RTHIRD "<<endl<<endl;
                outlog<<$1->getname()<<"["<<$3->getname()<<"]"<<endl<<endl;
                
                // Check if variable is declared
                symbol_info *var = sym_table->lookup($1->getname());
                
                if(var == NULL)
                {
                    log_error("Undeclared variable " + $1->getname());
                    $$ = new symbol_info($1->getname()+"["+$3->getname()+"]","varbl");
                    $$->set_data_type("int"); // default
                }
                else if(var->get_symbol_kind() != "array")
                {
                    log_error("variable is not of array type : " + $1->getname());
                    $$ = new symbol_info($1->getname()+"["+$3->getname()+"]","varbl");
                    $$->set_data_type(var->get_data_type());
                }
                else
                {
                    // Check if array index is integer
                    if($3->get_data_type() != "int" && $3->get_data_type() != "")
                    {
                        log_error("array index is not of integer type : " + $1->getname());
                    }
                    
                    $$ = new symbol_info($1->getname()+"["+$3->getname()+"]","varbl");
                    $$->set_data_type(var->get_data_type());
                    $$->set_is_array_access(true);
                }
        }
        ;

expression : logic_expression
        {
                outlog<<"At line no: "<<lines<<" expression : logic_expression "<<endl<<endl;
                outlog<<$1->getname()<<endl<<endl;
                $$ = new symbol_info($1->getname(),"expr");
                $$->set_data_type($1->get_data_type());
        }
        | variable ASSIGNOP logic_expression
        {
                outlog<<"At line no: "<<lines<<" expression : variable ASSIGNOP logic_expression "<<endl<<endl;
                outlog<<$1->getname()<<"="<<$3->getname()<<endl<<endl;
                
                // Type checking for assignment
                string left_type = $1->get_data_type();
                string right_type = $3->get_data_type();
                
                // Check if left operand is array
                if($1->get_symbol_kind() == "array" && !$1->get_is_array_access())
                {
                    log_error("variable is of array type : " + $1->getname());
                }
                
                // Check type compatibility
                if(left_type != "" && right_type != "")
                {
                    if(left_type == "void" || right_type == "void")
                    {
                        log_error("operation on void type");
                    }
                    else if(left_type == "int" && right_type == "float")
                    {
                        // Warning for float to int conversion
                        errlog << "At line no: " << lines << " Warning: Assignment of float value into variable of integer type " << endl;
                    }
                    else if(!types_compatible(left_type, right_type))
                    {
                        log_error("Type mismatch in assignment");
                    }
                }
                
                $$ = new symbol_info($1->getname()+"="+$3->getname(),"expr");
                $$->set_data_type(left_type);
        }
        ;

logic_expression : rel_expression
        {
                outlog<<"At line no: "<<lines<<" logic_expression : rel_expression "<<endl<<endl;
                outlog<<$1->getname()<<endl<<endl;
                $$ = new symbol_info($1->getname(),"lgc_expr");
                $$->set_data_type($1->get_data_type());
        }
        | rel_expression LOGICOP rel_expression
        {
                outlog<<"At line no: "<<lines<<" logic_expression : rel_expression LOGICOP rel_expression "<<endl<<endl;
                outlog<<$1->getname()<<$2->getname()<<$3->getname()<<endl<<endl;
                
                // Check for void type in logic operations
                if($1->get_data_type() == "void" || $3->get_data_type() == "void")
                {
                    log_error("operation on void type");
                }
                
                $$ = new symbol_info($1->getname()+$2->getname()+$3->getname(),"lgc_expr");
                $$->set_data_type("int"); // Result of logical operation is int
        }
        ;

rel_expression : simple_expression
        {
                outlog<<"At line no: "<<lines<<" rel_expression : simple_expression "<<endl<<endl;
                outlog<<$1->getname()<<endl<<endl;
                $$ = new symbol_info($1->getname(),"rel_expr");
                $$->set_data_type($1->get_data_type());
        }
        | simple_expression RELOP simple_expression
        {
                outlog<<"At line no: "<<lines<<" rel_expression : simple_expression RELOP simple_expression "<<endl<<endl;
                outlog<<$1->getname()<<$2->getname()<<$3->getname()<<endl<<endl;
                
                // Check for void type in relational operations
                if($1->get_data_type() == "void" || $3->get_data_type() == "void")
                {
                    log_error("operation on void type");
                }
                
                $$ = new symbol_info($1->getname()+$2->getname()+$3->getname(),"rel_expr");
                $$->set_data_type("int"); // Result of relational operation is int
        }
        ;

simple_expression : term
        {
                outlog<<"At line no: "<<lines<<" simple_expression : term "<<endl<<endl;
                outlog<<$1->getname()<<endl<<endl;
                $$ = new symbol_info($1->getname(),"simp_expr");
                $$->set_data_type($1->get_data_type());
        }
        | simple_expression ADDOP term
        {
                outlog<<"At line no: "<<lines<<" simple_expression : simple_expression ADDOP term "<<endl<<endl;
                outlog<<$1->getname()<<$2->getname()<<$3->getname()<<endl<<endl;
                
                // Check for void type in arithmetic operations
                if($1->get_data_type() == "void" || $3->get_data_type() == "void")
                {
                    log_error("operation on void type");
                }
                
                $$ = new symbol_info($1->getname()+$2->getname()+$3->getname(),"simp_expr");
                // Determine result type
                if($1->get_data_type() == "float" || $3->get_data_type() == "float")
                    $$->set_data_type("float");
                else
                    $$->set_data_type("int");
        }
        ;

term : unary_expression
        {
                outlog<<"At line no: "<<lines<<" term : unary_expression "<<endl<<endl;
                outlog<<$1->getname()<<endl<<endl;
                $$ = new symbol_info($1->getname(),"term");
                $$->set_data_type($1->get_data_type());
        }
        | term MULOP unary_expression
        {
                outlog<<"At line no: "<<lines<<" term : term MULOP unary_expression "<<endl<<endl;
                outlog<<$1->getname()<<$2->getname()<<$3->getname()<<endl<<endl;
                
                // Check for void type
                if($1->get_data_type() == "void" || $3->get_data_type() == "void")
                {
                    log_error("operation on void type");
                }
                
                // Special handling for modulus operator
                string op = $2->getname();
                if(op == "%")
                {
                    // Both operands must be integers
                    if($1->get_data_type() != "" && $1->get_data_type() != "int")
                    {
                        log_error("Modulus operator on non integer type");
                    }
                    if($3->get_data_type() != "" && $3->get_data_type() != "int")
                    {
                        log_error("Modulus operator on non integer type");
                    }
                    
                    // Check for division by zero (if right operand is constant 0)
                    if($3->gettype() == "INT" && $3->getname() == "0")
                    {
                        log_error("Modulus by 0");
                    }
                }
                // Division by zero check
                else if(op == "/")
                {
                    if($3->gettype() == "INT" && $3->getname() == "0")
                    {
                        log_error("Division by 0");
                    }
                }
                
                $$ = new symbol_info($1->getname()+$2->getname()+$3->getname(),"term");
                // Determine result type
                if(op == "%")
                    $$->set_data_type("int");
                else if($1->get_data_type() == "float" || $3->get_data_type() == "float")
                    $$->set_data_type("float");
                else
                    $$->set_data_type("int");
        }
        ;

unary_expression : ADDOP unary_expression
        {
                outlog<<"At line no: "<<lines<<" unary_expression : ADDOP unary_expression "<<endl<<endl;
                outlog<<$1->getname()<<$2->getname()<<endl<<endl;
                
                // Check for void type
                if($2->get_data_type() == "void")
                {
                    log_error("operation on void type");
                }
                
                $$ = new symbol_info($1->getname()+$2->getname(),"un_expr");
                $$->set_data_type($2->get_data_type());
        }
        | NOT unary_expression
        {
                outlog<<"At line no: "<<lines<<" unary_expression : NOT unary_expression "<<endl<<endl;
                outlog<<"!"<<$2->getname()<<endl<<endl;
                
                // Check for void type
                if($2->get_data_type() == "void")
                {
                    log_error("operation on void type");
                }
                
                $$ = new symbol_info("!"+$2->getname(),"un_expr");
                $$->set_data_type("int"); // Logical NOT returns int
        }
        | factor
        {
                outlog<<"At line no: "<<lines<<" unary_expression : factor "<<endl<<endl;
                outlog<<$1->getname()<<endl<<endl;
                $$ = new symbol_info($1->getname(),"un_expr");
                $$->set_data_type($1->get_data_type());
        }
        ;

factor : variable
        {
                outlog<<"At line no: "<<lines<<" factor : variable "<<endl<<endl;
                outlog<<$1->getname()<<endl<<endl;
                $$ = new symbol_info($1->getname(),"fctr");
                $$->set_data_type($1->get_data_type());
                $$->set_symbol_kind($1->get_symbol_kind());
        }
        | ID LPAREN argument_list RPAREN
        {
                outlog<<"At line no: "<<lines<<" factor : ID LPAREN argument_list RPAREN "<<endl<<endl;
                outlog<<$1->getname()<<"("<<$3->getname()<<")"<<endl<<endl;
                
                // Check if function is declared
                symbol_info *func = sym_table->lookup($1->getname());
                
                if(func == NULL)
                {
                    log_error("Undeclared function: " + $1->getname());
                    $$ = new symbol_info($1->getname()+"("+$3->getname()+")","fctr");
                    $$->set_data_type("int"); // default
                }
                else if(func->get_symbol_kind() != "function")
                {
                    log_error("function call with non-function type identifier");
                    $$ = new symbol_info($1->getname()+"("+$3->getname()+")","fctr");
                    $$->set_data_type("int");
                }
                else
                {
                    // Check function return type  - cannot use void function in expression
                    if(func->get_data_type() == "void")
                    {
                        log_error("operation on void type");
                    }
                    
                    // Check argument count and types
                    vector<string> param_types = func->get_param_types();
                    vector<string> arg_types = $3->get_param_types(); // We'll store arg types here
                    
                    if(arg_types.size() != param_types.size())
                    {
                        log_error("Inconsistencies in number of arguments in function call: " + $1->getname());
                    }
                    else
                    {
                        // Check each argument type
                        for(size_t i = 0; i < arg_types.size(); i++)
                        {
                            if(arg_types[i] != "" && param_types[i] != "")
                            {
                                if(!types_compatible(param_types[i], arg_types[i]))
                                {
                                    log_error("argument " + to_string(i+1) + " type mismatch in function call: " + $1->getname());
                                }
                            }
                        }
                    }
                    
                    $$ = new symbol_info($1->getname()+"("+$3->getname()+")","fctr");
                    $$->set_data_type(func->get_data_type());
                }
        }
        | LPAREN expression RPAREN
        {
                outlog<<"At line no: "<<lines<<" factor : LPAREN expression RPAREN "<<endl<<endl;
                outlog<<"("<<$2->getname()<<")"<<endl<<endl;
                $$ = new symbol_info("("+$2->getname()+")","fctr");
                $$->set_data_type($2->get_data_type());
        }
        | CONST_INT
        {
                outlog<<"At line no: "<<lines<<" factor : CONST_INT "<<endl<<endl;
                outlog<<$1->getname()<<endl<<endl;
                $$ = new symbol_info($1->getname(),"fctr");
                $$->set_data_type("int");
        }
        | CONST_FLOAT
        {
                outlog<<"At line no: "<<lines<<" factor : CONST_FLOAT "<<endl<<endl;
                outlog<<$1->getname()<<endl<<endl;
                $$ = new symbol_info($1->getname(),"fctr");
                $$->set_data_type("float");
        }
        | variable INCOP
        {
                outlog<<"At line no: "<<lines<<" factor : variable INCOP "<<endl<<endl;
                outlog<<$1->getname()<<"++"<<endl<<endl;
                
                // Check for void type
                if($1->get_data_type() == "void")
                {
                    log_error("operation on void type");
                }
                
                $$ = new symbol_info($1->getname()+"++","fctr");
                $$->set_data_type($1->get_data_type());
        }
        | variable DECOP
        {
                outlog<<"At line no: "<<lines<<" factor : variable DECOP "<<endl<<endl;
                outlog<<$1->getname()<<"--"<<endl<<endl;
                
                // Check for void type
                if($1->get_data_type() == "void")
                {
                    log_error("operation on void type");
                }
                
                $$ = new symbol_info($1->getname()+"--","fctr");
                $$->set_data_type($1->get_data_type());
        }
        ;

argument_list : arguments
        {
                outlog<<"At line no: "<<lines<<" argument_list : arguments "<<endl<<endl;
                outlog<<$1->getname()<<endl<<endl;
                $$ = new symbol_info($1->getname(),"arg_list");
                $$->add_param_type($1->get_data_type()); // Propagate argument types
        }
        |
        {
                outlog<<"At line no: "<<lines<<" argument_list :  "<<endl<<endl;
                outlog<<""<<endl<<endl;
                $$ = new symbol_info("","arg_list");
        }
        ;

arguments : arguments COMMA logic_expression
        {
                outlog<<"At line no: "<<lines<<" arguments : arguments COMMA logic_expression "<<endl<<endl;
                outlog<<$1->getname()<<","<<$3->getname()<<endl<<endl;
                $$ = new symbol_info($1->getname()+","+$3->getname(),"arg");
                
                // Copy all previous argument types
                for(auto &p : $1->get_param_types())
                    $$->add_param_type(p);
                // Add current argument type
                $$->add_param_type($3->get_data_type());
        }
        | logic_expression
        {
                outlog<<"At line no: "<<lines<<" arguments : logic_expression "<<endl<<endl;
                outlog<<$1->getname()<<endl<<endl;
                $$ = new symbol_info($1->getname(),"arg");
                $$->add_param_type($1->get_data_type());
        }
        ;

%%

int main(int argc, char *argv[])
{
        if(argc != 2)
        {
                cout<<"Please input file name"<<endl;
                return 0;
        }
        yyin = fopen(argv[1], "r");
        outlog.open("22301572_log.txt", ios::trunc);
        errlog.open("22301572_error.txt", ios::trunc);

        if(yyin == NULL)
        {
                cout<<"Couldn't open file"<<endl;
                return 0;
        }

        // Create symbol table and enter global scope
        sym_table = new symbol_table(11);
        outlog<<"New ScopeTable with id "<<sym_table->get_current_id()<<" created"<<endl<<endl;

        yyparse();

        outlog<<endl<<"Total lines: "<<lines<<endl;
        outlog<<"Total errors: "<<error_count<<endl;
        errlog<<"Total errors: "<<error_count<<endl;

        outlog.close();
        errlog.close();
        fclose(yyin);
        delete sym_table;

        return 0;
}
