import core.runtime;
import std.string;
import std.stdio;
import std.conv;

import cod4x.plugin_declarations;
import cod4x.functions;
import cod4x.callback_declarations;
import cod4x.server;

extern(C) int Scr_GetFunctionHandle( const char* scriptName, const char* labelName );
extern(C) int Scr_GetFunc( int i );
extern(C) int Scr_AddString( const char* str );
extern(C) short Scr_ExecThread( int callbackHook, uint numArgs);
extern(C) void Scr_FreeThread( short threadId);
extern(C) ftRequest_t* Plugin_HTTP_Request(const char* url, const char* method, byte* requestpayload, int payloadlen, const char* additionalheaderlines);
extern(C) int Plugin_HTTP_SendReceiveData(ftRequest_t* request);
extern(C) int Plugin_HTTP_FreeObj(ftRequest_t* request);


// plugin meta info
extern (C) void OnInfoRequest(pluginInfo_t *info)
{
	info.handlerVersion = version_t(3, 100);
	info.pluginVersion = version_t(0, 1);
}

extern (C) int OnInit()
{
	writeln("init ", Runtime.initialize());
	Plugin_ScrAddFunction("httpGet", &httpget);
	return 0;
}

extern (C) void OnSpawnServer()
{
	AsyncHttp.openRequests = [];
}

import std.algorithm;
import std.array;

class AsyncHttp
{
	static AsyncHttp[] openRequests;
	static void updateRequests()
	{
		foreach(idx, req; openRequests)
		{
			if(!req.done)
				req.run();
		}

		openRequests = openRequests.filter!(x => !x.done).array();
	}

	private bool done = false;
	private void delegate(ubyte*, int) callback;
	private ftRequest_t* req;

	this(string url, string method, void delegate(ubyte*, int) callback )
	{
		this.callback = callback;

		req = Plugin_HTTP_Request(
			url.toStringz,
			method.toStringz,
			null,
			0,
			null);

		openRequests ~= this;
	}

	~this() 
	{
		Plugin_HTTP_FreeObj(req);
	}

	private void run() 
	{	
		while(!done)
		{			
			int errCode = Plugin_HTTP_SendReceiveData(req);

			if(errCode == 1 || errCode == -1) // complete or failed
				done = true;

			if(errCode == 1) // complete
			{
				ubyte* data = req.recvmsg.data + req.headerLength;
				int buflen = req.contentLength;
				callback(data, buflen);
			}
		}
	}	
}

extern (C) void OnFrame()
{
	AsyncHttp.updateRequests(); // update all requests
}

extern(C) void httpget() 
{
	string host = Plugin_Scr_GetString( 0 ).fromStringz;
	int cbhandle = Scr_GetFunc( 1 );

	auto f = new AsyncHttp(host, "GET", (ubyte* content, int len)
	{
		if(cbhandle != 0)
		{
			string s = (cast(immutable(char)*)content)[0..len];
			Scr_AddString(s.toStringz);
			short result = Scr_ExecThread(cbhandle, 1);
			Scr_FreeThread(result);	
		}
	});	
}
