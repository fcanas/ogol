#  Logo Language

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


