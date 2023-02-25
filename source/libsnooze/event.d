module libsnooze.event;

import libsnooze.clib : pipe, write, read;
import libsnooze.clib : select, fd_set, fdSetZero, fdSetSet;
import libsnooze.clib : timeval, time_t, suseconds_t;
import core.thread : Thread, Duration, dur;
import core.sync.mutex : Mutex;
import libsnooze.exceptions : SnoozeError;

public class Event
{
	/* Array of [readFD, writeFD] pairs/arrays */
	private int[2][Thread] pipes;
	private Mutex pipesLock;

	private bool nonFail = false;

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
		else version(Windows)
		{
			throw SnoozeError("Platform Windows is not supported");
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
	 * Wait on this event indefinately
	 */
	public final void wait()
	{
		wait(dur!("seconds")(0));
	}

	private int[2] pipeExistenceEnsure(Thread thread)
	{
		int[2] pipePair;

		/* Lock the pipe-pairs */
		pipesLock.lock();

		/* If it is not in the pair, create a pipe-pair and save it */
		if(!(thread in pipes))
		{
			// TODO: Add a catch here, then unlock then rethrow
			pipes[thread] = newPipe();  //TODO: If bad (exception)
		}

		/* Grab the pair */
		pipePair = pipes[thread];

		/* Unlock the pipe-pairs */
		pipesLock.unlock();

		return pipePair;
	}

	// NOTE: Returns true on woken, false on timeout
	private final bool wait(timeval timestruct)
	{
		/* Get the thread object (TID) for the calling thread */
		Thread callingThread = Thread.getThis();

		/* Lock the pipe-pairs */
		pipesLock.lock();

		/* Checks if a pipe-pair exists, if not creates it */
		// TODO: Add a catch here, then unlock, rethrow
		int[2] pipePair = pipeExistenceEnsure(callingThread);

		/* Unlock the pipe-pairs */
		pipesLock.unlock();


		/* Get the reand-end of the pipe fd */
		int readFD = pipePair[0];

		// TODO: IO/queue block using select with a timeout
		// select();

		// NOTE: Not sure why but nfdsmust be the highest fd number that is being monitored+1
		// ... so in our case that must be `pipePair[0]+1`

		// Setup the fd_set for read fs struct

		/** 
		 * Setup the fd_set for read file descriptors
		 * 
		 * 1. Initialize the struct with FD_ZERO
		 * 2. Add the file descriptor of interest i.e. `readFD`
		 */
		fd_set readFDs;
		fdSetZero(&readFDs);
		fdSetSet(readFD, &readFDs);

		/** 
		 * Now block till we have a change in `readFD`'s state
		 * (i.e. it becomes readbale without a block). However,
		 * if a timeout was specified we can then return after
		 * said timeout.
		 */
		int status = select(readFD+1, &readFDs, null, null, &timestruct);

		/** 
		 * If timeout was 0 then it blocks till readable and hence the
		 * status would then be non-zero. The only way it can be `0` is if
		 * the timeout was non-zero meaning it returned after timing out and
		 * nothing changed in any fd_set(s) (nothing became readable)
		 */
		if(status == 0)
		{
			// TODO: Handle timeout
			return false;
		}
		// TODO: Check the -1 case
		else
		{
			// TODO: Perform read now to clear sttaus for next wait()
			/* Get the read end and read 1 byte (won't block) */
			byte singleBuff;
			read(readFD, &singleBuff, 1);
			// TODO: ENsure no IO exception

			return true;
		}

		// TODO: Then perform read to remove the status of "readbale"
		// ... such that the next call to select still blocks if a notify()
		// ... is yet to be called

		
	}

	/** 
	 * Waits on the event with a given timeout
	 *
	 * Params:
	 *   duration = the timeout
	 */
	public final bool wait(Duration duration)
	{
		/* Split out the duration into seconds and microseconds */
		time_t seconds;
		suseconds_t microseconds;
		duration.split!("seconds", "msecs")(seconds, microseconds);

		version(dbg)
		{
			/* If debugging enable, then print out these duirng compilation */
			pragma(msg, time_t);
			pragma(msg, suseconds_t);
		}
		
		/* Generate the timeval struct */
		timeval timestruct;
		timestruct.tv_sec = seconds;
		timestruct.tv_usec = microseconds;

		/* Call wait with this time duration */
		return wait(timestruct);
	}

	/** 
	 * Wakes up a single thread specified
	 *
	 * Params:
	 *   thread = the Thread to wake up
	 */
	public final void notify(Thread thread)
	{
		// TODO: Implement me
		// TODO: Throw error if the thread is not found

		/* Lock the pipe-pairs */
		pipesLock.lock();

		/* If the thread provided is wait()-ing on this event */
		if(thread in pipes)
		{
			/* Obtain the pipe pair for this thread */
			int[2] pipePair = pipes[thread];

			/* Obtain the write FD */
			int pipeWriteEnd = pipePair[1];

			/* Write a single byte to it */
			byte wakeByte = 69;
			write(pipeWriteEnd, &wakeByte, 1); // TODO: Collect status and if bad, unlock, throw exception
		}
		/* If the thread provided is NOT wait()-ing on this event */
		else
		{
			// TODO: Make this error configurable, maybe a non-fail mode should ne implementwd
			if(!nonFail)
			{
				/* Unlock the pipe-pairs */
				pipesLock.unlock();

				throw new SnoozeError("Provided thread has yet to call wait() atleast once");
			}	
		}

		/* Unlock the pipe-pairs */
		pipesLock.unlock();
	}

	/** 
	 * Wakes up all threads waiting on this event
	 */
	public final void notifyAll()
	{
		/* Lock the pipe-pairs */
		pipesLock.lock();

		/* Loop through each thread */
		foreach(Thread curThread; pipes.keys())
		{
			/* Notify the current thread */
			notify(curThread);
		}

		/* Unlock the pipe-pairs */
		pipesLock.unlock();
	}

	private int[2] newPipe()
	{
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
	import std.stdio : writeln;
	import libsnooze.clib : select, fd_set, fdSetZero, fdSetSet;


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
	event.notifyAll();

	/* Wait for all threads to exit */
	thread1.join();
	thread2.join();
}

unittest
{
	import std.conv : to;
	import core.thread : dur;
	import std.stdio : writeln;
	import libsnooze.clib : select, fd_set, fdSetZero, fdSetSet;

	Event event = new Event();

	class MyThread : Thread
	{
		this()
		{
			super(&worker);
		}

		public void worker() {}
	}
	Thread thread1 = new MyThread();

	try
	{
		/* Wake up a thread which isn't waiting (or ever registered) */
		event.notify(thread1);

		assert(false);
	}
	catch(SnoozeError e)
	{
		assert(true);
	}
}