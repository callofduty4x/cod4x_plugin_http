module cod4x.structs;

import std.conv;
import cod4x.plugin_declarations;

const MAX_STRING_CHARS = 1024;

alias qboolean = int;

alias gentity_t = void;

//C     typedef float vec_t;
alias float vec_t;
//C     typedef vec_t vec2_t[2];
alias vec_t [2]vec2_t;
//C     typedef vec_t vec3_t[3];
alias vec_t [3]vec3_t;
//C     typedef vec_t vec4_t[4];
alias vec_t [4]vec4_t;
//C     typedef vec_t vec5_t[5];
alias vec_t [5]vec5_t;


enum netadrtype_t {
	NA_BAD = 0,					// an address lookup failed
	NA_BOT = 0,
	NA_LOOPBACK = 2,
	NA_BROADCAST = 3,
	NA_IP = 4,
	NA_IP6 = 5,
	NA_TCP = 6,
	NA_TCP6 = 7,
	NA_MULTICAST6 = 8,
	NA_UNSPEC = 9,
	NA_DOWN = 10,
} ;

enum netsrc_t {
	NS_CLIENT,
	NS_SERVER
} ;

const NET_ADDRSTRMAXLEN = 48;	// maximum length of an IPv6 address string including trailing '\0'

align(1) struct netadr_t
{align(1):
    netadrtype_t type;
    int scope_id;
    ushort port;
    ushort pad;
    int sock;
    union
	{
		byte [4]ip;
		byte [10]ipx;
		byte [16]ip6;
	}
}


// msg.c
//

align(1) struct msg_t {
	qboolean	overflowed;		//0x00
	qboolean	readonly;		//0x04
	ubyte		*data;			//0x08
	ubyte		*splitdata;		//0x0c
	int		maxsize;		//0x10
	int		cursize;		//0x14
	int		splitcursize;		//0x18
	int		readcount;		//0x1c
	int		bit;			//0x20	// for bitwise reads and writes
	int		lastRefEntity;		//0x24
}



/* For HTTP API */
//



enum ftprotocols_t
{
	FT_PROTO_HTTP,
	FT_PROTO_FTP
}

align(1) struct ftRequest_t
{
	qboolean lock;
	qboolean active;
	qboolean transferactive;
	int transferStartTime;
	int socket;
	int transfersocket;
	int sentBytes;
	int finallen;
	int totalreceivedbytes;
	int transfertotalreceivedbytes;
	msg_t *extrecvmsg;
	msg_t *extsendmsg;
	msg_t sendmsg;
	msg_t recvmsg;
	msg_t transfermsg;
	qboolean complete;
	int code;
	int version_;
	char[32] status;
	char[MAX_STRING_CHARS] url;
	char[MAX_STRING_CHARS] address;
	char[256] username;
	char[256] password;
	char[64] contentType;
	char[MAX_STRING_CHARS] cookie;
	int mode;
	int headerLength;
	int contentLength;
	int contentLengthArrived;
	int currentChunkLength;
	int currentChunkReadOffset;
	int chunkedEncoding;
	int startTime;
	int stage;
	ftprotocols_t protocol;
	netadr_t remote;
};


