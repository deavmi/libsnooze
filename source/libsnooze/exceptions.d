module libsnooze.exceptions;

public class SnoozeError : Exception
{
    this(string msg)
    {
        super(msg);
    }
}