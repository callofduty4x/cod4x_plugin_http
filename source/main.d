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
extern(C) void Plugin_Scr_AddEntity(gentity_t* ent);
extern (C) int Plugin_Scr_GetNumParam();


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
	Plugin_ScrAddFunction("httpPostJson", &httpPostJson);
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

			printf("ENCODED: %s\n", buf.ptr);

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
				printf("[ERROR] couldnt create request\n");
				done = true;
				return;
			}

			int errCode = Plugin_HTTP_SendReceiveData(req);

			//printf("plugin DATA: %s\n", req.recvmsg.data);

			if(errCode == 1 || errCode == -1) // complete or failed
				done = true;

			//printf("returncode: %d\n", errCode);

			if(done && req.contentLength > 0) // complete
			{
				ubyte* data = req.recvmsg.data + req.headerLength;
				printf("plugin DATA2: %s\n", data);

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

JSONValue* jsonGet(bool createIfNotExists)
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
			writeln("createIfNotExists ", createIfNotExists);
			if(createIfNotExists)
			{
				writeln("create ", p);
				val.object[p] = JSONValue();
				val = &val.object[p];	
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

	JSONValue* val = jsonGet(false);
	
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
	JSONValue* val = jsonGet(false);
	
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

// depth first search a json object
void jsonDFS(string key, JSONValue val, int depth)
{
	for(int i=0;i<depth;++i)
		printf(" ");

	if(val.type == JSON_TYPE.ARRAY)
	{
		Scr_MakeArray(); writeln("Scr_MakeArray");

		foreach(i, v; val.array)
		{
			jsonDFS("", v, depth+1);
		}
	}
	else if(val.type == JSON_TYPE.OBJECT) 
	{
		Scr_MakeArray(); writeln("Scr_MakeArray");

		foreach(k, v; val.object)
		{
			jsonDFS(k, v, depth+1);
		}		
	}
	else if(val.type == JSON_TYPE.NULL)
	{
		Scr_AddUndefined(); writeln("Scr_AddUndefined");
	}
	else if(val.type == JSON_TYPE.STRING)
	{
		Scr_AddString(val.str.toStringz()); writeln("Scr_AddString");
	}
	else if(val.type == JSON_TYPE.INTEGER)
	{
		Scr_AddInt(val.integer().to!int); writeln("Scr_AddInt");
	}
	else if(val.type == JSON_TYPE.UINTEGER)
	{
		Scr_AddInt(val.integer().to!int); writeln("Scr_AddInt");
	}
	else if(val.type == JSON_TYPE.FLOAT)
	{
		Scr_AddFloat(val.floating()); writeln("Scr_AddFloat");
	}
	else if(val.type == JSON_TYPE.TRUE)
	{
		Scr_AddBool(1); writeln("Scr_AddBool");
	}
	else if(val.type == JSON_TYPE.FALSE)
	{
		Scr_AddBool(0); writeln("Scr_AddBool");
	}

	if(depth != 0)
	{
		if(key == "") 
		{
			Scr_AddArray(); writeln("Scr_AddArray");
		}
		else
		{
			Scr_AddArrayKey(Scr_AllocString(key.toStringz)); writeln("Scr_AddArrayKey ", key);
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
			writeln("json parsing failed: ", e.msg);
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