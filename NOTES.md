# notes

Most scenes only have dialog changes or slight movement tweaks. Current design requires a lot of 
extra work, then, in order to transcribe what you want to keep into the alternative language.

There are two ways to make changes, editing the code inline, or rewriting with the DSL. Each has 
their own tradeoffs. So, we have to present a choice, rather than always choose one or the other.

* Bootstrap scene for editing by organizing into dialog and events
* Event code can be hardcoded in DSL just using scene context.
* Allow insertion into document directly for editing
* Or allow overriding with event DSL
