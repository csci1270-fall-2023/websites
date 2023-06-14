---
title: Concurrency
name: concurrency
due: November 24
---

Theme Song: <a href="https://www.youtube.com/watch?v=rGKfrgqWcv0&ab_channel=MumfordAndSonsVEVO">I Will Wait</a>

A database running on a single thread and supporting a single client, is not particularly interesting. We want to be able to run multiple operations and serve multiple clients at the same time. In this assignment, we'll implement both fine-grain and resource-level locking to ensure that your database is safe to use concurrently.

*Note: This is a challenging assignment with a lot of moving parts. Start early and code incrementally. Starting at the last minute is a __very__ bad idea. Please do not take this advice as a challenge.*

---

# Background Knowledge

## Fine-Grain Locking

You may recall mutexes and reader-writers locks from the Pager assignment (if not, read that section of the Pager handout for a refresher) - in this assignment, we'll expand our usage of locks to make our B+Tree and hash table thread-safe using fine-grain locking.

Fine-grain locking is a locking technique that involves locking a part of a data structure to ensure safe access rather than locking the entire data structure. In B+Trees, this means only locking the nodes that we're currently looking at, and in a hash table, this means only locking the buckets we're currently looking at. Clearly this is desirable - now we can have multiple tenants safely traversing and modifying the data structure at the same time, leading to huge speed ups. However, getting fine-grain locking right is incredibly nuanced, as you'll learn in this assignment.

### Fine-Grain Locking on Pages

In the stencil code that we've provided, `Page`s have locks. Since the `Page` represents logical units in both hash tables and B+Trees, this `Lock` method will be instrumental in implementing the following two fine-grain locking schemes. 

### Fine-Grain Locking on Hash Tables

Hash tables are rather simple structures to lock; the only entrypoints into a bucket are through the lookup table. Therefore for each read or write, we only need to lock the lookup table, then the bucket!

On reads, we first acquire a read lock on the lookup table, then find our bucket. Next, we acquire a read lock on our bucket, then release our read lock on the lookup table, read our value, then release our read lock from the bucket.

On writes, we first acquire a read lock on the lookup table, then find and lock our bucket. We could have grabbed a write lock, but there's no need to grab a write lock on the lookup table unless we are sure that we are going to split; this is called **optimistic locking**, and can reduce unnecessary waiting for locks. After we've grabbed a write lock on the bucket, we check if we could potentially split (which essentially means checking if the bucket is currently full); if so, we grab a write lock on the lookup table and complete our insert and split. If we don't split, we simply insert. Afterwards, we release all of our locks. You aren't required to perform optimistic locking in this assignment - it's perfectly find just to grab the write lock from the get go. However, do ensure that you release the write lock if you don't need to hold onto it - otherwise, it's not fine-grain locking at all!

### Fine-Grain Locking on B+Trees

B+Trees are much more difficult structures to lock. There are few major concerns. Firstly, the structure of the tree can change under us as nodes split. Secondly, we don't want to be overly pessimistic in our locking, since holding a write lock on our root node locks all other clients out of the tree. Thirdly, table scans and queries get especially complicated, especially with resource locking below. And so on.

For sanity's sake, we will not be implementing fine-grain locking for selects, cursors, printing, or joins; we will focus on the main B+Tree operations: reading and writing. Primarily, we employ a scheme known as lock-crabbing which ensures that the structure of the database won't change underneath us as we acquire locks and traverse down the tree. The following is a brief overview of lock-crabbing.

On reads, we first acquire a read lock on the root node. Then, we find the child node we want to go to, and grab a read lock on the child node. Only after locking the child node do we unlock the parent (root) node. This is the essense of lock-crabbing and is how we ensure that the shape of the tree doesn't change underneath us. Consider the case where we release the lock on the root before grabbing one on the child. In that split second, another thread could split the root node, making the child node obsolete. Crabbing avoids this issue entirely. We continue in this fashion all the way down to our target leaf node, perform our read, then release our final lock.

On writes, we first acquire a write lock on the root node. Then, we find the child node we want to go to, and grab a write lock on this child node. We only release the write lock on our parent nodes if we can be sure that our child node will not split; if it can, then we hold onto the lock. Otherwise, we release the lock on our parent node and all other locks that we've been holding above us. It's worth thinking about how we can check if a child node could possibly split; this check is very similar to the one we would do in the hash table. As we recurse down, we hold locks on all parents that could potentially be affected by a node split. Eventually, we are guaranteed to unlock everything either after perfoming the write at a leaf node, or after a split is propagated up the tree. Because this algorithm is rather complicated, we've written a help doc [here](/misc/locking). Please use this and the associated helper functions in `btree_subr.go` when implementing locking!


## Transactions

Transactions are a way of grouping multiple actions into one, ACID-compliant package. That is to say, we are guaranteed that either all of the actions in a transaction succeed or none of them succeed, and that they are isolated from other transactions. Transactions acquire locks on the resources they are accessing to be sure that they can read and write safely. Critically, notice that the nature of transaction-level locks and data structure-level locks are very different. Transaction locks are completely unaware of the underlying representation of the data; we're only concerned in logical units to preserve the integrity of the external view of the database. On the other hand, data structure-level locks are completely unaware of the data its locking; only the structure of how the data is stored. Thus, these two locking schemes are completely orthogonal to one another, and yet, are both essential for a database serving multiple tenants concurrently.

### Strict 2PL

Our transactions will adhere to strict two-phase locking. That is, we will acquire locks as we need them, but we will hold on to all of them until after we have committed our changes to the database. **One great corrolary of this scheme is that we can be absolutely sure that there will not be cascading rollbacks**; that is, if a transaction aborts, no other transaction will have to rollback because of it! This makes our lives a lot easier when implementing aborts, but it does mean that our transactions may wait unnecessarily for resources to open.

### Deadlock Avoidance

We want to be sure that our transactions don't end up creating a deadlock; one way to do this is by detecting cycles in a "waits-for" graph. While a transaction is waiting for another transaction to free a particular resource, we should add an edge between it and the offending transaction to the "waits-for" graph. If a cycle is detected in this graph, that means that there is a cycle of transactions waiting for each other, meaning we have deadlocked and will not be able to proceed without killing off a transaction. As a matter of convention, the last transaction to join the graph should be the one that aborts. Critically, remember to remove edges between transactions once transactions die or are otherwise no longer waiting for a resource - otherwise, you may detect deadlocks that don't exist!


---

# Assignment Spec

## Overview

In this project, you'll implement fine-grain locking on Hash and B+Tree, then resource-level locking, and finally implement deadlock detection and avoidance! Note that the assignment parts are somewhat isolated from each other; feel free to work out of order on this assignment.


## New REPL Commands

The transaction REPL now supports two new commands:

- `transaction [begin|commit]` - either starts or ends a transaction. Each client can have up to 1 transaction running at a time.
- `lock <table> <key>` - grabs a write lock on a resource. Useful for debugging.


## Multiple Clients

Since we need to deal with multiple clients, we need to run BumbleBase as a server-client application rather than just as a command-line application. Running `./bumble -project transaction` should now start a server at port 8335. Then, run `./bumble_client -p 8335` to connect to the database and start running queries as normal! Using a tool like [tmux](https://github.com/tmux/tmux/wiki) might help you manage multiple terminals.

In our implementation, each client can have up to one transaction running at a time. To simulate multiple transactions, we need multiple clients; hence, now, our database supports multiple clients through `./bumble_client`. To begin a transaction, we run `transaction begin`, and to end it, `transaction commit`. Commands issued without an active transaction will be treated as a transaction of one action (`transaction begin`, [action], `transaction commit`).


## Stress Testing

Because it can be useful to clobber your database to detect deadlocks or unsafe behaviour using a shotgun approach, we've provided a new executable named `bumble_stress` to help with this. We've also provided a set of sample workloads in the `workloads/` directory to run with `bumble_stress` - poke through `workloads/README.md` to get a sense of what each workload is doing, and feel free to make your own workloads!

To stress test your database, build and run `./bumble_stress -index=<btree|hash> -workload=<w.txt> -n=<n> -verify`. The workload file should essentially mimic what would normally be piped through `STDIN`, separated by newlines. The numthreads argument will specify the number of threads that will run the workload - to be clear, we split the workload across `n` threads, not duplicate the workload for `n` threads, meaning each line will only be run once, but on different threads. The `index` flag determines which kind of index you'll be stress testing. Lastly, the `verify` flag runs a verification check at the end of the stress test to ensure that the datastructure is still consistent after the run. No `project` flag is required.

Stress testing is an especially experimental feature in the course. As a result, we will not be evaluating your code using this stress testing mechanism. Treat it as a way to discover bugs in your implementation and learn more, not as a metric for completion.


## Part 0: A New REPL

Before you continue, add the following function to your `repl.go` file; this will let your REPL work across multiple clients:

```go
// Run the REPL.
func (r *REPL) RunChan(c chan string, clientId uuid.UUID, prompt string) {
	// Get reader and writer; stdin and stdout if no conn.
	writer := os.Stdout
	replConfig := &REPLConfig{writer: writer, clientId: clientId}
	// Begin the repl loop!
	io.WriteString(writer, prompt)
	for payload := range c {
		// Emit the payload for debugging purposes.
		io.WriteString(writer, payload+"\n")
		// Parse the payload.
		fields := strings.Fields(payload)
		if len(fields) == 0 {
			io.WriteString(writer, prompt)
			continue
		}
		trigger := cleanInput(fields[0])
		// Check for a meta-command.
		if trigger == ".help" {
			io.WriteString(writer, r.HelpString())
			io.WriteString(writer, prompt)
			continue
		}
		// Else, check user commands.
		if command, exists := r.commands[trigger]; exists {
			// Call a hardcoded function.
			err := command(payload, replConfig)
			if err != nil {
				io.WriteString(writer, fmt.Sprintf("%v\n", err))
			}
		} else {
			io.WriteString(writer, "command not found\n")
		}
		io.WriteString(writer, prompt)
	}
	// Print an additional line if we encountered an EOF character.
	io.WriteString(writer, "\n")
}
```


## Part 1: Fine-Grain Locking - Hash Tables

Relevant files:

- `pkg/hash/bucket.go`
- `pkg/hash/table.go`

Add locking the following functions:

```go
func (table *HashTable) Find(key int64) (utils.Entry, error)
func (table *HashTable) Split(bucket *HashBucket, hash int64) error
func (table *HashTable) Insert(key int64, value int64) error
func (table *HashTable) Update(key int64, value int64) error
func (table *HashTable) Delete(key int64) error
func (table *HashTable) Select() ([]utils.Entry, error)
```

Some hints:
- Be careful whether you're using read or write locks!
- Using `defer` can save a lot of headache if you know for certain that a function will unlock some resource when it returns.
- Depending on your scheme, you may/should not have to add any locking to `Split` - think about what you should lock to keep the whole table safe, though!
- To lock a bucket, change calls to `GetBucket` and `GetBucketByPN` to `GetAndLockBucket` and `GetAndLockBucketByPN` respectively, passing in `READ_LOCK` or `WRITE_LOCK` as the second parameter - do this instead of locking the page directly. Don't forget to unlock the page when you are done!


## Part 2: Fine-Grain Locking - B+Trees

Relevant files:

- `pkg/btree/node.go`
- `pkg/btree/btree.go`
- `pkg/btree/btree_subr.go`

```go
func (node *LeafNode) insert(key int64, value int64, update bool) Split
func (node *LeafNode) delete(key int64)
func (node *LeafNode) get(key int64) (value int64, found bool)
func (node *InternalNode) insert(key int64, value int64, update bool) Split
func (node *InternalNode) delete(key int64)
func (node *InternalNode) get(key int64) (value int64, found bool)
```

Some hints:
- We guarantee these are the only functions you need to change. You should not have to change `split` or `insertSplit`.
- Before anything else, **read through the new helper methods in `btree_subr.go`**! It will save you a LOT of time if you understand what they do. 
- We handle the root node entirely for you in the `btree.go` file. Check out the `Insert` implementation in `btree.go` to see what else we handle for you.
- To lock a child node, change the call to `getChildAt` to `getAndLockChildAt` - do this instead of locking the page directly.
- After getting and locking a child node, you should immediately call `initChild` on it. This will set that node's parent field correctly so that `unlockParent` works properly.
- You should check whether we need to unlock parents at the begin of all of these function calls. You can do this by calling `unlockParent` with the `force` parameter set to `false`. 
- For all leaf node functions, we will need to eventually force the current node and all parent nodes to unlock. You should take a look at the `force` parameter of `unlockParent` as well as the `unlock` method.
- Lastly, think about whether we should unlock all parents in each case of a `split`. Critically, you'll have to look into the result of `node.insertSplit` in each `insert` call and react appropriately.


## Part 3: Transactions

<!-- A relevant CW post: https://campuswire.com/c/GAAA5D576/feed/975 -->

Relevant files:

- `pkg/concurrency/transaction.go`
- `pkg/concurrency/lock.go`

First, implement the following functions:

```go
func (tm *TransactionManager) Lock(clientId uuid.UUID, table db.Index, resourceKey int64, lType LockType) error
func (tm *TransactionManager) Unlock(clientId uuid.UUID, table db.Index, resourceKey int64, lType LockType) error
```

Some notes:

- There are two abstractions surrounding how we represent locks. Firstly, a `Resource` is a unique identifier for a specific tuple in a database using its table and key. Secondly, a `LockType` helps us keep track of which lock is currently being held on a particular resource. A `Transaction` keeps track of which locktypes it is holding.
- Transactions are identified by their `clientId`; whenever a new client connects to the server, it is assigned an ID, and since each client can only have one transaction at a time, its ID serves as a uuid for its transaction, should it exist.
- A `Transaction` should hold either a read or a write lock on a resource; never both and certainly not multiple of each. Thus, if a transaction requests a duplicate lock, ignore the duplicate, and if a transaction requests a read lock on a resource when it holds a write lock on the same resource, do nothing.
- Critically, we should disallow lock upgrades. This means that if a `Transaction` holds ` read lock on a resource and requests a write lock, you should throw an error.
- Remember to read-lock the `tmMtx` when you call `GetTransaction`!
- Remember to lock `Transaction`s when you access their resources!
- `Lock` should check what lock we want to request, add an edge to our `pGraph`, check if there is a cycle and throw an error if there is, lock the resource if we can, and remove an edge from our `pGraph`.
- `Unlock` should remove the lock from our transaction's resources and unlock the resource. Be sure to keep track of what locktype the resource had.


## Part 4: Deadlock Avoidance

Relevant files:

- `pkg/concurrency/transaction.go`
- `pkg/concurrency/deadlock.go`

Implement the following function and instrument your prior transactions code with it:

```go
func (g *Graph) DetectCycle() bool
```

Feel free to use any cycle detection algorithm you like. We recommend depth-first search. You'll most likely have to define some helper functions to complete this function.

Some notes:

- A transaction should only have an edge in the waits-for graph while it is actively waiting for a lock. Once it has been granted a lock, it should remove its edges from the graph to avoid false alarms.


## Testing

Run our unit tests on Gradescope. We've provided a subset of the tests [here](/static/posts/project/concurrency/concurrency_test_sample.go). Moreover, try out the `bumble_stress` executable on a few workloads.


## Getting started

To get started, download the following stencil package: [concurrency](https://drive.google.com/file/d/1tKS5su3LHwQFHmfV1M9x-JgtbyQ_rCTs/view?usp=sharing), [bumble_client](https://drive.google.com/file/d/11qutHgWAMJ5kF-HntZDLhMAfePBVcDnz/view?usp=sharing), [bumble_stress](https://drive.google.com/file/d/1By5XRqypVwaNmPM-JayQkP_fpkPp6JjL/view?usp=sharing), [patch](https://drive.google.com/file/d/1X_Tr6q7Alwteb_7chmovXhE_UVGw51R1/view?usp=sharing), and [workloads](https://drive.google.com/file/d/11IhFxKHMDUdnEdqcBye7gHWKeC7znYOt/view?usp=sharing). We've provided an updated `main.go` file [here](https://drive.google.com/file/d/1FjjGFsjWbKnaTN8fpq0f_EN_vvxZ0qV1/view?usp=sharing). When finished, your filestructure should look like this:

```
./
    - cmd/
        - bumble/
        - bumble_client/
        - bumble_stress/
    - pkg/
        - btree/
        - config/
        - db/
        - utils/
        - hash/
        - list/
        - pager/
        - repl/
        - query/
        - concurrency/
```

---
