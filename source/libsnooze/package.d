module libsnooze;

public import libsnooze.event : Event;
public import libsnooze.exceptions;

// TODO: See if this fixes when importing
// public import clib;
// public import libsnooze

mixin template ImportFix()
{
    import libsnooze.clib;
    import libsnooze;
}

// Cuases build issues but atleast unit tests work
mixin ImportFix!();
