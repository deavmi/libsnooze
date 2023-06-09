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

public enum FatalError
{
    WAIT_FAILURE,
    NOTIFY_FAILURE
}

public final class FatalException : SnoozeError
{
    private FatalError fatalType;

    this(Event e, FatalError fatalType, string extra = "")
    {
        string msg;
        if(fatalType == FatalError.NOTIFY_FAILURE)
        {
            msg = "There was an error notifying event '"~e.toString()~"'";
        }
        else
        {
            msg = "There was an error waiting on the event '"~e.toString()~"'";
        }
        msg = msg~extra;

        super(msg);
        this.fatalType = fatalType;
    }

    public FatalError getFatalType()
    {
        return fatalType;
    }
}