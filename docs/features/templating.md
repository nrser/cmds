Templating
==============================================================================

Echo {Cmds} instance has a {Cmds#template} string, which is provided as the
first argument during construction. This template is used to render the text
that will be executed when the {Cmds} is invoked.

```ruby
cmd = Cmds.new "cp %{src} %{dest}"

cmd.prepare src: "source.txt", dest: "copy.txt"
#=> "cp source.txt copy.txt"
```

Templates are processed with "[Embedded Ruby][]" (eRuby/ERB) using the
[Erubis][] gem, which offers an extended feature set over the built-in ERB
module.

[Embedded Ruby]: https://en.wikipedia.org/wiki/ERuby
[Erubis]: https://www.rubydoc.info/gems/erubis

For how it works check out

1.  {Cmds::ERBContext}
2.  {Cmds::ShellEruby}
3.  {Cmds#render}

Syntax
------------------------------------------------------------------------------

ERB uses a PHP-like syntax

1.  `<% expr %>` evaluates the expression `expr`. Used mostly for control
    structures.
    
2.  `<%= expr %>` evaluates the `expr` and substitutes the _shell-escaped_ return
    value in its place. Used to render values.
    
3.  `<%== expr %>` substitutes the "raw" result of `expr` (no shell-escaping).
    
4.  `<%# ... %>` is a comment.
    
Plus a few other odds and ends that I would need to look up because I never use
them.

As you may have noticed, Cmds customizes/extends ERB in a few ways:

1.  Accepting `%{ expr }` in place of `<%= expr %>`.
    
    I feel like this helps readability when simply substituting values:
    
    ```ruby
    Cmds 'cp %{src} %{dest}', src: "./a", dest: "./b"
    ```
    
    versus
    
    ```ruby
    Cmds 'cp <%=src%> <%=dest%>', src: "./a", dest: "./b"
    ```
    
2.  _Shell-escaping_ rendered values by default. This makes it so that the
    command being run sees each subsituted value as a single string, regardless
    of whether or not it has spaces or other shell syntax characters in it.
    
    I find this is most often what I want: a value is treated as a value, not as
    a chunk of code to be executed. Same idea as escaping when subsituting into
    HTML.
    
    Similarly, forgetting to shell escape leads to lurking bugs at best and
    security problems at worst. So escaping is the default.
    
    If you want to skip shell-escaping use `<%== %>`.

Subsituting Values
------------------------------------------------------------------------------

Each {Cmds} instance has an {Array} of positional values named `args` and a
{Hash} of keyword values named `kwds` available for substitution into the
template.

These collections will be empty by default.

### Positional Values (`args`) ###

1.  Use the `args` array made available in the templates with entry indexes.
    
    Example when constructing:
    
    ```ruby
    Cmds.new(
      'cp %{args[0]} %{args[1]}',
      args: [
        'source.txt',
        'dest.txt',
      ],
    ).prepare
    # => "cp source.txt dest.txt"
    ```
    
    This will raise an error if it's called after using the last positional
    argument, but will not complain if all positional arguments are not used.
    
2.  Use the `arg` method made available in the templates to get the next
    positional arg.
    
    ```ruby
    Cmds.prepare  'cp %{arg} %{arg}',
                  'source.txt',
                  'dest.txt'
    # => "cp source.txt dest.txt"
    ```

### Keyword Values (`kwds`) ###

Just use the key as the method name.

When constructing:

```ruby
Cmds.new(
  'cp %{src} %{dest}',
  kwds: {
    src: 'source.txt',
    dest: 'dest.txt',
  },
).prepare
# => "cp source.txt dest.txt"
```

When using "sugar" methods that take `kwds` as the double-splat (`**kwds`):

```ruby
Cmds.prepare  'cp %{src} %{dest}',
              src: 'source.txt',
              dest: 'dest.txt'
# => "cp source.txt dest.txt"
```

#### Key Names to Avoid ####

If possible, avoid naming your keys:

-   `arg`
-   `args`
-   `initialize`
-   `get_binding`
-   `method_missing`

If you must name them those things, don't expect to be able to access them as
shown above; use `<%= @kwds[key] %>`.

#### Keys That Might Not Be There ####

Normally, if you try to interpolate a key that doesn't exist you will get a
`KeyError`:

```ruby
Cmds.prepare "blah %{maybe} %{arg}", "value"
# KeyError: couldn't find keys :maybe or "maybe" in keywords {}
```

I like a lot this better than just silently omitting the value, but sometimes
you know that they key might not be set and want to receive `nil` if it's not.

In this case, append `?` to the key name (which is a method call in this case)
and you will get `nil` if it's not set:

1.  Executing
    
    ```ruby
    puts Cmds.prepare "blah %{maybe?} %{arg}", "value"
    ```
    
    prints
    
        blah value
    
2.  Executing
    
    ```ruby
    puts Cmds.prepare "blah %{maybe?} %{arg}", "value", maybe: "yes"
    ```
    
    prints
    
        blah yes value

Shell Escaping
------------------------------------------------------------------------------

Shell-escaping is generally performed by [Shellwords.shellescape][] from the Ruby standard libray.

It doesn't always do the prettiest job, but it's built-in and seems to work
pretty well... shell escaping is a messy and complicated topic (escaping for
*which* shell?!), so going with the built-in solution seems reasonable.

[Shellwords.shellescape]: https://ruby-doc.org/current/stdlibs/shellwords/Shellwords.html#method-c-shellescape

### JSON (The Exception) ###

The _exception_ is when rendering a value as JSON, where
[Shellwords.shellescape][] makes things quite painful to read.

1.  Executing
    
    ```ruby
    require 'shellwords'
    require 'json'

    puts Shellwords.shellescape(JSON.dump({name: "NR$ER", fav_color: "blue"}))
    ```

    prints

        \{\"name\":\"NR\$ER\",\"fav_color\":\"blue\"\}

In this case, Cmds uses a bespoke implementation of single-quote escaping.

1.  Executing
    
    ```ruby
    require 'json'
    require 'cmds'

    puts Cmds.quote(JSON.dump({name: "NR$ER", fav_color: "blue"}))
    ```

    prints

        '{"name":"NR$ER","fav_color":"blue"}'

Raw Substitution
------------------------------------------------------------------------------

You can render a raw string with `<%== %>`.

To see the difference with regard to the previous example (which would break the
`cp` command in question):

1.  Executing
    
    ```ruby
    Cmds.prepare "cp <%= src %> <%== dest %>",
      src: "source.txt",
      dest: "path with spaces.txt"

    ```

    prints

        cp source.txt path with spaces.txt

2.  And a way it make (slightly) more sense, executing
    
    ```ruby
    puts Cmds.prepare "<%== bin %> <%= *args %>",
      'blah',
      'boo!',
      bin: '/usr/bin/env echo'
    ```

    prints

        /usr/bin/env echo blah boo\!

#### Splatting (`*`) ####

Render multiple shell tokens (individual strings the shell picks up - basically,
each one is an entry in `ARGV` for the child process) in one expression tag by
prefixing the value with `*`:

1.  Executing
    
    ```ruby
    puts Cmds.prepare  '%{*exe} %{cmd} %{opts} %{*args}',
                  'x', 'y', # <= these are the `args`
                  exe: ['/usr/bin/env', 'blah'],
                  cmd: 'do-stuff',
                  opts: {
                    really: true,
                    'some-setting': 'dat-value',
                  }
    ```

    prints

        /usr/bin/env blah do-stuff --really --some-setting=dat-value x y

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

You can of course use "splatting" together with slicing or mapping or whatever.

##### Logic #####

All of ERB is available to you. I've tried to put in features and options that
make it largely unnecessary, but if you've got a weird or complicated case, or
if you just like the HTML/Rails-esque templating style, it's there for you:

1.  Executing
    
    ```ruby
    cmd = Cmds.new <<~BLOCK
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
    BLOCK

    puts cmd.prepare(
      use_bin_env: true,
      tag: 'nrser/blah:latest',
      file: './prod.Dockerfile',
      build_args: {
        yarn_version: '1.3.2',
      },
      yarn_cache: true,
      yarn_cache_file: './yarn-cache.tgz',
    )
    ```

    prints

        /usr/bin/env docker build . -t nrser/blah:latest --file ./prod.Dockerfile --build-arg yarn_version=1.3.2 --build-arg yarn_cache_file=./yarn-cache.tgz

