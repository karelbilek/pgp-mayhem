(***********************************************************************)
(* build.ml - Executable: Builds up the key database from a multi-file *)
(*            database dump.                                           *)
(*            Dump files are taken from the command-line.              *)
(*                                                                     *)
(* Copyright (C) 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009, 2010, *)
(*               2011, 2012, 2013  Yaron Minsky and Contributors       *)
(*                                                                     *)
(* This file is part of SKS.  SKS is free software; you can            *)
(* redistribute it and/or modify it under the terms of the GNU General *)
(* Public License as published by the Free Software Foundation; either *)
(* version 2 of the License, or (at your option) any later version.    *)
(*                                                                     *)
(* This program is distributed in the hope that it will be useful, but *)
(* WITHOUT ANY WARRANTY; without even the implied warranty of          *)
(* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU   *)
(* General Public License for more details.                            *)
(*                                                                     *)
(* You should have received a copy of the GNU General Public License   *)
(* along with this program; if not, write to the Free Software         *)
(* Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 *)
(* USA or see <http://www.gnu.org/licenses/>.                          *)
(***********************************************************************)

module F(M:sig end) = struct
  open StdLabels
  open MoreLabels
  open Printf
  open Arg
  open Common
  module Set = PSet.Set
  open Packet
  
  let n = match !Settings.n with 0 -> 1 | x -> x
  let fnames = !Settings.anonlist

  let sign_to_time sign =
    match ParsePGP.parse_signature sign with
      | V3sig s ->
          Some s.v3s_ctime
      | V4sig s ->
	  let ss = (s.v4s_hashed_subpackets @ s.v4s_unhashed_subpackets) in
	  let ssp = List.hd ss in
	  Some (ParsePGP.int64_of_string ssp.ssp_body)

 
 
  let rec get_keys_rec nextkey partial = match nextkey () with
      Some key ->
        (try
           let ckey = Fixkey.canonicalize key in
           get_keys_rec nextkey (ckey::partial)
         with
             Fixkey.Bad_key -> get_keys_rec nextkey partial
        )
    | None -> partial

  let get_keys nextkey = get_keys_rec nextkey []

  let timestr sec =
    sprintf "%.2f min" (sec /. 60.)

  let rec nsplit n list = match n with
      0 -> ([],list)
    | n -> match list with
          [] -> ([],[])
        | hd::tl ->
            let (beginning,ending) = nsplit (n-1) tl in
            (hd::beginning,ending)

  let rec batch_iter ~f n list =
    match nsplit n list with
        ([],_) -> ()
      | (firstn,rest) -> f firstn; batch_iter ~f n rest

  let get_keys_fname fname start =
    let cin = new Channel.sys_in_channel (open_in fname) in
    protect
      ~f:(fun () ->
            let nextkey = Key.next_of_channel cin in
            get_keys_rec nextkey start
         )
      ~finally:(fun () -> cin#close)

  let get_keys_multi flist =
    List.fold_left ~f:(fun keys fname -> get_keys_fname fname keys)
      flist ~init:[]

  let dbtimer = MTimer.create ()
  let timer = MTimer.create ()

  (***************************************************************)

  let () = Sys.set_signal Sys.sigusr1 Sys.Signal_ignore
  let () = Sys.set_signal Sys.sigusr2 Sys.Signal_ignore


  let maybe_time_str t = 
    match t with Some p -> sprintf "%Lu\n" p
		| None -> "" ;;
	

  let print_time_packet packet = 
     let t = sign_to_time packet in 
     let kk = maybe_time_str t in
     printf "%s" kk  
	
  (***************************************************************)
  let run () =
    set_logfile "build";
        perror "Running SKS %s%s" Common.version Common.version_suffix;


    protect
      ~f:(fun () ->
            batch_iter n fnames
            ~f:(fun fnames ->
                  MTimer.start timer;
                  printf "Loading keys..."; flush stdout;
                  let keys = get_keys_multi fnames in
	          (*Array.iter (fun key -> printf "Key!") keys*)
		  (*sprintf "keke %s" keys;*)
		  List.iter (fun plist -> 
				(printf "L1\n===\n";
				 List. iter( fun packet->
		                           printf "L2\n---\n";
			                   if packet.packet_type = Signature_Packet
					   then print_time_packet packet ;
					   
					   print_packet packet
					  ) plist
				)
			    ) keys;
		  (*print_packet keys;*)
                  printf "done\n"; flush stdout;
                  flush stdout;
               )
         )
      ~finally:(fun () -> printf "wat\n";)

end
