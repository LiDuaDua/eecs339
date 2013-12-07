#include <assert.h>
#include <stack>
#include "btree.h"

KeyValuePair::KeyValuePair()
{}


KeyValuePair::KeyValuePair(const KEY_T &k, const VALUE_T &v) :
key(k), value(v)
{}


KeyValuePair::KeyValuePair(const KeyValuePair &rhs) :
key(rhs.key), value(rhs.value)
{}


KeyValuePair::~KeyValuePair()
{}


KeyValuePair & KeyValuePair::operator=(const KeyValuePair &rhs)
{
	return *( new (this) KeyValuePair(rhs));
}

BTreeIndex::BTreeIndex(SIZE_T keysize,
						SIZE_T valuesize,
						BufferCache *cache,
						bool unique)
{
	superblock.info.keysize=keysize;
	superblock.info.valuesize=valuesize;
	buffercache=cache;
	// note: ignoring unique now
}

BTreeIndex::BTreeIndex()
{
	// shouldn't have to do anything
}


//
// Note, will not attach!
//
BTreeIndex::BTreeIndex(const BTreeIndex &rhs)
{
	buffercache=rhs.buffercache;
	superblock_index=rhs.superblock_index;
	superblock=rhs.superblock;
}

BTreeIndex::~BTreeIndex()
{
	// shouldn't have to do anything
}


BTreeIndex & BTreeIndex::operator=(const BTreeIndex &rhs)
{
	return *(new(this)BTreeIndex(rhs));
}


ERROR_T BTreeIndex::AllocateNode(SIZE_T &n)
{
	n=superblock.info.freelist;

	if (n==0) {
		return ERROR_NOSPACE;
	}

	BTreeNode node;

	node.Unserialize(buffercache,n);

	assert(node.info.nodetype==BTREE_UNALLOCATED_BLOCK);

	superblock.info.freelist=node.info.freelist;

	superblock.Serialize(buffercache,superblock_index);

	buffercache->NotifyAllocateBlock(n);

	return ERROR_NOERROR;
}


ERROR_T BTreeIndex::DeallocateNode(const SIZE_T &n)
{
	BTreeNode node;

	node.Unserialize(buffercache,n);

	assert(node.info.nodetype!=BTREE_UNALLOCATED_BLOCK);

	node.info.nodetype=BTREE_UNALLOCATED_BLOCK;

	node.info.freelist=superblock.info.freelist;

	node.Serialize(buffercache,n);

	superblock.info.freelist=n;

	superblock.Serialize(buffercache,superblock_index);

	buffercache->NotifyDeallocateBlock(n);

	return ERROR_NOERROR;

}

ERROR_T BTreeIndex::Attach(const SIZE_T initblock, const bool create)
{
	ERROR_T rc;

	superblock_index=initblock;
	assert(superblock_index==0);

	if (create) {
		// build a super block, root node, and a free space list
		//
		// Superblock at superblock_index
		// root node at superblock_index+1
		// free space list for rest
		BTreeNode newsuperblock(BTREE_SUPERBLOCK,
								superblock.info.keysize,
								superblock.info.valuesize,
								buffercache->GetBlockSize());
		newsuperblock.info.rootnode=superblock_index+1;
		newsuperblock.info.freelist=superblock_index+2;
		newsuperblock.info.numkeys=0;

		buffercache->NotifyAllocateBlock(superblock_index);

		rc=newsuperblock.Serialize(buffercache,superblock_index);

		if (rc) {
			return rc;
		}

		BTreeNode newrootnode(BTREE_ROOT_NODE,
								superblock.info.keysize,
								superblock.info.valuesize,
								buffercache->GetBlockSize());
		newrootnode.info.rootnode=superblock_index+1;
		newrootnode.info.freelist=superblock_index+2;
		newrootnode.info.numkeys=0;

		buffercache->NotifyAllocateBlock(superblock_index+1);

		rc=newrootnode.Serialize(buffercache,superblock_index+1);

		if (rc) {
			return rc;
		}

		for (SIZE_T i=superblock_index+2; i<buffercache->GetNumBlocks();i++) {
			BTreeNode newfreenode(BTREE_UNALLOCATED_BLOCK,
									superblock.info.keysize,
									superblock.info.valuesize,
									buffercache->GetBlockSize());
			newfreenode.info.rootnode=superblock_index+1;
			newfreenode.info.freelist= ((i+1)==buffercache->GetNumBlocks()) ? 0: i+1;

			rc = newfreenode.Serialize(buffercache,i);

			if (rc) {
				return rc;
			}

		}
	}

	// OK, now, mounting the btree is simply a matter of reading the superblock

	return superblock.Unserialize(buffercache,initblock);
}


ERROR_T BTreeIndex::Detach(SIZE_T &initblock)
{
	return superblock.Serialize(buffercache,superblock_index);
}

ERROR_T BTreeIndex::LookupOrUpdateInternal(const SIZE_T &node,
											const BTreeOp op,
											const KEY_T &key,
											VALUE_T &value)
{
	BTreeNode b;
	ERROR_T rc;
	SIZE_T offset;
	KEY_T testkey;
	SIZE_T ptr;

	rc= b.Unserialize(buffercache,node);

	if (rc!=ERROR_NOERROR) {
		return rc;
	}

	switch (b.info.nodetype) {
	case BTREE_ROOT_NODE:
	case BTREE_INTERIOR_NODE:
		// Scan through key/ptr pairs
		//and recurse if possible
		for (offset=0;offset<b.info.numkeys;offset++) {
			rc=b.GetKey(offset,testkey);
			if (rc) { return rc; }
			if (key<testkey || key==testkey) {
				// OK, so we now have the first key that's larger
				// so we ned to recurse on the ptr immediately previous to
				// this one, if it exists
				rc=b.GetPtr(offset,ptr);
				if (rc) { return rc; }
				return LookupOrUpdateInternal(ptr,op,key,value);
			}
		}
		// if we got here, we need to go to the next pointer, if it exists
		if (b.info.numkeys>0) {
			rc=b.GetPtr(b.info.numkeys,ptr);
			if (rc) { return rc; }
			return LookupOrUpdateInternal(ptr,op,key,value);
		} else {
			// There are no keys at all on this node, so nowhere to go
			return ERROR_NONEXISTENT;
		}
		break;
	case BTREE_LEAF_NODE:
		// Scan through keys looking for matching value
		for (offset=0;offset<b.info.numkeys;offset++) {
			rc=b.GetKey(offset,testkey);
			if (rc) { return rc; }
			if (testkey==key) {
				if (op==BTREE_OP_LOOKUP) {
					return b.GetVal(offset,value);
				} else {
					ERROR_T out = b.SetVal(offset,value);
					if(out == ERROR_NOERROR){
						return b.Serialize(buffercache,node);
					}else{
						return out;
					}
				}
			}
		}
		return ERROR_NONEXISTENT;
		break;
	default:
		// We can't be looking at anything other than a root, internal, or leaf
		return ERROR_INSANE;
		break;
	}

	return ERROR_INSANE;
}


static ERROR_T PrintNode(ostream &os, SIZE_T nodenum, BTreeNode &b, BTreeDisplayType dt)
{
	KEY_T key;
	VALUE_T value;
	SIZE_T ptr;
	SIZE_T offset;
	ERROR_T rc;
	unsigned i;

	if (dt==BTREE_DEPTH_DOT) {
		os << nodenum << " [ label=\""<<nodenum<<": ";
	} else if (dt==BTREE_DEPTH) {
		os << nodenum << ": ";
	} else {
	}

	switch (b.info.nodetype) {
	case BTREE_ROOT_NODE:
	case BTREE_INTERIOR_NODE:
		if (dt==BTREE_SORTED_KEYVAL) {
		} else {
			if (dt==BTREE_DEPTH_DOT) {
			} else {
				os << "Interior: ";
			}
			for (offset=0;offset<=b.info.numkeys;offset++) {
				rc=b.GetPtr(offset,ptr);
				if (rc) { return rc; }
				os << "*" << ptr << " ";
				// Last pointer
				if (offset==b.info.numkeys) break;
				rc=b.GetKey(offset,key);
				if (rc) { return rc; }
				for (i=0;i<b.info.keysize;i++) {
					os << key.data[i];
				}
				os << " ";
			}
		}
		break;
	case BTREE_LEAF_NODE:
		if (dt==BTREE_DEPTH_DOT || dt==BTREE_SORTED_KEYVAL) {
		} else {
			os << "Leaf: ";
		}
		for (offset=0;offset<b.info.numkeys;offset++) {
			if (offset==0) {
				// special case for first pointer
				rc=b.GetPtr(offset,ptr);
				if (rc) { return rc; }
				if (dt!=BTREE_SORTED_KEYVAL) {
					os << "*" << ptr << " ";
				}
			}
			if (dt==BTREE_SORTED_KEYVAL) {
				os << "(";
			}
			rc=b.GetKey(offset,key);
			if (rc) { return rc; }
			for (i=0;i<b.info.keysize;i++) {
				os << key.data[i];
			}
			if (dt==BTREE_SORTED_KEYVAL) {
				os << ",";
			} else {
				os << " ";
			}
			rc=b.GetVal(offset,value);
			if (rc) { return rc; }
			for (i=0;i<b.info.valuesize;i++) {
				os << value.data[i];
			}
			if (dt==BTREE_SORTED_KEYVAL) {
				os << ")\n";
			} else {
				os << " ";
			}
		}
		break;
	default:
		if (dt==BTREE_DEPTH_DOT) {
			os << "Unknown("<<b.info.nodetype<<")";
		} else {
			//EVIL SUPPRESSED ERROR for rachel's sanity. :D
			//os << "Unsupported Node Type " << b.info.nodetype ;
		}
	}
	if (dt==BTREE_DEPTH_DOT) {
		os << "\" ]";
	}
	return ERROR_NOERROR;
}

ERROR_T BTreeIndex::Lookup(const KEY_T &key, VALUE_T &value)
{
	return LookupOrUpdateInternal(superblock.info.rootnode, BTREE_OP_LOOKUP, key, value);
}

ERROR_T BTreeIndex::Insert(const KEY_T &key, const VALUE_T &value)
{
	return InsertInternal(superblock.info.rootnode, superblock_index, key, value);
}

ERROR_T BTreeIndex::InsertInternal(const SIZE_T nodeblock, const SIZE_T &parent, const KEY_T &key, const VALUE_T &value)
{
	BTreeNode node;
	ERROR_T rc;
	SIZE_T offset;
	KEY_T testkey;
	//VALUE_T val; // <- TMP!
	SIZE_T ptr;
	SIZE_T maxKeysInterior = MaxKeysInterior() * 2 / 3;
	SIZE_T maxKeysLeaf = MaxKeysLeaf() * 2 / 3;

	//increment numkeys in superblock
	//superblock.info.numkeys++;

	rc = node.Unserialize(buffercache, nodeblock);

	// cout << endl;
	// for(offset=0; offset<node.info.numkeys; offset++){
	// 	node.GetKey(offset, testkey);
	// 	if (node.info.nodetype != BTREE_LEAF_NODE) {
	// 		node.GetPtr(offset, ptr);
	// 		cout << "node at block: " << nodeblock << " at offset: " << offset << " has key: " << testkey.data << " ptr: " << ptr << endl;
	// 	} else {
	// 		node.GetVal(offset, val);
	// 		cout << "leaf at block: " << nodeblock << " at offset: " << offset << " has key: " << testkey.data << " value: " << val.data << endl;
	// 	}
	// }
	// cout << endl;

	if (rc) { return rc; }

	cout << "Trying to insert key " << key.data << " and value " << value.data << " at block " << nodeblock << endl;

	switch (node.info.nodetype) {
	case BTREE_ROOT_NODE:
		//cout << "In root node" << endl;
		if (node.info.numkeys == 0) {
			cout << "making leaf node with key: " << key.data << " and value: " << value.data << endl;
			rc = Create(BTREE_LEAF_NODE, key, value, 0, ptr);
			if (rc) { return rc; }

			node.info.numkeys++;
			rc = node.SetKey(0, key);
			if (rc) { return rc; }

			rc = node.SetPtr(0, ptr);
			if (rc) { return rc; }

			rc = node.Serialize(buffercache, nodeblock);
			return rc;
		}
	case BTREE_INTERIOR_NODE:
		for (offset=0; offset<node.info.numkeys; offset++) {
			rc = node.GetKey(offset,testkey);
			if (rc) { return rc; }
			//cout << "interior node test key: " << testkey.data << endl;
			if (key < testkey) {
				rc = node.GetPtr(offset, ptr);
				if (rc) { return rc; }

				cout << "found key: " << key.data << " < " << testkey.data << " in interior node offset " << offset << ", recursing into block " << ptr << endl;
				rc = InsertInternal(ptr, nodeblock, key, value);
				if (rc) { return rc; }

				break;
			} else if (key == testkey) {
				superblock.info.numkeys--;
				return ERROR_CONFLICT;
			}
		}

		// no key was less than or equal to the key we're inserting. try the last pointer if there is one
		if (offset == node.info.numkeys) {
			rc = node.GetPtr(offset, ptr);
			if (rc) { return rc; }

			if (ptr && ptr > 0) {
				cout << "found a node at the last pointer, key > " << key.data << ", offset: " << offset << ", recursing" << endl;

				rc = InsertInternal(ptr, nodeblock, key, value);
				if (rc) { return rc; }
			} else {
				// there isn't a pointer to a node at the end. let's add one.
				rc = Create(BTREE_LEAF_NODE, key, value, 0, ptr); // <- note: ptr is being redefined
				if (rc) { return rc; }

				cout << "Making leaf node into block: " << ptr << " offset: " << offset << endl;

				rc = node.SetPtr(offset, ptr);
				if (rc) { return rc; }

				cout << "serializing after making new ptr" << endl;
				rc = node.Serialize(buffercache, nodeblock);
			}
		}

		//inserted successfully. check that node didn't grow too large
		if (node.info.numkeys <= maxKeysInterior) {
			return rc;
		} else if (node.info.nodetype == BTREE_ROOT_NODE) {
			cout << "splitting the root node" << endl;

			rc = node.GetKey(node.info.numkeys-1, testkey);
			if (rc) { return rc; }

			rc = Create(BTREE_ROOT_NODE, testkey, value, superblock.info.rootnode, ptr);
			if (rc) { return rc; }

			rc = node.Unserialize(buffercache, nodeblock);
			if (rc) { return rc; }

			cout << "hopefully made a root node. at block " << superblock.info.rootnode << " this node (" << nodeblock << ") is now of type " << node.info.nodetype << endl;

			rc = Split(node, nodeblock, superblock.info.rootnode);

			return rc;
		} else {
			cout << "splitting an interior node" << endl;
			rc = Split(node, nodeblock, parent);
			if (rc) { return rc; }

			return node.Serialize(buffercache, nodeblock);
		}

		break;
	case BTREE_LEAF_NODE:
		cout << "inserting key: " << key.data << " value: " << value.data << " into leaf at block " << nodeblock << endl;
        	//increment numkeys in superblock
                superblock.info.numkeys++;

		rc = InsertKeyInternal(node, key, value, 0);
		if (rc) { return rc; }

		rc = node.Serialize(buffercache, nodeblock);
		if (rc) { return rc; }

		if (node.info.numkeys <= maxKeysLeaf) {
			//under the limit of keys. carry on
			return rc;
		} else {
			// need to split
			cout << "splitting a leaf node" << endl;
			rc = Split(node, nodeblock, parent);

			return rc;
		}
	default:
		// We can't be looking at anything other than a root, internal, or leaf
		return ERROR_INSANE;
		break;
	}

	return ERROR_INSANE;
}

SIZE_T BTreeIndex::MaxKeysLeaf()
{
	SIZE_T n = (superblock.info.blocksize - 10 * sizeof(SIZE_T) - sizeof(ostream) - superblock.info.valuesize) / (superblock.info.keysize + superblock.info.valuesize);
	return n;
}

SIZE_T BTreeIndex::MaxKeysInterior()
{
	SIZE_T n = (superblock.info.blocksize - 10 * sizeof(SIZE_T) - sizeof(ostream) - sizeof(SIZE_T)) / (superblock.info.keysize + sizeof(SIZE_T));
	return n;
}

ERROR_T BTreeIndex::Split(BTreeNode &node, const SIZE_T &nodeblock, const SIZE_T &parent)
{
	ERROR_T rc;
	SIZE_T offset;
	SIZE_T numkeysClone = node.info.numkeys / 2;
	KEY_T key;
	KEY_T testkey;
	VALUE_T value;
	SIZE_T ptr;
	SIZE_T n;
	BTreeNode parentNode;

	cout << "In split function" << endl;
	// node.GetKey(node.info.numkeys-1, key);
	// cout << "the old largest key is " << key.data << endl;

	//clone node
	BTreeNode clone = BTreeNode(node);

	//odd number of keys?
	if (node.info.numkeys % 2 == 1) {
		node.info.numkeys++;
	}
	node.info.numkeys /= 2;

	//shift over all values in clone
	for (offset=0; offset<numkeysClone; offset++) {
		rc = clone.GetKey(offset + node.info.numkeys, key);
		if (rc) { return rc; }

		rc = clone.SetKey(offset, key);
		if (rc) { return rc; }

		if (node.info.nodetype == BTREE_LEAF_NODE) {
			rc = clone.GetVal(offset + node.info.numkeys, value);
			if (rc) { return rc; }

			rc = clone.SetVal(offset, value);
			if (rc) { return rc; }
		} else {
			rc = clone.GetPtr(offset + node.info.numkeys, ptr);
			if (rc) { return rc; }

			rc = clone.SetPtr(offset, ptr);
			if (rc) { return rc; }
		}
	}

	//cout << "this should still be that key: " << key.data << endl;

	clone.info.numkeys = numkeysClone;

	AllocateNode(n);

	rc = clone.Serialize(buffercache, n);
	if (rc) { return rc; }

	rc = parentNode.Unserialize(buffercache, parent);
	if (rc) { return rc; }

	//search for old key in parent and replace it with node's largest key
	for (offset=0; offset<parentNode.info.numkeys; offset++) {
		rc = parentNode.GetKey(offset, testkey);
		if (rc) { return rc; }

		if (testkey == key) {
			rc = node.GetKey(node.info.numkeys-1, testkey);
			if (rc) { return rc; }

			cout << "replacing old key-ptr with " << testkey.data << endl;

			rc = parentNode.SetKey(offset, testkey);
			if (rc) { return rc; }

			break;
		}
	}

	if (offset == parentNode.info.numkeys) {
		rc = node.GetKey(node.info.numkeys-1, testkey);
		if (rc) { return rc; }
		cout << "couldn't find the key (" << testkey.data << "). must be dealing with an end ptr of an interior node" << endl;

		parentNode.info.numkeys++;
		rc = parentNode.SetKey(offset, testkey);
		if (rc) { return rc; }

		rc = parentNode.SetPtr(offset+1, n);
		if (rc) { return rc; }
	} else {
		rc = InsertKeyInternal(parentNode, key, value, n);
		if (rc) { return rc; }
	}

	cout << "clones allocated block: " << n << " whose key should be " << key.data << endl;

	for(offset=0; offset<parentNode.info.numkeys; offset++){
		parentNode.GetKey(offset, key);
		parentNode.GetPtr(offset, ptr);

		cout << "parent node of split node (block " << parent << "). offset: " << offset << " key: " << key.data << " ptr: " << ptr << endl;
	}
	parentNode.GetPtr(offset, ptr);

	cout << "parent node of split node final ptr: " << ptr << endl;

	rc = parentNode.Serialize(buffercache, parent);
	if (rc) { return rc; }

	rc = node.Serialize(buffercache, nodeblock);

	return rc;
}

ERROR_T BTreeIndex::InsertKeyInternal(BTreeNode &node, const KEY_T &key, const VALUE_T &value, const SIZE_T &pointer)
{
	ERROR_T rc;
	KEY_T tmpkey1;
	KEY_T tmpkey2;
	VALUE_T tmpvalue1;
	VALUE_T tmpvalue2;
	SIZE_T tmpptr1;
	SIZE_T tmpptr2;
	SIZE_T offset;
	bool hasSwapped = false;

	//cout << "pointer: " << pointer << endl;

	if (node.info.nodetype == BTREE_LEAF_NODE) {
		node.info.numkeys++;
	} else {
		//only increase numkeys in interior node if rightmost pointer exists
		rc = node.GetPtr(node.info.numkeys, tmpptr1);
		if (rc) { return rc; }

		if (tmpptr1 > 0) {
			cout << "increasing numkeys of an interior node" << endl;
			node.info.numkeys++;
		}
	}

	for (offset=0; offset<node.info.numkeys; offset++) {
		rc = node.GetKey(offset,tmpkey1);
		if (rc) { return rc; }

		cout << "in node key insert. offset: " << offset << " tmpkey1: " << tmpkey1.data << " key: " << key.data << " hasSwapped: " << hasSwapped << endl;
		//bool tmp = tmpkey1.data[0] == NULL;
		if (!hasSwapped && (tmpkey1.data[0] == NULL || key < tmpkey1 || (node.info.nodetype == BTREE_LEAF_NODE && offset == node.info.numkeys-1))) {
			hasSwapped = true;

			tmpkey2 = tmpkey1;

			cout << "swapping key over in node" << endl;
			//copy the key and value over one offset

			//if (node.info.nodetype == BTREE_LEAF_NODE || offset != node.info.numkeys-1) {
				rc = node.SetKey(offset, key);
				if (rc) { return rc; }
			//}

			if (node.info.nodetype == BTREE_LEAF_NODE) {
				rc = node.GetVal(offset, tmpvalue2);
				if (rc) { return rc; }

				rc = node.SetVal(offset, value);
				if (rc) { return rc; }
			} else {
				rc = node.GetPtr(offset, tmpptr2);
				if (rc) { return rc; }

				rc = node.SetPtr(offset, pointer);
				if (rc) { return rc; }
			}

			//cout << "tmpkey2: " << tmpkey2.data << " tmpptr2: " << tmpptr2 << endl;
		} else if (hasSwapped) {
			cout << "continuing the swap. tmpkey2: " << tmpkey2.data << " tmpvalue2: " << tmpvalue2.data << endl;

			//if (node.info.nodetype == BTREE_LEAF_NODE || offset != node.info.numkeys-1) {
				rc = node.SetKey(offset, tmpkey2);
				if (rc) { return rc; }
			//}

			tmpkey2 = tmpkey1;

			if (node.info.nodetype == BTREE_LEAF_NODE) {
				rc = node.GetVal(offset, tmpvalue1);
				if (rc) { return rc; }

				rc = node.SetVal(offset, tmpvalue2);
				if (rc) { return rc; }

				tmpvalue2 = tmpvalue1;
			} else {
				rc = node.GetPtr(offset, tmpptr1);
				if (rc) { return rc; }

				rc = node.SetPtr(offset, tmpptr2);
				if (rc) { return rc; }

				tmpptr2 = tmpptr1;

				// cout << "tmpptr1: " << tmpptr1 << " tmpptr2: " << tmpptr2 << " tmpkey1: " << tmpkey1.data << " tmpkey2: " << tmpkey2.data << endl;
			}
		} else if (tmpkey1 == key) {
			cout << "tmpkey: " << tmpkey1.data << " key: " << key.data << endl;
			superblock.info.numkeys--;
			node.info.numkeys--;
			return ERROR_CONFLICT;
		}
	}

	if (node.info.nodetype != BTREE_LEAF_NODE) {
		// got one more ptr to assign if an interior node

		if (hasSwapped && tmpptr2 > 0) {
			cout << "interior node. adding one more ptr: " << tmpptr2 << endl;
			rc = node.SetPtr(offset, tmpptr2);
			if (rc) { return rc; }
		} else {
			cout << "interior node. adding one more ptr: " << pointer << endl;
			hasSwapped = true;
			rc = node.SetPtr(offset, pointer);
			if (rc) { return rc; }
		}

	}

	if (!hasSwapped) {
		cout << "Whoah! You entered insert and never swapped around keys, values or ptrs!" << endl;
		return ERROR_INSANE;
	}

	//cout << "leaving node key insert" << endl;
	return rc;
}

ERROR_T BTreeIndex::Create(int nodetype, const KEY_T &key, const VALUE_T &value, const SIZE_T &pointer, SIZE_T &n)
{
	BTreeNode root;
	ERROR_T rc;

	rc = root.Unserialize(buffercache,superblock.info.rootnode);

	if (rc) { return rc; }

	BTreeNode node = BTreeNode(nodetype, root.info.keysize, root.info.valuesize, root.info.blocksize);

	switch (nodetype) {
	case BTREE_ROOT_NODE:
		node.info.numkeys++;
		node.SetKey(0, key);
		node.SetPtr(0, pointer);

		AllocateNode(n);

		rc = node.Serialize(buffercache, n);
		if (rc) { return rc; }

		root.info.nodetype = BTREE_INTERIOR_NODE;

		rc = root.Serialize(buffercache, superblock.info.rootnode);
		if (rc) { return rc; }

		superblock.info.rootnode = n;

		rc = superblock.Serialize(buffercache, superblock_index);
		break;
	case BTREE_LEAF_NODE:
		node.info.numkeys++;
		node.SetKey(0, key);
		node.SetVal(0, value);

		AllocateNode(n);

		rc = node.Serialize(buffercache, n);
		break;
	}

	return rc;
}

ERROR_T BTreeIndex::Update(const KEY_T &key, const VALUE_T &value)
{
	VALUE_T temp = (VALUE_T)value;
	return LookupOrUpdateInternal(superblock.info.rootnode, BTREE_OP_UPDATE, key, temp);
}


ERROR_T BTreeIndex::Delete(const KEY_T &key)
{
	// This is optional extra credit
	//
	//
	return ERROR_UNIMPL;
}


//
//
// DEPTH first traversal
// DOT is Depth + DOT format
//

ERROR_T BTreeIndex::DisplayInternal(const SIZE_T &node,
									ostream &o,
									BTreeDisplayType display_type) const
{
	KEY_T testkey;
	SIZE_T ptr;
	BTreeNode b;
	ERROR_T rc;
	SIZE_T offset;

	rc= b.Unserialize(buffercache,node);

	if (rc!=ERROR_NOERROR) {
		return rc;
	}

	rc = PrintNode(o,node,b,display_type);

	if (rc) { return rc; }

	if (display_type==BTREE_DEPTH_DOT) {
		o << ";";
	}

	if (display_type!=BTREE_SORTED_KEYVAL) {
		o << endl;
	}

	switch (b.info.nodetype) {
	case BTREE_ROOT_NODE:
	case BTREE_INTERIOR_NODE:
		if (b.info.numkeys>0) {
			for (offset=0;offset<=b.info.numkeys;offset++) {
				rc=b.GetPtr(offset,ptr);
				if (rc) { return rc; }
				if (display_type==BTREE_DEPTH_DOT) {
					o << node << " -> "<<ptr<<";\n";
				}
				rc=DisplayInternal(ptr,o,display_type);
				if (rc) { return rc; }
			}
		}
		return ERROR_NOERROR;
		break;
	case BTREE_LEAF_NODE:
		return ERROR_NOERROR;
		break;
	default:
		if (display_type==BTREE_DEPTH_DOT) {
		} else {
			//EVIL SUPPRESSED ERROR for rachel's sanity. :D
			//o << "Unsupported Node Type " << b.info.nodetype ;
		}
		return ERROR_INSANE;
	}

	return ERROR_NOERROR;
}


ERROR_T BTreeIndex::Display(ostream &o, BTreeDisplayType display_type) const
{
	ERROR_T rc;
	if (display_type==BTREE_DEPTH_DOT) {
		o << "digraph tree { \n";
	}
	rc=DisplayInternal(superblock.info.rootnode,o,display_type);
	if (display_type==BTREE_DEPTH_DOT) {
		o << "}\n";
	}
	SanityCheck();
	return ERROR_NOERROR;
}
SIZE_T leafKeys = 1;

ERROR_T BTreeIndex::SanityCheck() const {
	cout<<"Inside of sanitycheck"<<endl;
	SIZE_T check = SanityCheckHelper(superblock.info.rootnode);
	if(leafKeys != superblock.info.numkeys){
	cout<<"Error. Number of keys in superblock: "<<superblock.info.numkeys<<" does not match number of keys in the leaves: "<<leafKeys<<endl;
              return ERROR_GENERAL;
             }
	else{
	cout<<"Number of keys in superblock matches number of keys in the leaves"<<endl;
   }
	return check;
}

SIZE_T BTreeIndex::MaxKeysLeafCheck() const
{
	SIZE_T n = (superblock.info.blocksize - 10 * sizeof(SIZE_T) - sizeof(ostream)) / (superblock.info.keysize + superblock.info.valuesize);
	return n;
}

ERROR_T BTreeIndex::SanityCheckHelper(const SIZE_T &node) const
{
//	cout<<"Inside Sanity CheckHelper"<<endl;
	KEY_T testkey;
	KEY_T testkey2;
	SIZE_T ptr;
	BTreeNode b;
	ERROR_T rc;
	SIZE_T offset;
	SIZE_T maxKeyLeaf=MaxKeysLeafCheck()*2/3;

	rc=b.Unserialize(buffercache,node);
	if (rc) { return rc;}

	switch(b.info.nodetype){
	case BTREE_ROOT_NODE:
	case BTREE_INTERIOR_NODE:
		if(b.info.numkeys>0){
			//NOTE: When we have the correct insert function  need offset
			//to be <= to numKeys
			cout<<"Number of keys in current node: "<<b.info.numkeys<<endl;
			for(offset=0;offset<b.info.numkeys;offset++){
				//cout<<"Offset is: "<<offset<<endl;
				rc=b.GetPtr(offset,ptr);
				//cout<<"Ptr is: "<<ptr<<endl;
				if(rc){return rc;}
				rc = SanityCheckHelper(ptr);
				if(rc){return rc;}
			}
		//No keys at all in the node
		return ERROR_NONEXISTENT;
		}
	case BTREE_LEAF_NODE:
		//Check number of keys to make sure the node isn't too full
		if(b.info.numkeys > maxKeyLeaf){
			cout<<"Error. You have too many keys in the leaf"<<endl;
			return ERROR_NOSPACE;
		}
		else{
			cout<<"YAY! Leaf node has right number key, value pairs"<<endl;
		}
		//Now check to make sure that the key value pairs in the leaf
		//are in the correct order
		cout<<"Leaf has: "<<b.info.numkeys<<" number of keys"<<endl;
		for(offset=0;offset<b.info.numkeys-1;offset++){
			rc=b.GetKey(offset, testkey);
			if(rc){return rc;}

			rc=b.GetKey(offset+1, testkey2);
			if(rc){return rc;}

			if(testkey < testkey2){
				cout<<testkey.data<<" is smaller than " <<testkey2.data<<endl;
			//	return ERROR_NOERROR;
			}
			else{
				cout<<"Error. Key: "<<testkey.data<<" and Key: "<<testkey2.data<<" are out of order."<<endl;
				return ERROR_GENERAL;
			}
			leafKeys++;
		}
	//	leafKeys=leafKeys+b.info.numkeys;
		return ERROR_NOERROR;
	}
//	if(leafKeys != superblock.info.numkeys){
//		cout<<"Error. Number of keys in superblock: "<<superblock.info.numkeys<<" does not match number of keys in the leaves: "<<leafKeys<<endl;
//		return ERROR_GENERAL;
//	}
//	else{
//		cout<<"Number of keys in superblock match number of keys in the leaves"<<endl;
//		return ERROR_NOERROR;
//	}
}


ostream & BTreeIndex::Print(ostream &os) const
{
	Display(os, BTREE_DEPTH_DOT);
	return os;
}
