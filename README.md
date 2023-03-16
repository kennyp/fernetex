## FernetEx

[![CI Status](https://github.com/kennyp/fernetex/actions/workflows/test.yml/badge.svg)](https://github.com/kennyp/fernetex/actions/workflows/test.yml)

Fernet takes a user-provided *message* (an arbitrary sequence of
bytes), a *key* (256 bits), and the current time, and produces a
*token*, which contains the message in a form that can't be read
or altered without the key.

This package is compatible with the other implementations at
[https://github.com/fernet](https://github.com/fernet).
They can exchange tokens freely among each other.

Documentation: [http://hexdocs.pm/fernetex/0.3.1/](http://hexdocs.pm/fernetex/0.3.1/)


### Adding FernetEx To Your Project

To use FernetEx with your projects, edit your `mix.exs` file and add it as a dependency:

```elixir
defp deps do
  [{:fernetex, "~> 0.3.1"}]
end
```

For more information and background, see the Fernet spec at
[https://github.com/fernet/spec](https://github.com/fernet/spec).

FernetEx is distributed under the terms of the MIT license.
See the License file for details.


### Useful Mix tasks

FernetEx comes with two useful mix tasks

- `mix fernet.keygen` is useful for generating keys
- `mix fernet.sign key` is useful for signing a message using the given key
