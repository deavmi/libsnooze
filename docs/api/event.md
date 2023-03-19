Event
=====

## The `Event` type

The `Event` type is at the core of the libsnooze system and is what provides the "wait/notify" mechanism, i.e. a group of threads _wait_
on an `Event` and another thread _notifies_ that `Event` to wake those waiting threads up.