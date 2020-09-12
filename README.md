# LogoLang

A compiler and virtual machine for a variant of the Logo computer language.

This project is organized into subcomponents:

- Execution
  - Describes a weird combination AST, runtime, and high-level virtual machine
- LogoLang
  - Contains a Parser converting this compilable variant of Logo to structures described in the Execution module.
- libLogo
  - Core libraries including math functions, Turtle Graphics, and  core language procedures that require interacting with the runtime such as `output`, `stop`, and `make`
- logo
  - A basic CLI logo with no Turtle Graphics
- Tooling Support
  - An abstract definition of a parser and associated syntax coloring and error types supporting an editor.    

[Development Log](Log.md)
