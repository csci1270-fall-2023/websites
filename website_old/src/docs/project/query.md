---
title: Query
name: query
due: November 8
---

Theme Song: <a href="https://www.youtube.com/watch?v=gJLIiF15wjQ&ab_channel=SpiceGirlsVEVO">Wannabe</a>

The most powerful feature of a relational database is the ability to combine your data to extract meaningful results. We use advanced queries to select, filter, and join our tables to get the insights we desire. In this assignment, you will implement a join algorithm to allow your database to return more interesting results.

---

# Background Knowledge

## Hash Joins

We've explored many join algorithms in class; now it's time to dive deep into one join algorithm: the hash join. In particular, this implementation uses the grace hash join, which is much more efficient than the classic hash join when the tables we're joining are too large to fit into memory.

When performing a classic hash join algorithm on two tables, we have to find tuples that match on some key or value across both tables. To do so, the classic hash join creates a hash table index over the inner table, and then linearly scans the outer table, probing the inner table for corresponding values. However, due to the nature of hash functions, these tuples are distributed at random in the inner hash table. If the hash table is too large to reside entirely in memory, then we have to fetch data from disk at random, which greatly increases our disk i/o cost because pages will keep getting churned through our buffer cache. To illustrate this point, imagine that our inner table gets hashed into 100 buckets, and memory can only hold 8 buckets. For each tuple in the outer table, we are likely going to need to go to a different bucket. So, we end up doing one block transfer per element in the outer table; at this pace, we may as well have done a nested block loop join.

Luckily, the grace hash join offers us a solution. Let's say we have two tables, denoted $L$ and $R$ . We'll say [WLOG](https://en.wikipedia.org/wiki/Without_loss_of_generality) that $L$ is our outer relation. The grace hash join will first extract the entirety of $L$ and $R$ into two hash tables using the same hash function, using each table's join key as the search key; concretely, if we were joining $L$ 's value on $R$ 's key, then we would create one hash table with all of $L$ 's tuples, hashed on their value, and another hash table with all of $R$ 's tuples, hashed on their key. Buckets are written out to disk to avoid running out of memory. Critically, the two hash tables are made to have the same global depth, even if this means expanding one table without splitting any buckets.

After partitioning our two relations and resizing our hash tables so that we have the same number of entries in our global index, we then load corresponding pairs of buckets into memory and match up pairs of tuples. Concretely, we load the `i`th bucket from $L$ and the `i`th bucket from $R$ , which should contain elements with the same hash. Since we used the same hash function, if there was a value in $L$ that matched with a value in $R$, they would be in the same bucket pair; because otherwise, their hash keys must have been different, so they wouldn't have been in a bucket pair. We repeat this matching process for every pair of buckets until we have finished iterating through the buckets.

The main issue to worry about is duplicity; if we ever come across the same pair of buckets twice, we may end up outputting duplicate join results. Thus, it is important to be sure that we never process the same pair of buckets twice; keeping track of which pairs of buckets we have seen will solve this problem. It's a good exercise to think through when this case would occur.

You may also have noticed that each pair of buckets has a disjoint result set (think about what it would mean if result sets weren't disjoint), indicating that there is room for parallelization. Our stencil code implements parallelized joins for you using channels.

<!-- TODO: An example of execution -->

## Bloom Filters

One inefficiency in a hash join is that you potentially have to iterate through an entire bucket to find a value. To do that for every search value is really expensive - if we could speed up our search time somehow, that would be a huge win! Unfortunately, maintaining a bucket ordering doesn't really make sense just for a one-time search, and building an index over such a small data structure is overkill.

Bloom filters are a lightweight solution to the sparse search problem. A Bloom filter is a probabilistic data structure that can tell us one of two things about an element: whether it is **definitely not in a set**, or **possibly in a set**. See a visual simulation of a bloom filter [here](https://llimllib.github.io/bloomfilter-tutorial/).

A bloom filter has two parts: a bitset (essentially an array of $m$ bits) and a set of $n$ hashes (in this assignments, $n=2$ ). When we insert an element into a set, we hash it $n$ times and take those values modulo $m$ - call these values $h_i$ . We then set each $h_i$ -th bit to 1 in our bitset. As a concrete example, let's say the string "hello" hashed to 3 and 5. Then, we would set the 3rd and 5th bit (0-indexed) to 1.

Next, when we want to check if a particular element is in the set, we hash it $n$ times and take those values module $m$ - call these values $h_i$ . Now, if at least one of the $h_i$ -th bits are 0, then we know for certain that the element in question is not in the set; if it were, then all of these bits would be 1. If they are all 1, then we know that it is possible that the element in question is in the set. But we can't say for sure that the element is present, since the bits may have been set by a combination of other elements that set all of those bits to 1. However, with a large enough bitset and enough hashes, we can avoid collisions as much as possible, making this a nearly constant-time check for inclusion!

In this implementation, we use [this bitset implementation](github.com/bits-and-blooms/bitset), as well as [xxhash](github.com/cespare/xxhash) from before, alongside [murmurhash](github.com/spaolacci/murmur3). We found our preferred bloom filter parameters using [this calculator](https://hur.st/bloomfilter), but you are welcome to experiment and find your preferred space-time tradeoffs. 

---

# Assignment Spec

## Overview

In this project, you'll implement the grace hash join algorithm, and then speed it up using bloom filters!

The following are the files you'll need to alter:

- `cmd/bumble/main.go`
- `pkg/query/hash_join.go`
- `pkg/query/bloom_filter.go`

And the following are the files you'll need to read:

- `pkg/query/query_repl.go`


## New REPL Commands

Our REPL now supports the following command:

- `join <table1> <key|val> on <table2> <key|val>` - prints the result of table1 joined on table2.


## Part 1: Grace Hash Join

Implement the following functions:

```go
func buildHashIndex(sourceTable db.Index, useKey bool) (tempIndex *hash.HashIndex, dbName string, err error)
```

The `buildHashIndex` function should convert an arbitrary source table into a hash table for use in the grace hash join. Some hints to help you along:

- You are not permitted to use `sourceTable.Select()` for this function. This is because reading the entire table into memory is precisely what we wanted to avoid doing by computing a join, and in many cases, won't even be possible. Instead, use the index-agnostic `Cursor` to get all of the values you need! `TableStart` will return a cursor for you to use.
- If `useKey` is true, it means that the the join key is the search key. If it is false, it means that the join key is actually the tuple's value. Be cognizant of whether you're hashing on keys or values; it's fine to temporarily transform entries by flipping their keys and values to store them in the hash index, just be sure to flip them back in `probeBuckets`.


```go
func probeBuckets(ctx context.Context, resultsChan chan EntryPair, lBucket *hash.HashBucket, rBucket *hash.HashBucket, joinOnLeftKey bool, joinOnRightKey bool) error
```

The `probeBuckets` function takes a pair of buckets and sends matching pairs to a channel. Some hints to help you along:

- Use `sendResult` to return results from `probeBuckets` - this allows the function to work with our concurrent join setup. Use `sendResult` like this: `sendResult(ctx, resultsChan, EntryPair{l: left, r: right})`. Don't worry about what `ctx` and `resultsChan` are doing; these are constructs to enable parallelism in your join.
- Similarly to `buildHashIndex`'s `useKey` parameter, the `joinOnLeftKey` parameter will be true when the left table's join key is the search key, and false when the join key is the value. The same applies to the `joinOnRightKey` parameter.
- Be sure to handle all four combinations of key-value joining, including swapping entry keys and values before returning, if you need to.
- Do **NOT** use `GetAndLockBucket` or `GetAndLockBucketByPN` - these functions will be used in a later assignment.


## Part 2: Bloom Filters

Implement the following functions:

```go
func CreateFilter(size int64) *BloomFilter
func (filter *BloomFilter) Insert(key int64)
func (filter *BloomFilter) Contains(key int64) bool
```

And then use your bloom filter to speed up your `probeBuckets` function.

Some hints:

- We will use two hash functions. Please use `hash.XxHasher` and `hash.MurmurHasher` as your two hash functions.
- The `bitset` package will be useful; check out `bitset.New`, `bits.Set`, and `bits.Test`.
- Make sure that when you call `CreateFilter` in `probeBuckets`, you pass in `DEFAULT_FILTER_SIZE` as the `size` parameter.


## Testing

Run our unit tests on Gradescope. We've provided a subset of the tests [here](/static/posts/project/query/query_test_sample.go).


## Getting started

To get started, download the following stencil package: [query](https://drive.google.com/file/d/1aFVyPrt03Wc8_n1vWkqjiiznHoRhoC4-/view?usp=sharing). We've provided an updated `main.go` file [here](https://drive.google.com/file/d/1HT1r6Z_zOl6bZEX7ddjg3xUJ6aXYcniH/view?usp=sharing). When finished, your filestructure should look like this:

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
        - query/
```

---
