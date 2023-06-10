/**
 * Exception types
 */
module libsnooze.exceptions;

import libsnooze.event : Event;

/** 
 * The general libsnooze error type
 */
public abstract class SnoozeError : Exception
{
    /** 
     * Constructs a new `SnoozeError` with the provided
     * error message
     *
     * Params:
     *   msg = the error message
     */
    package this(string msg)
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
    /** 
     * The `Event` with which the error occurred on
     */
    private Event e;

    /** 
     * Constructs a new `InterruptedException` with
     * provided `Event`
     *
     * Params:
     *   e = the `Event` on which the error occurred
     */
    package this(Event e)
    {
        super("Interrupted whilst waiting on event '"~e.toString()~"'");
        this.e = e;
    }

    /** 
     * Returns the `Event` with with this error occurred
     *
     * Returns: the event
     */
    public Event getEvent()
    {
        return e;
    }
}

/** 
 * The sub-kind of fatal error
 */
public enum FatalError
{
    /** 
     * On error during a call to `wait()`
     */
    WAIT_FAILURE,

    /** 
     * On error during a call to `notify()`
     * or `notifyAll()`
     */
    NOTIFY_FAILURE
}

/** 
 * This exception is thrown during a call to `wait()`,
 * `notify()` or `notifyAll()` when a fatal error
 * occurs with the underlying eventing system
 */
public final class FatalException : SnoozeError
{
    private FatalError fatalType;

    package this(Event e, FatalError fatalType, string extra = "")
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