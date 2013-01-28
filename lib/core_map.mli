(** This module defines the [Map] module for [Core.Std].  We use "core_map" as the file
    name rather than "map" to avoid conflicts with OCaml's standard map module.  In this
    documentation, we use [Map] to mean this module, not the OCaml standard one.

    [Map] is a functional datastructure (balanced binary tree) implementing finite maps
    over a totally-ordered domain, called a "key".  The map types and operations appear
    in three places:

    | Map      | polymorphic map operations                                      |
    | Map.Poly | maps that use polymorphic comparison to order keys              |
    | Key.Map  | maps with a fixed key type that use [Key.compare] to order keys |

    One should use [Map] for functions that access existing maps, like [find], [mem],
    [add], [fold], [iter], and [to_alist].  For functions that create maps, like [empty],
    [singleton], and [of_alist], one should strive to use the corresponding [Key.Map]
    function, which will use the comparison function specifically for [Key].  As a last
    resort, if one does not have easy access to a comparison function for the keys in
    one's map, use [Map.Poly] to create the map.  This will use OCaml's built-in
    polymorphic comparison to compare keys, which has all the usual performance and
    robustness problems that entails.

    For the specification of the actual map operations, read Core_map_intf.  The accessor
    functions are defined in [Accessors], and the creation functions are defined in
    [Creators].  The code in this mli instantiates those signatures to specify the
    operations in [Map], [Map.Poly], and [Key.Map].

    Parallel to the three kinds of map modules, there are also tree modules [Map.Tree],
    [Map.Poly.Tree], and [Key.Map.Tree].  A tree is a bare representation of a map,
    without the comparator.  Thus tree operations need to obtain the comparator from
    somewhere.  For [Map.Poly.Tree] and [Key.Map.Tree], the comparator is implicit in the
    module name.  For [Map.Tree], the comparator must be passed to each operation.  The
    main advantages of trees over maps are slightly improved space usage (there is no
    outer container holding the comparator) and the ability to marshal trees, because a
    tree doesn't contain a closure, unlike a map.  The main disadvantages of using trees
    are needing to be more explicit about the comparator, and the possibility of
    accidental use of polymorphic equality on a tree (for which maps dynamically detect
    failure due to the presence of a closure in the data structure).

    For a detailed explanation of the interface design, read on.

    An instance of the map type is determined by the types of the map's keys and values,
    and the comparison function used to order the keys:

    | type ('key, 'value, 'comparator) Map.t

    The 'comparator is a phantom type uniquely identifying the comparison function,
    as generated by [Comparator.Make].

    [Map.Poly] supports arbitrary key and value types, but enforces that the comparison
    function used to order the keys is polymorphic comparison.  [Key.Map] has a fixed key
    type and comparison function, and supports arbitrary values.

    | type ('key, 'value) Map.Poly.t = ('key , 'value, Comparator.Poly.t) Map.t
    | type 'value Key.Map.t          = (Key.t, 'value, Key.comparator   ) Map.t

    The same map operations exist in [Map], [Map.Poly], and [Key.Map], albeit with
    different types.  For example:

    | val Map.length      : (_, _, _) Map.t   -> int
    | val Map.Poly.length : (_, _) Map.Poly.t -> int
    | val Key.Map.length  : _ Key.Map.t       -> int

    Because [Map.Poly.t] and [Key.Map.t] are exposed as instances of the more general
    [Map.t] type, one can use [Map.length] on any map.  The same is true for all of the
    functions that access an existing map, such as [add], [change], [find], [fold],
    [iter], [map], [to_alist], etc.

    Rather than write the type for each accessor functions three times, we define a single
    module type, [Accessors], in core_map_intf.ml, with generic "map" and "key" types, [t]
    and [key], and a generic type specification for each accessor function such that each
    of the three specific types is an instance of the generic type specification.  So,
    [Accessors] defines the generic types with:

    | type ('k, 'v, 'comparator) t   (* generic map type *)
    | type 'k key                    (* generic key type *)

    And, for example, to specify [iter], [Accessors] has the following:

    | val iter : ('k, 'v, _) t -> f:(key:'k key -> data:'v -> unit) -> unit

    In this interface for [Map], we instantiate [Accessors] in three different ways to
    obtain the signatures for [Map], [Map.Poly], and [Key.Map].

    |          | ('k, 'v, 'comparator) t | type 'k key |
    |----------+-------------------------+-------------|
    | Map      | ('k, 'v, 'comparator) t | 'k          |
    | Map.Poly | ('k, 'v) Map.Poly.t     | 'k          |
    | Key.Map  | 'v Key.Map.t            | Key.t       |

    For [iter], one can check that this gives the following types:

    | val Map.iter      : ('k, 'v, _) t         -> f:(key:'k    -> data:'v -> unit) -> unit
    | val Map.Poly.iter : ('k, 'v) Map.Poly.t   -> f:(key:'k    -> data:'v -> unit) -> unit
    | val Key.Map.iter  : ('k, 'v, _) Key.Map.t -> f:(key:Key.t -> data:'v -> unit) -> unit

    Technically, the instantiation of [Accessors] is done using the [with type ... := ...]
    syntax.  For example, here is the essence of how the accessors for [Key.Map] are
    specified, a fragment of the [S] signature defined in core_map_intf.ml:

    | module type S = sig
    |   module Key : Comparator.S
    |   type +'v t
    |   type ('k, 'v, 'comparator) t_ = 'v t
    |   type 'a key_ = Key.t
    |   include Accessors
    |     with type ('a, 'b, 'c) t := ('a, 'b, 'c) t_
    |     with type 'a key := 'a key_
    | end

    The syntax is unfortunately unnecessarily verbose, because OCaml doesn't allow the
    use of a type expression on the right-hand-side of a [:=].  So, we first define
    single-use types [t_] and [key_] to be equal to what we would like to write on
    the right-hand-side of the [:=].  We then instantiate [Accessors] with the single-use
    types.

    We use the same approach for functions that create maps, like [empty], [singleton],
    and [of_alist].  In core_map_intf.ml, we define a generic [Creators] signature,
    and instantiate it three times here.  There is one additional twist with [Creators].
    For [Map.Poly] and [Key.Map], the comparison function to order keys in the map is
    clear from the module being used: polymorphic comparison for [Map.Poly] and
    [Key.compare] for [Key.Map].  However, for [Map], there is no unambiguous comparison
    function.  So, the creation functions in [Map] require one to be passed in.  In order
    to make all three creation functions instances of the same generic type, [Creators]
    uses a generic [options] type to factor out the difference.  So, in [Creators]
    we have

    | type ('k, 'v, 'comparator) t
    | type 'k key
    | type ('a, 'comparator, 'z) options
    | val of_alist
    |   : ('k,
    |      'comparator,
    |      ('k key * 'v) list -> [ `Ok of ('k, 'v, 'comparator) t
    |                            | `Duplicate_key of 'k key
    |                            ]
    |     ) options

    And then in [Map.Poly] and [Key.Map] we instantiate [options] with
    [without_comparator], while in [Map] we instantiate it with [with_comparator], which
    are defined as:

    | type ('a, 'comparator, 'z) without_comparator = 'z
    |
    | type ('a, 'comparator, 'z) with_comparator =
    |   comparator:('a, 'comparator) Comparator.t -> 'z

    For example, this makes the type of the three [of_alist] functions as follows:

    | val Map.of_alist
    |   :  comparator:('a, 'comparator) Comparator.t
    |   -> ('k * 'v) list
    |   -> [ `Ok of ('k, 'v, 'comparator) Map.t | `Duplicate_key of 'k ]
    |
    | val Map.Poly.of_alist
    |   :  ('k * 'v) list
    |   -> [ `Ok of ('k, 'v) Map.Poly.t         | `Duplicate_key of 'k ]
    |
    | val Key.Map.of_alist
    |   :  (Key.t * 'v) list
    |   -> [ `Ok of 'v Key.Map.t                | `Duplicate_key of Key.t ]
*)

open Core_map_intf

type ('key, +'value, 'comparator) t
type ('a, 'b, 'c) t_ = ('a, 'b, 'c) t
type ('key, +'value, 'comparator) tree
type 'a key = 'a
type ('a, 'b, 'c) options = ('a, 'b, 'c) with_comparator

include Creators
  with type ('a, 'b, 'c) t    := ('a, 'b, 'c) t
  with type ('a, 'b, 'c) tree := ('a, 'b, 'c) tree
  with type 'a key := 'a key
  with type ('a, 'b, 'c) options := ('a, 'b, 'c) with_comparator

include Accessors
  with type ('a, 'b, 'c) t    := ('a, 'b, 'c) t
  with type ('a, 'b, 'c) tree := ('a, 'b, 'c) tree
  with type 'a key := 'a key
  with type ('a, 'b, 'c) options := ('a, 'b, 'c) without_comparator

val comparator : ('a, _, 'comparator) t -> ('a, 'comparator) Comparator.t

module Poly : sig
  type ('a, 'b, 'c) map = ('a, 'b, 'c) t
  type ('a, +'b, 'c) tree
  type ('a, 'b) t = ('a, 'b, Comparator.Poly.comparator) map with bin_io, sexp, compare
  type ('a, 'b, 'c) t_ = ('a, 'b) t
  type 'a key = 'a
  type ('a, 'b, 'c) options = ('a, 'b, 'c) without_comparator

  include Creators_and_accessors
    with type ('a, 'b, 'c) t := ('a, 'b, 'c) t_
    with type ('a, 'b, 'c) tree := ('a, 'b, 'c) tree
    with type 'a key := 'a key
    with type ('a, 'b, 'c) options := ('a, 'b, 'c) without_comparator

  (* [empty] has the same spec in [Creators], but adding it here prevents a type-checker
     issue with nongeneralizable type variables. *)
  val empty : (_, _) t

  module Tree : sig
    type ('k, +'v) t = ('k, 'v, Comparator.Poly.comparator) tree with sexp

    include Creators_and_accessors
      with type ('a, 'b, 'c) t := ('a, 'b, 'c) tree
      with type ('a, 'b, 'c) tree := ('a, 'b, 'c) tree
      with type 'a key := 'a key
      with type ('a, 'b, 'c) options := ('a, 'b, 'c) without_comparator
  end
end
  with type ('a, 'b, 'c) tree = ('a, 'b, 'c) tree

module type Key = Key

module type Key_binable = Key_binable

module type S = S
  with type ('a, 'b, 'c) map  = ('a, 'b, 'c) t
  with type ('a, 'b, 'c) tree = ('a, 'b, 'c) tree

module type S_binable = S_binable
  with type ('a, 'b, 'c) map  = ('a, 'b, 'c) t
  with type ('a, 'b, 'c) tree = ('a, 'b, 'c) tree

module Make (Key : Key) : S with type Key.t = Key.t

module Make_using_comparator (Key : Comparator.S)
  : S with type Key.t = Key.t
      with type Key.comparator = Key.comparator

module Make_binable (Key : Key_binable) : S_binable with type Key.t = Key.t

module Make_binable_using_comparator (Key : Comparator.S_binable)
  : S_binable
      with type Key.t = Key.t
      with type Key.comparator = Key.comparator

module Tree : sig
  type ('k, 'v, 'comparator) t = ('k, 'v, 'comparator) tree with sexp_of

  include Creators_and_accessors
    with type ('a, 'b, 'c) t := ('a, 'b, 'c) t
    with type ('a, 'b, 'c) tree := ('a, 'b, 'c) tree
    with type 'a key := 'a key
    with type ('a, 'b, 'c) options := ('a, 'b, 'c) with_comparator
end
