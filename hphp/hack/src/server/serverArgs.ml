(**
 * Copyright (c) 2014, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the "hack" directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
 *)

(*****************************************************************************)
(* File parsing the arguments on the command line *)
(*****************************************************************************)

(*****************************************************************************)
(* The options from the command line *)
(*****************************************************************************)

type options = {
    check_mode       : bool;
    json_mode        : bool;
    root             : Path.path;
    should_detach    : bool;
    convert          : Path.path option;
    load_save_opt    : env_store_action option;
  }

and env_store_action =
  | Load of string
  | Save of string

(*****************************************************************************)
(* Usage code *)
(*****************************************************************************)
let usage = Printf.sprintf "Usage: %s [WWW DIRECTORY]\n" Sys.argv.(0)

let print_usage_and_exit () =
  Printf.fprintf stderr "%s" usage;
  exit 1

(*****************************************************************************)
(* Options *)
(*****************************************************************************)

module Messages = struct
  let debug         = " debugging mode"
  let check         = " check and exit"
  let json          = " output errors in json format (arc lint mode)"
  let daemon        = " detach process"
  let from_vim      = " passed from hh_client"
  let from_emacs    = " passed from hh_client"
  let from_hhclient = " passed from hh_client"
  let convert       = " adds type annotations automatically"
  let load          = " load server state from file"
  let save          = " save server state to file"
end


(*****************************************************************************)
(* CAREFUL!!!!!!! *)
(*****************************************************************************)
(* --json is used for the linters. External tools are relying on the
   format -- don't change it in an incompatible way!
*)
(*****************************************************************************)

let arg x = Arg.Unit (fun () -> x := true)

let populate_options () =
  let root          = ref "" in
  let from_vim      = ref false in
  let from_emacs    = ref false in
  let from_hhclient = ref false in
  let debug         = ref false in
  let check_mode    = ref false in
  let json_mode     = ref false in
  let should_detach = ref false in
  let convert_dir   = ref None  in
  let load_save_opt = ref None  in
  let cdir          = fun s -> convert_dir := Some s in
  let load          = fun s -> load_save_opt := Some (Load s) in
  let save          = fun s -> load_save_opt := Some (Save s) in
  let options =
    ["--debug"         , arg debug         , Messages.debug;
     "--check"         , arg check_mode    , Messages.check;
     "--json"          , arg json_mode     , Messages.json; (* CAREFUL!!! *)
     "--daemon"        , arg should_detach , Messages.daemon;
     "-d"              , arg should_detach , Messages.daemon;
     "--from-vim"      , arg from_vim      , Messages.from_vim;
     "--from-emacs"    , arg from_emacs    , Messages.from_emacs;
     "--from-hhclient" , arg from_hhclient , Messages.from_hhclient;
     "--convert"       , Arg.String cdir   , Messages.convert;
     "--load"          , Arg.String load   , Messages.load;
     "--save"          , Arg.String save   , Messages.save;
   ] in
  let options = Arg.align options in
  Arg.parse options (fun s -> root := s) usage;
  (* json implies check *)
  let check_mode = !check_mode || !json_mode; in
  (* Conversion mode implies check *)
  let check_mode = check_mode || !convert_dir <> None in
  let convert = Utils.opt_map Path.mk_path (!convert_dir) in
  (match !root with
  | "" ->
      Printf.fprintf stderr "You must specify a root directory!\n";
      exit 2
  | _ -> ());
  { json_mode     = !json_mode;
    check_mode    = check_mode;
    root          = Path.mk_path !root;
    should_detach = !should_detach;
    convert       = convert;
    load_save_opt = !load_save_opt;
  }

(* useful in testing code *)
let default_options ~root =
{
  check_mode = false;
  json_mode = false;
  root = Path.mk_path root;
  should_detach = false;
  convert = None;
  load_save_opt = None;
}

(*****************************************************************************)
(* Code checking that the options passed are correct.
 * Pretty minimalistic for now.
 *)
(*****************************************************************************)

let check_options options =
  let root = options.root in
  Wwwroot.assert_www_directory root;
  ()

(*****************************************************************************)
(* The main entry point *)
(*****************************************************************************)

let parse_options () =
  let options = populate_options () in
  check_options options;
  options

(*****************************************************************************)
(* Accessors *)
(*****************************************************************************)

let check_mode options = options.check_mode
let json_mode options = options.json_mode
let root options = options.root
let should_detach options = options.should_detach
let convert options = options.convert
let load_save_opt options = options.load_save_opt
