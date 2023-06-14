---
title: B+Tree
name: b+tree
due: October 25
---

Theme Song: <a href="https://www.youtube.com/watch?v=U7EKvt_COlI&ab_channel=AnnabethMcKaslin15">Here Comes The Sun</a>

You've surely encountered binary search trees before - data structures that allow quick ( $O(\log(n))$ ) search. A similar search structure, the B+Tree, is like a binary tree generalized to `n` children. In this assignment, you will implement a B+Tree from scratch and use it to store and retrieve data.

---

# Background Knowledge

## BTrees

![btree](/static/posts/project/b+tree/btree.jpeg)

To understand B+Trees, we should first cover what a BTree is. A BTree is a self-balancing recursive data structure that allows logarithmic time search, insertion, and deletion. It is a generalization of the binary search tree in that each node can have more than 1 search key and more than 2 children. A BTree of order $m$ is formally defined as a tree that satisfies the following properties:

- Each node has at most $m$ children,
- Every non-leaf (internal) node has at least $\lceil m/2 \rceil$ children,
- The root has at least two children unless it is a leaf node,
- A non-leaf node with $k$ children contains $k-1$ keys,
- All leaves appear on the same level and carry no information.

One way to visualize what an internal node looks like is an array of $2k-1$ values, alternating between a child node pointer and a key: 

```
[child_1, key_1, child_2, key_2, ..., key_k-1, child_k]
```

And a leaf node is similarly visualizable, except that there is a one-to-one correspondence between keys and values, making it an array of $2k$ values:

```
[key_1, value_1, key_2, value_2, ..., value_k-1, key_k, value_k]
```

Critically, all of the values of a node in between two values must be between those two values. So, there will never be any keys less than `key_1` or greater than `key_2` in `child_2` or any of its descendants. This mirrors the invariant present in any search tree.

This data structure supports search, insertion, and deletion. Updates are supported as well, but can be thought of as a deletion followed by a subsequent insertion. We describe each of these algorithms.

**Search** - to search for a entry, we start at the root node. If the entry we're looking for is in this node, we return it. Otherwise, we binary search over the keys to find the branch that our desired entry could be in, and repeat this process for that child node until we either find the entry or bottom out.

**Insertion** - to insert a entry, we start at the root node. Then, we traverse to a leaf node and insert the entry in the correct spot, assuming the entry doesn't already exist. If the leaf node *overflows* (i.e. has more than $k$ entries), then we need to *split* it so that our BTree is still valid. To split a leaf node, we create a new leaf node and transfer half of the entries (not including the median) over to the new leaf node. Then, we take the median element and push that value up into the parent node to serve as a separator key for our two new nodes. If the parent node overflows, we repeat this process for that node.

**Deletion** - to delete a value, we first find the value (if it exists), then we remove it. This operation becomes rather complicated when nodes underflow (less than $\lceil m/2 \rceil$ children), or when deleting a value from an internal node; we leave it as an exercise to the reader to explore this operation.

To explore how some of these BTree operations work, try out this [online visualization](https://www.cs.usfca.edu/~galles/visualization/BTree.html).


## B+Trees

![b+tree](/static/posts/project/b+tree/b+tree.jpeg)

Now that we understand BTrees, it's time to explore what a B+Tree is. A B+Tree is a BTree with a few important changes:

- Each leaf node has a pointer to its right neighbor. This makes linear scans much easier, since we don't have to traverse the tree structure to get to the next leaf node.
- Internal nodes store duplicates of values in leaf nodes. Critically, when a leaf node splits, it doesn't push any entries up to the parent; rather, it only pushes a copy of the entry up. This means that if we were to scan every leaf node, we would retrieve every value in the tree.

Otherwise, everything else is the same as in a BTree. This structure is better optimized for when data you're looking for is on disk, since internal nodes only need to store keys, and then all of the large values are kept on leaf nodes. In our scheme, each node corresponds to a page, meaning the number of pages we have to read in to find a particular value is equal to the height of our B+Tree.

The operations in a B+Tree are slightly different:

**Search** - to search for a value, we start at the root node and traverse all the way to the correct leaf node, using binary search to descend quickly. Once we arrive at the leaf node, binary search for the value.

**Insertion** - to insert a value, we start at the root node. Then, we traverse to a leaf node and insert the value in the correct spot. If the leaf node *overflows* (i.e. has more than $k$ values), then we need to *split* it so that our BTree is still valid. To split a leaf node, we create a new leaf node and transfer half of the values (including the median) over to the new leaf node. Then, we take a copy of the median element and push that value up into the parent node to serve as a separator key for our two new nodes. If the parent node overflows, we repeat this process for that node. The main difference here is that we duplicate the median key when we split.

**Deletion** - to delete a value, we first find the value in a leaf node(if it exists), then we remove it. This operation becomes rather complicated when nodes underflow (less than $\lceil m/2 \rceil$ children), or when deleting a value from an internal node; we leave it as an exercise to the reader to explore this operation.

To explore how some of these B+Tree operations work, try out this [online visualization](https://www.cs.usfca.edu/~galles/visualization/BPlusTree.html).

### Split Indexing

Splitting a node is actually quite a tricky operation which requires careful indexing; to help you wrap your head around the implementation of this opereation, we provide the following example. Let's say our internal node looks like this:

```
[child_0, key_0, child_1, key_1, child_2, key_2, child_3, key_3, child, key_4, child_5]
```

and then our second child (child index = 1) splits. Here's the node after the split, with `child*` as the new child, and `key*` the new key.

```
[child_0, key_0, child_1, key*, child*, key_1, child_2, key_2, child_3, key_3, child, key_4, child_5]
```

Notice how many keys and how many children we shifted. We shifted 3 of each. Next, notice the indices of the keys and children that we shifted. We shifted child indexes 3 and above, and we shifted key indexes 2 and above. **The indexes for the keys and children we moved do not match up!** Be careful about this nuance when you implement splits for internal nodes!


## Cursors

One of the B+Tree's biggest optimization is the existence of links between leaf nodes to allow faster linear scans. A cursor is an abstraction that takes advantage of these links to carry out selections quickly.

Essentially, a cursor is a data structure that points to a particular part of another data structure, with a few options for movement and action. A cursor typically has two operations: `StepForward` and `GetEntry`. `StepForward` steps the cursor over the next value; for example, if we are in the middle of a node, it moves on to the next value, otherwise, it skips over to the next node. `GetEntry` returns the value that the cursor is currently pointing at for the surrounding program to handle. Critically, in a B+Tree, a cursor never needs to be in an internal node, making it an easy to understand and simple to use abstraction.

---

# Assignment Spec

## Overview

In this project, you'll first do a little bit of setup, then you'll be writing a B+Tree: nodes, cursors, and all!

The following are the files you'll need to alter:

- `cmd/bumble/main.go`
- `pkg/db/db.go`
- `pkg/btree/node.go`
- `pkg/btree/cursor.go`
- `pkg/btree/btree.go`

And the following are the files you'll need to read:

- `pkg/db/db.go`
- `pkg/btree/entry.go`
- `pkg/btree/btree_subr.go`


## Subroutine Code

We've provided subroutine code so that you don't have to worry about the fact that all of this data is actually being stored on pages. We handle the marshalling and unmarshalling of data, you handle the actual logic of the B+Tree.

**You will need to read the `btree_subr.go` file in full to implement this assignment.** We recommend doing this before starting to write any code. You don't need to understand exactly how every function works, just understand what they do so that you know when you need to call them. If you ever find yourself manipulating bytes yourself, you have done something wrong and need to leverage the subroutine code more. You shouldn't change the subroutine code unless a TA has instructed you to do so.

A common pattern you will see is how we get nodes; we use [defer](https://tour.golang.org/flowcontrol/12) to ensure that the page is returned to the pager eventually, and then use one of the following three converter functions to use the page as a header, leaf node, or internal node:

```go
// Get page and put later:
page, err := table.pager.GetPage(pagenum)
if err != nil {
    return nil, err
}
defer page.Put()
// And then one of the following:
header := pageToNodeHeader(page)
leaf := pageToLeafNode(page)
internal := pageToInternalNode(page)
```

Some more notes about subroutine or stencil code:

- The `search` function gives you the index of the smallest element larger than the key you give it. In other words, for internal nodes it tells you the index of the child branch to descend into, and for leaf nodes, it tells you the index that the key you're looking for, should it exist, would be at.
- The following node functions should be used to get and manipulate keys and values: `getKeyAt`, `getValueAt`, `getPNAt`,  `getChildAt`, `updateKeyAt`, `updateValueAt`, `updatePNAt`, `updateNumKeys`, `modifyEntry`. **Do not edit any node struct attributes directly; otherwise, changes will not be persisted in the database!**
- To create a new leaf node, use `createLeafNode(node.page.GetPager())`. To create a new internal node, use `createInternalNode(node.page.GetPager())`.
- To get a node's child, use `getChildAt`. Note: as the function's name and documentation suggest, this helper function increases the pinCount of the page storing the child, and hence the node's page must be `Put` accordingly after use.
- Do **NOT** use `getAndLockChildAt` - this function will be used in a later assignment.
- After using any function that creates or gets a node, be sure to run `defer newNode.getPage().Put()` so that you properly release the new page you just read in.
- B+Tree leaf nodes have a right sibling; to change it, use `setRightSibling`.


## The Database Abstraction

The `db` package serves as an interface between the B+Tree and the rest of your code; since a B+Tree is one of many potential index schemes (foreshadowing), this allows us to support multiple kinds of indexes rather easily. We recommend poking through the code to get a sense of what it does and how it works. Once you have added the above code, you should have access to the `DatabaseRepl` functionality, which supports the following commands:

- `create <type> table <table>` - Creates a table with a particular type. For now, only supports type of "btree". You must create a table before using it.
- `find <key> from <table>` - Finds a particular key-value pair from the given table.
- `insert <key> <value> into <table>` - Inserts a particular key-value pair into the given table. Does not allow insertion of duplicates.
- `update <table> <key> <value>` - Updates a particular key-value pair in the given table. Does not update non-existent entries.
- `delete <key> from <table>` - Deletes a particular key-value pair from the given table.
- `select from <table>` - Returns all of the key-value pairs from the given table.
- `pretty from <table>` - Pretty-prints the internal structure of the index.


## Part 1: Node Functions

Relevant files:

- `pkg/btree/node.go`
- `pkg/btree/btree_subr.go`

Implement the following functions:

```go
func (node *LeafNode) insert(key int64, value int64, update bool) Split
func (node *LeafNode) delete(key int64)
func (node *LeafNode) split() Split 

func (node *InternalNode) insert(key int64, value int64, update bool) Split
func (node *InternalNode) insertSplit(split Split) Split
func (node *InternalNode) delete(key int64)
func (node *InternalNode) split() Split 
```

**Note that we do not expect you to handle coalescing underflowing nodes on deletion.** It's perfectly fine for your delete implementation to simply remove a value from the leaf node; don't worry about maintaining the "at least $\lceil m/2 \rceil$ values" invariant.

You may be wondering what a `Split` is - a `Split` is a struct that indicates whether the operation below triggered a node split, and if it did, the node that was pushed up, so that the calling function can receive it. Let's say we're at node A and we call insert on our child; our child comes back and tells us that it has split, and pushes a new node up to us. We then add that node to node A, and potentially split again to our parent. In this project, we handle root node splitting for you; however, you must handle the cases where internal and leaf nodes split!

Some notes:

- A B+Tree is a recursive data structure, so you should expect your code to be recursive in nature! Take advantage of the fact that both internal and leaf nodes implement the `Node` interface.
- If any child function call returns an error, you should propagate that error upwards! Critically, there is an error field in the `Split` struct; if a child function call returns a `Split` with an error in it, the parent function call should also return this error.
- The `update` field in `insert` indicates whether the insertion is an insertion or an update. If `update == true`, then the function should only modify the value for an existing key. If `update == false`, then the function should only insert a new key-value pair.
- To insert or delete an entry, you should be shifting entries left or right to make space.
- Remember to always run `defer page.Put()` whenever you traverse a node!


## Part 2: Cursor Functions

Relevant files:

- `pkg/btree/cursor.go`
- `pkg/btree/btree.go`

Next, we'll want to take advantage of the B+Tree structure and define a cursor that can scan over leaf nodes. We've defined the basic cursor functions for you and filled out `TableStart` so you have a sense of how to approach the rest of the functions. With that, implement the following functions in `pkg/btree/cursor.go`:

```go
func TableEnd(table *BTreeIndex) (*Cursor, error)
func TableFind(table *BTreeIndex, key int64) (*Cursor, error)
func TableFindRange(table *BTreeIndex, startKey int64, endKey int64)
```

And the following in `pkg/btree/btree.go`:

```go
func (table *BTreeIndex) Select() ([]entry.Entry, error)
```

Some hints to get you started:

- Use the `TableStart` implementation as a guide to how to interact with nodes and their underlying page representation.
- Remember to always run `defer page.Put()` whenever you traverse a node!
- `StepForward` will return `true` when the cursor has reached the end of the table.
- To convert a cursor's current position into an Entry, use `GetEntry`.


## Debugging

We know that this is a difficult assignment, so we have a few tips on how to debug.

Each node currently can hold up to a few dozen entries before it will split. To lower the number of entries you need to insert before a split occurs, make the following changes:

```go
// var ENTRIES_PER_LEAF_NODE int64 = ((pager.PAGESIZE - LEAF_NODE_HEADER_SIZE) / ENTRYSIZE) - 1
var ENTRIES_PER_LEAF_NODE int64 = 5 // Or another integer

// ...

// var KEYS_PER_INTERNAL_NODE int64 = (ptrSpace / (KEY_SIZE + PN_SIZE)) - 1
var KEYS_PER_INTERNAL_NODE int64 = 5 // Or another integer
```

**WARNING: REMEMBER TO REVERT THESE CHANGES BEFORE YOU SUBMIT, OTHERWISE THE AUTOGRADER __WILL__ TIME OUT!**

Then, run your database on the command line. You should be able to `insert`, `delete`, and `update` entries (among other operations) after you've run `create btree table <table_name>`. Critically, by running `pretty from <table>`, you can pretty-print the current state of your B+Tree. This should provide some observability into the system that will be useful in debugging.

### Example Usage

Let's run our database using `./bumble -project db`. Next, we create a table using `create btree table t`, and insert keys [1, 2, 4, 5, 6, 8] with any value (`insert k v into t`). Let's observe the state of the database using `pretty from t` (pretty-print the table `t`):

```bash
bumble> pretty from t
[0] Internal (root) size: 2
 |
 |--> [2] Leaf size: 3
 |     |--> (1, 0)
 |     |--> (2, 0)
 |     |--> (4, 0)
 |     |--+
 |        | node @ 1
 |        v

 |    [KEY] 5
 |
 |--> [1] Leaf size: 3
 |     |--> (5, 0)
 |     |--> (6, 0)
 |     |--> (8, 0)
```

Let's dissect the above; we ran `pretty from t` and see that our root node is an internal node with page number 0, and has 2 children. Each of the leafs has three keys and three values. The leaf at page number 2 has a right sibling at page number 1.


## Testing

Run our unit tests on Gradescope. We've provided a subset of the tests [here](/static/posts/project/b+tree/btree_test_sample.go).


## Getting started

To get started, download the following stencil packages: [db](https://drive.google.com/file/d/1fyy0O7ohlSMlrXXVtkv8DToWVjMYUiTj/view?usp=sharing), [btree](https://drive.google.com/file/d/120iBQF-NYy6uFY4zj_Z3wFWTVj3j1V5r/view?usp=sharing). We've provided an updated `main.go` file [here](https://drive.google.com/file/d/1POqLJ3Ufp3UE9TOjo9uq_5hojS6CKrv1/view?usp=sharing). When finished, your filestructure should look like this:

```
./
    - cmd/
        - bumble/
    - pkg/
        - btree/
        - config/
        - db/
        - utils/
        - list/
        - pager/
        - repl/
```

---
