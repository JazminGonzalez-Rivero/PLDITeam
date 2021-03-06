(* 
 *   Evaluator for final project. To make the evaluator homework 4 was combined with code from lecture 10. 
 *)


structure Evaluator = struct

  structure I = InternalRepresentation



  exception Evaluation of string

  fun evalError msg = raise Evaluation msg

 (*Type Checking Function Used for Debugging*)   
  fun checkType (I.VCons k) = "cons"
    | checkType (I.VList k) = "list"
    | checkType (I.VInt k) = "int"
    | checkType (I.VBool k) =  "bool"
    | checkType (I.VClosure k) =  "Closure"
    | checkType (I.VRecClosure k) = "RecClosure"
    | checkType (I.VRecord k) = "record"
    | checkType (I.VNil) = "nil"
    | checkType (I.VDelayed k) = "delay"

       
 fun lookup (name:string) [] = evalError ("There is no function called "^name^", please check your spelling or your inputs")
    | lookup name ((n,v)::env) = 
        if (n = name) then 
    v
  else lookup name env


  (*
   *   Evaluation functions
   * 
   *)

  fun delay env e = I.VDelayed (ref (I.DelExpr (e,env)))

  fun eval _ (I.EVal v) = v
    | eval env (I.EFun (n,e)) = I.VClosure (n,e,env)
    | eval env (I.EIf (e,f,g)) = evalIf env (feval env e) f g
    | eval env (I.ELet (name,e,f)) = evalLet env name (delay env e) f
    | eval env (I.ELetFun (name,param,e,f)) = evalLetFun env name param e f
    | eval env (I.EIdent n) = lookup n env
    | eval env (I.EApp (e1,e2)) = evalApp env (feval env e1) (delay env e2)
    | eval env (I.EPrimCall1 (f,e1)) = f (delay env e1)
    | eval env (I.EPrimCall2 (f,e1,e2)) = 
            f (delay env e1) (delay env e2)
    | eval env (I.ERecord fs) = I.VRecord (map (fn (s, e) => (s, eval env e)) fs)
    | eval env (I.EField (e,s)) = (lookup s (case (eval env e) of (I.VRecord e) => e
                                              | _ => evalError "There is no record"))
    
  and feval env e = force (eval env e)    

  and evalApp _ (I.VClosure (n,body,env)) v = eval ((n,v)::env) body
    | evalApp _ (I.VRecClosure (f,n,body,env)) v = let
    val new_env = [(f,I.VRecClosure (f,n,body,env)),(n,v)]@env
      in 
    eval new_env body
      end
    | evalApp _ a b = evalError ("Cannot apply "^(I.stringOfValue a)^" to "^(I.stringOfValue (force b)))

  and evalIf env (I.VBool true) f g = eval env f
    | evalIf env (I.VBool false) f g = eval env g
    | evalIf _ _ _ _ = evalError "Error at evaluating if statement - input is not a boolean"
                       
  and evalLet env id v body = eval ((id,v)::env) body

  and evalLetFun env id param expr body = let
      val f = I.VRecClosure (id, param, expr, env)
  in
      eval ((id,f)::env) body
  end

  and force (I.VDelayed r) = 
      (case !r 
  of I.DelExpr (e,env) => let
       val v = force (eval env e)
     in
       r := I.DelVal v;
       v
     end
   | I.DelVal v => v)
    | force v = v


  (* 
   *   Primitive operations
   *)

(*Prim Cons was changed so that cons 1 2 = [1,2] rather then [1]*)
  fun primCons v1 v2 = 
        let 
            fun primCons' v1 v2 =
                                (if checkType v2 = "list" then
                                  (I.VCons (v1,v2))
                                else 
                                  (if checkType v2 = "cons" then 
                                      (I.VCons (v1,v2)) 
                                    else 
                                      (if  checkType v2 = "nil" then
                                          (I.VCons (v1,v2))
                                        else 
                                          (I.VCons (v1, (I.VCons (v2,I.VNil)))))))
        in
            primCons' (force v1) (force v2)
        end
    
    (*Changed primHd so that it works with Lists and Cons*)
  fun primHd v1 = let
    fun primHd' (I.VCons (v1,v2)) = v1
      | primHd' I.VNil = evalError "empty at PrimHd"
      | primHd' (I.VList []) = I.VNil 
      | primHd' (I.VList (x::xs)) = x
      | primHd' a = evalError "Not a list - head"
  in
    primHd' (force v1)
  end

(*Changed primTl so that it works with Lists and Cons*)
  fun primTl v1 = let
    fun primTl' (I.VCons (v1,v2)) = v2
      | primTl' I.VNil = I.VNil
      | primTl' (I.VList []) = I.VNil
      | primTl' _ = evalError "Not a list - tail"
  in
     primTl' (force v1)
  end

  fun primIntHelp (I.VList ks) (I.VInt j) (I.VInt newI) = if ((newI - 1) = j ) then (I.VList ks) else (primIntHelp (primCons (I.VInt j) (I.VList ks)) (I.VInt (j-1)) (I.VInt (newI)))
    | primIntHelp (I.VCons ks) (I.VInt j) (I.VInt newI) = if ((newI - 1) = j ) then (I.VCons ks) else (primIntHelp (primCons (I.VInt j) (I.VCons ks)) (I.VInt (j-1)) (I.VInt (newI)))
    | primIntHelp ks _ _= evalError ("Error in interval function "^(I.stringOfValue (ks)))

  and primInterval v1 v2 = let
      fun primInterval' (I.VInt i) (I.VInt j) = if (j < i ) then I.VNil else (primIntHelp (I.VList []) (I.VInt j) (I.VInt i))
      | primInterval' _ _ = evalError "Error in interval function"    
    in 
      primInterval' (force v1) (force v2)
    end

(*Changed primPlus so that it can add an empty value with an int.
    Needed for let fun *)
  fun primPlus v1 v2 = let
    fun primPlus' (I.VInt a) (I.VInt b) = I.VInt (a+b)
      | primPlus' I.VNil (I.VInt b) = I.VInt(b)
      | primPlus' (I.VInt a) I.VNil = I.VInt(a)
      | primPlus' a b = evalError "Addition is not possible"
  in
    primPlus' (force v1) (force v2)
  end

(*Changed primMinus so that it can add an empty value with an int.
    Needed for let fun *)
  fun primMinus v1 v2 = let
    fun primMinus' (I.VInt a) (I.VInt b) = I.VInt (a-b)
      | primMinus' I.VNil (I.VInt b) = I.VInt(b)
      | primMinus' (I.VInt a) I.VNil = I.VInt(a)
      | primMinus' _ _ = evalError "Subtraction is not possible"
  in
    primMinus' (force v1) (force v2)
  end

  fun primMod v1 v2 = let
    fun primMod' (I.VInt a) (I.VInt b) = I.VInt (a mod b)
      | primMod' _ _ = evalError "Mod is not possible"
  in
    primMod' (force v1) (force v2)
  end


  fun primEqHelper (I.VList []) (I.VList []) =  true
     | primEqHelper I.VNil I.VNil = true
     | primEqHelper (I.VCons (x,xs)) (I.VNil) = false
     | primEqHelper (I.VNil) (I.VCons (x,xs)) = false
     | primEqHelper (I.VCons(x,xs)) (I.VCons (y,ys)) = 
    (case (primEq x y) 
        of (I.VBool false) => false 
        | (I.VBool true) => (primEqHelper xs ys)
        | _ => evalError "This error should not happen. Start over")
     | primEqHelper _ _ = evalError "You are comparing apples to tofu"


  and primEq v1 v2 = let
    fun primEq' (I.VInt a) (I.VInt b) = I.VBool (a=b)
      | primEq' (I.VBool a) (I.VBool b) = I.VBool (a=b)
      | primEq' (I.VNil) (I.VNil) = I.VBool true
      | primEq' (I.VList []) (I.VList []) = I.VBool true
      | primEq' (I.VCons xs) (I.VCons ys) = I.VBool (primEqHelper (I.VCons xs) (I.VCons ys))
      | primEq' xs ys = I.VBool false
  in
    primEq' (force v1) (force v2)
  end
    
  fun primLess v1 v2 = let
    fun primLess' (I.VInt a) (I.VInt b) = I.VBool (a<b)
      | primLess' _ _ = I.VBool false
  in
    primLess' (force v1) (force v2)
  end

(*CHanged Map and Filter to play nice with delay and cons*)
  fun initMap v1 v2 = let 
        fun initMap' (I.VClosure (n,e,env)) (I.VCons (I.VNil,I.VNil)) = I.VCons (I.VNil,I.VNil)
          | initMap' (I.VClosure (n,e,env)) (I.VList a) = I.VNil
          | initMap' (I.VClosure (n,e,env)) I.VNil = I.VNil
          | initMap' (I.VClosure (n,e,env)) (I.VCons (first,tail)) = let
                                                           val entryVal = (eval env (I.EApp (I.EFun (n,e),I.EVal first)))
                                                         in
                                                            if (checkType first) = "nil" 
                                                            then 
                                                               (eval env (I.EApp (I.EFun (n,e),I.EVal first)))
                                                            else     
                                                                I.VCons (entryVal,(initMap' (I.VClosure (n,e,env)) tail))
                                                         end
          | initMap' _ _ = evalError "Error at map - input is not a mapping function"
        in
          initMap' (force v1) (force v2)
        end


fun initFilter v1 v2 = let
    fun initFilter' (I.VClosure (n,e,env)) (I.VCons (I.VNil,I.VNil)) = I.VCons (I.VNil,I.VNil)
      | initFilter' (I.VClosure (n,e,env)) (I.VList a) = I.VNil
      | initFilter' (I.VClosure (n,e,env)) (I.VCons (first,tail)) = let
                                                                val xApp = (primEq (eval env (I.EApp (I.EFun (n,e),I.EVal first))) (I.VBool true))
                                                                fun checkEq (I.VBool first) = first
                                                                  | checkEq _ = evalError "Error at filter list - input is not a filter function"
                                                              in

                                                                if (checkEq xApp)
                                                                  then I.VCons (first,(initFilter' (I.VClosure (n,e,env)) tail))
                                                                else initFilter' (I.VClosure (n,e,env)) tail
                                                              end
      | initFilter' _ _ =  evalError "initFilter"
    in 
      initFilter' (force v1) (force v2)
    end
  
  val initialEnv = 
      [("add", I.VClosure ("a", 
			   I.EFun ("b", 
				   I.EPrimCall2 (primPlus,
						 I.EIdent "a",
						 I.EIdent "b")),
			   [])),
       ("sub", I.VClosure ("a", 
			   I.EFun ("b", 
				   I.EPrimCall2 (primMinus,
						 I.EIdent "a",
						 I.EIdent "b")),
			   [])),
        ("interval", I.VClosure ("a", 
                           I.EFun ("b", 
                                   I.EPrimCall2 (primInterval,
                                                 I.EIdent "a",
                                                 I.EIdent "b")),
                           [])),
       ("hd", I.VClosure ("a", 
                                I.EPrimCall1 (primHd,
                                        I.EIdent "a"),
                           [])),
        ("tl", I.VClosure ("a", 
                                I.EPrimCall1 (primTl,
                                        I.EIdent "a"),
                           [])),
       ("cons", I.VClosure ("a", 
                           I.EFun ("b", 
                                   I.EPrimCall2 (primCons,
                                                 I.EIdent "a",
                                                 I.EIdent "b")),
                           [])),
       ("nil", I.VNil),
       ("map", I.VClosure ("f", I.EFun("xs",
                                  I.EPrimCall2 (initMap,
                                                I.EIdent "f",
                                                I.EIdent "xs")),
                          [])),
       ("filter", I.VClosure ("p", I.EFun("xs",
                                  I.EPrimCall2 (initFilter,
                                                I.EIdent "p",
                                                I.EIdent "xs")),
                          [])),
       ("equal", I.VClosure ("a",
			  I.EFun ("b",
				  I.EPrimCall2 (primEq,
						I.EIdent "a",
						I.EIdent "b")),
			  [])),
       ("less", I.VClosure ("a",
			    I.EFun ("b",
				    I.EPrimCall2 (primLess,
						  I.EIdent "a",
						  I.EIdent "b")),
			    []))]
  
				 
end
