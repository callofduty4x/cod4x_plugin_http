module functions;

import std.string;
import cod4x.functions;
import cod4x.server;

int Plugin_Milliseconds() {
	return cod4x.functions.Plugin_Milliseconds();
}

auto Plugin_GetPlayerUID(int slot)
{
	return cod4x.functions.Plugin_GetPlayerUID(slot);
    
    /*client_t* cl = Plugin_GetClientForClientNum(slot);
    import std.stdio;
    
    writeln(cl.clFPS);
    //writeln(cl.loginname);
    
    writeln(cl.connectedTime);
    writeln(cl.xversion);
    writeln(cl.protocol);
    writeln(cl.needupdate);
    writeln(cl.updateconnOK);
    writeln(cl.updateBeginTime);
    writeln(cl.steamid);
    writeln(cl.steamidPending);
    writeln(cl.clanid);
    writeln(cl.clanidPending);
    writeln(cl.playerid);
    
    writeln(cl.ssdata);
    writeln(cl.name);
    writeln(cl.userinfo);
    
    return cl.steamid;*/
}

auto Plugin_GetPlayerName(int slot)
{
	char* rawname = cod4x.functions.Plugin_GetPlayerName(slot);
	import std.conv : to;
	return fromStringz(rawname).to!string; 
}

/*GUID Plugin_GetPlayerGUID(int slot)
{
	import std.stdio : writeln;
	import core.stdc.stdio;
	
	//immutable(char)* erg = cod4x.functions.Plugin_GetPlayerGUID(slot);
    client_t* cl = Plugin_GetClientForClientNum(slot);
    immutable(char)* erg = cast(immutable(char)*)cl.legacy_pbguid;
	    
    GUID g;
	for(int i = 0; i < 32; i++)
		g[i] = *(erg+i);
	return g;
}*/

ubyte[4] Plugin_GetPlayerIP(int slot)
{
    // FIXME plz :V
    client_t* cl = Plugin_GetClientForClientNum(slot);
    ubyte* uglyptr = cast(ubyte*)cl.netchan.remoteAddress.ip;
    //uglyptr += 2;
    
    ubyte[4] ip;
    ip[0] = uglyptr[0];
    ip[1] = uglyptr[1];
    ip[2] = uglyptr[2];
    ip[3] = uglyptr[3];
    return ip;
}

string Plugin_Cvar_VariableString(string var)
{
	char[1024] buf;
	immutable(char)* arg = toStringz(var);
	cod4x.functions.Plugin_Cvar_VariableStringBuffer(arg, buf.ptr, buf.length);
	
	import std.conv;
	return fromStringz(buf.ptr).to!string;
}

void Plugin_Printf(string str)
{
	cod4x.functions.Plugin_Printf(str.toStringz());
}

void Plugin_Printf(string str, int i)
{	
	cod4x.functions.Plugin_Printf(str.toStringz(), i);
}

void Plugin_ChatPrintf(int slot, string str)
{
	cod4x.functions.Plugin_ChatPrintf(slot, str.toStringz());
}

void Plugin_BoldPrintf(int slot, string str)
{
	cod4x.functions.Plugin_BoldPrintf(slot, str.toStringz());
}

void Plugin_DropClient(int slot, string reason)
{
	cod4x.functions.Plugin_DropClient(slot, reason.toStringz());
}

string Plugin_Cvar_GetString(string var)
{
	immutable(char)* arg = toStringz(var);
	immutable(char)* erg = cod4x.functions.Plugin_Cvar_GetString(arg);
	return fromStringz(erg);
}

int Plugin_Cvar_VariableIntegerValue(string var)
{
	immutable(char)* arg = toStringz(var);
	return cod4x.functions.Plugin_Cvar_VariableIntegerValue(arg);
}

/*string Plugin_Cvar_VariableString(string var)
{
	immutable(char)* arg = toStringz(var);
	char* erg = cod4x.functions.Plugin_Cvar_VariableString(arg);
	
	import std.conv;
	return fromStringz(erg).to!string;
}*/

void Plugin_Cvar_Set(string var, string val)
{
	import std.conv;
	cod4x.functions.Plugin_Cvar_Set(var.toStringz, val.toStringz);
}

void Plugin_Exec(string cmd)
{
	char* arg = cast(char*)toStringz(cmd);
	Plugin_Cbuf_AddText(arg);
}

void Plugin_Scr_AddString(string str)
{
	cod4x.functions.Plugin_Scr_AddString(str.toStringz);
}

void Plugin_Scr_AddInt(int value) 
{
	cod4x.functions.Plugin_Scr_AddInt(value);
}

void PluginNotifyPlayer(int slot, ushort str, int args)
{
	cod4x.server.gentity_t* ent = cod4x.functions.Plugin_GetGentityForEntityNum(slot);
	cod4x.functions.Plugin_Scr_Notify(ent, str, args);
}

/*void PluginNotifyLevel(ushort str, int args)
{
	cod4x.functions.Plugin_Scr_Notify(str, args);
}*/

ushort Plugin_Scr_AllocString(string message)
{
	return cod4x.functions.Plugin_Scr_AllocString(message.toStringz);
}

/*void PluginNotifyPlayer(int slot, ushort str, int args)
{
	cod4x.server.gentity_t* ent = cod4x.functions.Plugin_GetGentityForEntityNum(slot);
	cod4x.functions.Plugin_Scr_Notify(ent, str, args);
}*/

/*void Plugin_Scr_NotifyLevel(ushort str, int numArgs)
{
	cod4x.functions.Plugin_Scr_NotifyLevel(str, numArgs);
}*/

void Cvar_RegisterString(string variable, string value, string desc)
{
    cod4x.functions.Plugin_Cvar_RegisterString(variable.toStringz,value.toStringz,0,desc.toStringz);
}

ulong Plugin_GetPlayerID(int clientslot)
{
	return cod4x.functions.Plugin_GetPlayerID(clientslot);
}

ulong Plugin_GetPlayerSteamID(int clientslot)
{
	return cod4x.functions.Plugin_GetPlayerSteamID(clientslot);
}

string Plugin_Scr_GetString( int i)
{
	immutable(char*) str = cod4x.functions.Plugin_Scr_GetString(i); 
	return fromStringz(str);
}

gentity_t* Plugin_Scr_GetEntity( int i)
{
	return cod4x.functions.Plugin_Scr_GetEntity(i);
}