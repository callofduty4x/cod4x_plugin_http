import core.runtime;
import std.string;
import std.stdio;
import std.conv;
import std.json;

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
	Plugin_ScrAddFunction("httpGetJson", &httpGetJson);
	Plugin_ScrAddFunction("jsonGetInt", &jsonGetInt);
	Plugin_ScrAddFunction("jsonSetInt", &jsonSetInt);
	Plugin_ScrAddFunction("jsonGetString", &jsonGetString);
	Plugin_ScrAddFunction("jsonSetString", &jsonSetString);
	Plugin_ScrAddFunction("jsonReleaseObject", &releaseJsonObject);

	
	return 0;
}

extern(C) void conprint()
{
	Plugin_Printf("%s\n", Plugin_Scr_GetString(0));
}

extern (C) void OnExitLevel()
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


/// JSON
JSONValue[int] jsonStore; // global json variable store

int newJsonId()
{
	for(int i = 0; i < int.max; ++i)
	{
		if(i !in jsonStore)
		{
			return i; 
		}
	}

	assert(0);
}

int parseJsonString(string str)
{
	int obj = newJsonId();
	jsonStore[obj] = parseJSON(str);
	return obj;
}

JSONValue* jsonGet(bool createIfNotExists = false)
{
	int handle = Plugin_Scr_GetInt(0);
	string path = Plugin_Scr_GetString(1).fromStringz;

	writeln(handle, " ", path);

	if(handle !in jsonStore) // does handle exist ?
		return null;

	writeln("found handle");

	JSONValue* val = &jsonStore[handle];

	string[] pathparts = path.split(".");

	foreach(string p; pathparts) // follow the path
	{
		writeln("check ", p);

		if(val.type == JSON_TYPE.ARRAY)
		{
			val = &val.array[p.to!int];
		}
		else if(val.type == JSON_TYPE.OBJECT && p in val.object) // does handle exist ?
		{
			val = &val.object[p];			
		}
		else
		{
			if(createIfNotExists)
			{
				writeln("create ", p);
				val.object[p] = JSONValue();
			}
			else
			{
				writeln("not found ", p);
				return null;
			}
		}
	}

	return val;
}

extern(C) void jsonGetInt()
{
	writeln(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> jsongetit");

	JSONValue* val = jsonGet();
	
	writeln("got value");

	if(val is null)
	{
		Plugin_Scr_AddUndefined();
		return;
	}

	writeln("blablub");

	int x;
	if (val.type() == JSON_TYPE.INTEGER)
	{
		x = cast(int)val.integer;
	}
	else
	{
		try {
			x = to!int(val.str);
		} catch(Exception e) {
			Plugin_Scr_AddUndefined(); return;
		}
	}

	writeln("value: ", x);
	
	Plugin_Scr_AddInt(x);
}

extern(C) void jsonGetString()
{
	JSONValue* val = jsonGet();
	
	if(val is null)
	{
		Plugin_Scr_AddUndefined();
		return;
	}
	
	writeln(val.str);
	Plugin_Scr_AddString(val.str.toStringz);
}

extern(C) void jsonSetString()
{
	JSONValue* val = jsonGet(true);
	string value = Plugin_Scr_GetString(2).fromStringz;
	
	if(val is null)
	{
		Plugin_Scr_AddUndefined();
		return;
	}

	val.str = value;
}

extern(C) void jsonSetInt()
{
	JSONValue* val = jsonGet(true);
	int value = Plugin_Scr_GetInt(2);
	
	if(val is null)
	{
		Plugin_Scr_AddUndefined();
		return;
	}

	val.integer = value;
}

/*extern(C) jsonGetInt(int handle, string path)
{
	string[] pathparts = path.split(".");

	if(handle !in jsonStore || key !in jsonStore[handle] || jsonStore[handle][key].type() == JSON_TYPE.INTEGER) 
		Plugin_Scr_AddUndefined();
	else
}*/

extern(C) void releaseJsonObject()
{
	int handle = Plugin_Scr_GetInt(0);
	if(handle in jsonStore) 
		jsonStore.remove(handle);
}

extern(C) void httpGetJson()
{
	string host = Plugin_Scr_GetString( 0 ).fromStringz;
	int cbhandle = Scr_GetFunc( 1 );

	auto f = new AsyncHttp(host, "GET", (ubyte* content, int len)
	{
		if(cbhandle != 0)
		{
			string s = (cast(immutable(char)*)content)[0..len];
			//JSONValue j = parseJSON(s);
			int handle = parseJsonString(s);

			//Scr_AddString(s.toStringz);
			Plugin_Scr_AddInt(handle);
			short result = Scr_ExecThread(cbhandle, 1);
			Scr_FreeThread(result);	
		}
	});	
}