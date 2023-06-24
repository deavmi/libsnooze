/**
 * The `Event` type and facilities
 */
module libsnooze.event;

// TODO: Would be nice if this built without unit tests failing
// ... so I'd like libsnooze.clib to work as my IDE picks up on
// ... it then

version(release)
{
	import libsnooze.clib : pipe, write, read;
	import libsnooze.clib : select, fd_set, fdSetZero, fdSetSet;
	import libsnooze.clib : timeval, time_t, suseconds_t;
}
else
{
	import clib : pipe, write, read;
	import clib : select, fd_set, fdSetZero, fdSetSet;
	import clib : timeval, time_t, suseconds_t;
}

import core.thread : Thread, Duration, dur;
import core.sync.mutex : Mutex;
import libsnooze.exceptions;
import std.conv : to;
import core.stdc.errno;

/** 
 * Represents an object you can wait and notify/notifyAll on
 */
public class Event
{
	/* Array of [readFD, writeFD] pairs/arrays */
	private int[2][Thread] pipes;
	private Mutex pipesLock;

	private bool nonFail = false;

	/** 
	 * Constructs a new Event
	 */
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
			pragma(msg, "Buulding on linux uses the `pipe(int*)` system call");
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
	 *
	 * Throws:
	 *   `InterruptedException` if the `wait()`
	 * was interrupted for some reason
	 * Throws:
	 *   `FatalException` if a fatal error with
	 * the underlying mechanism occurs
	 */
	public final void wait()
	{
		/* Wait with no timeout (hence the null) */
		wait(null);
	}

	/** 
	 * Ensures that the calling Thread gets a registered
	 * pipe added for it when called.
	 *
	 * This can be useful if one wants to initialize several
	 * threads that should be able to all be notified and wake up
	 * on their first call to wait instead of having wait
	 * ensure the pipe is created on first call.
	 */
	public final void ensure()
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
	}


	// TODO: Make this a method we can call actually

	/** 
	 * Returns the pipe-pair for the mapped `Thread`
	 * provided. if one does not exist then it is
	 * created first and then returned.
	 *
	 * Throws:
	 *   `FatalException` on creating the pipe-pair
	 * if needs be
	 * Params:
	 *   thread = the `Thread` to ensure for
	 * Returns: the pipe-pair as an `int[]`
	 */
	private int[2] pipeExistenceEnsure(Thread thread)
	{
		int[2] pipePair;

		/* Lock the pipe-pairs */
		pipesLock.lock();

		/* On successful return or error */
		scope(exit)
		{
			/* Unlock the pipe-pairs */
			pipesLock.unlock();
		}

		/* If it is not in the pair, create a pipe-pair and save it */
		if(!(thread in pipes))
		{
			pipes[thread] = newPipe();
		}

		/* Grab the pair */
		pipePair = pipes[thread];

		return pipePair;
	}
	
	/** 
	 * Waits for the time specified, returning `true`
	 * if awoken, `false` on timeout (if specified as
	 * non-zero).
	 *
	 * Throws:
	 *   `InterruptedException` if the `wait()` was
	 * interrupted for some reason.
	 * Throws:
	 *   `FatalException` on fatal error with the
	 * underlying mechanism.
	 *
	 * Params:
	 *   timestruct = the `timeval*` to indicate timeout period
	 * Returns: `true` if awoken, `false` on timeout
	 */
	private final bool wait(timeval* timestruct)
	{
		/* Get the thread object (TID) for the calling thread */
		Thread callingThread = Thread.getThis();

		/* Checks if a pipe-pair exists, if not creates it */
		int[2] pipePair = pipeExistenceEnsure(callingThread);


		/* Get the read-end of the pipe fd */
		int readFD = pipePair[0];

		// NOTE: Not sure why but nfdsmust be the highest fd number that is being monitored+1
		// ... so in our case that must be `pipePair[0]+1`

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
		int status = select(readFD+1, &readFDs, null, null, timestruct);

		/** 
		 * The number of Fds (1 in this case) ready for reading is returned.
		 *
		 * This means that if we have:
		 *
		 * 1. `1` returned that then `readFD` is available for reading
		 *
		 * If timeout was 0 (timeval* is NULL) then it blocks till readable
		 * and hence the status would then be non-zero. The only way it can
		 * be `0` is if the timeout was non-zero (timeval* non-NULL) meaning
		 * it returned after timing out and nothing changed in any fd_set(s)
		 * (nothing became readable)
		 */
		if(status == 0)
		{
			return false;
		}
		/**
		 * On error doing `select()`
		 *
		 * We check the `errno` as this could be an error resulting
		 * from an unblock due to a signal having been received, in
		 * that specific case we don't want to throw an error but rather
		 * an interrupted exception.
		 */
		else if(status == -1)
		{
			// Retrieve the kind-of error
			int errKind = errno();

			version(dbg)
			{
				import std.stdio;
				writeln("select() interrupted, errno: ", errKind);
			}

			// Handle as an interrupt
			if(errKind == EINTR)
			{
				throw new InterruptedException(this);
			}
			// Anything else is a legitimate error
			else
			{
				throw new FatalException(this, FatalError.WAIT_FAILURE, "Error selecting pipe fd '"~to!(string)(readFD)~"' when trying to wait(), got errno '"~to!(string)(errKind)); 
			}
		}
		/* On success */
		else
		{
			/* Get the read end and read 1 byte (won't block) */
			byte singleBuff;
			ptrdiff_t readCount = read(readFD, &singleBuff, 1); // TODO: We could get EINTR'd here too

			/* If we did not read 1 byte then there was an error (either 1 or -1) */
			if(readCount != 1)
			{
				throw new FatalException(this, FatalError.WAIT_FAILURE, "Error reading pipe fd '"~to!(string)(readFD)~"' when trying to wait()");
			}

			return true;
		}

		// TODO: Then perform read to remove the status of "readbale"
		// ... such that the next call to select still blocks if a notify()
		// ... is yet to be called

		
	}


	/** 
	 * Determines whether this event is ready or not, useful for checking if
	 * a wait would block if called relatively soon
	 *
	 * Returns: true if it would block, false otherwise
	 *
	 * TODO: Test this and write a unit test (it has not yet been tested)
	 */
	private final bool wouldWait()
	{
		/* Would we wait? */
		bool waitStatus;

		/* Get the thread object (TID) for the calling thread */
		Thread callingThread = Thread.getThis();

		/* Checks if a pipe-pair exists, if not creates it */
		int[2] pipePair = pipeExistenceEnsure(callingThread);


		/* Get the read-end of the pipe fd */
		int readFD = pipePair[0];

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
		 * Now we set a timeout that is very low so we can return
		 * very quickly, and then determine if within the deadline
		 * it became readable ("would not wait") or we exceeded the deadline and it 
		 * was not readable ("would wait")
		 */
		timeval timestruct;
		timestruct.tv_sec = 0;
		timestruct.tv_usec = 1;
		int status = select(readFD+1, &readFDs, null, null, &timestruct);

		/* If we timed out (i.e. "it would wait") */
		if(status == 0)
		{
			return true;
		}
		/* TODO: Handle select() errors */
		else if(status == -1)
		{
			// TODO: Handle this
			return false;
		}
		/* If we have a number of fds readable (only 1) (i.e. "it would NOT wait") */
		else
		{
			return false;
		}



		// return waitStatus;
	}

	/** 
	 * Waits for the time specified, returning `true`
	 * if awoken, `false` on timeout
	 *
	 * Params:
	 *   duration = the `Duration` to indicate timeout period
	 * Returns: `true` if awoken, `false` on timeout
	 * Throws:
	 *   `FatalException` on fatal error with the
	 * underlying mechanism
	 * Throws:
	 *   `InterruptedException` if the `wait()` was
	 * interrupted for some reason
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
		return wait(&timestruct);
	}

	/** 
	 * Wakes up a single thread specified
	 *
	 * Params:
	 *   thread = the Thread to wake up
	 * Throws:
	 *   `FatalException` if the underlying
	 * mechanism failed to notify
	 */
	public final void notify(Thread thread)
	{
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

				throw new FatalException(this, FatalError.NOTIFY_FAILURE, "Provided thread has yet to call wait() atleast once");
			}	
		}

		/* Unlock the pipe-pairs */
		pipesLock.unlock();
	}

	/** 
	 * Wakes up all threads waiting on this event
	 *
	 * Throws:
	 *   `FatalException` if the underlying
	 * mechanism failed to notify
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

	/** 
	 * Creates a new pipe-pair and returns it
	 *
	 * Throws:
	 *   `FatalException` on error creating the pipe
	 * Returns: the pipe-pair as an `int[]`
	 */
	private int[2] newPipe()
	{
		/* Allocate space for the two FDs */
		int[2] pipePair;

		/* Create a new pipe and put the fd of the read end in [0] and write end in [1] */
		int status = pipe(pipePair.ptr);

		/* If the pipe creation failed */
		if(status != 0)
		{
			// Throw an exception is pipe creation failed
			throw new FatalException(this, FatalError.WAIT_FAILURE, "Could not initialize the pipe");
		}

		return pipePair;
	}
}

version(unittest)
{
	import std.conv : to;
	import std.stdio : writeln;
}

/**
 * Basic example of two threads, `thread1` and `thread2`,
 * which will wait on the `event`. We will then, from the
 * main thread, notify them all (causing them all to wake up)
 */
unittest
{
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

/**
 * An example of trying to `notify()` a thread
 * which isn't registered (has never been `ensure()`'d
 * or had `wait()` called from it at least once)
 */
unittest
{
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

/**
 * Here we have an example of a thread which waits
 * on `event` but never gets notified but because
 * we are using a timeout-based wait it will unblock
 * after the timeout
 */
unittest
{
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

			/* Here we test timeout, we never notify so this should timeout and return false */
			assert(event.wait(dur!("seconds")(2)) == false);
			writeln("("~to!(string)(Thread.getThis().id())~") Thread is waiting... [done]");
		}
	}

	TestThread thread1 = new TestThread(event);
	thread1.start();

	/* Wait for the thread to exit */
	thread1.join();
}



// unittest
// {
// 	Event event = new Event();

// 	class TestThread : Thread
// 	{
// 		private Event event;

// 		this(Event event)
// 		{
// 			super(&worker);
// 			this.event = event;
// 		}

// 		public void worker()
// 		{
// 			writeln("("~to!(string)(Thread.getThis().id())~") Thread is waiting...");

// 			try
// 			{
// 				/* Wait */
// 				event.wait();
// 			}
// 			catch(InterruptedException e)
// 			{
// 				writeln("Had an interrupt");
// 			}
// 		}
// 	}

// 	TestThread thread1 = new TestThread(event);
// 	thread1.start();

// 	Thread.sleep(dur!("seconds")(10));
// 	writeln("Main thread is going to notify two threads");

	


// 	// TODO: Add assert to check

// 	/* Wake up all sleeping on this event */
// 	// event.notifyAll();

// 	import core.thread.osthread : getpid;
// 	writeln("Cur pid: ", getpid());

// 	/* Wait for all threads to exit */
// 	thread1.join();
// }