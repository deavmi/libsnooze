module libsnooze.exceptions;

import libsnooze.event : Event;

public class SnoozeError : Exception
{
    this(string msg)
    {
        super(msg);
    }
}
/** 
 * This exception is thrown if the call to `wait()`
 * was interrupted for some reason
 */
public final class InterruptedException : SnoozeError
{
    private Event e;

    this(Event e)
    {
        super("Interrupted whilst waiting on event '"~e.toString()~"'");
        this.e = e;
    }

    public Event getEvent()
    {
        return e;
    }
}

// public final class WaitException : SnoozeError
// {

// }

// public final class NotifyException : SnoozeError