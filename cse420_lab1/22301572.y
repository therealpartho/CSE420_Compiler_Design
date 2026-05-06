%{
#include <iostream>
#include <fstream>
#include <string>
#include "symbol_info.h"

#define YYSTYPE symbol_info*

using namespace std;

int yyparse(void);
int yylex(void);
extern FILE *yyin;
extern int lines;

ofstream outlog;

void yyerror(char *s) {
    outlog << "Error at line " << lines << ": " << s << endl;
}
%}

/* Token Definitions from Grammar and Lexer */
%token IF ELSE FOR WHILE INT FLOAT VOID RETURN PRINTLN
%token ID CONST_INT CONST_FLOAT
%token ADDOP MULOP RELOP LOGICOP ASSIGNOP INCOP DECOP NOT
%token SEMICOLON COMMA LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD

/* Resolve if-else dangling else ambiguity  */
%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%%

start : program
	{
		outlog << "At line no: " << lines << " start : program " << endl << endl;
	}
	;

program : program unit
	{
		outlog << "At line no: " << lines << " program : program unit " << endl << endl;
		outlog << $1->getname() << "\n" << $2->getname() << endl << endl;
		$$ = new symbol_info($1->getname() + "\n" + $2->getname(), "program");
	}
	| unit
	{
		outlog << "At line no: " << lines << " program : unit " << endl << endl;
		outlog << $1->getname() << endl << endl;
		$$ = new symbol_info($1->getname(), "program");
	}
	;

unit : var_declaration
	| func_definition
	;

func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement
		{	
			outlog << "At line no: " << lines << " func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement " << endl << endl;
			outlog << $1->getname() << " " << $2->getname() << "(" << $4->getname() << ")\n" << $6->getname() << endl << endl;
			$$ = new symbol_info($1->getname() + " " + $2->getname() + "(" + $4->getname() + ")\n" + $6->getname(), "func_def");
		}
		| type_specifier ID LPAREN RPAREN compound_statement
		{
			outlog << "At line no: " << lines << " func_definition : type_specifier ID LPAREN RPAREN compound_statement " << endl << endl;
			outlog << $1->getname() << " " << $2->getname() << "()\n" << $5->getname() << endl << endl;
			$$ = new symbol_info($1->getname() + " " + $2->getname() + "()\n" + $5->getname(), "func_def");	
		}
 		;

parameter_list : parameter_list COMMA type_specifier ID
		{
			$$ = new symbol_info($1->getname() + "," + $3->getname() + " " + $4->getname(), "param_list");
		}
		| type_specifier ID
		{
			$$ = new symbol_info($1->getname() + " " + $2->getname(), "param_list");
		}
		/* Add other variations from grammar  */
		;

compound_statement : LCURL statements RCURL
		{
			outlog << "At line no: " << lines << " compound_statement : LCURL statements RCURL " << endl << endl;
			outlog << "{\n" << $2->getname() << "\n}" << endl << endl;
			$$ = new symbol_info("{\n" + $2->getname() + "\n}", "compound_stmt");
		}
		| LCURL RCURL
		{
			$$ = new symbol_info("{}", "compound_stmt");
		}
		;

var_declaration : type_specifier declaration_list SEMICOLON
		{
			outlog << "At line no: " << lines << " var_declaration : type_specifier declaration_list SEMICOLON " << endl << endl;
			outlog << $1->getname() << " " << $2->getname() << ";" << endl << endl;
			$$ = new symbol_info($1->getname() + " " + $2->getname() + ";", "var_dec");
		}
		;

type_specifier : INT { $$ = new symbol_info("int", "type"); }
		| FLOAT { $$ = new symbol_info("float", "type"); }
		| VOID { $$ = new symbol_info("void", "type"); }
		;

declaration_list : declaration_list COMMA ID
		{
			$$ = new symbol_info($1->getname() + "," + $3->getname(), "dec_list");
		}
		| ID
		{
			$$ = new symbol_info($1->getname(), "dec_list");
		}
		;

statements : statement
		{
			$$ = new symbol_info($1->getname(), "stmnts");
		}
		| statements statement
		{
			$$ = new symbol_info($1->getname() + "\n" + $2->getname(), "stmnts");
		}
		;

statement : var_declaration { $$ = $1; }
	  | expression_statement { $$ = $1; }
	  | compound_statement { $$ = $1; }
	  | FOR LPAREN expression_statement expression_statement expression RPAREN statement
	  {
	    	outlog << "At line no: " << lines << " statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement " << endl << endl;
			outlog << "for(" << $3->getname() << $4->getname() << $5->getname() << ")\n" << $7->getname() << endl << endl;
			$$ = new symbol_info("for(" + $3->getname() + $4->getname() + $5->getname() + ")\n" + $7->getname(), "stmnt");
	  }
	  | IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE
	  {
			outlog << "At line no: " << lines << " statement : IF LPAREN expression RPAREN statement " << endl << endl;
			$$ = new symbol_info("if(" + $3->getname() + ")\n" + $5->getname(), "if_stmnt");
	  }
	  | IF LPAREN expression RPAREN statement ELSE statement
	  {
			outlog << "At line no: " << lines << " statement : IF LPAREN expression RPAREN statement ELSE statement " << endl << endl;
			$$ = new symbol_info("if(" + $3->getname() + ")\n" + $5->getname() + "\nelse\n" + $7->getname(), "ifelse_stmnt");
	  }
	  | RETURN expression SEMICOLON
	  {
			outlog << "At line no: " << lines << " statement : RETURN expression SEMICOLON " << endl << endl;
			$$ = new symbol_info("return " + $2->getname() + ";", "ret_stmnt");
	  }
	  ;

expression_statement : SEMICOLON { $$ = new symbol_info(";", "expr_stmt"); }
			| expression SEMICOLON { $$ = new symbol_info($1->getname() + ";", "expr_stmt"); }
			;

expression : logic_expression { $$ = $1; }
	   | variable ASSIGNOP logic_expression 
	   {
			$$ = new symbol_info($1->getname() + "=" + $3->getname(), "expr");
	   }
	   ;

logic_expression : rel_expression { $$ = $1; }
		 | rel_expression LOGICOP rel_expression
		 {
			$$ = new symbol_info($1->getname() + $2->getname() + $3->getname(), "logic_expr");
		 }
		 ;

rel_expression : simple_expression { $$ = $1; }
		| simple_expression RELOP simple_expression
		{
			$$ = new symbol_info($1->getname() + $2->getname() + $3->getname(), "rel_expr");
		}
		;

simple_expression : term { $$ = $1; }
		  | simple_expression ADDOP term
		  {
			$$ = new symbol_info($1->getname() + $2->getname() + $3->getname(), "simple_expr");
		  }
		  ;

term : unary_expression { $$ = $1; }
     | term MULOP unary_expression
	 {
		$$ = new symbol_info($1->getname() + $2->getname() + $3->getname(), "term");
	 }
     ;

unary_expression : ADDOP unary_expression { $$ = new symbol_info($1->getname() + $2->getname(), "unary"); }
		 | NOT unary_expression { $$ = new symbol_info("!" + $2->getname(), "unary"); }
		 | factor { $$ = $1; }
		 ;

factor : variable { $$ = $1; }
       | ID LPAREN argument_list RPAREN { $$ = new symbol_info($1->getname() + "(" + $3->getname() + ")", "factor"); }
       | LPAREN expression RPAREN { $$ = new symbol_info("(" + $2->getname() + ")", "factor"); }
       | CONST_INT { $$ = $1; }
       | CONST_FLOAT { $$ = $1; }
       | variable INCOP { $$ = new symbol_info($1->getname() + "++", "factor"); }
       ;

variable : ID { $$ = $1; }
	 | ID LTHIRD expression RTHIRD { $$ = new symbol_info($1->getname() + "[" + $3->getname() + "]", "var"); }
	 ;

argument_list : arguments { $$ = $1; }
	      | { $$ = new symbol_info("", "arg_list"); }
	      ;

arguments : arguments COMMA logic_expression { $$ = new symbol_info($1->getname() + "," + $3->getname(), "args"); }
	  | logic_expression { $$ = $1; }
	  ;

%%

int main(int argc, char *argv[])
{
	if(argc != 2) 
	{
        cout << "Please provide input file name" << endl;
		return 0;
	}
	yyin = fopen(argv[1], "r");
	outlog.open("22301572_log1.txt", ios::trunc);
	
	if(yyin == NULL)
	{
		cout << "Couldn't open file" << endl;
		return 0;
	}
    
	yyparse();
	
	outlog << "Total lines: " << lines << endl; 
	
	outlog.close();
	fclose(yyin);
	return 0;
}