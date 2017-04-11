# cmds

cmds tries to make it easier to read, write and remember using shell commands in Ruby.

it treats generating shell the in a similar fashion to generating SQL or HTML.


## status

eh, it's kinda starting to work... i'll be using it for stuff and seeing how it goes, but no promises until `1.0` of course.


## installation

Add this line to your application's Gemfile:

```
gem 'cmds'
```


And then execute:

```
$ bundle
```


Or install it yourself as:

```
$ gem install cmds
```



## real-world examples

instead of

```
`psql -U #{ db_config['username'] || ENV['USER'] } #{ db_config['database']} < #{ filepath.shellescape }`
```

write

```
Cmds 'psql %{opts} %{db} < %{dump}',
  db: db_config['database'],
  dump: filepath,
  opts: {
    username: db_config['username'] || ENV['USER']
  }
```

instead of

```
`aws s3 sync s3://#{ PROD_APP_NAME } #{ s3_path.shellescape }`
```

write

```
Cmds 'aws s3 sync %{uri} %{path}', uri: "s3://#{ PROD_APP_NAME }"
                                   path: s3_path
```

instead of

```
`PGPASSWORD=#{ config[:password].shellescape } pg_dump -U #{ config[:username].shellescape } -h #{ config[:host].shellescape } -p #{ config[:port] } #{ config[:database].shellescape } > #{ filepath.shellescape }`
```

write

```
Cmds 'PGPASSWORD=%{password} pg_dump %{opts} %{database} > %{filepath}',
  password: config[:password],
  database: config[:database],
  filepath: filepath,
  opts: {
    username: config[:username],
    host: config[:host],
    port: config[:port],
  }
```



## architecture

Cmds is based around a central `Cmds` class that takes a template for the command and a few options and operates by either wrapping the results in a `Cmds::Result` instance or streaming the results to `IO` objects or handler blocks. the Cmds` `augmented with a health helping of connivence methods for creating and executing a `Cmds` instance in common ways.

### constructor

the `Cmds` constructor looks like

```
Cmds(template:String, opts:Hash)
```

a brief bit about the arguments:

* `template`
    * a `String` template processed with ERB against positional and keyword arguments.
* `opts`
    * `:args`
        * an `Array` of positional substitutions for the template.
        * assigned to `@args`.
        * defaults to an empty `Array`.
    * `:kwds`
        * a `Hash` of keyword substitutions for the template.
        * assigned to `@kwds`.
        * defaults to an empty `Hash`.
    * `:input`
        * a `String` to provide as standard input.
        * assigned to `@input`.
        * defaults to `nil`.
    * `:assert`
        * if this tests true, the execution of the command will raise an error on a nonzero exit status.
        * assigned to `@assert`.
        * defaults to `False`.

### execution

you can provide three types of arguments when executing a command:

1. positional arguments for substitution
2. keyword arguments for substitution
3. input to stdin

all `Cmds` instance execution methods have the same form for accepting these:

1. positional arguments are provided in an optional array that must be the first argument:
    
    `Cmds "cp <%= arg %> <%= arg %>", [src_path, dest_path]`
    
    note that the arguments need to be enclosed in square braces. Cmds does **NOT** use *splat for positional arguments because it would make a `Hash` final parameter ambiguous.
    
2. keyword arguments are provided as optional hash that must be the last argument:
    
    `Cmds "cp <%= src %> <%= dest %>", src: src_path, dest: dest_path`
    
    in this case, curly braces are not required since Ruby turns the trailing keywords into a `Hash` provided as the last argument (or second-to-last argument in the case of a block included in the method signature).
    
3. input and output is handled with blocks:
    
    `Cmds(“wc -l”){ “one\ntwo\nthree\n” } 
    
    Cmds.stream './test/tick.rb <%= times %>', times: times do |io|
      io.on_out do |line|
        # do something with the output line
      end
    
      io.on_err do |line|
        # do something with the error line
      end
    end`



## templates

command templates are processed with [eRuby](https://en.wikipedia.org/wiki/ERuby), which many people know as [ERB](http://ruby-doc.org/stdlib-2.2.2/libdoc/erb/rdoc/ERB.html). you may know ERB from [Rails](http://guides.rubyonrails.org/layouts_and_rendering.html).

actually, Cmds uses [Erubis](http://www.kuwata-lab.com/erubis/). which is the same thing Rails uses; calm down.

this takes care of a few things:

1. automatically shell escape values substituted into templates with [`Shellwords.escape`](http://ruby-doc.org/stdlib-2.2.2/libdoc/shellwords/rdoc/Shellwords.html#method-c-escape). it doesn't always do the prettiest job, but `Shellwords.escape` is part of Ruby's standard library and seems to work pretty well.
2. allow for fairly nice and readable logical structures like `if` / `else` in the command template. you've probably built html like this at some point. of course, the full power of Ruby is also available, though you probably won't find yourself needing much beyond some simple control structures.

## substitutions

substitutions can be positional, keyword, or both.

### positional

positional arguments can be substituted in order using the `arg` method call:

```
Cmds.sub "psql <%= arg %> <%= arg %> < <%= arg %>", [
  {
    username: "bingo bob",
    host: "localhost",
    port: 12345,
  },
  "blah",
  "/where ever/it/is.psql",
]
# => 'psql --host=localhost --port=12345 --username=bingo\ bob blah < /where\ ever/it/is.psql'
```

internally this translates to calling `@args.fetch(@arg_index)` and increments `@arg_index` by 1.

this will raise an error if it's called after using the last positional argument, but will not complain if all positional arguments are not used. this prevents using a keyword arguments named `arg` without accessing the keywords hash directly. 

the arguments may also be accessed directly though the bound class's `@args` instance variable:

```
Cmds.sub "psql <%= @args[2] %> <%= @args[0] %> < <%= @args[1] %>", [
  "blah",
  "/where ever/it/is.psql",
  {
    username: "bingo bob",
    host: "localhost",
    port: 12345,
  },
]
# => 'psql --host=localhost --port=12345 --username=bingo\ bob blah < /where\ ever/it/is.psql'
```

note that `@args` is a standard Ruby array and will simply return `nil` if there is no value at that index (though you can use `args.fetch(i)` to get the same behavior as the `arg` method with a specific index `i`).

### keyword

keyword arguments can be accessed by making a method call with their key:

```
Cmds.sub "psql <%= opts %> <%= database %> < <%= filepath %>",
  [],
  database: "blah",
  filepath: "/where ever/it/is.psql",
  opts: {
    username: "bingo bob",
    host: "localhost",
    port: 12345,
  }
# => 'psql --host=localhost --port=12345 --username=bingo\ bob blah < /where\ ever/it/is.psql'
```

this translates to a call of `@kwds.fetch(key)`, which will raise an error if `key` isn't present.

there are four key names that may not be accessed this way due to method definition on the context object:

* `arg` (see above)
* `initialize`
* `get_binding`
* `method_missing`

though keys with those names may be accessed directly via `@kwds.fetch(key)` and the like.

to test for a key's presence or optionally include a value, append `?` to the method name:

```
c = Cmds.new <<-BLOCK
  defaults
  <% if current_host? %>
    -currentHost <%= current_host %>
  <% end %>
  export <%= domain %> <%= filepath %>
BLOCK

c.call domain: 'com.nrser.blah', filepath: '/tmp/export.plist'
# defaults export com.nrser.blah /tmp/export.plist

c.call current_host: 'xyz', domain: 'com.nrser.blah', filepath: '/tmp/export.plist'
# defaults -currentHost xyz export com.nrser.blah /tmp/export.plist
```

### both

both positional and keyword substitutions may be provided:

```
Cmds.sub "psql <%= opts %> <%= arg %> < <%= filepath %>",
  ["blah"],
  filepath: "/where ever/it/is.psql",
  opts: {
    username: "bingo bob",
    host: "localhost",
    port: 12345,
  }
# => 'psql --host=localhost --port=12345 --username=bingo\ bob blah < /where\ ever/it/is.psql'
```

this might be useful if you have a simple positional command like

```
Cmds "blah <%= arg %>", ["value"]
```

and you want to quickly add in some optional value

```
Cmds "blah <%= maybe? %> <%= arg %>", ["value"]
Cmds "blah <%= maybe? %> <%= arg %>", ["value"], maybe: "yes!"
```

### shortcuts

there are support for `sprintf`-style shortcuts.

**positional**

`%s` is replaced with `<%= arg %>`.

so

```
Cmds.sub "./test/echo_cmd.rb %s", ["hello world!"]
```

is the same as

```
Cmds "./test/echo_cmd.rb <%= arg %>", ["hello world!"]
```

**keyword**

`%{key}` and `%<key>s` are replaced with `<%= key %>`, and `%{key?}` and `%<key?>s` are replaced with `<%= key? %>` for optional keywords.

so

```
Cmds "./test/echo_cmd.rb %{key}", key: "hello world!"
```

and

```
Cmds "./test/echo_cmd.rb %<key>s", key: "hello world!"
```

are the same is

```
Cmds "./test/echo_cmd.rb <%= key %>", key: "hello world!"
```

**escaping**

strings that would be replaced as shortcuts can be escaped by adding one more `%` to the front of them:

```
Cmds.sub "%%s" # => "%s"
Cmds.sub "%%%<key>s" # => "%%<key>s"
```

note that unlike `sprintf`, which has a much more general syntax, this is only necessary for patterns that exactly match a shortcut, not `%` in general:

```
Cmds.sub "50%" # => "50%"
```



## reuse commands

```
playbook = Cmds.new "ansible-playbook -i %{inventory} %{playbook}"
playbook.call inventory: "./hosts", playbook: "blah.yml"
```

currying

```
dev_playbook = playbook.curry inventory: "inventory/dev"
prod_playbook = playbook.curry inventory: "inventory/prod"

# run setup.yml on the development hosts
dev_playbook.call playbook: "setup.yml"

# run setup.yml on the production hosts
prod_playbook.call playbook: "setup.yml"
```



## defaults

NEEDS TEST

can be accomplished with reuse and currying stuff

```
playbook = Cmds.new "ansible-playbook -i %{inventory} %{playbook}", inventory: "inventory/dev"

# run setup.yml on the development hosts
playbook.call playbook: "setup.yml"

# run setup.yml on the production hosts
prod_playbook.call playbook: "setup.yml", inventory: "inventory/prod"
```



## input

```
c = Cmds.new("wc", input: "blah blah blah).call
```



## future..?

### exec

want to be able to use to exec commands

### formatters

kinda like `sprintf` formatters or string escape helpers in Rails, they would be exposed as functions in ERB and as format characters in the shorthand versions:

```
Cmds "blah <%= j obj %>", obj: {x: 1}
# => blah \{\"x\":1\}

Cmds "blah %j", [{x: 1}]
# => blah \{\"x\":1\}

Cmds "blah %<obj>j", obj: {x: 1}
# => blah \{\"x\":1\}
```

the `s` formatter would just format as an escaped string (no different from `<%= %>`).

other formatters could include

* `j` for JSON (as shown above)
* `r` for raw (unescaped)
* `l` or `,` for comma-separated list (which some commands like as input)
* `y` for YAML
* `p` for path, joining with `File.join`
