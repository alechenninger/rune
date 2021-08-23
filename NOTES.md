# notes

Most scenes only have dialog changes or slight movement tweaks. Current design requires a lot of 
extra work, then, in order to transcribe what you want to keep into the alternative language.

There are two ways to make changes, editing the code inline, or rewriting with the DSL. Each has 
their own tradeoffs. So, we have to present a choice, rather than always choose one or the other.

* Bootstrap scene for editing by organizing into dialog and events
* Event code can be hardcoded in DSL just using scene context.
* Allow insertion into document directly for editing
* Or allow overriding with event DSL

## google docs workflow

1. (Mike) Add new scene
2. (Alec) insert existing event flags (event code reused at this point)
3. Generate rom
   ```
   -> generate each scene asm
   -> upload to drive
   -> ping lab builder
   -> builder uploads latest to drive / responds with download url
   (or can use google drive sync app)
   ```

   or can github actions be used in a productive way here?
4. play

event code can be edited inline somehow (e.g. own dsl, or inline assembly as footnotes, or 
image(s) with description alt text, or ...).

after edits, repeat from 3.

### google docs parsing

portrait image - alt text is character name. text in same paragraph is dialog

image alt text could also be used for cutscene panels

just ignore paragraph text otherwise.
