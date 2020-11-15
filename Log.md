#  Ogol Language

## 2020-11-14

I've made small changes in the parser including several useful changes in the language:
- Parameter lists for procedure declarations are enclosed in brackets [] and comma-separated
- Parameters for a procedure invocation are enclosed in brackets [] and comma-separated
- Parameters in a declaration remain preceded with a `:`
- Variable use no longer requires being preceded by `:` rather names listed without decoration are a "lookup", which may work its way into the runtime

This makes the implementation of `repeat` look like this:

```
to repeat[:count, :instructionList]
   if[count = 0, [stop[]]]
   run[instructionList]
   make["count", count - 1]
   repeat[count, instructionList]
end
```

I think I want to turn `:name` into declarations in general. Or writes into the local context with a new name. So then `make["foo", 3]` becomes `:foo = 3`. Or possibly `:foo` would be a reference into the context, allowing `make[:foo, 3]` to be possible, especially for `make` to be able to write into a context outside of itself. Procedure definitions could be handled in a similar way.

```
to [:repeat, [:count, :instructionList], [
      if[count = 0, [stop[]] ]
      run[instructionList]
      make["count", count - 1]
      repeat[count, instructionList]
   ]
]
```

Maybe some syntactic sugar for trailing lists could give a familiar syntax...

```
if [x < 5] {
   repeat [x] {
      fd[x]
      rt[20]
   }
}
```

The application to `to` could use some more thought, but the effect on `if` and `repeat` is relally nice.

```
to [:repeat, [:count, :instructionList]] {
   if [count = 0] { stop[] }
   run[instructionList]
   make["count", count - 1]
   repeat[count, instructionList]
}
```

## 2020-09-19

Logo is a lot like Lisp without the parenthesis. And that leads to some ambiguity in the language. `foo bar "baz` could be inerpreted as `(foo (bar "baz))` or `(foo bar "baz)`. The correct parsing requires knowldge of `bar`'s expected parameters at parse time. In Logo, that is done at run time. A good way to implement Logo is to implement a Lisp, then convert Logo input to Lisp. But that’s not what I wanted to build.

I'm interested in exploring a different syntax for a new language. The current Logo implementation is far from a complete, if incompatible, Logo. I'd like to keep it around, possibly pushing it closer to completion at some point. So I internally forked the project. The top level is now Ogol. The execution and tooling is substantially the same. libLogo is now libOgol, and is continues to be common to both languages. I will keep LogoLang, and I may continue improving it to improve compatibility with other Logos somewhat. And OgoLang is the new Ogol language package. It's currently an copy of Logo with some renaming. Parts of LogoLang and the executable CLI `logo` have moved to ToolingSupport, currently leaving just lexing and parsing to the "Lang" packages.

## 2020-08-15

Just to wrap up the thoughts around executable lists described in [2020-07-27(b)](#2020-07-27(b)): Adding a `command(ExecutionNode)` case to `Bottom`  has worked well. An internal mechanism to convert lists of bottoms to lists of `ExecutionNode`s when that's expected means that `run` can take a list as a parameter, convert to execution nodes, then run through them all. I was really delighted to find that I could then not only remove `repeat` from the language, but implement it _in Logo_!

```
to repeat :count, :instructionList
   if :count = 0 [ stop ]
   run :instructionList
   make "count :count - 1
   repeat :count :instructionList
end
```

I had usually thought of tail recursion as a mechanism that gets "optimized" to a loop. It's amusing to think of a loop being lazily implemented as tail recursion instead. The approach is amusing for now. And it's fun to see simple low-level pieces of the language be used in force-amplifying ways. 

I wonder whether Logo will target environment other than my own execution engine. And whether that execution engine will always remain a Swift executable. The target environment will start having an impact on the choices like these. I feel like this runtime is still sufficiently flexible that it's more important to keep working towards a comfortable environment to work in. Bad string support and ambiguous grammar is more of a hinderance right now. So I've been thinking of making a new language.

## 2020-07-27(b)

How to get lists of instructions? Are they `Value`s or `Bottom`s? `Value` didn't work well. So I'm trying to make an `ExecutableNode` exist in `Bottom` as a command. Then I can use a `List`.

## 2020-07-27

From late may to early June, I took on some interesting refactoring efforts that modularized a lot of the language. 

First, turtle graphics left the language and made was converted into a module. This reduced the special cases in lexing and parsing. It didn't drastically simplify parsing on its own, but it definitely reduced the amount of parsing code. Now, the turtle graphics module is more bound to the runtime than the language. It needs to set up structures to track a turtle in an execution context. Then the procedures that manipulate the turtle and the canvas act on those structures.

I don't remember whether it was the extraction of the turtle alone, but around this time I began to notice performance problems. So I removed some indirection. I fixed some over-aggressive creation of execution contexts during execution, and also added tail recursion. I created a mechanism for program nodes to simplify themselves, for example pre-computing arithmetic operations.

I also made all execution nodes serializable. So parsed programs could be saved to arbitrary Codable formats. I was really excited by serialization because while currently the programs can basically be serialized to JSON or plists, it highlights the opportunity to "serialize" into executable formats. I've been thinking about wasm specifically, mostly as a way to learn more about the technology, but also as an interesting low-level target "architecture" that will be supported on a lot of platforms!

I also started a new REPL front-end for macOS that uses SVG output and a web view for rendering. It's a little more focused on giving the user access to the execution environment rather than being an IDE/document editor.

Then I became discouraged about the suitibility of Logo as a pre-parsed, pre-compiled language. The problem is in Logo's lack of delimiters for procedure invocations. Consider the following line:

```
MAKE "fib LIST 1 1 2 3 5
```

Without knowing how many arguments each of `MAKE` and `LIST` accept, this is not a parsable line. It's not known whether `LIST` should take two parameters and return one, leaving 5 total parameters to `MAKE`, or to (mostly correctly) have `LIST` take anywhere from no parameters to all the parameters remaining on the line.  But it is, as far as I know, this is idomatic Logo. And because the line will not be parsed until it is _executed_, then the number of desired parameters to `MAKE` and `LIST` can be checked at run-time.

I thought of taking a lot of different directions:

LISP:
```
(make "fib (list 1 1 2 3 5))
```

C:
make("fib, list(1, 1, 2, 3, 5))

Add labels for parameters, requiring syntax for variadic procedures, breaking the elegance of the LIST procedure:

```
make name:"fib value: list :values (1, 1, 2, 3, 5)
```

Or Lift blocks up to return the value of their last expression, and require ambiguous sequences to be carved up, anything else is undefined behavior TBD at runtime:

```
make "fib [list 1 1 2 3 5]
```

Maybe the language needs procedure declarations. Maybe the language and runtime needs to allow for unparsed fragments to be resolved during an optimization step before running?

The whole situation around multiple and variadic arguments is fraught. And so I set it aside for a few weeks in July. Until about a week ago, when I decided to just add variadic arguments with an optional Rest parameter borrowed from [UCBLogo](https://people.eecs.berkeley.edu/~bh/usermanual), and explored where that led:

```
to list [:elements]
    output :elements
end
```

It's mostly leading to reducing the viability of consecutive statements on one line, as it can confuse the parser. And the excitement of the above implementation of `list` as a convenient side-effect of the Rest parameter led me to wanting to implement more of the core language in Logo itself.

### Self-Hosting

After an initial burst of excitement after implementing `list`, I quickly hit a bit of a wall.

```
to list [:elements]
   output :elements
end

to add :lhs, :rhs
   output :lhs + :rhs
end

to sub :lhs, :rhs
   output :lhs - :rhs
end

to mul :lhs, :rhs
   output :lhs * :rhs
end

to div :lhs, :rhs
   output :lhs / :rhs
end
```

My Logo didn't yet have much in the way of iterations -- foreach needs lists, and those are brand new, and for loops are sort of parsed but not implemented. But most control structures look like they could be implemented in Logo itself, given a few additions to the language (indeed other Logos do have a lot of their common procedures that define the language written in Logo).

So at the core of many control structures is a boolean type. Adding a boolean type, and reducing the amount of special parsing code for `IF` was the first step towards a more self-hosted Logo. While the language still doesn't have `true` or `false` keywords, Expressions were expanded to handle logical types. What was an expression before became an arithmetic expression:

```
arithmeticExpression
: multiplyingExpression (('+' | '-') multiplyingExpression)*
```

And a new Expression type was added that is an arithmetic expression, optionally compared against another arithmetic expression.

```
expression
: arithmeticExpression (('<'|'>'|'=') arithmeticExpression)
```

And now the parsing structure for  `IF` is nearly indistinguishable from a `REPEAT`. Once I convert the "blocks" following the constructs' keyword and condition, they should be readily expressible as regular procedures -- even if they may initially require direct access to the runtime rather than being native Logo procedures.

## 2020-05-17

I recently added the ability for procedures to return values.
An output command triggers an execution handoff of type `output` with the parameter. 
Then a procedure invocation can be "executed" as normal, which won't do aything special with the output.
But a procedure invocation can now be "evaluated" as well. 
And now procedure invocations exist as Values through that path.
It was exciting to see it working with fairly little code.

There are some interesting optimizations I could make too.
I should be able to do tail-call optimizations reasonably easily.
If procedures can be identified as pure (not writing to variables outside their scope, or triggering turtle commands), they may be able to run without creating a new context.
It's possible Turtle state should be put into the execution context as well.
That would be an interesting way to push more of the language into native procedures.

I've thinking about adding native extensions for math, for `random`, `cos`, `sin` and the like.
I was able to add many of these in a matter of minutes.
I made a simple interface for defining and loading modules.
The Math module packaged in the language, and the program defininf a CLI module.
This may be a really interesting way to do turtle commands too, and pull them out of the language.

-----


