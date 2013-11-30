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
 *  $Id: grammar.y 95 2007-10-15 06:05:26Z peter $
 *
 *  $LastChangedRevision: 95 $
 *	
 *
 *
 */

%{

#include "config.h"

#include <stdio.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>

#ifdef HAVE_STDINT_H
#include <stdint.h>
#endif

#include "nf_common.h"
#include "rbtree.h"
#include "nfdump.h"
#include "nffile.h"
#include "nftree.h"
#include "ipconv.h"
#include "util.h"

/*
 * function prototypes
 */
static void  yyerror(char *msg);

enum { SOURCE = 1, DESTINATION, SOURCE_AND_DESTINATION, SOURCE_OR_DESTINATION };


/* var defs */
extern int 			lineno;
extern char 		*yytext;
extern uint32_t	StartNode;
extern uint16_t	Extended;
extern int (*FilterEngine)(uint32_t *);


%}


%union {
	uint64_t		value;
	char			*s;
	FilterParam_t	param;
	void			*list;
}

%token ANY IP IF IDENT TOS FLAGS HOST NET PORT IN OUT SRC DST EQ LT GT
%token NUMBER IPSTRING ALPHA_FLAGS PROTOSTR PORTNUM ICMPTYPE AS PACKETS BYTES PPS BPS BPP DURATION
%token IPV4 IPV6
%token NOT END
%type <value>	expr NUMBER PORTNUM ICMPTYPE 
%type <s>	IPSTRING IDENT ALPHA_FLAGS PROTOSTR
%type <param> dqual inout term comp scale
%type <list> iplist ullist

%left	'+' OR
%left	'*' AND
%left	NEGATE

%%
prog: 		/* empty */
	| expr 	{   
		StartNode = $1; 
	}
	;

term:	ANY { /* this is an unconditionally true expression, as a filter applies in any case */
		$$.self = NewBlock(OffsetProto, 0, 0, CMP_EQ, FUNC_NONE, NULL ); 
	}

	| IDENT {	
		uint32_t	index = AddIdent($1);
		$$.self = NewBlock(0, 0, index, CMP_IDENT, FUNC_NONE, NULL ); 
	}

	| IPV4 { 
		$$.self = NewBlock(OffsetRecordFlags, (1LL << ShiftRecordFlags)  & MaskRecordFlags, 
					(0LL << ShiftRecordFlags)  & MaskRecordFlags, CMP_EQ, FUNC_NONE, NULL); 
	}

	| IPV6 { 
		$$.self = NewBlock(OffsetRecordFlags, (1LL << ShiftRecordFlags)  & MaskRecordFlags, 
					(1LL << ShiftRecordFlags)  & MaskRecordFlags, CMP_EQ, FUNC_NONE, NULL); 
	}

	| PROTOSTR { 
		int64_t	proto;
		char *s = $1;
		while ( *s && isdigit((int)s[0]) ) s++;
		if ( *s ) // alpha string for protocol
			proto = Proto_num($1);
		else 
			proto = atoi($1);

		if ( proto > 255 ) {
			yyerror("Protocol number > 255");
			YYABORT;
		}
		if ( proto < 0 ) {
			yyerror("Unknown protocol");
			YYABORT;
		}
		$$.self = NewBlock(OffsetProto, MaskProto, (proto << ShiftProto)  & MaskProto, CMP_EQ, FUNC_NONE, NULL); 
	}

	| PACKETS comp NUMBER scale	{ 
		$$.self = NewBlock(OffsetPackets, MaskPackets, $3 * $4.scale, $2.comp, FUNC_NONE, NULL); 
	}

	| BYTES comp NUMBER scale {	
		$$.self = NewBlock(OffsetBytes, MaskBytes, $3 * $4.scale , $2.comp, FUNC_NONE, NULL); 
	}

	| PPS comp NUMBER scale	{	
		$$.self = NewBlock(0, AnyMask, $3 * $4.scale , $2.comp, FUNC_PPS, NULL); 
	}

	| BPS comp NUMBER scale	{	
		$$.self = NewBlock(0, AnyMask, $3 * $4.scale , $2.comp, FUNC_BPS, NULL); 
	}

	| BPP comp NUMBER scale	{	
		$$.self = NewBlock(0, AnyMask, $3 * $4.scale , $2.comp, FUNC_BPP, NULL); 
	}

	| DURATION comp NUMBER {	
		$$.self = NewBlock(0, AnyMask, $3, $2.comp, FUNC_DURATION, NULL); 
	}

	| TOS comp NUMBER {	
		if ( $3 > 255 ) {
			yyerror("TOS must be 0..255");
			YYABORT;
		}
		$$.self = NewBlock(OffsetTos, MaskTos, ($3 << ShiftTos) & MaskTos, $2.comp, FUNC_NONE, NULL); 
	}

	| FLAGS comp NUMBER	{	
		if ( $3 > 63 ) {
			yyerror("Flags must be 0..63");
			YYABORT;
		}
		$$.self = NewBlock(OffsetFlags, MaskFlags, ($3 << ShiftFlags) & MaskFlags, $2.comp, FUNC_NONE, NULL); 
	}

	| FLAGS ALPHA_FLAGS	{	
		uint64_t fl = 0;
		if ( strlen($2) > 7 ) {
			yyerror("Too many flags");
			YYABORT;
		}

		if ( strchr($2, 'F') ) fl |=  1;
		if ( strchr($2, 'S') ) fl |=  2;
		if ( strchr($2, 'R') ) fl |=  4;
		if ( strchr($2, 'P') ) fl |=  8;
		if ( strchr($2, 'A') ) fl |=  16;
		if ( strchr($2, 'U') ) fl |=  32;
		if ( strchr($2, 'X') ) fl =  63;

		$$.self = NewBlock(OffsetFlags, (fl << ShiftFlags) & MaskFlags, 
					(fl << ShiftFlags) & MaskFlags, CMP_FLAGS, FUNC_NONE, NULL); 
	}

	| dqual IP IPSTRING { 	
		int af, bytes;
		if ( parse_ip(&af, $3, $$.ip, &bytes) == 0 ) {
			yyerror("Invalid IP address");
			YYABORT;
		}
		if ( ( af == PF_INET && bytes != 4 ) || ( af == PF_INET6 && bytes != 16 )) {
			yyerror("incomplete IP address");
			YYABORT;
		}

		$$.direction = $1.direction;
		if ( $$.direction == SOURCE ) {
			$$.self = Connect_AND(
				NewBlock(OffsetSrcIPv6b, MaskIPv6, $$.ip[1] , CMP_EQ, FUNC_NONE, NULL ),
				NewBlock(OffsetSrcIPv6a, MaskIPv6, $$.ip[0] , CMP_EQ, FUNC_NONE, NULL )
			);
		} else if ( $$.direction == DESTINATION) {
			$$.self = Connect_AND(
				NewBlock(OffsetDstIPv6b, MaskIPv6, $$.ip[1] , CMP_EQ, FUNC_NONE, NULL ),
				NewBlock(OffsetDstIPv6a, MaskIPv6, $$.ip[0] , CMP_EQ, FUNC_NONE, NULL )
			);
		} else if ( $$.direction == SOURCE_OR_DESTINATION ) {
			$$.self = Connect_OR(
						Connect_AND(
							NewBlock(OffsetSrcIPv6b, MaskIPv6, $$.ip[1] , CMP_EQ, FUNC_NONE, NULL ),
							NewBlock(OffsetSrcIPv6a, MaskIPv6, $$.ip[0] , CMP_EQ, FUNC_NONE, NULL )
						),
						Connect_AND(
							NewBlock(OffsetDstIPv6b, MaskIPv6, $$.ip[1] , CMP_EQ, FUNC_NONE, NULL ),
							NewBlock(OffsetDstIPv6a, MaskIPv6, $$.ip[0] , CMP_EQ, FUNC_NONE, NULL )
						)
			);
		} else if ( $$.direction == SOURCE_AND_DESTINATION ) {
			$$.self = Connect_AND(
						Connect_AND(
							NewBlock(OffsetSrcIPv6b, MaskIPv6, $$.ip[1] , CMP_EQ, FUNC_NONE, NULL ),
							NewBlock(OffsetSrcIPv6a, MaskIPv6, $$.ip[0] , CMP_EQ, FUNC_NONE, NULL )
						),
						Connect_AND(
							NewBlock(OffsetDstIPv6b, MaskIPv6, $$.ip[1] , CMP_EQ, FUNC_NONE, NULL ),
							NewBlock(OffsetDstIPv6a, MaskIPv6, $$.ip[0] , CMP_EQ, FUNC_NONE, NULL )
						)
			);
		} else {
			/* should never happen */
			yyerror("Internal parser error");
			YYABORT;
		}
	}

	| dqual IP IN '[' iplist ']' { 	

		$$.direction = $1.direction;
		if ( $$.direction == SOURCE ) {
			$$.self = NewBlock(OffsetSrcIPv6a, MaskIPv6, 0 , CMP_IPLIST, FUNC_NONE, (void *)$5 );
		} else if ( $$.direction == DESTINATION) {
			$$.self = NewBlock(OffsetDstIPv6a, MaskIPv6, 0 , CMP_IPLIST, FUNC_NONE, (void *)$5 );
		} else if ( $$.direction == SOURCE_OR_DESTINATION ) {
			$$.self = Connect_OR(
					NewBlock(OffsetSrcIPv6a, MaskIPv6, 0 , CMP_IPLIST, FUNC_NONE, (void *)$5 ),
					NewBlock(OffsetDstIPv6a, MaskIPv6, 0 , CMP_IPLIST, FUNC_NONE, (void *)$5 )
			);
		} else if ( $$.direction == SOURCE_AND_DESTINATION ) {
			$$.self = Connect_AND(
					NewBlock(OffsetSrcIPv6a, MaskIPv6, 0 , CMP_IPLIST, FUNC_NONE, (void *)$5 ),
					NewBlock(OffsetDstIPv6a, MaskIPv6, 0 , CMP_IPLIST, FUNC_NONE, (void *)$5 )
			);
		} else {
			/* should never happen */
			yyerror("Internal parser error");
			YYABORT;
		}
	}

	| dqual PORT comp NUMBER {	
		$$.direction = $1.direction;
		if ( $4 > 65535 ) {
			yyerror("Port outside of range 0..65535");
			YYABORT;
		}

		if ( $$.direction == SOURCE ) {
			$$.self = NewBlock(OffsetPort, MaskSrcPort, ($4 << ShiftSrcPort) & MaskSrcPort, $3.comp, FUNC_NONE, NULL );
		} else if ( $$.direction == DESTINATION) {
			$$.self = NewBlock(OffsetPort, MaskDstPort, ($4 << ShiftDstPort) & MaskDstPort, $3.comp, FUNC_NONE, NULL );
		} else if ( $$.direction == SOURCE_OR_DESTINATION ) {
			$$.self = Connect_OR(
				NewBlock(OffsetPort, MaskSrcPort, ($4 << ShiftSrcPort) & MaskSrcPort, $3.comp, FUNC_NONE, NULL ),
				NewBlock(OffsetPort, MaskDstPort, ($4 << ShiftDstPort) & MaskDstPort, $3.comp, FUNC_NONE, NULL )
			);
		} else if ( $$.direction == SOURCE_AND_DESTINATION ) {
			$$.self = Connect_AND(
				NewBlock(OffsetPort, MaskSrcPort, ($4 << ShiftSrcPort) & MaskSrcPort, $3.comp, FUNC_NONE, NULL ),
				NewBlock(OffsetPort, MaskDstPort, ($4 << ShiftDstPort) & MaskDstPort, $3.comp, FUNC_NONE, NULL )
			);
		} else {
			/* should never happen */
			yyerror("Internal parser error");
			YYABORT;
		}
	}

	| dqual PORT IN '[' ullist ']' { 	
		struct ULongListNode *node;

		$$.direction = $1.direction;
		if ( $$.direction == SOURCE ) {
			RB_FOREACH(node, ULongtree, (ULongtree_t *)$5) {
				node->value = (node->value << ShiftSrcPort) & MaskSrcPort;
			}
			$$.self = NewBlock(OffsetPort, MaskSrcPort, 0, CMP_ULLIST, FUNC_NONE, (void *)$5 );
		} else if ( $$.direction == DESTINATION) {
			RB_FOREACH(node, ULongtree, (ULongtree_t *)$5) {
				node->value = (node->value << ShiftDstPort) & MaskDstPort;
			}
			$$.self = NewBlock(OffsetPort, MaskDstPort, 0, CMP_ULLIST, FUNC_NONE, (void *)$5 );
		} else { // src and/or dst port
			// we need a second list due to different shifts for src and dst ports
			ULongtree_t *root = malloc(sizeof(ULongtree_t));

			struct ULongListNode *n;
			if ( root == NULL) {
				yyerror("malloc() error");
				YYABORT;
			}
			RB_INIT(root);

			RB_FOREACH(node, ULongtree, (ULongtree_t *)$5) {

				if ((n = malloc(sizeof(struct ULongListNode))) == NULL) {
					yyerror("malloc() error");
					YYABORT;
				}
				n->value 	= (node->value << ShiftDstPort) & MaskDstPort;
				node->value = (node->value << ShiftSrcPort) & MaskSrcPort;
				RB_INSERT(ULongtree, root, n);
			}

			if ( $$.direction == SOURCE_OR_DESTINATION ) {

				$$.self = Connect_OR(
					NewBlock(OffsetPort, MaskSrcPort, 0, CMP_ULLIST, FUNC_NONE, (void *)$5 ),
					NewBlock(OffsetPort, MaskDstPort, 0, CMP_ULLIST, FUNC_NONE, (void *)root )
				);
			} else if ( $$.direction == SOURCE_AND_DESTINATION ) {
				$$.self = Connect_AND(
					NewBlock(OffsetPort, MaskSrcPort, 0, CMP_ULLIST, FUNC_NONE, (void *)$5 ),
					NewBlock(OffsetPort, MaskDstPort, 0, CMP_ULLIST, FUNC_NONE, (void *)root )
				);
			} else {
				/* should never happen */
				yyerror("Internal parser error");
				YYABORT;
			}
		}
	}

	| dqual AS NUMBER {	
		$$.direction = $1.direction;
		if ( $3 > 65535 || $3 < 0 ) {
			yyerror("AS number outside of range 0..65535");
			YYABORT;
		}

		if ( $$.direction == SOURCE ) {
			$$.self = NewBlock(OffsetAS, MaskSrcAS, ($3 << ShiftSrcAS) & MaskSrcAS, CMP_EQ, FUNC_NONE, NULL );
		} else if ( $$.direction == DESTINATION) {
			$$.self = NewBlock(OffsetAS, MaskDstAS, ($3 << ShiftDstAS) & MaskDstAS, CMP_EQ, FUNC_NONE, NULL);
		} else if ( $$.direction == SOURCE_OR_DESTINATION ) {
			$$.self = Connect_OR(
				NewBlock(OffsetAS, MaskSrcAS, ($3 << ShiftSrcAS) & MaskSrcAS, CMP_EQ, FUNC_NONE, NULL ),
				NewBlock(OffsetAS, MaskDstAS, ($3 << ShiftDstAS) & MaskDstAS, CMP_EQ, FUNC_NONE, NULL)
			);
		} else if ( $$.direction == SOURCE_AND_DESTINATION ) {
			$$.self = Connect_AND(
				NewBlock(OffsetAS, MaskSrcAS, ($3 << ShiftSrcAS) & MaskSrcAS, CMP_EQ, FUNC_NONE, NULL ),
				NewBlock(OffsetAS, MaskDstAS, ($3 << ShiftDstAS) & MaskDstAS, CMP_EQ, FUNC_NONE, NULL)
			);
		} else {
			/* should never happen */
			yyerror("Internal parser error");
			YYABORT;
		}
	}

	| dqual AS IN '[' ullist ']' { 	
		struct ULongListNode *node;

		$$.direction = $1.direction;
		if ( $$.direction == SOURCE ) {
			RB_FOREACH(node, ULongtree, (ULongtree_t *)$5) {
				node->value = (node->value << ShiftSrcAS) & MaskSrcAS;
			}
			$$.self = NewBlock(OffsetAS, MaskSrcAS, 0, CMP_ULLIST, FUNC_NONE, (void *)$5 );
		} else if ( $$.direction == DESTINATION) {
			RB_FOREACH(node, ULongtree, (ULongtree_t *)$5) {
				node->value = (node->value << ShiftDstAS) & MaskDstAS;
			}
			$$.self = NewBlock(OffsetAS, MaskDstAS, 0, CMP_ULLIST, FUNC_NONE, (void *)$5 );
		} else {
			// src and/or dst AS
			// we need a second list due to different shifts for src and dst AS
			ULongtree_t *root = malloc(sizeof(ULongtree_t));

			struct ULongListNode *n;
			if ( root == NULL) {
				yyerror("malloc() error");
				YYABORT;
			}
			RB_INIT(root);

			RB_FOREACH(node, ULongtree, (ULongtree_t *)$5) {

				if ((n = malloc(sizeof(struct ULongListNode))) == NULL) {
					yyerror("malloc() error");
					YYABORT;
				}
				n->value 	= (node->value << ShiftDstAS) & MaskDstAS;
				node->value = (node->value << ShiftSrcAS) & MaskSrcAS;
				RB_INSERT(ULongtree, root, n);
			}

			if ( $$.direction == SOURCE_OR_DESTINATION ) {
				$$.self = Connect_OR(
					NewBlock(OffsetAS, MaskSrcAS, 0, CMP_ULLIST, FUNC_NONE, (void *)$5 ),
					NewBlock(OffsetAS, MaskDstAS, 0, CMP_ULLIST, FUNC_NONE, (void *)root )
				);
			} else if ( $$.direction == SOURCE_AND_DESTINATION ) {
				$$.self = Connect_AND(
					NewBlock(OffsetAS, MaskSrcAS, 0, CMP_ULLIST, FUNC_NONE, (void *)$5 ),
					NewBlock(OffsetAS, MaskDstAS, 0, CMP_ULLIST, FUNC_NONE, (void *)root )
				);
			} else {
				/* should never happen */
				yyerror("Internal parser error");
				YYABORT;
			}
		}
	}

	| dqual NET IPSTRING IPSTRING { 
		int af, bytes;
		uint64_t	mask[2];
		if ( parse_ip(&af, $3, $$.ip, &bytes) == 0 ) {
			yyerror("Invalid IP address");
			YYABORT;
		}
		if ( af != PF_INET ) {
			yyerror("IP netmask syntax valid only for IPv4");
			YYABORT;
		}
		if ( bytes != 4 ) {
			yyerror("Need complete IP address");
			YYABORT;
		}
		if ( parse_ip(&af, $4, mask, &bytes) == 0 ) {
			yyerror("Invalid IP address");
			YYABORT;
		}
		if ( af != PF_INET || bytes != 4 ) {
			yyerror("Invalid netmask for IPv4 address");
			YYABORT;
		}

		$$.ip[0] &= mask[0];
		$$.ip[1] &= mask[1];

		$$.direction = $1.direction;

		if ( $$.direction == SOURCE ) {
			$$.self = Connect_AND(
				NewBlock(OffsetSrcIPv6b, mask[1], $$.ip[1] , CMP_EQ, FUNC_NONE, NULL ),
				NewBlock(OffsetSrcIPv6a, mask[0], $$.ip[0] , CMP_EQ, FUNC_NONE, NULL )
			);
		} else if ( $$.direction == DESTINATION) {
			$$.self = Connect_AND(
				NewBlock(OffsetDstIPv6b, mask[1], $$.ip[1] , CMP_EQ, FUNC_NONE, NULL ),
				NewBlock(OffsetDstIPv6a, mask[0], $$.ip[0] , CMP_EQ, FUNC_NONE, NULL )
			);
		} else if ( $$.direction == SOURCE_OR_DESTINATION ) {
			$$.self = Connect_OR(
						Connect_AND(
							NewBlock(OffsetSrcIPv6b, mask[1], $$.ip[1] , CMP_EQ, FUNC_NONE, NULL ),
							NewBlock(OffsetSrcIPv6a, mask[0], $$.ip[0] , CMP_EQ, FUNC_NONE, NULL )
						),
						Connect_AND(
							NewBlock(OffsetDstIPv6b, mask[1], $$.ip[1] , CMP_EQ, FUNC_NONE, NULL ),
							NewBlock(OffsetDstIPv6a, mask[0], $$.ip[0] , CMP_EQ, FUNC_NONE, NULL )
						)
			);
		} else if ( $$.direction == SOURCE_AND_DESTINATION ) {
			$$.self = Connect_AND(
						Connect_AND(
							NewBlock(OffsetSrcIPv6b, mask[1], $$.ip[1] , CMP_EQ, FUNC_NONE, NULL ),
							NewBlock(OffsetSrcIPv6a, mask[0], $$.ip[0] , CMP_EQ, FUNC_NONE, NULL )
						),
						Connect_AND(
							NewBlock(OffsetDstIPv6b, mask[1], $$.ip[1] , CMP_EQ, FUNC_NONE, NULL ),
							NewBlock(OffsetDstIPv6a, mask[0], $$.ip[0] , CMP_EQ, FUNC_NONE, NULL )
						)
			);
		} else {
			/* should never happen */
			yyerror("Internal parser error");
			YYABORT;
		}
	}

	| dqual NET IPSTRING '/' NUMBER { 
		int af, bytes;
		uint64_t	mask[2];
		if ( parse_ip(&af, $3, $$.ip, &bytes) == 0 ) {
			yyerror("Invalid IP address");
			YYABORT;
		}

		if ( $5 > (bytes*8) ) {
			yyerror("Too many netbits for this IP addresss");
			YYABORT;
		}

		if ( af == PF_INET ) {
			mask[0] = 0xffffffffffffffffLL;
			mask[1] = 0xffffffffffffffffLL << ( 32 - $5 );
		} else {	// PF_INET6
			if ( $5 > 64 ) {
				mask[0] = 0xffffffffffffffffLL;
				mask[1] = 0xffffffffffffffffLL << ( 128 - $5 );
			} else {
				mask[0] = 0xffffffffffffffffLL << ( 64 - $5 );
				mask[1] = 0;
			}
		}
		// IP aadresses are stored in network representation 
		mask[0]	 = mask[0];
		mask[1]	 = mask[1];

		$$.ip[0] &= mask[0];
		$$.ip[1] &= mask[1];

		$$.direction = $1.direction;
		if ( $$.direction == SOURCE ) {
			$$.self = Connect_AND(
				NewBlock(OffsetSrcIPv6b, mask[1], $$.ip[1] , CMP_EQ, FUNC_NONE, NULL ),
				NewBlock(OffsetSrcIPv6a, mask[0], $$.ip[0] , CMP_EQ, FUNC_NONE, NULL )
			);
		} else if ( $$.direction == DESTINATION) {
			$$.self = Connect_AND(
				NewBlock(OffsetDstIPv6b, mask[1], $$.ip[1] , CMP_EQ, FUNC_NONE, NULL ),
				NewBlock(OffsetDstIPv6a, mask[0], $$.ip[0] , CMP_EQ, FUNC_NONE, NULL )
			);
		} else if ( $$.direction == SOURCE_OR_DESTINATION ) {
			$$.self = Connect_OR(
						Connect_AND(
							NewBlock(OffsetSrcIPv6b, mask[1], $$.ip[1] , CMP_EQ, FUNC_NONE, NULL ),
							NewBlock(OffsetSrcIPv6a, mask[0], $$.ip[0] , CMP_EQ, FUNC_NONE, NULL )
						),
						Connect_AND(
							NewBlock(OffsetDstIPv6b, mask[1], $$.ip[1] , CMP_EQ, FUNC_NONE, NULL ),
							NewBlock(OffsetDstIPv6a, mask[0], $$.ip[0] , CMP_EQ, FUNC_NONE, NULL )
						)
			);
		} else if ( $$.direction == SOURCE_AND_DESTINATION ) {
			$$.self = Connect_AND(
						Connect_AND(
							NewBlock(OffsetSrcIPv6b, mask[1], $$.ip[1] , CMP_EQ, FUNC_NONE, NULL ),
							NewBlock(OffsetSrcIPv6a, mask[0], $$.ip[0] , CMP_EQ, FUNC_NONE, NULL )
						),
						Connect_AND(
							NewBlock(OffsetDstIPv6b, mask[1], $$.ip[1] , CMP_EQ, FUNC_NONE, NULL ),
							NewBlock(OffsetDstIPv6a, mask[0], $$.ip[0] , CMP_EQ, FUNC_NONE, NULL )
						)
			);
		} else {
			/* should never happen */
			yyerror("Internal parser error");
			YYABORT;
		}
	}

	| inout IF NUMBER {
		if ( $3 > 65535 ) {
			yyerror("Input interface number must be 0..65535");
			YYABORT;
		}
		if ( $$.direction == SOURCE ) {
			$$.self = NewBlock(OffsetInOut, MaskInput, ($3 << ShiftInput) & MaskInput, CMP_EQ, FUNC_NONE, NULL); 
		} else if ( $$.direction == DESTINATION) {
			$$.self = NewBlock(OffsetInOut, MaskOutput, ($3 << ShiftOutput) & MaskOutput, CMP_EQ, FUNC_NONE, NULL); 
		} else if ( $$.direction == SOURCE_OR_DESTINATION ) {
			$$.self = Connect_OR(
				NewBlock(OffsetInOut, MaskInput, ($3 << ShiftInput) & MaskInput, CMP_EQ, FUNC_NONE, NULL),
				NewBlock(OffsetInOut, MaskOutput, ($3 << ShiftOutput) & MaskOutput, CMP_EQ, FUNC_NONE, NULL)
			);
		} else {
			/* should never happen */
			yyerror("Internal parser error");
			YYABORT;
		}
	}

	;

/* iplist definition */
iplist:	IPSTRING	{ 
		int af, bytes;
		uint64_t	ipaddr[2];
		struct IPListNode *node;

		IPlist_t *root = malloc(sizeof(IPlist_t));

		if ( root == NULL) {
			yyerror("malloc() error");
			YYABORT;
		}
		RB_INIT(root);

		if ( parse_ip(&af, $1, ipaddr, &bytes) == 0 ) {
			yyerror("Invalid IP address");
			YYABORT;
		}
		if ( ( af == PF_INET && bytes != 4 ) || ( af == PF_INET6 && bytes != 16 )) {
			yyerror("incomplete IP address");
			YYABORT;
		}
		if ((node = malloc(sizeof(struct IPListNode))) == NULL) {
			yyerror("malloc() error");
			YYABORT;
		}
		node->ip[0] = ipaddr[0];
		node->ip[1] = ipaddr[1];

		RB_INSERT(IPtree, root, node);
		$$ = (void *)root;
	}
	| iplist IPSTRING { 
		int af, bytes;
		uint64_t	ipaddr[2];
		struct IPListNode *node;

		if ( parse_ip(&af, $2, ipaddr, &bytes) == 0 ) {
			yyerror("Invalid IP address");
			YYABORT;
		}
		if ( ( af == PF_INET && bytes != 4 ) || ( af == PF_INET6 && bytes != 16 )) {
			yyerror("incomplete IP address");
			YYABORT;
		}
		if ((node = malloc(sizeof(struct IPListNode))) == NULL) {
			yyerror("malloc() error");
			YYABORT;
		}
		node->ip[0] = ipaddr[0];
		node->ip[1] = ipaddr[1];
		RB_INSERT(IPtree, (IPlist_t *)$$, node);
	}
	;

/* ULlist definition */
ullist:	NUMBER	{ 
		struct ULongListNode *node;

		if ( $1 > 65535 ) {
			yyerror("Value outside of range 0..65535");
			YYABORT;
		}
		ULongtree_t *root = malloc(sizeof(ULongtree_t));

		if ( root == NULL) {
			yyerror("malloc() error");
			YYABORT;
		}
		RB_INIT(root);

		if ((node = malloc(sizeof(struct ULongListNode))) == NULL) {
			yyerror("malloc() error");
			YYABORT;
		}
		node->value = $1;

		RB_INSERT(ULongtree, root, node);
		$$ = (void *)root;
	}
	| ullist NUMBER { 
		struct ULongListNode *node;

		if ( $2 > 65535 ) {
			yyerror("Value outside of range 0..65535");
			YYABORT;
		}
		if ((node = malloc(sizeof(struct ULongListNode))) == NULL) {
			yyerror("malloc() error");
			YYABORT;
		}
		node->value = $2;
		RB_INSERT(ULongtree, (ULongtree_t *)$$, node);
	}
	;

/* scaling  qualifiers */
scale:				{ $$.scale = 1; }
	| 'k'			{ $$.scale = 1024; }
	| 'm'			{ $$.scale = 1024*1024; }
	| 'g'			{ $$.scale = 1024*1024*1024; }
	;

/* comparator qualifiers */
comp:				{ $$.comp = CMP_EQ; }
	| EQ			{ $$.comp = CMP_EQ; }
	| LT			{ $$.comp = CMP_LT; }
	| GT			{ $$.comp = CMP_GT; }
	;

/* 'direction' qualifiers */
dqual:	  			{ $$.direction = SOURCE_OR_DESTINATION;  }
	| SRC			{ $$.direction = SOURCE;				 }
	| DST			{ $$.direction = DESTINATION;			 }
	| SRC OR DST 	{ $$.direction = SOURCE_OR_DESTINATION;  }
	| DST OR SRC	{ $$.direction = SOURCE_OR_DESTINATION;  }
	| SRC AND DST	{ $$.direction = SOURCE_AND_DESTINATION; }
	| DST AND SRC	{ $$.direction = SOURCE_AND_DESTINATION; }
	;

inout:	  			{ $$.direction = SOURCE_OR_DESTINATION;  }
	| IN			{ $$.direction = SOURCE;				 }
	| OUT			{ $$.direction = DESTINATION;			 }
	;

expr:	term		{ $$ = $1.self;        }
	| expr OR  expr	{ $$ = Connect_OR($1, $3);  }
	| expr AND expr	{ $$ = Connect_AND($1, $3); }
	| NOT expr	%prec NEGATE	{ $$ = Invert($2);			}
	| '(' expr ')'	{ $$ = $2; }
	;

%%

static void  yyerror(char *msg) {
	fprintf(stderr,"line %d: %s at '%s'\n", lineno, msg, yytext);
} /* End of yyerror */


