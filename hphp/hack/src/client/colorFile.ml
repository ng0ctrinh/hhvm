(**
 * Copyright (c) 2014, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the "hack" directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
 *)

open Utils

module CL = Coverage_level

(*****************************************************************************)
(* Module comparing positions (to sort them later)
 * This assumes that all positions are either nested or disjoint,
 * i.e. there are no partial overlaps... which should be the case for all
 * well-formed ASTs *)
(*****************************************************************************)

module Compare = struct

  let pos pos1 pos2 =
    let char_start1, char_end1 = Pos.info_raw pos1 in
    let char_start2, char_end2 = Pos.info_raw pos2 in
    if char_end1 < char_start2
    then -1
    else if char_end2 < char_start1
    then 1
    (* If one position is nested inside another, put the outer position first *)
    else if char_start1 < char_start2
    then -1
    else compare char_end2 char_end1

end

(*****************************************************************************)
(* Flatten nested positions (intervals).
 * E.g. if A, B, C are colors, we convert [AA[B]A[C]A] to [AA][B][A][C][A]. *)
(*****************************************************************************)

let rec flatten_ acc stack = function
  | [] | [_] as l when Stack.is_empty stack -> l @ acc
  | [] | [_] as l ->
      let elem = Stack.pop stack in
      flatten_ acc stack (elem :: l)
  | (pos1, x as elt1) :: ((pos2, _) :: _ as rl) ->
      let _, char_end1 = Pos.info_raw pos1 in
      let char_start2, _ = Pos.info_raw pos2 in
      if char_end1 <= char_start2
      then (* Intervals are disjoint *)
        if Stack.is_empty stack
        then
          flatten_ (elt1 :: acc) stack rl
        else
          let elem = Stack.pop stack in
          flatten_ (elt1 :: acc) stack (elem :: rl)
      else begin (* interval 2 is nested within interval 1 *)
        (* avoid creating zero-length intervals *)
        if pos1.Pos.pos_end <> pos2.Pos.pos_end
        then
          (let pos1_rest = { pos1 with Pos.pos_start = pos2.Pos.pos_end } in
          Stack.push (pos1_rest, x) stack);
        let pos1_head = { pos1 with Pos.pos_end = pos2.Pos.pos_start } in
        flatten_ ((pos1_head, x) :: acc) stack rl
      end

let flatten xs =
  flatten_ [] (Stack.create ()) xs |> List.rev

(*****************************************************************************)
(* Walks the content of a string and adds colors at the given positions. *)
(*****************************************************************************)

let walk content pos_level_list =
  let result = ref [] in
  let i = ref 0 in
  let add level_opt j =
    if j <= !i then () else
    let size = j - !i in
    result := (level_opt, String.sub content !i size) :: !result;
    i := !i + size
  in
  List.iter begin fun (pos, level) ->
    let char_start, char_end = Pos.info_raw pos in
    add None char_start;
    add (Some level) char_end;
  end pos_level_list;
  add None (String.length content);
  List.rev !result

(*****************************************************************************)
(* The entry point. *)
(*****************************************************************************)

let go str (pos_level_l: (Pos.t * Coverage_level.t) list) =
  let cmp x y = Compare.pos (fst x) (fst y) in
  let pos_level_l = List.sort cmp pos_level_l in
  let pos_level_l = flatten pos_level_l in
  walk str pos_level_l
