---
name: Refena StatelessWidget ref access
description: How to correctly access providers from StatelessWidgets in refena_flutter; and why Notifier has no overridable dispose().
---

## Rule
Never apply `with Refena` to a `StatelessWidget`. It is only valid on `State<T>` (StatefulWidget's state class).

**Why:** The `Refena` mixin attaches itself to the state lifecycle. StatelessWidget has no `initState`/`dispose`, so there is nothing to hook into — the mixin compiles but can silently break or cause "ref used outside widget tree" runtime errors.

**How to apply:** In StatelessWidgets, use the BuildContext extensions provided by refena_flutter:
- `context.read(provider)` — read once, no rebuild
- `context.watch(provider)` — subscribe, causes rebuild
- `context.read(provider.notifier)` — get the notifier
- `context.global.dispatchAsync(Action())` — global dispatch

## Rule
`Notifier<T>` in refena_flutter does NOT declare a virtual `dispose()` method.

**Why:** Refena notifiers are long-lived singletons tied to the `RefenaScope`. There is no per-consumer lifecycle.

**How to apply:** If you need timer/stream cleanup, cancel inside the *widget's* `dispose()` (State.dispose), not in the Notifier. Or simply let the timer run for the app's lifetime if acceptable (polling timers are usually fine).
