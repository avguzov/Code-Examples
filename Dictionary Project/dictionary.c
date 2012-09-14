/****************************************************************************
 * dictionary.c
 *
 * Computer Science 50
 * Problem Set 6
 *
 * Implements a dictionary's functionality.
 ***************************************************************************/
#include <ctype.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "dictionary.h"
#include "trie.h"

// prototype for recursive function that frees trie with given root
 
void unloadrecurs(node *root);

// prototype for function that returns a new node 
node *create_node(void);
 
// trie
node *first = NULL;

// number of words in the dictionary
int dict_size = 0;

/*
 * Returns true if word is in dictionary else false.
 */

bool
check(const char *word)
{
    // hash value for current letter in word
    int hash_word;
    
    // pointer that keeps track of current position in trie
    node *current = first;
    
    // length of word being checked in dictionary
    int word_length = strlen(word);
    
    // traverses trie while iterating through word backwards
	for (int i = 0; i <word_length; i++)
	{
		if (word[i] != 39)
		    hash_word = tolower(word[i]) - 97;
		else
		    hash_word = 26;
		    
		current = current->children[hash_word];
		
		// returns false if word longer than path that exists for it
		if (current == NULL)
			return false;
	}
	
	// checks whether word is in trie
	if (current->is_word == true)
		return true;
    return false;
}


/*
 * Loads dict into memory.  Returns true if successful else false.
 */

bool
load(const char *dict)
{
    // open dictionary
    FILE *fp = fopen(dict, "r");
    if (fp == NULL)
        return false;
    
    // check for empty dictionary
	if (first == NULL)
		first  = create_node();
	
	// initialize variables used during file traversal
	node *current = first;
	int hash_word;
	    
    // iterates through file, one character at a time
    for (int c = fgetc(fp); c != EOF; c = fgetc(fp))
    {
        // allows only alphabetical characters and apostrophes
        if (isalpha(c) || (c == '\''))
        {
                    
            if (c != 39)
		        hash_word = c - 97;
   			else
		        hash_word = 26;
			    
		    // creates new node if pointer for current character is NULL    
			if (current->children[hash_word] == NULL)
			{
				current->children[hash_word] = create_node();
				current =current->children[hash_word];
				
			}
			else
			{
			    // moves to next node in trie
				current = current->children[hash_word];
					
				// if last character, marks end of a word
			}		
		}
		else
		{
		    dict_size++;
		    current->is_word = true;	
			// resets index and points back to the first node of the trie
			current = first;
		}	
	}
	
	// closes the file and returns
	fclose(fp);
	return true;
}


/*
 * Returns number of words in dictionary if loaded else 0 if not yet loaded.
 */

unsigned int
size(void)
{
    // returns the size of the dictionary
    return dict_size;
}


/*
 * Unloads dictionary from memory.  Returns true if successful else false.
 */

bool
unload(void)
{
    // calls recursive function which unloads dictionary and returns
    unloadrecurs(first);
    return true;
}

/* 
 * Recursive function called by unload to unload the dictionary from
 * memory
 */

void
unloadrecurs(node *root)
{
	// base case: returns if root doesn't point to any other nodes
	if (root == NULL)
		return;
	else
	{
	    // calls this function for every child of root node, then frees root
		for (int i = 0; i < 27; i++)
		    unloadrecurs(root->children[i]);
		free(root);	
	}
}	

/*
 * This function returns a pointer to a new initialized node
 */
 
node *
create_node(void)
{
    // mallocs new pointer to a struct node
    node *newptr = malloc(sizeof(node));
    
    // returns if null
    if (newptr == NULL)
        return NULL;
    
    // initializes new node 
    newptr->is_word = false;
    for (int i = 0; i < 27; i++)
        newptr->children[i] = NULL;
        
    return newptr;
}
