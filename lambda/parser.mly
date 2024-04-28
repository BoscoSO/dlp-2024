
%{
  open Lambda;;
%}

%token LAMBDA
%token TYPE
%token TRUE
%token FALSE
%token IF
%token THEN
%token ELSE
%token SUCC
%token PRED
%token ISZERO
%token LET
%token LETREC
%token IN
%token CONCAT
%token FIRST
%token REST
%token BOOL
%token NAT
%token STRING
%token FIX
%token LPAREN
%token RPAREN
%token DOT
%token EQ
%token COLON
%token ARROW
%token EOF


%token TPAIR

%token LBRACKET
%token COMMA
%token RBRACKET
%token RCORCHETE
%token LCORCHETE


%token <int> INTV
%token <string> IDV
%token <string> IDT
%token <string> STRINGV

%start s
%type <Lambda.command> s
%type <Lambda.term> term

%%

s :
    term EOF
        { EvalOfTerm $1 }
    | TYPE ty EOF
        { EvalOfType $2 }
    | IDV EQ term EOF
        { BindOfTerm ($1, $3) }
    | IDT EQ ty EOF
        { BindOfType ($1, $3) }
    | LET IDV EQ term EOF
        { BindOfTerm ($2, TmLetIn($2, $4, TmVar $2)) }
    | LETREC IDV COLON ty EQ term EOF
        { BindOfTerm ($2, TmLetIn($2, TmFix(TmAbs ($2, $4, $6)), TmVar $2)) }


term :
    appTerm
      { $1 }
  | IF term THEN term ELSE term
      { TmIf ($2, $4, $6) }
  | LAMBDA IDV COLON ty DOT term
      { TmAbs ($2, $4, $6) }
  | LET IDV EQ term IN term
      { TmLetIn ($2, $4, $6) }
  | LETREC IDV COLON ty EQ term IN term
      { TmLetIn ($2, TmFix (TmAbs ($2, $4, $6)), $8) }

appTerm :
    atomicTerm
      { $1 }
  | SUCC atomicTerm
      { TmSucc $2 }
  | PRED atomicTerm
      { TmPred $2 }
  | ISZERO atomicTerm
      { TmIsZero $2 }
  | CONCAT atomicTerm atomicTerm
      { TmConcat ($2, $3) }
  | FIRST atomicTerm
      { TmFirst $2 }
  | REST atomicTerm
      { TmRest $2 }
  | FIX atomicTerm
      { TmFix $2 }
  | appTerm atomicTerm
      { TmApp ($1, $2) }

atomicTerm :
    LPAREN term RPAREN
      { $2 }
  | LBRACKET appTerm COMMA appTerm RBRACKET
      { TmPair ($2, $4) }
  | TRUE
      { TmTrue }
  | FALSE
      { TmFalse }
  | IDV
      { TmVar $1 }
  | STRINGV
      { TmString $1 }
  | INTV
      { let rec f = function
            0 -> TmZero
          | n -> TmSucc (f (n-1))
        in f $1 }
  | LBRACKET recordTM
    { TmRecord $2 }


recordTM:
   | RBRACKET { [] }
   | STRINGV EQ appTerm RBRACKET { [($1,$3)] }
   | STRINGV EQ appTerm COMMA recordTM { (($1,$3)::($5)) }

ty :
    atomicTy
      { $1 }
  | atomicTy TPAIR atomicTy
      { TyPair ($1, $3) }
  | atomicTy ARROW ty
      { TyArr ($1, $3) }

atomicTy :
    LPAREN ty RPAREN  
      { $2 } 
  | BOOL
      { TyBool }
  | NAT
      { TyNat }
  | STRING 
      { TyString }
  | IDT
      { TyDeclared $1 }
  | LBRACKET recordTY
      { TyRecord $2 }

recordTY:
   | RBRACKET { [] }
   | STRINGV COLON ty RBRACKET { [($1,$3)] }
   | STRINGV COLON ty COMMA recordTY { (($1,$3)::($5)) }