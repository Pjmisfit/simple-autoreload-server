
require! {path,fs}

# Utils

flatten = ([...array])->
  array.reduce ((p,n)->
    p ++ ((typeof! n is \Array and flatten n) or [n])
  ), []

regex-clone = (r)->
  flags = for k,v of r{global,multiline,ignore-case}
    v and k.char-at 0 or ''
  new RegExp r.source, flags * ''

deep-copy = (src={},out={})->
  for k,v of src
    out[k] = match typeof v
    | _       => v
    | /^obj/g => match typeof! v
      | _       => &callee v, (&callee out[k])
      | \RegExp => regex-clone v
  out

new-copy = (src={},out={})->
  deep-copy src, deep-copy out

get-logger = (log-prefix)->
  (...texts)-> console.log do
    ([log-prefix!] ++ (flatten texts)) * ' '

visit-dir = (dirpath,file-filter=((file,stat)->true),stat)->
  self =  &callee
  try
    stat ?= fs.lstat-sync dirpath

    unless stat .is-directory! and file-filter dirpath, stat
      return dirpath

    fs.readdir-sync dirpath
    .map ->
      P = path.join dirpath, it
      file: P
      stat: fs.lstat-sync P

    .filter ->
      file-filter it.file, it.stat

    .map ->
      self it.file, file-filter, it.stat

    |> ([dirpath] ++)

  catch
    return dirpath

#
# Connect Middle-ware API
#   Ref: https://gist.github.com/danielbeardsley/1041099
#
# notes: [...x] clones it using slice() internaly
create-connect-stack = ([...middle-wares])->
  (req,res,next)->
    mw = middle-wares.slice!~shift
    do (err)->
      | err => next err
      | mw! => that req, res, &callee
      | _   => next!

load = (base,file,enc='UTF-8')->
  p = path.resolve base, file
  fs.read-file-sync p, enc

export {
  flatten, regex-clone, deep-copy, new-copy,
  get-logger,
  load, visit-dir,
  create-connect-stack
}
