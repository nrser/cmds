Cmds
=============================================================================

`Cmds` tries to make it easier to read, write and remember using shell commands in Ruby.

It treats generating shell the in a similar fashion to generating SQL or HTML.

Best read at

<http://www.rubydoc.info/gems/cmds/>

where the API doc links should work and you got a table and contents.


-----------------------------------------------------------------------------
Status
-----------------------------------------------------------------------------

Ya know, before you get too excited...

It's kinda starting to work. I'll be using it for stuff and seeing how it goes, but no promises until `1.0` of course.


-----------------------------------------------------------------------------
License
-----------------------------------------------------------------------------

MIT


-----------------------------------------------------------------------------
Real-World Examples
-----------------------------------------------------------------------------

Or, "what's it look like?"...

-   Instead of
    
    ```ruby
    `psql \
      --username=#{ (db_config['username'] || ENV['USER']).shellescape } \
      #{ db_config['database'].shellescape } \
      < #{ filepath.shellescape }`
    ```
    
    write
    
    ```ruby
    Cmds 'psql %{opts} %{db} < %{dump}',
      db: db_config['database'],
      dump: filepath,
      opts: {
        username: db_config['username'] || ENV['USER']
      }
    ```
    
    to run a command like
    
    ```bash
    psql --username=nrser that_db < ./some/file/path
    ```
    
    Cmds takes care of shell escaping for you.
    
    
-   Instead of
    
    ```ruby
    `PGPASSWORD=#{ config[:password].shellescape } \
      pg_dump \
        --username=#{ config[:username].shellescape } \
        --host=#{ config[:host].shellescape } \
        --port=#{ config[:port].shellescape } \
        #{ config[:database].shellescape } \
      > #{ filepath.shellescape }`
    ```
    
    which can be really hard to pick out what's going on from a quick glance, write
    
    ```ruby
    Cmds.new(
      'pg_dump %{opts} %{database}',
      kwds: {
        opts: {
          username: config[:username],
          host: config[:host],
          port: config[:port],
        },
        database: config[:database],
      },
      env: {
        PGPASSWORD: config[:password],
      },
    ).stream! { |io| io.out = filename }
    ```
    
    I find it much easier to see what's going on their quickly.
    
    Again, with some additional comments and examples:
    
    ```ruby
    # We're going to instantiate a new {Cmds} object this time, because we're
    # not just providing values for the string template, we're specifying an
    # environment variable for the child process too.
    # 
    cmd = Cmds.new(
      # The string template to use.
      'pg_dump %{opts} %{database}',
      kwds: {
        # Hashes will automatically be expanded to CLI options. By default,
        # we use `--name=VALUE` format for long ones and `-n VALUE` for short,
        # but it's configurable.
        opts: {
          username: config[:username],
          host: config[:host],
          port: config[:port],
        },
        # As mentioned above, everything is shell escaped automatically
        database: config[:database],
      },
      # Pass environment as it's own Hash. There are options for how it is
      # provided to the child process as well.
      env: {
        # Symbol keys are fine, we'll take care of that for you
        PGPASSWORD: config[:password],
      },
    )
    
    # Take a look!
    cmd.prepare
    # => "PGPASSWORD=shhh\\! pg_dump --host=localhost --port=5432 --username=nrser blah"
    
    # Now stream it. the `!` means raise if the exit code is not 0
    exit_code = cmd.stream! { |io|
      # We use the block to configure I/O. Here we send the standard output to
      # a file, which can be a String, Pathname or IO object
      io.out = filename
    }
    ```


-----------------------------------------------------------------------------
Installation
-----------------------------------------------------------------------------

Add this line to your application's `Gemfile`:

    gem 'cmds'


And then execute:

    bundle install


Or install it globally with:

    gem install cmds



-----------------------------------------------------------------------------
Overview
-----------------------------------------------------------------------------

Cmds is based around a central {Cmds} class that takes a template for the command and a few options and operates by either wrapping the results in a {Cmds::Result} instance or streaming the results to `IO` objects or handler blocks.


-----------------------------------------------------------------------------
Features
-----------------------------------------------------------------------------

### Templates ###

#### ERB ####

Templates are processed with "[Embedded Ruby][]" (eRuby/ERB) using the [Erubis][] gem.

[Embedded Ruby]: https://en.wikipedia.org/wiki/ERuby
[Erubis]: http://www.kuwata-lab.com/erubis/

For how it works check out

1.  {Cmds::ERBContext}
2.  {Cmds::ShellEruby}
3.  {Cmds#render}

******************************************************************************


##### Positional Values from `args` #####

1.  Use the `args` array made available in the templates with entry indexes.
    
    Example when constructing:
    
    ```ruby
    Cmds.new(
      'cp <%= args[0] %> <%= args[1] %>',
      args: [
        'source.txt',
        'dest.txt',
      ],
    ).prepare
    # => "cp source.txt dest.txt"
    ```
    
    This will raise an error if it's called after using the last positional argument, but will not complain if all positional arguments are not used.
    
2.  Use the `arg` method made available in the templates to get the next positional arg.
    
    Example when using "sugar" methods that take `args` as the single-splat (`*args`):
    
    ```ruby
    Cmds.prepare  'cp <%= arg %> <%= arg %>',
                  'source.txt',
                  'dest.txt'
    # => "cp source.txt dest.txt"
    ```

******************************************************************************


##### Keyword Values from `kwds` #####

Just use the key as the method name.

When constructing:

```ruby
Cmds.new(
  'cp <%= src %> <%= dest %>',
  kwds: {
    src: 'source.txt',
    dest: 'dest.txt',
  },
).prepare
# => "cp source.txt dest.txt"
```

When using "sugar" methods that take `kwds` as the double-splat (`**kwds`):

```ruby
Cmds.prepare  'cp <%= src %> <%= dest %>',
              src: 'source.txt',
              dest: 'dest.txt'
# => "cp source.txt dest.txt"
```


###### Key Names to Avoid ######

If possible, avoid naming your keys:

-   `arg`
-   `args`
-   `initialize`
-   `get_binding`
-   `method_missing`

If you must name them those things, don't expect to be able to access them as shown above; use `<%= @kwds[key] %>`.


###### Keys That Might Not Be There ######

Normally, if you try to interpolate a key that doesn't exist you will get a `KeyError`:

```ruby
Cmds.prepare "blah <%= maybe %> <%= arg %>", "value"
# KeyError: couldn't find keys :maybe or "maybe" in keywords {}
```

I like a lot this better than just silently omitting the value, but sometimes you know that they key might not be set and want to receive `nil` if it's not.

In this case, append `?` to the key name (which is a method call in this case) and you will get `nil` if it's not set:

```ruby
Cmds.prepare "blah <%= maybe? %> <%= arg %>", "value"
# => "blah value"
```

```ruby
Cmds.prepare "blah <%= maybe? %> <%= arg %>", "value", maybe: "yes"
# => "blah yes value"
```

******************************************************************************


##### Shell Escaping #####

Cmds automatically shell-escapes values it interpolates into templates by passing them through the Ruby standard libray's [Shellwords.escape][].

[Shellwords.escape]: http://ruby-doc.org/stdlib/libdoc/shellwords/rdoc/Shellwords.html#method-c-escape

```ruby
Cmds.prepare "cp <%= src %> <%= dest %>",
  src: "source.txt",
  dest: "path with spaces.txt"
=> "cp source.txt path\\ with\\ spaces.txt"
```

It doesn't always do the prettiest job, but it's part of the standard library and seems to work pretty well... shell escaping is a messy and complicated topic (escaping for *which* shell?!), so going with the built-in solution seems reasonable for the moment, though I do hate all those backslashes... they're a pain to read.


###### Raw Interpolation ######

You can render a raw string with `<%== %>`.

To see the difference with regard to the previous example (which would break the `cp` command in question):

```ruby
Cmds.prepare "cp <%= src %> <%== dest %>",
  src: "source.txt",
  dest: "path with spaces.txt"
=> "cp source.txt path with spaces.txt"
```

And a way it make a little more sense:

```ruby
Cmds.prepare "<%== bin %> <%= *args %>",
  'blah',
  'boo!',
  bin: '/usr/bin/env echo'
=> "/usr/bin/env echo blah boo\\!"
```

******************************************************************************


##### Splatting (`*`) To Render Multiple Shell Tokens #####

Render multiple shell tokens (individual strings the shell picks up - basically, each one is an entry in `ARGV` for the child process) in one expression tag by prefixing the value with `*`:

```ruby
Cmds.prepare  '<%= *exe %> <%= cmd %> <%= opts %> <%= *args %>',
              'x', 'y', # <= these are the `args`
              exe: ['/usr/bin/env', 'blah'],
              cmd: 'do-stuff',
              opts: {
                really: true,
                'some-setting': 'dat-value',
              }
# => "/usr/bin/env blah do-stuff --really --some-setting=dat-value x y"
```

`ARGV` tokenization by the shell would look like:

```ruby
[
  '/usr/bin/env',
  'blah',
  'do-stuff',
  '--really',
  '--some-setting=dat-value',
  'x',
  'y',
]
```

-   Compare to *without* splats:
    
    ```ruby
    Cmds.prepare  '<%= exe %> <%= cmd %> <%= opts %> <%= args %>',
                  'x', 'y', # <= these are the `args`
                  exe: ['/usr/bin/env', 'blah'],
                  cmd: 'do-stuff',
                  opts: {
                    really: true,
                    'some-setting': 'dat-value',
                  }
    # => "/usr/bin/env,blah do-stuff --really --some-setting=dat-value x,y"
    ```
    
    Which is probably *not* what you were going for... it would produce an `ARGV`     something like:
    
    ```ruby
    [
      '/usr/bin/env,blah',
      'do-stuff',
      '--really',
      '--some-setting=dat-value',
      'x,y',
    ]
    ```

You can of course use "splatting" together with slicing or mapping or whatever.

******************************************************************************


##### Logic #####

All of ERB is available to you. I've tried to put in features and options that make it largely unnecessary, but if you've got a weird or complicated case, or if you just like the HTML/Rails-esque templating style, it's there for you:

```ruby
cmd = Cmds.new <<-END
  <% if use_bin_env %>
    /usr/bin/env
  <% end %>
  
  docker build .
    -t <%= tag %>
    
    <% if file %>
      --file <%= file %>
    <% end %>
    
    <% build_args.each do |key, value| %>
      --build-arg <%= key %>=<%= value %>
    <% end %>
    
    <% if yarn_cache %>
      --build-arg yarn_cache_file=<%= yarn_cache_file %>
    <% end %>
END

cmd.prepare(
  use_bin_env: true,
  tag: 'nrser/blah:latest',
  file: './prod.Dockerfile',
  build_args: {
    yarn_version: '1.3.2',
  },
  yarn_cache: true,
  yarn_cache_file: './yarn-cache.tgz',
)
# => "/usr/bin/env docker build . -t nrser/blah:latest
#       --file ./prod.Dockerfile --build-arg yarn_version=1.3.2
#       --build-arg yarn_cache_file=./yarn-cache.tgz"
# (Line-breaks added for readability; output is one line)
```

******************************************************************************


#### `printf`-Style Short-Hand (`%s`, `%{key}`, `%<key>s`)

Cmds also supports a [printf][]-style short-hand. Sort-of.

[printf]: https://en.wikipedia.org/wiki/Printf_format_string

It's a clumsy hack from when I was first writing this library, and I've pretty moved to using the ERB-style, but there are still some examples that use it, and I guess it still works (to whatever extent it ever really did), so it's probably good to mention it.

It pretty much just replaces some special patterns with their ERB-equivalent via the {Cmds.replace_shortcuts} method before moving on to ERB processing:

| Format      | ERB Replacement |
| ----------- | --------------- |
| `%s`        |  `<%= arg %>`   |
| `%{key}`    |  `<%= key %>`   |
| `%{key?}`   |  `<%= key? %>`  |
| `%<key>s`   |  `<%= key %>`   |
| `%<key?>s`  |  `<%= key? %>`  |

And the escaping versions, where you can put anothe `%` in front to get the literal intead of the subsitution:

| Format      | ERB Replacement |
| ----------- | --------------- |
| `%%s`       | `%s`            |
| `%%{key}`   | `%{key}`        |
| `%%{key?}`  | `%{key?}`       |
| `%%<key>s`  | `%<key>s`       |
| `%%<key?>s` | `%<key?>s`      |

That's it. No `printf` formatting beyond besides `s` (string).


-----------------------------------------------------------------------------
Old docs I haven't cleaned up yet...
-----------------------------------------------------------------------------

### execution

you can provide three types of arguments when executing a command:

1. positional arguments for substitution
2. keyword arguments for substitution
3. input to stdin

all `Cmds` instance execution methods have the same form for accepting these:

1. positional arguments are provided in an optional array that must be the first argument:
    
    `Cmds "cp <%= arg %> <%= arg %>", [src_path, dest_path]`
    
    note that the arguments need to be enclosed in square braces. Cmds does **NOT** use \*splat for positional arguments because it would make a `Hash` final parameter ambiguous.
    
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


### Reuse Commands

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


### defaults

NEEDS TEST

can be accomplished with reuse and currying stuff

```
playbook = Cmds.new "ansible-playbook -i %{inventory} %{playbook}", inventory: "inventory/dev"

# run setup.yml on the development hosts
playbook.call playbook: "setup.yml"

# run setup.yml on the production hosts
prod_playbook.call playbook: "setup.yml", inventory: "inventory/prod"
```


### input

```
c = Cmds.new("wc", input: "blah blah blah).call
```


### future..?

#### exec

want to be able to use to exec commands

#### formatters

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
