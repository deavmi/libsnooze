/**
 * Exception types
 */
module libsnooze.exceptions;

public class SnoozeError : Exception
{
    package this(string msg)
    {
        super(msg);
    }
}