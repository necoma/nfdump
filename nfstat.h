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
 *  $Id: nfstat.h 47 2005-08-25 12:58:27Z peter $
 *
 *  $LastChangedRevision: 47 $
 *	
 */

/* Definitions */

/* 
 * Common type for FlowTableRecord_t and StatRecord_t
 * Needed for some common functions 
 * No variable is ever generated of this type. It's just needed for type coercing
 * Maybe some day I will rewrite that ... to make it easier
 */
typedef struct CommonRecord_s {
	// record chain - points to next record
	struct CommonRecord_s *next;	
	// flow counter parameters for FLOWS, PACKETS and BYTES
	uint64_t	counter[3];
	uint32_t	first;
	uint32_t	last;
	uint16_t	msec_first;
	uint16_t	msec_last;
} CommonRecord_t;

/*
 * Flow Table
 * In order to aggregate flows or to generate any flow statistics, the flows passed the filter
 * are stored into an internal hash table.
 */

/* Element of the Flow Table */
typedef struct FlowTableRecord {
	// record chain - points to next record with same hash in case of a hash collision
	struct FlowTableRecord *next;	
	// flow counter parameters for FLOWS, PACKETS and BYTES
	uint64_t	counter[3];
	uint32_t	first;
	uint32_t	last;
	uint16_t	msec_first;
	uint16_t	msec_last;

	// more flow parameters
  	uint8_t   	pad1;
  	uint8_t   	tcp_flags;
  	uint8_t   	proto;
  	uint8_t   	tos;

	// elements used for hash generation
	uint32_t	ip1;
	uint32_t	ip2;
	uint16_t	port1;
	uint16_t	port2;
} FlowTableRecord_t;

typedef struct hash_FlowTable {
	/* hash table data */
	uint16_t 			NumBits;		/* width of the hash table */
	uint32_t			IndexMask;		/* Mask which corresponds to NumBits */
	FlowTableRecord_t 	**bucket;		/* Hash entry point: points to elements in the flow block */
	FlowTableRecord_t 	**bucketcache;	/* in case of index collisions, this array points to the last element with that index */

	/* memory management */
	/* memory blocks - containing the flow blocks */
	FlowTableRecord_t	**memblock;		/* array holding all NumBlocks allocated flow blocks */
	uint32_t 			MaxBlocks;		/* Size of memblock array */
	/* flow blocks - containing the flows */
	uint32_t 			NumBlocks;		/* number of allocated flow blocks in memblock array */
	uint32_t 			Prealloc;		/* Number of flow records in each flow block */
	uint32_t			NextBlock;		/* This flow block contains the next free slot for a flow recorrd */
	uint32_t			NextElem;		/* This element in the current flow block is the next free slot */
} hash_FlowTable;

/*
 * Stat Table
 * In order to generate any flow element statistics, the flows passed the filter
 * are stored into an internal hash table.
 */

typedef struct StatRecord {
	// record chain
	struct StatRecord *next;
	// flow parameters
	uint64_t	counter[3];
	uint32_t	first;
	uint32_t	last;
	uint16_t	msec_first;
	uint16_t	msec_last;
	// key 
	uint32_t	stat_key;
} StatRecord_t;

typedef struct hash_StatTable {
	/* hash table data */
	uint16_t 			NumBits;		/* width of the hash table */
	uint32_t			IndexMask;		/* Mask which corresponds to NumBits */
	StatRecord_t 		**bucket;		/* Hash entry point: points to elements in the stat block */
	StatRecord_t 		**bucketcache;	/* in case of index collisions, this array points to the last element with that index */

	/* memory management */
	/* memory blocks - containing the stat records */
	StatRecord_t		**memblock;		/* array holding all NumBlocks allocated stat blocks */
	uint32_t 			MaxBlocks;		/* Size of memblock array */
	/* stat blocks - containing the stat records */
	uint32_t 			NumBlocks;		/* number of allocated stat blocks in memblock array */
	uint32_t 			Prealloc;		/* Number of stat records in each stat block */
	uint32_t			NextBlock;		/* This stat block contains the next free slot for a stat recorrd */
	uint32_t			NextElem;		/* This element in the current stat block is the next free slot */
} hash_StatTable;

typedef struct SortElement {
	void 		*record;
    uint64_t	count;
} SortElement_t;


/* Function prototypes */
int Init_FlowTable(uint16_t NumBits, uint32_t Prealloc);

int Init_StatTable(uint16_t NumBits, uint32_t Prealloc);

void Dispose_Tables(int flow_stat, int ip_stat);

int SetStat(char *str, int *element_stat, int *flow_stat);

int SetStat_DefaultOrder(char *order);

void InsertFlow(flow_record_t *flow_record);

int AddStat(flow_header_t *flow_header, flow_record_t *flow_record, int flow_stat, int element_stat);

void ReportAggregated(printer_t print_record, uint32_t limitflows, int date_sorted, int anon);

void ReportStat(char *record_header, printer_t print_record, int topN, int flow_stat, int ip_stat, int anon);

void PrintSortedFlows(printer_t print_record, uint32_t limitflows, int anon);
