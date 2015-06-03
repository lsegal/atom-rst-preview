# ReStructuredText Preview package

Show the rendered HTML rst to the right of the current editor using
`ctrl-shift-r`

It can be activated from the editor using the `ctrl-shift-r` key-binding and is
currently enabled for `.rst` files.

## Installing

This package requires [Pandoc][1] to run. You can install Pandoc from:

https://github.com/jgm/pandoc/releases

## Workaround on OSX for pandoc could not be spawned error

If launching Atom from the OSX dock rather than from the terminal, you might see a path problem where
/usr/local/bin is not loaded into the path causing pandoc not to be found.

```
'pandoc' could not be spawned. 
Is it installed and on your path? 
If so please open an issue on the package spawning the process.
```

This is a [current bug][2] in Atom.

Until this atom bug is fixed, a workaround is to add the following config
to the ~/.atom/init.coffee file the relaunch from the OSX dock:
```
process.env.PATH = ["/usr/bin",
                    "/usr/local/bin",
                    ].join(":")
```


[1]: http://johnmacfarlane.net/pandoc/index.html
[2]: https://github.com/atom/atom/issues/6956
