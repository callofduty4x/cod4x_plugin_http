## Http GSC Plugin
This plugin allows you to do http requests within your gsc scripts.

Usage:
```
callback(content) // callback function receiving the request content as string
{
    iprintln("out:" + content); // print the result
}

...

httpget("127.0.0.1/test.php", ::callback);
```

httpget interprets the received contents as a string which can be read from the callback

#### Compiling:
This plugin is written in D. You can get the needed compiler [here](https://dlang.org/download.html`) and the dub build system [here](https://code.dlang.org/download). To compile the plugin run `dub --arch=x86` in the folder containing `package.json`.

additional planned features:
* json support
