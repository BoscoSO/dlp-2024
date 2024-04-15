
(* TYPE DEFINITIONS *)

type ty =
    TyBool
  | TyNat
  | TyString
  | TyArr of ty * ty
;;



type term =
    TmTrue
  | TmFalse
  | TmIf of term * term * term
  | TmZero
  | TmSucc of term
  | TmPred of term
  | TmIsZero of term
  | TmVar of string
  | TmAbs of string * ty * term
  | TmApp of term * term
  | TmLetIn of string * term * term
  | TmFix of term
  | TmString of string
  | TmConcat of term * term
;;

(* Command *)
type command =
    Eval of term
  | Bind of string * term
;;

(* CONTEXT MANAGEMENT *)
type context =
  (string * ty * term option) list
;;

let emptyctx =
  []
;;

(* Adds binding to a given context *)
let addbinding ctx x ty te =
  (x, ty, Some(te)) :: ctx
;;

let addbinding_type ctx x ty =
  (x, ty, None) :: ctx
;;

exception Not_Found of string;;

(* Gets binding to a given context *)
let rec getbinding_type ctx x = match ctx with
  ((a,ty,_)::t) -> if x=a then ty else getbinding_type t x
  |[] -> raise (Not_Found x)
;;

let rec getbinding_term ctx x = match ctx with
  ((a,_,Some(term))::t) -> if x=a then term else getbinding_term t x
  |((a,_,None)::t) -> getbinding_term t x
  |[] -> raise (Not_Found x)
;;


(* TYPE MANAGEMENT (TYPING) *)

let rec string_of_ty ty = match ty with
    TyBool ->
      "Bool"
  | TyNat ->
      "Nat"
  | TyString ->
      "String"
  | TyArr (ty1, ty2) ->
      "(" ^ string_of_ty ty1 ^ ")" ^ " -> " ^ "(" ^ string_of_ty ty2 ^ ")"
;;

exception Type_error of string
;;

let rec typeof ctx tm = match tm with
    (* T-True *)
    TmTrue ->
      TyBool

    (* T-False *)
  | TmFalse ->
      TyBool

    (* T-If *)
  | TmIf (t1, t2, t3) ->
      if typeof ctx t1 = TyBool then
        let tyT2 = typeof ctx t2 in
        if typeof ctx t3 = tyT2 then tyT2
        else raise (Type_error "arms of conditional have different types")
      else
        raise (Type_error "guard of conditional not a boolean")
      
    (* T-Zero *)
  | TmZero ->
      TyNat

    (* T-Succ *)
  | TmSucc t1 ->
      if typeof ctx t1 = TyNat then TyNat
      else raise (Type_error "argument of succ is not a number")

    (* T-Pred *)
  | TmPred t1 ->
      if typeof ctx t1 = TyNat then TyNat
      else raise (Type_error "argument of pred is not a number")

    (* T-Iszero *)
  | TmIsZero t1 ->
      if typeof ctx t1 = TyNat then TyBool
      else raise (Type_error "argument of iszero is not a number")

    (* T-Var *)
  | TmVar x ->
      (try getbinding_type ctx x with
       _ -> raise (Type_error ("no binding type for variable " ^ x)))

    (* T-Abs *)
  | TmAbs (x, tyT1, t2) ->
      let ctx' = addbinding_type ctx x tyT1 in
      let tyT2 = typeof ctx' t2 in
      TyArr (tyT1, tyT2)

    (* T-App *)
  | TmApp (t1, t2) ->
      let tyT1 = typeof ctx t1 in
      let tyT2 = typeof ctx t2 in
      (match tyT1 with
           TyArr (tyT11, tyT12) ->
             if tyT2 = tyT11 then tyT12
             else raise (Type_error "parameter type mismatch")
         | _ -> raise (Type_error "arrow type expected"))

    (* T-Let *)
  | TmLetIn (x, t1, t2) ->
      let tyT1 = typeof ctx t1 in
      let ctx' = addbinding_type ctx x tyT1 in
      typeof ctx' t2

    (* T-Fix*)
  | TmFix t1 ->
      let tyT1 = typeof ctx t1 in 
      (match tyT1 with
        TyArr (tyT11, tyT12) ->
          if tyT11 = tyT12 then tyT12
          else raise (Type_error "result of body not compatible with domain")
          | _ -> raise (Type_error "arrow type expected"))
  | TmString _ ->
      TyString
  | TmConcat (t1, t2)->
      let tyT1 = typeof ctx t1 in 
      let tyT2 = typeof ctx t2 in 
      (match (tyT1, tyT2) with
          (TyString, TyString) -> TyString
        | (_, TyString) -> raise (Type_error "first argument is not a string")
        | (TyString, _) -> raise (Type_error "second argument is not a string")
        | (_, _) -> raise (Type_error "none of the arguments are strings")
      )
;;


(* TERMS MANAGEMENT (EVALUATION) *)

let rec string_of_term = function
    TmTrue ->
      "true"
  | TmFalse ->
      "false"
  | TmIf (t1,t2,t3) ->
      "if " ^ "(" ^ string_of_term t1 ^ ")" ^
      " then " ^ "(" ^ string_of_term t2 ^ ")" ^
      " else " ^ "(" ^ string_of_term t3 ^ ")"
  | TmZero ->
      "0"
  | TmSucc t ->
     let rec f n t' = match t' with
          TmZero -> string_of_int n
        | TmSucc s -> f (n+1) s
        | _ -> "succ " ^ "(" ^ string_of_term t ^ ")"
      in f 1 t
  | TmPred t ->
      "pred " ^ "(" ^ string_of_term t ^ ")"
  | TmIsZero t ->
      "iszero " ^ "(" ^ string_of_term t ^ ")"
  | TmVar s ->
      s
  | TmAbs (s, tyS, t) ->
      "(lambda " ^ s ^ ":" ^ string_of_ty tyS ^ ". " ^ string_of_term t ^ ")"
  | TmApp (t1, t2) ->
      "(" ^ string_of_term t1 ^ " " ^ string_of_term t2 ^ ")"
  | TmLetIn (s, t1, t2) ->
      "let " ^ s ^ " = " ^ string_of_term t1 ^ " in " ^ string_of_term t2
  | TmFix t ->
      "(fix " ^ string_of_term t ^ ")"
  | TmString s ->
      "\"" ^ s ^ "\""
  | TmConcat (s1, s2) ->
      string_of_term s1 ^ string_of_term s2
;;
(***********************************-EVAL-***********************************)

let rec ldif l1 l2 = match l1 with
    [] -> []
  | h::t -> if List.mem h l2 then ldif t l2 else h::(ldif t l2)
;;

let rec lunion l1 l2 = match l1 with
    [] -> l2
  | h::t -> if List.mem h l2 then lunion t l2 else h::(lunion t l2)
;;

let rec free_vars tm = match tm with
    TmTrue ->
      []
  | TmFalse ->
      []
  | TmIf (t1, t2, t3) ->
      lunion (lunion (free_vars t1) (free_vars t2)) (free_vars t3)
  | TmZero ->
      []
  | TmSucc t ->
      free_vars t
  | TmPred t ->
      free_vars t
  | TmIsZero t ->
      free_vars t
  | TmVar s ->
      [s]
  | TmAbs (s, _, t) ->
      ldif (free_vars t) [s]
  | TmApp (t1, t2) ->
      lunion (free_vars t1) (free_vars t2)
  | TmLetIn (s, t1, t2) ->
      lunion (ldif (free_vars t2) [s]) (free_vars t1)
  | TmFix t ->
      free_vars t
  | TmString _ ->
      []
  | TmConcat (t1, t2) ->
      lunion (free_vars t1) (free_vars t2)
;;

let rec fresh_name x l =
  if not (List.mem x l) then x else fresh_name (x ^ "'") l
;;
    
let rec subst ctx x s tm = match tm with
    TmTrue ->
      TmTrue
  | TmFalse ->
      TmFalse
  | TmIf (t1, t2, t3) ->
      TmIf (subst ctx x s t1, subst ctx x s t2, subst ctx x s t3)
  | TmZero ->
      TmZero
  | TmSucc t ->
      TmSucc (subst ctx x s t)
  | TmPred t ->
      TmPred (subst ctx x s t)
  | TmIsZero t ->
      TmIsZero (subst ctx x s t)
  | TmVar y ->
      if y = x then s else tm
  | TmAbs (y, tyY, t) -> 
      if y = x then tm
      else let fvs = free_vars s in
           if not (List.mem y fvs)
           then TmAbs (y, tyY, subst ctx x s t)
           else let z = fresh_name y (free_vars t @ fvs) in
                TmAbs (z, tyY, subst ctx x s (subst ctx y (TmVar z) t))  
  | TmApp (t1, t2) ->
      TmApp (subst ctx x s t1, subst ctx x s t2)
  | TmLetIn (y, t1, t2) ->
      if y = x then TmLetIn (y, subst ctx x s t1, t2)
      else let fvs = free_vars s in
           if not (List.mem y fvs)
           then TmLetIn (y, subst ctx x s t1, subst ctx x s t2)
           else let z = fresh_name y (free_vars t2 @ fvs) in
                TmLetIn (z, subst ctx x s t1, subst ctx x s (subst ctx y (TmVar z) t2))
  | TmFix t ->
      TmFix (subst ctx x s t)
  | TmString t ->
      TmString t
  | TmConcat (t1, t2) ->
      TmConcat (subst ctx x s t1,subst x s t2)
;;

let rec isnumericval tm = match tm with
    TmZero -> true
  | TmSucc t -> isnumericval t
  | _ -> false
;;

let rec isval tm = match tm with
    TmTrue  -> true
  | TmFalse -> true
  | TmAbs _ -> true
  | TmString _ -> true
  | t when isnumericval t -> true
  | _ -> false
;;

exception NoRuleApplies
;;

let rec eval1 ctx tm = match tm with
    (* E-IfTrue *)
    TmIf (TmTrue, t2, _) ->
      t2

    (* E-IfFalse *)
  | TmIf (TmFalse, _, t3) ->
      t3

    (* E-If *)
  | TmIf (t1, t2, t3) ->
      let t1' = eval1 ctx t1 in
      TmIf (t1', t2, t3)

    (* E-Succ *)
  | TmSucc t1 ->
      let t1' = eval1 ctx t1 in
      TmSucc t1'

    (* E-PredZero *)
  | TmPred TmZero ->
      TmZero

    (* E-PredSucc *)
  | TmPred (TmSucc nv1) when isnumericval nv1 ->
      nv1

    (* E-Pred *)
  | TmPred t1 ->
      let t1' = eval1 ctx t1 in
      TmPred t1'

    (* E-IszeroZero *)
  | TmIsZero TmZero ->
      TmTrue

    (* E-IszeroSucc *)
  | TmIsZero (TmSucc nv1) when isnumericval nv1 ->
      TmFalse

    (* E-Iszero *)
  | TmIsZero t1 ->
      let t1' = eval1 ctx t1 in
      TmIsZero t1'

    (* E-AppAbs *)
  | TmApp (TmAbs(x, _, t12), v2) when isval v2 ->
      subst ctx x v2 t12

    (* E-App2: evaluate argument before applying function *)
  | TmApp (v1, t2) when isval v1 ->
      let t2' = eval1 ctx t2 in
      TmApp (v1, t2')

    (* E-App1: evaluate function before argument *)
  | TmApp (t1, t2) ->
      let t1' = eval1 ctx t1 in
      TmApp (t1', t2)

    (* E-LetV *)
  | TmLetIn (x, v1, t2) when isval v1 ->
      subst ctx x v1 t2

    (* E-Let *)
  | TmLetIn(x, t1, t2) ->
      let t1' = eval1 ctx t1 in
      TmLetIn (x, t1', t2)
    (* E-FixBeta *)
  | TmFix (TmAbs (x, _, t2)) ->
      subst ctx x tm t2
    (* E-Fix *)
  | TmFix t1 ->
      let t1' = eval1 ctx t1 in 
      TmFix t1'
    (* E-Concat *)
  | TmConcat (TmString s1, TmString s2) ->
      TmString (s1 ^ s2)
    (* E-Concat *)
  | TmConcat (TmString s1, t2) ->
      let t2' = eval1 ctx t2 in 
      TmConcat (TmString s1, t2')
    (* E-Concat *)
  | TmConcat (t1, t2) ->
      let t1' = eval1 ctx t1 in 
      TmConcat (t1', t2)

  | _ ->
      raise NoRuleApplies
;;


(* Evaluate until no more terms can be evaluated *)
let rec eval ctx tm d =
  try
    let tm' = eval1 ctx tm in
      if (d) then print_endline ("\t" ^ string_of_term (tm'));
      eval ctx tm' d
  with
    NoRuleApplies -> tm
;;
