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
 *  $Id: expire.h 83 2006-10-30 07:25:33Z peter $
 *
 *  $LastChangedRevision: 83 $
 *  
 */

typedef struct channel_s {
	struct channel_s	*next;
	char				*datadir;
	dirstat_t 			*dirstat;
	bookkeeper_t		*books;
	int					books_stat;
	int					do_rescan;
	int					status;
	FTS 				*fts;
	FTSENT 				*ftsent;
} channel_t;

enum { OK = 0, NOFILES };

uint64_t ParseSizeDef(char *s, uint64_t *value);

uint64_t ParseTimeDef(char *s, uint64_t *value);

void RescanDir(char *dir, dirstat_t *dirstat);

void ExpireDir(char *dir, dirstat_t *dirstat, uint64_t maxsize, uint64_t maxlife );

void ExpireProfile(channel_t *channel, dirstat_t *current_stat, uint64_t maxsize, uint64_t maxlife );

void UpdateStat(dirstat_t *dirstat, bookkeeper_t *books);
