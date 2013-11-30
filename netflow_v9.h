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
 *  $Id: netflow_v9.h 70 2006-05-17 08:38:01Z peter $
 *
 *  $LastChangedRevision: 70 $
 *	
 */

/* v9 structures */

/*   Packet Header Field Descriptions
 *
 *   Version
 *         Version of Flow Record format exported in this packet.  The
 *         value of this field is 9 for the current version.
 *
 *   Count
 *         The total number of records in the Export Packet, which is the
 *         sum of Options FlowSet records, Template FlowSet records, and
 *         Data FlowSet records.
 *
 *   sysUpTime
 *         Time in milliseconds since this device was first booted.
 *
 *   UNIX Secs
 *         Time in seconds since 0000 UTC 1970, at which the Export Packet
 *         leaves the Exporter.
 *
 *   Sequence Number
 *         Incremental sequence counter of all Export Packets sent from
 *         the current Observation Domain by the Exporter.  This value
 *         MUST be cumulative, and SHOULD be used by the Collector to
 *         identify whether any Export Packets have been missed.
 *
 *   Source ID
 *         A 32-bit value that identifies the Exporter Observation Domain.
 *         NetFlow Collectors SHOULD use the combination of the source IP
 *         address and the Source ID field to separate different export
 *         streams originating from the same Exporter.
 */

typedef struct netflow_v9_header {
	uint16_t  version;
	uint16_t  count;
	uint32_t  SysUptime;
	uint32_t  unix_secs;
	uint32_t  sequence;
	uint32_t  source_id;
} netflow_v9_header_t;

#define NETFLOW_V9_HEADER_LENGTH sizeof(netflow_v9_header_t)

/* FlowSet ID
 *         FlowSet ID value of 0 is reserved for the Template FlowSet.
 *   Length
 *         Total length of this FlowSet.  Because an individual Template
 *         FlowSet MAY contain multiple Template Records, the Length value
 *         MUST be used to determine the position of the next FlowSet
 *         record, which could be any type of FlowSet.  Length is the sum
 *         of the lengths of the FlowSet ID, the Length itself, and all
 *         Template Records within this FlowSet.
 *
 *   Template ID
 *         Each of the newly generated Template Records is given a unique
 *         Template ID.  This uniqueness is local to the Observation
 *         Domain that generated the Template ID.  Template IDs 0-255 are
 *         reserved for Template FlowSets, Options FlowSets, and other
 *         reserved FlowSets yet to be created.  Template IDs of Data
 *         FlowSets are numbered from 256 to 65535.
 *
 *   Field Count
 *         Number of fields in this Template Record.   Because a Template
 *         FlowSet usually contains multiple Template Records, this field
 *         allows the Collector to determine the end of the current
 *         Template Record and the start of the next.
 *
 *   Field Type
 *         A numeric value that represents the type of the field.  Refer
 *         to the "Field Type Definitions" section.
 *
 *   Field Length
 *         The length of the corresponding Field Type, in bytes.  Refer to
 *         the "Field Type Definitions" section.
 */

typedef struct template_record_s {
	uint16_t  	template_id;
	uint16_t  	count;
	struct {
		uint16_t  type;
		uint16_t  length;
	} record[1];
} template_record_t;

typedef struct template_flowset_s {
	uint16_t  	flowset_id;
	uint16_t  	length;
	template_record_t	fields[1];
} template_flowset_t;

typedef struct data_flowset_s {
	uint16_t  	flowset_id;
	uint16_t  	length;
	uint8_t		data[4];
} data_flowset_t;

typedef struct option_template_flowset_s {
	uint16_t  	flowset_id;
	uint16_t  	length;
	uint16_t	template_id;
	uint16_t	count;
} option_template_flowset_t;

typedef struct common_header_s {
	uint16_t  	flowset_id;
	uint16_t  	length;
} common_header_t;

#define NF9_TEMPLATE_FLOWSET_ID     0
#define NF9_OPTIONS_FLOWSET_ID      1
#define NF9_MIN_RECORD_FLOWSET_ID   256

/* Flowset record types implemented */
#define NF9_FIRST_SWITCHED      22
#define NF9_LAST_SWITCHED       21
#define NF9_DIRECTION	        61
#define NF9_TCP_FLAGS           6
#define NF9_SRC_TOS         	5
#define NF9_IN_PROTOCOL         4
#define NF9_INPUT_SNMP          10
#define NF9_OUTPUT_SNMP         14
#define NF9_L4_SRC_PORT         7
#define NF9_L4_DST_PORT         11
#define NF9_SRC_AS          	16
#define NF9_DST_AS          	17
#define NF9_OUT_BYTES       	23
#define NF9_OUT_PKTS       		24

// count as two elements only
#define NF9_IPV4_SRC_ADDR       8
#define NF9_IPV4_DST_ADDR       12
#define NF9_IPV6_SRC_ADDR       27
#define NF9_IPV6_DST_ADDR       28

#define NF9_IN_BYTES            1
#define NF9_IN_PACKETS          2

#define MAX_TEMPLATE_ELEMENTS	18

/* Flowset record types not implemented */
#define NF9_FLOWS		        3
#define NF9_SRC_MASK            9
#define NF9_DST_MASK            13
#define NF9_IPV4_NEXT_HOP       15
#define NF9_IPV6_SRC_MASK       29
#define NF9_IPV6_DST_MASK       30
#define NF9_IPV6_FLOW_LABEL		31
#define NF9_ICMP_TYPE			32
#define NF9_ENGINE_TYPE         38
#define NF9_ENGINE_ID           39
#define NF9_DST_TOS				55
#define NF9_IPV6_NEXT_HOP       62


/* prototypes */
void Init_v9(void);

void *Process_v9(void *in_buff, ssize_t in_buff_cnt, data_block_header_t *data_header, void *writeto, 
	stat_record_t *stat_record, uint64_t *first_seen, uint64_t *last_seen);

void Init_v9_output(send_peer_t *peer);

int Add_v9_output_record(master_record_t *master_record, send_peer_t *peer);
