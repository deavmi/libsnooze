module libsnooze.event;

import libsnooze.clib : pipe, write, read;
import core.thread : Thread;
import core.sync.mutex : Mutex;
import libsnooze.exceptions : SnoozeError;

// TODO: Remove the below import - it is only for testing
import std.stdio : writeln;

public class Event
{
	/* Array of [readFD, writeFD] pairs/arrays */
	private int[2][Thread] pipes;
	private Mutex pipesLock;

	this()
	{
		internalInit();
	}

	private void internalInit()
	{
		version(Linux)
		{
			// TODO: Switch to eventfd in the future
			initPipe();
		}
		else
		{
			initPipe();
		}
	}

	private void initPipe()
	{
		/* Create a lock for the pipe-pair array */
		pipesLock = new Mutex();
	}

	/** 
	 * Wait on this event
	 */
	public final void wait()
	{
		import core.thread;

		/* Get the thread object (TID) for the calling thread */
		Thread callingThread = Thread.getThis();

		/* Lock the pipe-pairs */
		pipesLock.lock();

		/* Checks if a pipe-pair exists, if not creates it */
		int[2] pipePair = pipeExistenceEnsure(callingThread);

		/* Unlock the pipe-pairs */
		pipesLock.unlock();

		/* Get the read end and read 1 byte (blockingly) */
		int readFD = pipePair[0];
		byte singleBuff;
		read(readFD, &singleBuff, 1);


	}

	private int[2] pipeExistenceEnsure(Thread thread)
	{
		int[2] pipePair;

		/* Lock the pipe-pairs */
		pipesLock.lock();

		/* If it is not in the pair, create a pipe-pair and save it */
		if(!(thread in pipes))
		{
			pipes[thread] = newPipe();  //TODO: If bad (exception)
		}

		/* Grab the pair */
		pipePair = pipes[thread];

		/* Unlock the pipe-pairs */
		pipesLock.unlock();

		return pipePair;
	}

	public final void notify()
	{
		/* Lock the pipe-pairs */
		pipesLock.lock();

		/* Loop through each pipe-pair */
		foreach(int[2] pipePair; pipes)
		{
			/* Obtain the write FD */
			int pipeWriteEnd = pipePair[1];

			/* Write a single byte to it */
			byte wakeByte = 69;
			write(pipeWriteEnd, &wakeByte, 1); // TODO: Collect status and if bad, unlock, throw exception
		}

		/* Unlock the pipe-pairs */
		pipesLock.unlock();
	}

	private int[2] newPipe()
	{
		

		// writeln(pipes[0]);

		/* Allocate space for the two FDs */
		int[2] pipePair;

		// /* Create a new pipe and put the fd of the read end in [0] and write end in [1] */
		int status = pipe(pipePair.ptr);

		/* If the pipe creation failed */
		if(status != 0)
		{
			// Throw an exception is pipe creation failed
			throw new SnoozeError("Could not initialize the pipe");
		}

		return pipePair;
	}
}

unittest
{
	import std.conv : to;
	import core.thread : dur;

	Event event = new Event();

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

	TestThread thread2 = new TestThread(event);
	thread2.start();

	Thread.sleep(dur!("seconds")(10));
	writeln("Main thread is going to notify two threads");


	// TODO: Add assert to check

	/* Wake up all sleeping on this event */
	event.notify();
}