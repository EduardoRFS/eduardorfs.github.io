(* used to identify identical types, like type variables, also useful for
   recursive types, even if those are not supported here *)
module Uid : sig
  type t
  val pp : Format.formatter -> t -> unit
  val compare : t -> t -> int
  val next : unit -> t
end = struct
  type t = int
  let pp fmt = Format.fprintf fmt "%d"
  let acc = ref 0
  let compare = compare
  let next () =
    incr acc;
    !acc
end

(* big difference from the level / rank based typer in OCaml or SML,
    this level never decreases as there is no `exit` function provided *)
module Level : sig
  type t
  val pp : Format.formatter -> t -> unit
  val initial : t
  val reset : unit -> unit

  val enter : unit -> unit
  val current : unit -> t

  val set_after : t -> unit
  val after : unit -> t

  val marked : t
end = struct
  type t = int
  let pp fmt = Format.fprintf fmt "%d"
  let initial = 0
  let current = ref initial
  let after = ref initial

  let reset () =
    current := initial;
    after := initial

  let enter () = incr current
  let current () = !current

  let set_after new_after = after := new_after
  let after () = !after

  let marked = -1
end

(* id's are used to distinguish between variables and also to handle
    recursive types

    levels are used to determine if something is quantified, but all types have
    a level, this is similar to OCaml but also easier to reason about some
    optimizations *)
type typ = { id : Uid.t; mutable level : Level.t; mutable desc : desc }

and desc =
  (* can be quantified or not depending on is_quantified typ *)
  | TVar
  (* previously a variable that was unified *)
  | TLink of typ
  | TArrow of (typ * typ)

(*
  a variable is quantified when it's level is smaller than the current level
  this allows to describe free type variables by making so that their level is
  in the last level after the expression.

  so essentially by incrementing the level all variables present in an
  expression can be quantified
*)
let is_quantified typ = typ.level < Level.current ()

type expr =
  | EVar of string
  (*
    we need to know ahead of time what is gonna be the level after typing,
    as all type variables needs to be created on the level
    after the current expression so that inside of this expression the type
    variables introduced by this expressions is not quantified.

    to achieve that all expressions that can create a type variable carry
    the level after typing, this fields can be populated during parsing or
    be provided by the fix_levels helper function

    also unlike OCaml we're doing essentially lambda ranking, which is similar
    to what SML does http://people.cs.uchicago.edu/~gkuan/pubs/ml07-km.pdf
  *)
  | EAbs of string * expr * Level.t ref
  | EApp of expr * expr * Level.t ref
  | ELet of string * expr * expr

(* ast helpers *)
let var name = EVar name
let abs param body = EAbs (param, body, ref Level.initial)
let app funct argument = EApp (funct, argument, ref Level.initial)
let elet name e1 e2 = ELet (name, e1, e2)

let rec fix_levels expr =
  (match expr with
  | EVar _ -> ()
  | EApp (funct, argument, after) ->
      fix_levels funct;
      fix_levels argument;
      after := Level.current ()
  | ELet (_, e1, e2) ->
      fix_levels e1;
      fix_levels e2
  | EAbs (_, body, after) ->
      fix_levels body;
      after := Level.current ());
  Level.enter ()

let rec repr typ =
  match typ.desc with
  | TLink link ->
      let t_repr = repr link in
      typ.desc <- TLink t_repr;
      t_repr
  | _ -> typ

(* debug flags *)
let show_level = ref false
let show_id = ref false

module Uid_map = Map.Make (Uid)
let pp_typ fmt typ =
  let open Format in
  let counter = ref 0 in
  let known = ref Uid_map.empty in
  let rec loop fmt typ =
    let typ = repr typ in
    match typ.desc with
    | TVar ->
        let name =
          match Uid_map.find_opt typ.id !known with
          | Some name -> name
          | None ->
              let name = String.make 1 (Char.chr (Char.code 'a' + !counter)) in
              incr counter;
              known := Uid_map.add typ.id name !known;
              name
        in
        if is_quantified typ then fprintf fmt "'%s" name
        else fprintf fmt "'_%s" name;
        if !show_id then fprintf fmt "[%a]" Uid.pp typ.id;
        if !show_level then fprintf fmt "[%a]" Level.pp typ.level
    | TLink typ -> loop fmt typ
    | TArrow (param, return) ->
        (match (repr param).desc with
        | TArrow _ -> fprintf fmt "(%a)" loop param
        | _ -> fprintf fmt "%a" loop param);
        fprintf fmt " -> %a" loop return
  in
  loop fmt typ

(* new types are not generalized by default so they're always created on
    the after level of the expression that introduced them *)
let new_ty level desc = { id = Uid.next (); level; desc }
let new_var () = new_ty (Level.after ()) TVar
let new_arrow param return =
  let level = min param.level return.level in
  new_ty level (TArrow (param, return))

(* yes, that's how simple it is to generalize all type variables in the
    current region *)
let gen () = Level.enter ()

(*
  because the type of a composite type is always the smallest type present
  in the contained types this will short circuit on composite types that contain
  only free variables
*)
let inst typ =
  let known = ref Uid_map.empty in

  let rec loop typ = if is_quantified typ then loop_desc typ else typ
  and loop_desc typ =
    match typ.desc with
    | TVar -> (
        match Uid_map.find_opt typ.id !known with
        | Some typ -> typ
        | None ->
            let typ' = new_var () in
            known := Uid_map.add typ.id typ' !known;
            typ')
    | TLink typ -> loop typ
    | TArrow (param, return) ->
        let param = loop param in
        let return = loop return in
        new_arrow param return
  in
  loop typ

let set_var typ ~to_ = typ.desc <- TLink to_

let rec update_level level typ =
  (* TODO: could this be delayed to somewhere else? Similar to sound_lazy *)
  match typ.desc with
  | TVar -> if level > typ.level then typ.level <- level
  | TArrow (param, return) ->
      update_level level param;
      update_level level return
  | TLink typ -> update_level level typ

exception Occur of typ
exception Clash of (typ * typ)
let rec unify t1 t2 =
  if t1 == t2 then ()
  else
    let t1 = repr t1 in
    let t2 = repr t2 in
    match (t1, t1.desc, t2, t2.desc) with
    | t1, TVar, t2, TVar ->
        (* bind the lowest-level var *)
        if t1.level > t2.level then set_var t2 ~to_:t1 else set_var t1 ~to_:t2
    | tv, TVar, t', _ | t', _, tv, TVar ->
        update_level tv.level t';
        set_var tv ~to_:t'
    | t1, TArrow (param1, return1), t2, TArrow (param2, return2) ->
        if t1.level = Level.marked then raise (Occur t1);
        if t2.level = Level.marked then raise (Occur t2);

        let max_level = max t1.level t2.level in
        t1.level <- Level.marked;
        t2.level <- Level.marked;
        unify param1 param2;
        unify return1 return2;
        t1.level <- max_level;
        t2.level <- max_level
    | _ -> raise (Clash (t1, t2))

module String_map = Map.Make (String)
exception Unknown_variable of string
let rec typeof context expr =
  let typ =
    match expr with
    | EVar name -> (
        match String_map.find_opt name context with
        | Some typ -> typ
        | None -> raise (Unknown_variable name))
    | EAbs (param, body, after) ->
        Level.set_after !after;

        let param_typ = new_var () in
        let return_typ =
          let context = String_map.add param param_typ context in
          typeof context body
        in
        new_arrow param_typ return_typ
    | EApp (funct, argument, after) ->
        Level.set_after !after;

        let funct_typ = typeof context funct in
        let argument_typ = typeof context argument in
        let return_typ = new_var () in

        (* this should be equivalent to instantiating on EVar the difference
            is that let aliases are not gonna trigger type instantiation
            without a good reason *)
        unify (inst funct_typ) (new_arrow (inst argument_typ) return_typ);

        return_typ
    | ELet (name, e1, e2) ->
        let e1_typ = typeof context e1 in
        let e2_typ =
          let context = String_map.add name e1_typ context in
          typeof context e2
        in
        e2_typ
  in
  (* like a true HM we generalize every expression *)
  gen ();
  typ

let print_typ expr =
  Level.reset ();
  fix_levels expr;
  Level.reset ();
  let typ = typeof String_map.empty expr in
  Format.printf "%a\n%!" pp_typ typ

let id = abs "x" (var "x")
let apply = abs "f" (abs "x" (app (var "f") (var "x")))
let sequence = abs "a" (abs "b" (var "b"))
let fix = abs "f" (app (var "f") (var "f"))

let () =
  (* fun x -> x *)
  print_typ id;
  (* fun f v -> f v *)
  print_typ apply;
  (* fun a b -> b *)
  print_typ sequence;
  (* (fun x -> x) (fun x -> x) *)
  print_typ (app id id);
  (* (fun f v -> f v) (fun x -> x) *)
  print_typ (app apply id);
  (* fun id a b -> sequence (id a) (id b) *)
  print_typ
    (abs "id"
        (abs "a"
          (abs "b"
              (app
                (app sequence (app (var "id") (var "a")))
                (app (var "id") (var "b"))))));
  (* let polymorphism *)
  (* fun a b ->
      let id x = x in
      let _ = id a in
      id b *)
  print_typ
    (abs "a"
        (abs "b"
          (elet "id" id
              (elet "_" (app (var "id") (var "a")) (app (var "id") (var "b"))))));
  (* let id x = x in id *)
  print_typ (elet "id" id (var "id"));
  (* fun a -> let id x = x in id *)
  print_typ (abs "a" (elet "id" id (var "id")));
  (* fun a -> let id x = x in id a *)
  print_typ (abs "a" (elet "id" id (app (var "id") (var "a"))));
  (* fun a -> let b = a in b *)
  print_typ (abs "a" (elet "b" (var "a") (var "b")))
