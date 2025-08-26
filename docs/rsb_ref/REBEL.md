# 💀  REBEL

Rust Rebel is the soft layer over Rust’s hard edges, translating the language’s often terse, academic naming conventions into accessible, intuitive terms.

Rust’s core vocabulary is powerful but unwelcoming. Concepts that have obvious idioms in other languages are wrapped in unnecessarily esoteric names and diva patterns.

Rebel exists to ~~normalize~~ shit on those patterns, and provide meaningful mental anchors so you don’t need a PhD or a fetish for category theory to feel at home.


Many concepts in Rust ship without strong domain metaphors; Rebel fills that gap by naming things from first principles, and throws Rustiness out the window when it gets in the way of mental modeling.

Rebel is the anomaly in Rustland — the stuff no one tells you.

We (I) have absolutely **nothing** to do with the Rust Foundation, besides bending Rust to our (my) will.


## You may be wondering how I got here.


Why am I here? *sigh* It's an abusive relationship at this point. I came for the hype found some gems, and put up with the ugly. And this coming from someone crazy enough to write 4000 lines of bash code without breaking a sweat.

I used to think I was the Lord of Junkyard Engineering, but Rust takes it to another level. Big brain flying monkies are going to akshually the shit out of this, but I got one thing to say, I am not a PhD, but you can call me Dr Vega*junk* aka Mr. Zero Fucks.


## Module Patterns

Rust doesnt provide a friendly mental anchor to hang your hat on here; so Rebel takes the liberty of naming them on behalf of everyone:

**Naive Mod Pattern** (as in I have no idea how to design a modular system)

Using `mod.rs` inside of a directory to  **hoist** faces, types and functions into the parent scope. This pattern is older but still supported.

```bash
mod_name/
 ├─ mod.rs
 ├─ foo.rs
 └─ bar.rs
```
Inside `mod.rs`

```rust
// mod_name/mod.rs
pub mod foo;
pub mod bar;
```

Seems tame, unless you have more than 2 of these bad boys open.

**Nice Neighbor Pattern** (nice as in neighbors telling you how to decorate your house)

Using a sibling file `mod_name.rs` that matches a directory `mod_name`, the mod_name.rs file acts as mod.rs does in the older pattern. But unlike mod.rs it is outside of the folder lol. They did this so you dont have to shuffle through ambigously named mod files. An improvement of sorts, still wreaks of I dont know how to design a modular system.

```bash
mod_name.rs
mod_name/
 ├─ foo.rs
 └─ bar.rs
```
Inside `mod_name.rs`

```rust
// mod_name.rs
// an improvement but still suffers from nosey neighbors
pub mod foo;
pub mod bar;
```

**💀 Rebel Smart Pattern** (A Proposal)

In an ideal world you wouldn't need a file to prime the hoisting mechanism; the compiler should be smarter about what needs to be exported.


```bash
mod_name/
 ├─ foo.rs
 └─ bar.rs
```
Inside `foo.rs`, it would be **hot** if files could just define their own exports. They have the power of the file boundary, and within that boundary it would make a hella of a lot more sense if files  decide what to shape and reveal rather than having some other external file do it for them. Be gone, you have no power here external file!


```rust
// mod_name/foo.rs
pub export Foo, foo_stats;
pub super export FooConfig;

```

The flying monkeys will scream, "But this breaks the explicit module tree! The compiler needs a single root for each submodule to know what exists!" The explicit module tree? no **funk** that. 

You see with your own two virtual eyes that files are bounded modules and theyre in a folder, like DUH. Just create a stub and put the exports in it. Compiler why you no module discovery?


## Shitty Functions, Diva Compiler

Some times our brains are just way too big for the entire universe to contain them all, not to mention the infinite layers of meta data needed to describe our unfathomable intelligence. We all know that sentience is what happens when conciousness finally sees itself in the mirror, right? wrong. Look at this ~~Tarzan hieroglyphic looking~~ shit:

> Function implements Violence

```rust
// This is nothing less than utter violence against human cognition. 
// no seriously. what is this shit?
fn process_data<T, E>(
    input: &mut Vec<Option<Result<T, E>>>,
    processor: impl Fn(&T) -> Result<T, E>,
    filter: Option<&dyn Fn(&T) -> bool>
) -> Result<Vec<T>, ProcessingError<E>>
```

This is arguably one of *many* things keeping people from learning Rust. It is a dyslexic's nightmare. Sure, if you have to stare at insanity like this for 16 hours a day you *might* think this was normal, but I'd argue that one of the fundamnetal principles of good software design is **legibility**. 

A professor I deeply respect once said and I quote 

> "A true sign of *intelligence* is doing more with **less**." 


Elegance and simplicity are not conveniences, but rather obvious signs of a well designed system. On that note, let's turn our attention to the diva herself: the compiler. 

Why is the Rust compiler such a ✨princess✨ that she needs you to show up in full gown, makeup and heels for a casual rendevouz? And then to add insult to injury she has the audacity to tell you how to curtsie correctly if you skip a beat.


```rust

error[E0308]: mismatched types
  --> src/main.rs:42:5
   |
42 |     return arg;
   |            ^^^ expected `Result<Context, ContextError>` but found `Context`
   |
help: try wrapping the expression in `Ok`:
   |
42 |     return Ok(arg);
   |            +++   +

```
"Oh, you didn't wrap it in Ok()? Let me explain proper error handling etiquette to you, peasant."

Some people think the compiler is being "nice", if it were nice it would fix it for me and shut up. The correct word is *pendantic*. Havent you heard? This is the era of Automation ya'll. **Don't make the user do work the machine can do.**

Rust isnt sending anyone to Mars *yet*.


**💀 Rebel "Hot Rod" Function** (A Proposal)

Look at this beautiful hot rod. Isn't it divine? Just one ride, thats all I want, do your crazy shit in the function not outside of it. Yes, yes, yes type checking. Thats fine this doesnt eskew type checking, it requires one less brain cell firing on all cylinders to understand; also makes functional programming (chaining) hella easier for FREE. Who doesnt love free shit?

```rust

//Context implements the Argument trait and a Result trait lol

fn process_data( arg: Context ... ) -> Context {

  //do stuff to args innards
  return arg;

}

```


Performance purists might raise concerns about the "Hot Rod" approach, arguing that the hyper-explicit generic signatures allow for finer-grained monomorphization and optimization by the compiler. (The Rebel retort, of course, is that this is a premature optimization that costs more in developer sanity than it saves in nanoseconds)


## Rebel Asides

The annoying *paradox* of Rust is that it forces you to be hyper-explicit about the shape of your abstractions. 

"Generic" says: "This will work for anything." The Rust function signature then adds a list of non-negotiable demands: "...as long as that 'anything' fits into this exact box, wrapped in this specific paper, tied with this particular bow, and adheres to these seventeen rules of etiquette."

It's like telling an architect, "I want a generic building," and then handing them a thousand-page specification detailing the exact tensile strength of every screw.

It's a design philosophy that is fundamentally at odds with itself, and it's the developer who pays the cognitive price for that contradiction. (I suspect this is why some struggle with asynchronous programming in Rust or avoid it altogether.)

I guess it could be worse. *coNIXugh*. Something in my throat... as I was saying...

## Hyper-explicit generic is an oxymoron.
There I said it. Emperor has no clothes, no war in Bah Sin Se etc...good times. 

Another quote that captures the spirit of what I am trying to do here, by renowned dancer Martha Graham, goes something along the lines of, 

> If you never share your unique expression with the universe, it will never have it. It will only live in your head and your contribution will be lost forever. 

Or something to that effect.

Every developer, coder, engineer who could have ever created something amazing by the power Rust gives, may never be able to wield the tool and paint with its colors. And again, this is coming from someone whose obsession with Bash is Moby Dick levels of insane.

More "Junkyard Engineering" asides later. Ciao for now.  Dr. VJ 💀
