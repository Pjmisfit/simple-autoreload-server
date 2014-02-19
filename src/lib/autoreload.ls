
require! {
  connect
  colors
  WebSocket: \faye-websocket
  http
  path
  static-transform: \connect-static-transform
  \./utils
  \./watch
  m-options: \./options
}


def-options = m-options.default-module-options

# utils
{flatten,regex-clone,new-copy,get-logger,create-connect-stack} = utils

module.exports = (options)->
  ars-obj = new SimpleAutoreloadServer options
    ..init!
    ..start!

# Main class
class SimpleAutoreloadServer

  get-tagged-logger = (color)->
    (tag,...texts)->
        @log-impl.apply @, ( [tag.to-string![color]] ++ texts )

  (options={})->
    @living-sockets = []

    @log-impl = get-logger ~>
      @@log-prefix "localhost:#{@options.port}"

    @normal-log = get-tagged-logger 'green'
    @error-log  = get-tagged-logger 'red'
    @verb-log   = (->)

    @set-options options
    @running = false

  set-options: (options-arg={})->
    options = new-copy options-arg, def-options

    # check onmessage
    if \function isnt typeof options.onmessage
      options.onmessage = (->)

    # set logger state
    if options.verbose
      @verb-log = @normal-log

    @options = options


  stop: ->
    @watcher?.stop!
    @server?.close!
    @running = false

    @normal-log "server", "stopped."

  start: ->
    @stop! if @running
    @watcher.start!
    @server
      ..listen @options.port
      ..add-listener \upgrade, @create-upgrade-listerner!

    port      = @options.port.to-string!green
    root-path = @options.root.to-string!green

    @running = true
    @normal-log "server", "started on :#port at #root-path"

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

  # Create watch
  create-watcher: ->

    # show notes
    if @options.recursive
      @verb-log "server", "init with recursive-option. this may take a while."

    root     = @options.root
    abs-root = path.resolve @options.root
    self     = this

    do-reload = @@@create-reload-matcher @options.force-reload

    # Watch
    watch-obj = watch do
      root:root
      recursive: @options.recursive
      delay: @options.watch-delay
      on-change:(ev,source-path)->
        if ev is \error
          self.error-log "watch", source-path
          return

        matcher = ->
          typeof! it is \RegExp and it.test source-path

        unless flatten [ self.options.watch ] .some matcher
        then
          self.verb-log "watch", "(ignored)".cyan, source-path
          return

        self.normal-log "watch", "updated", source-path

        http-path = (do
          try
            relative-path = path.relative root, source-path

            # returning '' if it is outer
            relative-path isnt /^\// and "/#relative-path" or ''
          catch
             ''
        )

        self.broadcast do
          type:\update
          path:http-path
          force-reload: do-reload http-path

    # fix Este to catch the error
    watch-obj

  # Creating httpd-server
  create-server: ->
    root = path.resolve @options.root

    server =
      # head of middleware conf
      * null

      # logger 
        @options.verbose and connect.logger ([
            ":ar-prefix :remote-addr :method"
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

  @log-prefix = (host)->
    pid  = process.pid
    # root = @options.root
    "[autoreload \##pid #host]".cyan

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


connect.logger.token \ar-prefix, (r)~>
  SimpleAutoreloadServer.log-prefix r.headers.host
  |> (+ " httpd".green)

