---
title: Hash
name: hash
due: November 1
---

Theme Song: <a href="https://www.youtube.com/watch?v=wKyMIrBClYw&ab_channel=DEANTRBL">instagram</a>

Sometimes, range queries and sorted order don't matter too much to you, and all you care about is fast lookup. A hash table is a very popular data structure for performing quick lookups used in everything from coding interviews to industry standard indexes. In this assignment, you will implement an extendible hash table.

---

# Background Knowledge

## Extendible Hashing

As you know from lecture, extendible hashing is a method of hashing that adapts as you insert more and more data. This is a direct upgrade from static hashing, which doesn't adapt as the amount of entries grows, thus leading to inefficient lookups later on. For direct lookups, extendible hashing can be a very efficient and lightweight indexing solution. However, it does not support range queries or maintain any sorted order, making it less than ideal as a general purpose indexing scheme like a B+Tree.

An extendible hash table has two moving parts: the table and the buckets. The table is essentially an array of pointers to buckets. Each bucket has a *local depth*, denoted $d_i$ , which is the number of trailing bits that every element in that bucket has in common. The table has a *global depth*, denoted $d$ , that is the maximum of the buckets' local depths.

A hash table also has an associated hash function. Ideally, this hash function is fast and uniform across the output space, meaning that keys will be uniformly distributed across the buckets. In this implementation, we use [xxhash](https://github.com/cespare/xxhash) since it is the state of the art, but really, many other hash functions would work just fine. You won't need to call this hash function directly; just use the `Hasher` function in the `hash_subr.go` file.

### Basic Operations

When a hash table performs **lookup**, the search key is hashed, and then the table is used to determine the bucket that we should look at. The last $d$ bits of the search key's hash are used as the key to the table, and then we do a linear scan over the bucket it points to.

When a hash table performs **insertion**, the insertion key is hashed, and then the table is used to determine the bucket that our new tuple should be in. The last $d$ bits of the hash is used as the key to the hash table, after which we add the new tuple to the end of the bucket.

### Splitting

When a value is inserted into a hash table, one of two things can happen: either the bucket doesn't overflow, or the bucket does overflow. If it overflows, then we need to **split** our bucket. To split a bucket, we create a new bucket with the same search key as the bucket that overflowed, but with a "1" prepended to it. We then prepend a "0" to the original bucket's search key. As an example, if a bucket with a local depth of 3 and search key "101" splits, we would be left with two buckets, each of local depth 4 and with search keys "0101" and "1101". Then, we transfer values matching the new search key from the old bucket to the new bucket, and we are done.

*It's worth noting that while we talk about "prepending" as if we are dealing with strings, in actuality, this action is done entirely through the bit-level representation of integers. Think about what you would have to add to a search key to effectively prepend its bit representation with a 1 or a 0. Hint: it has something to do with powers of 2.*

However, if a bucket overflows and ends up with a local depth greater than the global depth, this is no good. We should always maintain a global depth equal to the maximum of the buckets' local depths. To remedy this, we double the size of the hash table by appending it to itself and increasing global depth by 1. Then, we can iterate through and make sure that the buckets are all being pointed to by the correct slots in the hash table.

It is possible that after a split, all of the values in the old bucket ended up in the same bucket, immediately triggering a second split. This can be caused either by a bad hash function (imagine a hash function that maps all inputs to the same output), or due to an *adversarial workload*. In your database, you should handle recursive splits; however, you should not worry about endless recursive splits (which would happen if all elements in a splitting bucket had exactly the same hash).

<!-- TODO: A worked example of insertions and splits -->

### Deletion and Fragmentation

When a hash table performs **deletion**, depending on your scheme, the other values may have to be moved over to fill the space it left. A good indexing scheme would use slotted pages to avoid this, but our setup doesn't readily accomodate this. Alternatively, we could populate a free list. There are many ways to handle deletion, since we don't have to maintain any sort order on the bucket level. In this assignment, you should shift over the remaining entries on the right one place left or move the last entry into the gap created by the deletion to ensure that there is no internal fragmenting in the bucket.

---

# Assignment Spec

## Overview

The following are the files you will need to alter:

- `cmd/bumble/main.go`
- `pkg/db/db.go`
- `pkg/hash/table.go`
- `pkg/hash/bucket.go`

And the following are the files you'll need to read:

- `pkg/db/db.go`
- `pkg/hash/hash.go`
- `pkg/hash/hash_subr.go`
- `pkg/hash/entry.go`


## Subroutine Code

We've provided subroutine code so that you don't have to worry about the fact that all of this data is actually being stored on pages. We handle the marshalling and unmarshalling of data, you handle the actual logic of the hash table.

You will need to read the `hash_subr.go` and `entry.go` files to implement this assignment. The `hash.go` file is just a wrapper for the `db.Index` interface. You don't need to understand exactly how every function works, just understand what they do so that you know when you need to call them. If you ever find yourself manipulating bytes yourself, you have done something wrong and need to leverage the subroutine code more. You shouldn't change the subroutine code unless a TA has instructed you to do so. Note that there are a number of functions that are tagged with future assignment names - you won't need them now.

A common pattern you will see is how we get buckets; we use [defer](https://tour.golang.org/flowcontrol/12) to ensure that the page is returned to the pager eventually.

```go
// Get page and put later:
newBucket, err := NewHashBucket(table.pager, bucket.depth)
if err != nil {
    return err
}
defer newBucket.page.Put()
```


## Implementation-specific Details

Your hash table should allow inserts of duplicate values! Don't worry, non-duplicity is enforced through the database layer, so there won't be any undefined behaviour. However, we do need to allow duplicate entries for later in the course. One known issue is that if the bucket size is $x$ , and we insert $x+1$ elements with the same key (and thus the same hash), this scheme will lead to infinite bucket splits; ignore this issue, because there is no good solution to this problem without involving overflow chains, which you are not expected to implement.


## Part 1: Bucket Functions

Implement the following functions:

```go
func (bucket *HashBucket) Find(key int64) (entry.Entry, bool)
func (bucket *HashBucket) Insert(key int64, value int64) (bool, error) // ALLOW DUPLICATE ENTRIES
func (bucket *HashBucket) Update(key int64, value int64) error
func (bucket *HashBucket) Delete(key int64) error
func (bucket *HashBucket) Select() ([]entry.Entry, error) 
```

Some hints:

- These functions operate on a single bucket; you can safely assume that the key-value pair belongs in this bucket if these functions are called. 
- Use `modifyEntry`, `updateValueAt`, `updateKeyAt`, and `updateNumKeys` to change the values of entries.
- When deleting, we want to make sure that we don't introduce any fragmentation. Thus, when deleting from the middle of a bucket, we should shift the entries to the right of the hole left to fill the gap. Alternatively, we can move the last element in the bucket to fill the gap.
- The `bool` value in the return type of `Insert` should be true when that insert triggers a split. This will be used in part 2 when you implement splitting; this will help you detect splits on insertion.
- Some of these functions have an `error` in their return type; not all functions are expected to ever return an error! If you think a function should never error, just return `nil`.
- Do **NOT** use `GetAndLockBucket` or `GetAndLockBucketByPN` - these functions will be used in a later assignment.


## Part 2: Hash Table Functions

Implement the following functions:

```go
func (table *HashTable) Find(key int64) (entry.Entry, error)
func (table *HashTable) Split(bucket *HashBucket, hash int64) error
func (table *HashTable) Insert(key int64, value int64) error // ALLOW DUPLICATE ENTRIES
func (table *HashTable) Update(key int64, value int64) error
func (table *HashTable) Delete(key int64) error
func (table *HashTable) Select() ([]entry.Entry, error) 
```

Some hints:

- To hash a value, use `Hasher(key, depth)`.
- To get a bucket by its hash, use `table.GetBucket(hash)`. To get it by its page number, use `table.GetBucketByPN(pn)`
- `Split` takes the hash of the bucket that should be duplicated; this makes it easier to be called from `Insert`.
- The maximum size of a bucket is `BUCKETSIZE`; the splitting condition should be handled very similarly to in B+Tree.
- Remember to handle recursive splits!
- Some of these functions have an `error` in their return type; not all functions are expected to ever return an error! If you think a function should never error, just return `nil`.


## Debugging

We know that this is a difficult assignment, so we have a few tips on how to debug.

Each bucket currently can hold up to a lot of entries before it will split. To lower the number of entries you need to insert before a split occurs, make the following changes:

```go
// var BUCKETSIZE int64 = (PAGESIZE - BUCKET_HEADER_SIZE) / ENTRYSIZE // num entries
var BUCKETSIZE int64 = 5 // Or another number
```

Moreover, if you'd like to use the `mod` operator as the hasher instead of the actual hasher we use, feel free to replace `Hasher` with the following function:

```go
func Hasher(key int64, depth int64) int64 {
	return int64(key %powInt(2, depth))
}
```

**WARNING: REMEMBER TO REVERT THESE CHANGES BEFORE YOU SUBMIT, OTHERWISE THE AUTOGRADER __WILL__ TIME OUT!**

Then, run your database on the command line. You should be able to `insert`, `delete`, and `update` entries (among other operations) after you've run `create hash table <table_name>`. Critically, by running `pretty from <table>`, you can pretty-print the current state of your Hash Table. This should provide some observability into the system that will be useful in debugging.

### Example Usage

Let's run our database using `./bumble -project db`. Next, we create a table using `create hash table t`, and insert keys [1, 10, 20] with any value (`insert k v into t`). Let's observe the state of the database using `pretty from t` (pretty-print the table `t`):

```bash
bumble> pretty from t
====
global depth: 2
====
bucket 0
bucket depth: 2
entries:(20, 0),
====
bucket 1
bucket depth: 2
entries:(1, 0),
====
bucket 2
bucket depth: 2
entries:
====
bucket 3
bucket depth: 2
entries:(10, 0),
====
```

Let's dissect the above; we ran `pretty from t` and see that our global depth is 2 (meaning we are considering the last two bits of each key's hash). We have 4 buckets, three of which have entries in them.


## Testing

Run our unit tests on Gradescope. We've provided a subset of the tests [here](/static/posts/project/hash/hash_test_sample.go).


## Getting started

To get started, download the following stencil packages: [db](https://drive.google.com/file/d/11Ck0hhgptkrRTMhzXUfKhZwQGXx3FENj/view?usp=sharing), [hash](https://drive.google.com/file/d/19H6NvAiUwRW6-z-pa1CeS6sKqhMqEbrU/view?usp=sharing). **You should replace your old `db` package with this new one.** The `main.go` file should be left unchanged. When finished, your filestructure should look like this:

```
./
    - cmd/
        - bumble/
    - pkg/
        - btree/
        - config/
        - db/
        - utils/
        - hash/
        - list/
        - pager/
        - repl/
```

---
