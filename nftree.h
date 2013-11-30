/*
 *  This file is part of the nfdump project.
 *
 *  Copyright (c) 2004, SWITCH - Teleinformatikdienste fuer Lehre und Forschung
 *  All rights reserved.
 *  
 *  Redistribution and use in source and binary forms, with or without 
 *  modification, are permitted provided that the following conditions are met:
 *  
 *   * Redistributions of source code must retain the above copyright notice, 
 *     this list of conditions and the following disclaimer.
 *   * Redistributions in binary form must reproduce the above copyright notice, 
 *     this list of conditions and the following disclaimer in the documentation 
 *     and/or other materials provided with the distribution.
 *   * Neither the name of SWITCH nor the names of its contributors may be 
 *     used to endorse or promote products derived from this software without 
 *     specific prior written permission.
 *  
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
 *  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
 *  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
 *  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
 *  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
 *  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
 *  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
 *  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
 *  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
 *  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
 *  POSSIBILITY OF SUCH DAMAGE.
 *  
 *  $Author: peter $
 *
 *  $Id: nftree.h 34 2005-08-22 12:01:31Z peter $
 *
 *  $LastChangedRevision: 34 $
 *	
 */


/*
 * type definitions for nf tree
 */

typedef uint32_t (*flow_proc_t)(uint32_t *);

typedef struct FilterBlock {
	/* Filter specific data */
	uint32_t	offset;
	uint32_t	mask;
	uint32_t	value;

	/* Internal block info for tree setup */
	uint32_t	superblock;			/* Index of superblock */
	uint32_t	*blocklist;			/* index array of blocks, belonging to
								   	   this superblock */
	uint32_t	numblocks;			/* number of blocks in blocklist */
	uint32_t	OnTrue, OnFalse;	/* Jump Index for tree */
	int16_t		invert;				/* Invert result of test */
	uint16_t	comp;				/* comperator */
	flow_proc_t	function;			/* function for flow processing */
	char		*fname;				/* ascii function name */
} FilterBlock_t;

typedef struct FilterEngine_data_s {
	FilterBlock_t	*filter;
	uint32_t		StartNode;
	uint16_t 		Extended;
	uint32_t		*nfrecord;
	int (*FilterEngine)(struct FilterEngine_data_s *);
} FilterEngine_data_t;

/* 
 * Definitions
 */
enum { CMP_EQ = 0, CMP_GT, CMP_LT };

/*
 * filter functions:
 * For some filter functions, netflow records need to be processed first in order to filter them
 * This involves all data not directly available in the netflow record, such as packets per second etc. 
 * Filter speed is a bit slower due to extra netflow processsing
 * The sequence of the enum values must correspond with the entries in the flow_procs array
 */

enum { 	FUNC_NONE = 0,	/* no function - just plain filtering - just to be complete here */
		FUNC_PPS,		/* function code for pps ( packet per second ) filter function */
		FUNC_BPS,		/* function code for bps ( bits per second ) filter function */
		FUNC_BPP,		/* function code for bpp ( bytes per packet ) filter function */
		FUNC_DURATION	/* function code for duration ( in miliseconds ) filter function */
};

/* 
 * Filter Engine Functions
 */
int RunFilter(FilterEngine_data_t *args);
int RunExtendedFilter(FilterEngine_data_t *args);
/*
 * For testing purpose only
 */
int nblocks(void);

/*
 * Initialize globals
 */
void InitTree(void);

/*
 * Returns the current Filter Tree
 */
FilterEngine_data_t *CompileFilter(char *FilterSyntax);

/*
 * Clear Filter
 */
void ClearFilter(void);

/* 
 * Returns next free slot in blocklist
 */
uint32_t	NewBlock(uint32_t offset, uint32_t mask, uint32_t value, uint16_t comp, uint32_t function);

/* 
 * Connects the to blocks b1 and b2 ( AND ) and returns index of superblock
 */
uint32_t	Connect_AND(uint32_t b1, uint32_t b2);

/* 
 * Connects the to blocks b1 and b2 ( OR ) and returns index of superblock
 */
uint32_t	Connect_OR(uint32_t b1, uint32_t b2);

/* 
 * Inverts OnTrue and OnFalse
 */
uint32_t	Invert(uint32_t a );

/*
 * Dump Filterlist 
 */
void DumpList(FilterEngine_data_t *args);

/* 
 * Prints info while filer is running
 */
int RunDebugFilter(uint32_t	*block);
