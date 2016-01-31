require! {
  \./utils
}

default-injection-code =
  utils.load __dirname, \./client.js

export
  generate-minimist-opt: (opt=@commandline-options)->
    output = {boolean:[],string:[],alias:{},default:{}}

    for {label,type=null,short=[],def=null} in opt
      key = type is String and \string or \boolean
      output[key] ++= label

      for n in [].concat short
        output.alias[n] = [label]

      output.default[label] = def

    output

  generate-commandline-help:->
    for {label,short,type,desc,def} in @commandline-options
      spec  = ["--#{label}"]
      short = if short? then ", -#{short}" else []
      param = type is String and ' <param>' or []

      [(spec ++ short ++ param).join ''] ++ desc ++ (def ? [])

  commandline-options:
    * label: 'root'
      short: \d
      type:  String
      desc:  'set base directory to publish.'
      def: \.

    * label: 'port'
      short: \p
      type:  String
      desc:  'set port to listen (http).'
      def: 8080

    * label: 'list-directory'
      short: \l
      desc:  'enable directory listing.'
      def: true

    * label: 'browse'
      short: \b
      desc:  'open url of server by platform default program.'
      def: false

    * label: 'execute'
      type:  String
      short: \e
      desc:  'execute command when the server has prepared.'
      def: null

    * label: 'stop-on-exit'
      desc:  'exit when invoked process specified by \'--execute\' died.'
      def: false

    * label: 'watch'
      type:  String
      short: \w
      desc:  'regex pattern for file to watch.'
      def: /^/

    * label: 'watch-delay'
      type:  String
      desc:  'delay the watch event to supress duplication (in ms).'
      def: 1ms

    * label: 'verbose'
      short: \v
      desc:  'enable verbose logging.'
      def: false

    * label: 'client-log'
      desc:  'inform client to log.'
      def: false

    * label: 'recursive'
      short: \r
      desc:  'watch sub-directories recursively. (may take a while at startup)'
      def: true

    * label: 'follow-symlink'
      short: \l
      desc:  'follow symbolic-link. (it affects only when the resursive option specified.)'
      def: false

    * label: 'force-reload'
      type:  String
      short: \f
      desc:  'regex pattern for file forced to reload the whole page.'
      def: null

    * label: 'broadcast-delay'
      type: String
      desc: 'delay time before broadcasting event (in ms).'
      def: 0ms

    * label: 'no-default-script'
      desc:  'disable default script injection.'
      def:  false

    * label: 'inject-file'
      type:  String
      short: \I
      desc:  'the file to be injected into content.'
      def: null

    * label: 'inject-method'
      type:  String
      short: \M
      desc:  'specify the injection method [prepend or append]'
      def: \p

    * label: 'inject-match-text'
      type:  String
      short: \T
      desc:  'specify the regex or string pattern for content where to inject'
      def: null

    * label: 'inject-match-file'
      type:  String
      short: \F
      desc:  'specify the regex pattern for file where to inject.'
      def: null

    * label: 'version'
      short: \V
      desc:  'show version'

    * label: 'help'
      short: \h
      desc:  'show help'

  default-injection-code: default-injection-code

  default-module-options: {
    port: 8080
    root: process.cwd!

    # enable directory listing
    +list-directory

    # log verbose
    -verbose

    # watch recursively
    +recursive

    # follow symlink
    -follow-symlink

    # inform client to log 
    -client-log

    # delay time before fireing watch event (num in ms)
    watch-delay: 1ms

    # Pattern of file name(s) to watch (regex or array)
    watch: /^/

    # This function will be switched by option type
    #
    #   [String/Regex/Array]
    #     Pattern of the file name to which is forced to reload
    #
    #   [Boolean]
    #     Always reload the 'page' on any event if true 
    #
    force-reload: false

    # the event listener on received the message which was sent by client.
    onmessage: ((message)->)

    # code injection settings (array or object)
    inject:

      # raw code
      code:  """
        <script type='text/javascript'>
        (function(){#{default-injection-code}})();
        </script>
      """

      # the pattern of the text to where to insert
      match: /<\/(body|head|html)>/i

      # the pattern of the file-name to which to insert
      file:  /(\.(php|html?|cgi|pl|rb))$/i

      # prepend or append when inject the code
      prepend: true
  }

