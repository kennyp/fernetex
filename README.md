## FernetEx

Fernet takes a user-provided *message* (an arbitrary sequence of
bytes), a *key* (256 bits), and the current time, and produces a
*token*, which contains the message in a form that can't be read
or altered without the key.

This package is compatible with the other implementations at
[https://github.com/fernet](http://hexdocs.pm/fernetex/0.0.1/).
They can exchange tokens freely among each other.

Documentation: [http://hexdocs.pm/fernetex/0.0.1/](http://hexdocs.pm/fernetex/0.0.1/)


### Adding FernetEx To Your Project

To use FernetEx with your projects, edit your `mix.exs` file and add it as a dependency:

```elixir
defp deps do
  [{:fernetex, "~> 0.0.1"}]
end
```

For more information and background, see the Fernet spec at
[https://github.com/fernet/spec](https://github.com/fernet/spec).

FernetEx is distributed under the terms of the MIT license.
See the License file for details.
