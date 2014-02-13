
require! {
  connect
  colors
  WebSocket: \faye-websocket
  http
  \este-watch
  path
  static-transform: \connect-static-transform
  \./utils
  def-options: \./default-options
}

# utils
{flatten,regex-clone,new-copy,get-logger,create-connect-stack} = utils

module.exports = (options)->
  ars-obj = new SimpleAutoreloadServer options
    ..init!
    ..start!

# Main class
class SimpleAutoreloadServer
  (options={})->
    @living-sockets = []
    @normal-log = get-logger @~log-prefix
    @verb-log   = (->)
    @set-options options

  set-options: (options-arg={})->
    options = new-copy options-arg, def-options

    # check onmessage
    if \function isnt typeof options.onmessage
      options.onmessage = (->)

    # set logger state
    if options.verbose
      @verb-log = (tag,...texts)~>
        @normal-log.apply @, ( [tag.to-string!green] ++ texts )

      connect.logger.token \prefix, ~>
        @log-prefix! + " httpd".green

    @options = options

  log-prefix: ->
    pid  = process.pid
    root = @options.root
    port = @options.port
    "[autoreload \##pid @#root :#port]".cyan

  stop: ->
    @watcher?.dispose!
    @server?.close!

    @normal-log "Server stopped."

  start: ->
    @watcher.start!
    @server
      ..listen @options.port
      ..add-listener \upgrade, @create-upgrade-listerner!

    root-path = @options.root.to-string!green
    port      = @options.port.to-string!green

    @normal-log "Server started on :#port at #root-path"

  init: ->
    @watcher = @create-watcher!
    @server  = @create-server!

  create-upgrade-listerner: ->
    return (req, sock, head)~>
      return unless WebSocket.isWebSocket req

      addr = "#{sock.remote-address}:#{sock.remote-port}"
      verb-log-ws = (~>@verb-log \websocket, addr, "-", it)

      websock = new WebSocket req, sock, head

      websock
      .on \open, ~>
        verb-log-ws "new connection"
        websock.send JSON.stringify {type:\open, -client}

      .on \message, ({data})~>
        verb-log-ws "received message", data
        @options.onmessage data, websock

      .on \close, ~>
        verb-log-ws "connection closed"
        @living-sockets .= filter (isnt websock)
      |> @living-sockets.push

  # Create este-watch
  create-watcher: ->
    root     = @options.root
    abs-root = path.resolve @options.root
    self     = this

    do-reload = @@@create-reload-matcher @options.force-reload

    # Watch
    este-obj = este-watch [abs-root], (ev)->
      return unless flatten [ self.options.watch ] .some ->
        typeof! it is \RegExp and it.test ev.filepath

      self.verb-log "watch", "event on", ev.filepath

      file-path = (do
        try
          http-file-path = path.relative root, ev.filepath

          # returning '' if it is out of root-dir
          http-file-path isnt /^\// and "/#http-file-path" or ''
        catch
           ''
      )

      self.broadcast do
        type:\update
        path:file-path
        force-reload: do-reload file-path

    # fix Este to catch the error
    dir-change = este-obj.on-dir-change
    este-obj
      ..on-dir-change = ->
        try
          # call original function
          dir-change.apply @, &
        catch e
          self.normal-log 'Exception'.red, e

    este-obj

  # Creating httpd-server
  create-server: ->
    root = path.resolve @options.root

    server =
      # head of middleware conf
      * null

      # logger 
        @options.verbose and connect.logger ([
            ":prefix :remote-addr :method"
            '":url HTTP/:http-version"'
            ":status :referrer :user-agent"
        ] * ' ')


      # script injectors (array)
        @@create-strans root, @options.inject

      # static server
        @options.list-directory and
          connect.directory root, icons:true

        connect.static root

      # process array
      |> flatten
      |> (.filter Boolean)
      |> create-connect-stack
      |> connect! .use
      |> http.create-server

    # return
    server

  broadcast: (
    message,
    websockets=@living-sockets,
    delay=@options.broadcast-delay
  )->
    json-data = JSON.stringify message

    <~(set-timeout _, delay)
    @verb-log "broadcast",
      "to #{websockets.length} sockets :", json-data
    websockets.for-each (->it?.send json-data)

  @apply-rec = (obj,func)->
    match typeof! obj
    | \Array => flatten obj .map func
    | _      => [func obj]

  # static methods
  # create static-transform
  @create-strans = (root,option-arg)->
    (option)<- @apply-rec option-arg
    match typeof! option
      | \Function =>
        static-transform do
          root: root
          match: /^/ig
          transform: (file-path, data, send)->
            send <| option file-path, data
      | \Object =>
        optm = new-copy def-options.inject, option
        index-of = if optm.prepend then (-> 0) else (.length)

        static-transform do
          root:root
          match:optm.file
          transform: (file-path, text, send)->
            m = (optm.match.exec text) ? {0:text, index:0}
            i = m.index + index-of m.0
            S = text~slice
            send "#{S 0,i}#{option.code}#{S i}"
      | _ => throw new Error "Unacceptable object: #option"

  # static methods
  # create static-transform
  @create-reload-matcher = (option-arg)->
    if typeof option-arg is \boolean
      return ->option-arg

    array = @apply-rec option-arg, (option)->
      match typeof! option
        | \Function => option
        | \RegExp   => option~test
        | \String   => (-> option.index-of it >= 0)
        | _ => throw new Error 'Unacceptable object: #option'

    # matcher
    (file-path)-> array.some (->it file-path)


