open Postgresql
open Parser
open Util

open Report
open Report_model

module Db = Db_pg
module T = Templating.Templating

open Printf

let parse_channel ch =
  let lex = Message.lexer_from_channel "stdin" ch
  in let ast = Parser.toplevel Lexer.token lex
  in ast

let list_of_ds report ds =
    let hdr = (column_headers report)
    in List.map ( fun x -> List.map2 (fun (a,_) v -> (a,v)) hdr x) ds

let dump_output report out = 
    match report.output with
    | STDOUT    -> failwith "DUMP TO STDOUT"
    | FILE(s)   -> failwith "DUMP TO FILE"
    | TEMP_FILE -> failwith "DUMP TO TEMP_FILE"

let () =
    let report = parse_channel (Pervasives.stdin)
    
(*    in let _ = List.iter (fun (a, DS_TABLE(n)) -> Printf.printf "%s %s\n" a n) report.datasources*)
(*    in let _ = List.iter (fun (a, b) -> Printf.printf "%s %s\n" a b) report.connections*)
(*    in let _ = List.iter (fun a -> Printf.printf "%s\n" a) report.template_dirs*)

    in let sql = sql_of report
(*    in let _ = print_endline sql*)

    in let tmp_file =  Filename.temp_file "repogen" "template"

    in let _ = Printf.printf "TEMP %s\n" tmp_file

    in let cache = T.cache ()

    in 
        try
            let data = Db.with_connection (fun conn -> Db.select_all conn sql (fun ds -> list_of_ds report ds))
                                                                              (connection_of report)
            in let model = Model.make (column_headers report) data [("SQL", sql)]

            in match report.template with 
               | Some(s) ->
                   let tmpl  = T.from_file cache s
                   in dump_output report (T.render_string tmpl model) 
               | None -> ()
            
        with Error e -> prerr_endline (string_of_error e)
             | e     -> prerr_endline (Printexc.to_string e)

