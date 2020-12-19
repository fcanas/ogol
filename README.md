# ogol

A compiler and virtual machine for ogol. Ogol is currently a variant of the Logo computer language that is taking off in a different direction.

The project retains an internal version of the Logo parser before Ogol began to diverge significantly. Many basic Logo programs may be run without modification. But Ogol is missing many core procedures and data structures. In trying to be a compiled language, full compatibilty with other Logos is likely impossible.

This project is organized into subcomponents:

- Execution
  - Describes a weird combination AST, runtime, and high-level virtual machine
- OgoLang
  - Contains a Parser converting Ogol to structures described in the Execution module.
- LogoLang
  - Contains a Parser converting Ogol's Logo variant to structures described in the Execution module.
- libLogo
  - Core libraries including math functions, Turtle Graphics, and  core language procedures that require interacting with the runtime such as `output`, `stop`, and `make`
- ogol
  - A basic CLI Ogol REPL with no Turtle Graphics
- logo
  - A basic CLI Logo with no Turtle Graphics
- Tooling Support
  - An abstract definition of a parser and associated syntax coloring and error types supporting an editor.    

[Development Log](Log.md)
