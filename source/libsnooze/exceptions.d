/**
 * Exception types
 */
module libsnooze.exceptions;

/** 
 * The general libsnooze error type
 */
public class SnoozeError : Exception
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