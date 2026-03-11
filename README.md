<p align="center"><img style="width: 300px;" src="https://cdn.justjs.dev/assets/svg/mango_title.svg" /></p>

##

A simple key-value store for your CLI, backed by [libMDBX](https://libmdbx.dqdkfa.ru/).

```bash
$ mango set hello world
added key 'hello' with value 'world'

$ mango set foo bar
added key 'foo' with value 'bar'

$ mango get hello
world

$ mango list
  foo ··· bar
  hello · world

$ mango count
2

$ mango prefix he
{"hello": "world"}

$ mango range a h
{"foo": "bar"}

$ mango save backup.csv
saved store '~/.mango' to 'backup.csv'

$ mango del foo -s

$ mango reset -f
```

### Install

Requires [Zig](https://ziglang.org/) 0.15.2+.

```bash
zig build -Doptimize=ReleaseFast
zig build install-local  # installs to ~/.local/bin
```

Run `mango -h` for all commands and options.
