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

additional planned features:
* json support
