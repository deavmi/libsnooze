libsnooze
=========

#### _A wait/notify mechanism for D_

----

## Usage

Firstly we create an `Event` which is something that can be notified or awaited on. This is simply accomplished as follows:

```d
Event myEvent = new Event();
```

Now let's create a thread which consumes `myEvent` and waits on it:

```d
class TestThread : Thread
{
    private Event event;

    this(Event event)
    {
        super(&worker);
        this.event = event;
    }

    public void worker()
    {
        writeln("("~to!(string)(Thread.getThis().id())~") Thread is waiting...");
        event.wait();
        writeln("("~to!(string)(Thread.getThis().id())~") Thread is waiting... [done]");
    }
}

TestThread thread1 = new TestThread(event);
thread1.start();
```

Now on the main thread we can do the following to wakeup waiting threads:

```d
/* Wake up all sleeping on this event */
event.notifyAll();
```

## API

To see the full documentation (which is always up-to-date) check it out on [DUB](https://libsnooze.dpldocs.info/).

## Installing

In order to use libpb in your project simply run:

```bash
dub add libsnooze
```

Currently importing just with `import libsnooze` is broken, we recommend you import as follows:

```d
import libsnooze.clib;
import libsnooze;
```