require! {
  minimatch:{Minimatch}
}

is-array = (instanceof Array)

convert-to-keys = do ->
  to-camel-case = ->
    [head, ...rest] = it / /-|_/
    ([head] ++ rest.map (.replace /^./, (.to-upper-case!))) * ''

  (key,joiner,ch = '.')->
    [...keys,leaf] = key.split ch .map to-camel-case
    [(keys.join joiner), leaf]

flatten = (array)->
  if is-array array
    while array.some is-array
      array .= reduce (++), []
  array

clone-regex = ->
  new RegExp it.source, (* '') do
    for name, flag of it{global,ignore-case,multiline}
      flag and (name.char-at 0) or ''

options-source = require "./option-list" .options

class ParseHelper
  (@option-map)->
    @parsed     = {}
    @unknown    = {}

  set: (out,full-key,value)->
    [base,key] = convert-to-keys full-key, '.', '.'

    # depth = 0
    out = out[base or key] ?= []

    # depth = 1
    if base
      value := (key):value
      for {(key):it} in out | not it?
        it <<< value
        return

    out.push value

  prepare: (@target,@key,@value=true)->
    if @option-map[@target]?.[@key]?.type is \boolean
      @push!

  push: (value=@value)->
    switch
    | @value? => @put @target, @key, value
    | value?  => @set @unknown, "rest", value
    @value = null

  put: (target,key,value) ->
    if @option-map[target]?.[key]?
      @set @parsed, that.label, value
    else
      @set (@unknown[target] ?= {}), key, value

class OptionHelper
  @setup = (options)->
    options = {} <<< options
    option-helper = new OptionHelper

    get-root-def = (pname,name,alter=name)->
      (options,def-map)->
        | options[pname]?.[name]?   => that
        | options[pname]?.0?.[name] => that
        | options[name]? => that
        | _ => def-map[alter]

    defaults = {}
    defaults-src =
      mount:  <[ watch recursive followSymlinks ignoreCase ]>
      inject: <[ where which type ]>

    for key,names of defaults-src
      base = (defaults[key] ?= {})
      for def in names
        base[def] = get-root-def key, def

    options = option-helper.assure options, defaults
    base = {}
    try
      pre-file = file = null
      dir = process.cwd!
      do
        pre-file = file
        file     = path.resolve dir, @options.config
        try
          content  = fs.read-file-sync file, {encoding:'UTF-8'}
          json     = JSON.parse content.to-string!
        catch e
          "ignored"

        dir = path.join dir, ".."
      while (not json?) and (pre-file isnt file)

      base := json ? {}
    catch e
      "ignored"

    out = option-helper.assure (base <<<< options), defaults

    # check onmessage
    if out.onmessage not instanceof Function
      out.onmessage = (->)

    out

  @parse = (-> new OptionHelper it .parse!)

  @read-pattern = (pattern,nocase)-> switch typeof! pattern
    | \Array    => (pattern.map &callee _, nocase)~every . (|>)
    | \String   => (new Minimatch pattern, {nocase})~match
    | \RegExp   => (clone-regex pattern)~test
    | \Function => pattern
    | _         => ->pattern

  (@option-list=options-source,@defaults={})->
    # defaults: (options, option-map)-> option

    @option-map = {}
    for option-entry in @option-list
      for key, value of option-entry
        (@option-map[key] ?= {})[value] = option-entry

  parse: (argv=process.argv.slice 2)->
    ope = new ParseHelper @option-map

    # parse
    for arg in argv
      [matched,is-full-option,,negate,key,has-value,value] =
          arg is /^-(-)?((no-|without-)?([^=]+))(=(.+))?/ ? []

      if not matched
        ope.push arg
        continue

      ope.push!

      target = "label"
      if is-full-option
        if not has-value
          value := not negate
      else
        target := "short"
        [...skeys,key] = key / ''
        skeys.for-each (ope.put target, _, true)

      ope.prepare target,key,value

    ope.push!

    let @ = ope.unknown
      @full = @label
      delete @label

    ope{parsed,unknown}

  default-option: (option,key,entry,defaults,options)->
    value = | option?.[key]?   => that
            | defaults?.[key]? => that options, @option-map
            | entry?.def?      => that
            | _ => null

    option[key] = switch entry.type
    | \pattern => @@@read-pattern value
    | \number  => (is-array value and value.pop! or value) * 1
    | _        => value

  assure: (options,defaults=@defaults)->
    options = {} <<< options
    nodes   = {}

    # pass 1
    for {label}:entry in @option-list
      [base,key] = convert-to-keys label, '', '.'

      if not base
        let it = options[key]
          is-array it and options[key] = it[* - 1]
        @default-option options, key, entry, defaults[key]?, options
        continue

      primary = not nodes[base]?
      (nodes[base] ?= {}) .(key) = entry

      if not primary
        continue

      # primary entry
      options[base] = flatten . (? options[base]) <| (obj)->
        | typeof obj is 'string' => [ (key):obj ]
        | not obj?          => []
        | is-array obj      => obj.map &callee
        | is-array obj[key] => obj[key].map (->obj with (key):it)
        | obj[leaf]?        => [obj]
        | _                 => []

    # pass 2
    for base, node of nodes
     for name, entry of node
      for option in options[base]
       @default-option option, name, entry, defaults[base]?, options

    options

export
  OptionHelper
