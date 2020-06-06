import core.runtime;
import std.string;
import std.stdio;
import std.conv;
import std.json;

import cod4x.plugin_declarations;
import cod4x.functions;
import cod4x.callback_declarations;
import cod4x.structs;

extern(C) int Scr_GetFunctionHandle( const char* scriptName, const char* labelName );
extern(C) int Scr_GetFunc( int i );
extern(C) short Scr_ExecThread( int callbackHook, uint numArgs);
extern(C) short Scr_ExecEntThread( gentity_t* ent, int callbackHook, uint numArgs);
extern(C) void Scr_FreeThread( short threadId);
extern(C) ftRequest_t* Plugin_HTTP_Request(const char* url, const char* method, byte* requestpayload, int payloadlen, const char* additionalheaderlines);
extern(C) int Plugin_HTTP_SendReceiveData(ftRequest_t* request);
extern(C) int Plugin_HTTP_FreeObj(ftRequest_t* request);
extern(C) ftRequest_t* Plugin_HTTP_MakeHttpRequest(const char* url, const char* method, char* requestpayload, int payloadlen, const char* additionalheaderlines);
extern(C) void Plugin_HTTP_CreateString_x_www_form_urlencoded(const char* outencodedstring, int len, const char* key, const char* value);

extern(C) int  Scr_AllocString(const char* string);
extern(C) void Scr_MakeArray();
extern(C) void Scr_AddArray();
extern(C) void Scr_AddArrayKey(int key);
extern(C) void Scr_AddBool(int boolean);
extern(C) void Scr_AddInt(int val);
extern(C) void Scr_AddFloat(float val);
extern(C) void Scr_AddString(const char *string);
extern(C) void Scr_AddConstString(int strindex);
extern(C) void Scr_AddUndefined();
extern (C) int Plugin_Scr_GetNumParam();


// plugin meta info
extern (C) void OnInfoRequest(pluginInfo_t *info)
{
	info.handlerVersion = version_t(PLUGIN_HANDLER_VERSION_MAJOR, PLUGIN_HANDLER_VERSION_MINOR);
	info.pluginVersion = version_t(1, 1);
}

void dbgwriteln(T...)(T args)
{
    debug
    {

        static if (T.length == 0)
        {
		return;
        }
        string s;
        foreach(arg; args)
        {
            s = s ~ to!string(arg);
        }

        Plugin_Printf("Http-Plugin: %s\n", s.toStringz);

    }
}




extern (C) int OnInit()
{
	Plugin_Printf("HTTP plugin init %d\n", Runtime.initialize());
	Plugin_ScrAddFunction("httpGet", &httpget);
	Plugin_ScrAddFunction("httpGetJson", &httpGetJson);
	Plugin_ScrAddFunction("httpPostJson", &httpPostJson);
	Plugin_ScrAddFunction("jsonGetInt", &jsonGetInt);
	Plugin_ScrAddFunction("jsonGetFloat", &jsonGetFloat);
	Plugin_ScrAddFunction("jsonSetInt", &jsonSetInt);
	Plugin_ScrAddFunction("jsonGetString", &jsonGetString);
	Plugin_ScrAddFunction("jsonSetString", &jsonSetString);
	Plugin_ScrAddFunction("jsonReleaseObject", &releaseJsonObject);

	return 0;
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

	this(string url, string method, void delegate(ubyte*, int) callback, string postdata = "")
	{
		this.callback = callback;

		if(method == "GET")
		{
			req = Plugin_HTTP_MakeHttpRequest(
				url.toStringz,
				method.toStringz,
				null,
				0,
				null);
		}
		else if(method == "POST")
		{

			char[8192] buf;
			buf[0] = 0;

			//Plugin_HTTP_CreateString_x_www_form_urlencoded(buf.ptr, 8192, "testkey", "testvalue");
			//Plugin_HTTP_CreateString_x_www_form_urlencoded(buf.ptr, 8192, "testkey2", "testvalue2");

			immutable(char*) data = postdata.toStringz; //"{\"name\":   \"Bender\", \"hind\":   \"Bitable\", \"shiny\":  true}".toStringz;
			char* p = cast(char*)data; // hackme

			dbgwriteln("ENCODED: ", buf.ptr);

			import core.stdc.string;
			req = Plugin_HTTP_MakeHttpRequest(
				url.toStringz,
				method.toStringz,
				p,
				strlen(p),
				//"ContentType: application/x-www-form-urlencoded; charset=utf-8\r\n");
				"ContentType: application/json\r\n");
		}

		openRequests ~= this;
	}

	~this() 
	{
		Plugin_HTTP_FreeObj(req);
	}

	private void run() 
	{	
		//if(!done)
		{			
			if(req == null)
			{
				Plugin_Printf("[ERROR] couldnt create request\n");
				done = true;
				return;
			}

			int errCode = Plugin_HTTP_SendReceiveData(req);

			if(errCode == 1 || errCode == -1) // complete or failed
				done = true;

			if(done && req.contentLength > 0) // complete
			{
				ubyte* data = req.recvmsg.data + req.headerLength;
				dbgwriteln("plugin DATA2: ", data);

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
	for(int i = 1; i < int.max; ++i)
	{
		if(i !in jsonStore)
		{
			return i; 
		}
	}

	assert(0);
}

int parseJsonString(string str) //Returns 0 in error case
{
	int obj = newJsonId();
	try
	{
		jsonStore[obj] = parseJSON(str);
	}
	catch(JSONException e)
	{
		Plugin_Printf("Error parsing Json: %s\n", e.msg.toStringz);
		return 0;
	}
	return obj;
}

JSONValue* jsonGet(bool createIfNotExists, JSONValue* val, int* size)
{
	string path = Plugin_Scr_GetString(1).fromStringz;

	string[] pathparts = path.split(".");

	*size = -1;

	foreach(string p; pathparts) // follow the path
	{
		dbgwriteln("check ", p);

		if(val.type == JSON_TYPE.ARRAY)
		{
			dbgwriteln("Is array at ", p);
			if(p == "size")
			{
				
				*size = val.array.length;
				return null;
			}else{
				int index;
				try
				{
					index = p.to!int;
				}
				catch(std.conv.ConvException e)
				{
					Plugin_Printf("Error getting json for path=%s, position=%s exception=%s (I think I need an array index here for position)\n", path.toStringz, p.toStringz, e.msg.toStringz);
					return null;
				}
				if(index < 0 || index >= val.array.length)
				{
					Plugin_Printf("Error getting json for path=%s, position=%s exception=Array index out of range. Allowed range: 0 to %d\n", path.toStringz, p.toStringz, val.array.length);
					return null;
				}
				dbgwriteln(" Get Array ", index);

				val = &val.array[index];
			}
		}
		else if(val.type == JSON_TYPE.OBJECT && p in val.object) // does handle exist ?
		{
			dbgwriteln("Is object at ", p);
			val = &val.object[p];
		}
		else
		{
			dbgwriteln("createIfNotExists ", createIfNotExists);
			if(createIfNotExists)
			{
				dbgwriteln("create ", p);
				val.object[p] = JSONValue();
				val = &val.object[p];	
			}
			else
			{
				dbgwriteln("not found ", p);
				return null;
			}
		}
	}
	return val;
}

extern(C) void jsonGetInt()
{
//	dbgwriteln("jsonGetInt()...");

	int handle = Plugin_Scr_GetInt(0);
	int size;

	if(handle !in jsonStore){ // does handle exist ?
		dbgwriteln("handle ", handle, " not found");
		Plugin_Scr_AddUndefined();
		return;
	}
	JSONValue* val = jsonGet(false, &jsonStore[handle], &size);

	if(val is null && size > -1)
	{
		Plugin_Scr_AddInt(size);
		return;
	}
	if(val is null)
	{
		dbgwriteln("Value not found");
		Plugin_Scr_AddUndefined();
		return;
	}

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

//	dbgwriteln("value: ", x);
	
	Plugin_Scr_AddInt(x);
}

extern(C) void jsonGetFloat() //For CrazY
{
//	dbgwriteln("jsonGetFloat()...");

	int handle = Plugin_Scr_GetInt(0);
	int size;

	if(handle !in jsonStore){ // does handle exist ?
		dbgwriteln("handle ", handle, " not found");
		Plugin_Scr_AddUndefined();
		return;
	}
	JSONValue* val = jsonGet(false, &jsonStore[handle], &size);

	if(val is null && size > -1)
	{
		Plugin_Scr_AddInt(size);
		return;
	}
	if(val is null)
	{
		dbgwriteln("Value not found");
		Plugin_Scr_AddUndefined();
		return;
	}

	float x;
	if (val.type() == JSON_TYPE.FLOAT)
	{
		x = cast(float)val.floating;
	}
	else
	{
		try {
			x = to!float(val.str);
		} catch(Exception e) {
			Plugin_Scr_AddUndefined(); return;
		}
	}

//	dbgwriteln("value: ", x);
	
	Plugin_Scr_AddFloat(x);
}


extern(C) void jsonGetString()
{
	int handle = Plugin_Scr_GetInt(0);

	if(handle !in jsonStore){ // does handle exist ?
		dbgwriteln("handle ", handle, " not found");
		Plugin_Scr_AddUndefined();
		return;
	}

	int size;

	JSONValue* val = jsonGet(false, &jsonStore[handle], &size);

	if(val is null)
	{
		dbgwriteln("String not found");
		Plugin_Scr_AddUndefined();
		return;
	}
	
	string s;
	try {
		s = to!string(val.str);
	} catch(Exception e) {
		Plugin_Scr_AddUndefined(); return;
	}

	dbgwriteln(s);

	Plugin_Scr_AddString(s.toStringz);
}

extern(C) void jsonSetString()
{

	int handle = Plugin_Scr_GetInt(0);

	if(handle !in jsonStore){ // does handle exist ?
		dbgwriteln("handle ", handle, " not found");
		Plugin_Scr_AddUndefined();
		return;
	}
	
	int size;

	JSONValue* val = jsonGet(true, &jsonStore[handle], &size);
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

	int handle = Plugin_Scr_GetInt(0);

	if(handle !in jsonStore){ // does handle exist ?
		dbgwriteln("handle ", handle, " not found");
		Plugin_Scr_AddUndefined();
		return;
	}
	
	int size;
	
	JSONValue* val = jsonGet(true, &jsonStore[handle], &size);
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

// depth first search a json object
void jsonDFS(string key, JSONValue val, int depth)
{
/*	for(int i=0;i<depth;++i)
		Plugin_Printf(" ");
*/
	if(val.type == JSON_TYPE.ARRAY)
	{
		Scr_MakeArray(); dbgwriteln("Scr_MakeArray");

		foreach(i, v; val.array)
		{
			jsonDFS("", v, depth+1);
		}
	}
	else if(val.type == JSON_TYPE.OBJECT) 
	{
		Scr_MakeArray(); dbgwriteln("Scr_MakeArray");

		foreach(k, v; val.object)
		{
			jsonDFS(k, v, depth+1);
		}		
	}
	else if(val.type == JSON_TYPE.NULL)
	{
		Scr_AddUndefined(); dbgwriteln("Scr_AddUndefined");
	}
	else if(val.type == JSON_TYPE.STRING)
	{
		Scr_AddString(val.str.toStringz()); dbgwriteln("Scr_AddString");
	}
	else if(val.type == JSON_TYPE.INTEGER)
	{
		Scr_AddInt(val.integer().to!int); dbgwriteln("Scr_AddInt");
	}
	else if(val.type == JSON_TYPE.UINTEGER)
	{
		Scr_AddInt(val.integer().to!int); dbgwriteln("Scr_AddInt");
	}
	else if(val.type == JSON_TYPE.FLOAT)
	{
		Scr_AddFloat(val.floating()); dbgwriteln("Scr_AddFloat");
	}
	else if(val.type == JSON_TYPE.TRUE)
	{
		Scr_AddBool(1); dbgwriteln("Scr_AddBool");
	}
	else if(val.type == JSON_TYPE.FALSE)
	{
		Scr_AddBool(0); dbgwriteln("Scr_AddBool");
	}

	if(depth != 0)
	{
		if(key == "") 
		{
			Scr_AddArray(); dbgwriteln("Scr_AddArray");
		}
		else
		{
			Scr_AddArrayKey(Scr_AllocString(key.toStringz)); dbgwriteln("Scr_AddArrayKey ", key);
		}
	}
}

extern(C) void httpGetJson()
{
	string host = Plugin_Scr_GetString( 0 ).fromStringz;
	int cbhandle = Scr_GetFunc( 1 );

	gentity_t* ent = null;
	if(Plugin_Scr_GetNumParam() > 2)
		ent = Plugin_Scr_GetEntity( 2 );

	/*auto f = new AsyncHttp(host, "GET", (ubyte* content, int len)
	{
		string s = (cast(immutable(char)*)content)[0..len];

		try
		{
			JSONValue j = parseJSON(s);
			jsonDFS("", j, 0);
			short result = Scr_ExecThread(cbhandle, 1);
			Scr_FreeThread(result);	
		}
		catch(Exception e)
		{
			dbgwriteln("json parsing failed: ", e.msg);
		}
	});*/

	auto f = new AsyncHttp(host, "GET", (ubyte* content, int len)
	{
		if(cbhandle != 0)
		{
			string s = (cast(immutable(char)*)content)[0..len];
			//JSONValue j = parseJSON(s);
			int handle = parseJsonString(s);

			//Scr_AddString(s.toStringz);
			//Plugin_Scr_AddEntity(ent);
			Plugin_Scr_AddInt(handle);

			short result;
			if(!ent)
				result = Scr_ExecThread(cbhandle, 1);
			else
				result = Scr_ExecEntThread(ent, cbhandle, 1);
			Scr_FreeThread(result);	
		}
	});	
}

extern(C) void httpPostJson()
{
	string host = Plugin_Scr_GetString( 0 ).fromStringz;
	string jsonParams = Plugin_Scr_GetString( 1 ).fromStringz;
	int cbhandle = Scr_GetFunc( 2 );

	gentity_t* ent = null;
	if(Plugin_Scr_GetNumParam() > 3)
		ent = Plugin_Scr_GetEntity( 3 );
	
	//import std.c.stdlib;
	//exit(-1);

	auto f = new AsyncHttp(host, "POST", (ubyte* content, int len)
	{
		if(cbhandle != 0)
		{
			string s = (cast(immutable(char)*)content)[0..len];
			//JSONValue j = parseJSON(s);
			int handle = parseJsonString(s);

			//Scr_AddString(s.toStringz);
			Plugin_Scr_AddInt(handle);

			short result;
			if(!ent)
				result = Scr_ExecThread(cbhandle, 1);
			else
				result = Scr_ExecEntThread(ent, cbhandle, 1);
			Scr_FreeThread(result);	
		}
	}, jsonParams);	
}