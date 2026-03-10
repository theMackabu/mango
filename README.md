<p align="center"><img style="width: 300px;" src="https://cdn.justjs.dev/assets/svg/mango_title.svg" /></p>

##

A simple key-value store for your CLI, backed by [libMDBX](https://libmdbx.dqdkfa.ru/). Helps you store values for your scripts.

### Quick Start

```bash
$ mango set hello world
added key 'hello' with value 'world'

$ mango get hello
world

$ mango list
  hello · world
```

Suppress output with `-s` / `--silent`:

```bash
$ mango del hello -s
```

Save the entire store to a CSV file:

```bash
$ mango save backup.csv
saved store '~/.mango' to 'backup.csv'
```

Range query between keys:

```bash
$ mango range a z
{"hello": "world", "foo": "bar"}
```

For all commands, run `mango --help`.

### Installation

#### From source

Requires [Zig](https://ziglang.org/) 0.15.2+.

```bash
git clone https://github.com/themackabu/mango.git
cd mango
zig build -Doptimize=ReleaseFast
```

Install to `~/.local/bin`:

```bash
zig build install-local
```
