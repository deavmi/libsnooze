<p align="center">
<img src="branding/logo.png" width=220>
</p>

<br>

<h1 align="center">libsnooze</h1>

<h3 align="center"><i><b>A wait/notify mechanism for D</i></b></h3>

---

<br>
<br>

[![D](https://github.com/deavmi/libsnooze/actions/workflows/d.yml/badge.svg)](https://github.com/deavmi/libsnooze/actions/workflows/d.yml)

## API

To see the full documentation (which is always up-to-date) check it out on [DUB](https://libsnooze.dpldocs.info/).

## Usage

### Importing issues

Currently importing just with `import libsnooze` is broken, we recommend you import as follows:

```d
import libsnooze.clib;
import libsnooze;
```

Which should build!

### Example

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

        try
        {
            /* Wait */
            event.wait();
            writeln("("~to!(string)(Thread.getThis().id())~") Thread is waiting... [done]");
        }
        catch(InterruptedException e)
        {
            writeln("Had an interrupt");
        }
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
