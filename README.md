simple-autoreload-server
========================

[simple-autoreload-server] is simple live/auto reloading web server on Node.js.
  - Reload statically on update the html files
  - Refresh dynamically on update the files like css, js, png, and etc.
  - No browser extensions (but the WebSocket) are needed. 

Command Line Usage
----
```sh
autoreload [root-dir [port]]
```
#### Example

```sh
autoreload ./site-files 8008
```

Module Usage (Example)
----
```
var launcher = require('simple-autoreload-server');

var server = launcher({
  port: 8008,
  root: './',
  listDirectory: true,
  watch: /\.(png|js|html|json|swf)$/i,
  forceReload: [/\.json$/i, "static.swf"]
});
```

#### Option

See 'src/lib/default-options.ls' for details of the options.

Version
----
v0.0.7

Installation
--------------
You can install this package via 'npm'.

License
----
[MIT License]


[simple-autoreload-server]:https://github.com/cytb/simple-autoreload-server
[MIT License]:http://www.opensource.org/licenses/mit-license.php




