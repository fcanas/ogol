# ogol

Ogol is a derivative of the [Logo](https://en.wikipedia.org/wiki/Logo_(programming_language)) programming language that is taking off in a different direction.

The Ogol language has [dynamic scoping](https://en.wikipedia.org/wiki/Scope_(computer_science)#Dynamic_scope), [tail call optimization](https://en.wikipedia.org/wiki/Tail_call). The inluded core libraries include [turtle graphics](https://en.wikipedia.org/wiki/Turtle_graphics) with SVG output.

This project is organized into subcomponents:

- Execution
  - Describes a weird combination AST, runtime, and high-level virtual machine
- OgoLang
  - Contains a Parser converting Ogol to structures described in the Execution module.
- libOgol
  - Core language procedures that require interacting with the runtime such as `output`, `stop`, and `make` in the `Meta` module. libOgol also includes a `CoreLib` module with core utilities implemented in Ogol, such as `list` and `repeat`. Also included are [Turtle Graphics]((https://en.wikipedia.org/wiki/Turtle_graphics)) with SVG output,  
- OgolMath
  - Core math functions
- ogol
  - A basic CLI Ogol REPL with no Turtle Graphics
- Tooling Support
  - An abstract definition of a parser and associated syntax coloring and error types supporting an editor. Previously, this supported a separate Logo implementation. Currently it remains independent to facilitate rapid creation and iteration of experimental tools, which is one of the main reasons I've made this toy language to begin with.

[Development Log](Log.md)
