#  Logo Language

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


