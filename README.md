## 🥭 mango

A simple key-value store for your CLI, backed by [libMDBX](https://libmdbx.dqdkfa.ru/).

### usage

```
$ mango set hello world
$ mango get hello
world
$ mango list
  hello · world
$ mango del hello
```

Run `mango -h` for all commands and options.

### install

Requires [Zig](https://ziglang.org/) 0.15.2+.

```
zig build -Doptimize=ReleaseFast
zig build install-local
```
