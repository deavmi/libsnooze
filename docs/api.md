API
===

There isn't all too much in terms of the methods exposed via the API as the functionality provided is a rather simple mechanism. There
are, however, some methods of interest and some important things to note when using them.


## The `Event` type

The `Event` type is at the core of the libsnooze system and is what provides the "wait/notify" mechanism, i.e. a group of threads _wait_
on an `Event` and another thread _notifies_ that `Event` to wake those waiting threads up.


## Methods

TODO: Add `notify(Thread)`, `notifyAll()`, etc here


## Notes

### Notify stuff

TODO: Add stuff about ensurity