#include <sourcemod>
#include <tf2>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.11"

bool g_PoweredUp[MAXPLAYERS+1] = {false, ...};
bool g_fireEffectAvailable = true;
float g_Duration;
ConVar g_CDuration = null;
Handle hSDKSchema = null;
Handle hSDKAddCustomAttribute = null;
Handle hSDKRemoveCustomAttribute = null;
Handle hSDKGetAttributeDefByName = null;

public Plugin myinfo = 
{
    name = "[TF2] PowerPlay Redux",
    author = "luki1412, DarthNinja",
    description = "Uber and crits!",
    version = PLUGIN_VERSION,
    url = "https://forums.alliedmods.net/member.php?u=43109"
}

public void OnPluginStart()
{
	ConVar CVVersion = CreateConVar("sm_ppr_version", PLUGIN_VERSION, "PowerPlay Redux version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_CDuration = CreateConVar("sm_ppr_duration", "999999.0", "Duration of PowerPlay", FCVAR_NONE);

	RegAdminCmd("sm_powerup", PowerPlays, ADMFLAG_SLAY);
	RegAdminCmd("sm_powerplayredux", PowerPlays, ADMFLAG_SLAY);
	RegAdminCmd("sm_ppr", PowerPlays, ADMFLAG_SLAY);
	
	Handle g_hGameConfig = LoadGameConfigFile("PowerPlayRedux");
	
	if(!g_hGameConfig)
	{
		LogError("Could not load PowerPlayRedux gamedata for the fire effect");
		g_fireEffectAvailable = false;
	}

	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(g_hGameConfig, SDKConf_Signature, "GEconItemSchema");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//Returns address of CEconItemSchema
	hSDKSchema = EndPrepSDKCall();
	if (!hSDKSchema)
	{
		LogError("Could not initialize call to GEconItemSchema for the fire effect");
		g_fireEffectAvailable = false;
	}

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(g_hGameConfig, SDKConf_Signature, "CEconItemSchema::GetAttributeDefinitionByName");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//Returns address of a CEconItemAttributeDefinition
	hSDKGetAttributeDefByName = EndPrepSDKCall();
	if (!hSDKGetAttributeDefByName)
	{
		LogError("Could not initialize call to CEconItemSchema::GetAttributeDefinitionByName for the fire effect");
		g_fireEffectAvailable = false;
	}

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(g_hGameConfig, SDKConf_Signature, "CAttributeList::SetRuntimeAttributeValue");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	hSDKAddCustomAttribute = EndPrepSDKCall();
	if (!hSDKAddCustomAttribute) {
		LogError("Could not initialize call to CAttributeList::SetRuntimeAttributeValue for the fire effect");
		g_fireEffectAvailable = false;
	}
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(g_hGameConfig, SDKConf_Signature, "CAttributeList::RemoveAttribute");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	hSDKRemoveCustomAttribute = EndPrepSDKCall();
	if (!hSDKRemoveCustomAttribute) {
		LogError("Could not initialize call to CAttributeList::RemoveAttribute for the fire effect");
		g_fireEffectAvailable = false;
	}

	delete g_hGameConfig;
	HookEvent("player_spawn", Event_PlayerSpawn);
	SetConVarString(CVVersion, PLUGIN_VERSION);
}

public void Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	g_PoweredUp[client] = false;
}

public Action PowerPlays(int client, int args)
{	
	if (args != 0 && args != 2)
	{
		ReplyToCommand(client, "Usage: sm_ppr <target> <1/0> \nIf you dont enter a target, it will be used on yourself.");
		return Plugin_Handled;
	}
	
	if (args == 0 && IsPlayerHere(client))
	{
		if (!g_PoweredUp[client])
		{
			PowerPlay(client, true);
			g_PoweredUp[client] = true;
			LogAction(client, client, "%N enabled PowerPlay on himself", client);
			ReplyToCommand(client,"\x04[PowerPlayRedux]\x01 You enabled PowerPlay on yourself!");
			return Plugin_Handled;
		}
		else if (g_PoweredUp[client])
		{
			PowerPlay(client, false);
			g_PoweredUp[client] = false;
			LogAction(client, client, "%N disabled PowerPlay on himself", client);
			ReplyToCommand(client,"\x04[PowerPlayRedux]\x01 You disabled PowerPlay on yourself!");
			return Plugin_Handled;
		}
		
		return Plugin_Handled;
	}
	else if (args == 2)
	{
		if (!CheckCommandAccess(client, "sm_powerplayredux_override", ADMFLAG_BAN))
		{
			ReplyToCommand(client, "Usage: sm_ppr <target> <1/0> \nIf you dont enter a target, it will be used on yourself.");
			return Plugin_Handled;
		}
		
		char buffer[64];
		char target_name[MAX_NAME_LENGTH];
		int target_list[MAXPLAYERS];
		int target_count;
		bool tn_is_ml;
		
		GetCmdArg(1, buffer, sizeof(buffer));
		
		if ((target_count = ProcessTargetString(
				buffer,
				client,
				target_list,
				MAXPLAYERS,
				COMMAND_FILTER_ALIVE,
				target_name,
				sizeof(target_name),
				tn_is_ml)) <= 0)
		{
			ReplyToTargetError(client, target_count);
			return Plugin_Handled;
		}
		
		char Enabled[32];
		GetCmdArg(2, Enabled, sizeof(Enabled));
		int iEnabled = StringToInt(Enabled);
		
		if (iEnabled == 1)
		{
			ReplyToCommand(client,"\x04[PowerPlayRedux]\x01 You enabled PowerPlay on %s!", target_name);
		}
		else
		{
			ReplyToCommand(client,"\x04[PowerPlayRedux]\x01 You disabled PowerPlay on %s!", target_name);
		}
		
		for (int i = 0; i < target_count; i++)
		{
			if (IsPlayerHere(target_list[i])) {
				if (iEnabled == 1)
				{
					PowerPlay(target_list[i], true);
					g_PoweredUp[target_list[i]] = true;
					LogAction(client, target_list[i], "[PowerPlayRedux] %N enabled PowerPlay on %N", client, target_list[i]);
				}
				else
				{
					PowerPlay(target_list[i], false);
					g_PoweredUp[target_list[i]] = false;
					LogAction(client, target_list[i], "[PowerPlayRedux] %N disabled PowerPlay on %N", client, target_list[i]);
				}
			}
		}
	}
	
	return Plugin_Handled;
}

public void PowerPlay(int client, bool enabled)
{
	g_Duration = GetConVarFloat(g_CDuration);
	
	if (enabled)
	{
		TF2_AddCondition(client, TFCond_UberchargedCanteen, g_Duration, client);
		TF2_AddCondition(client, TFCond_CritCanteen, g_Duration, client);
		if(g_fireEffectAvailable == true) {
			if(!AddAttribute(client, "attach particle effect static", 1.0)) {
				PrintToChat(client,"Failed to set on fire");
			}
		}
	}
	else
	{
		TF2_RemoveCondition(client, TFCond_UberchargedCanteen);
		TF2_RemoveCondition(client, TFCond_CritCanteen);
		if(g_fireEffectAvailable == true) {
			if(!AddAttribute(client, "attach particle effect static", 1.0, false)) {
				PrintToChat(client,"Failed to remove fire");
			}
		}
	}
}

bool IsPlayerHere(int client)
{
	return (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && IsPlayerAlive(client));
}

bool AddAttribute(int client, const char[] attrname, float value, bool remove = false)
{
	if (!IsPlayerHere(client))
	{
		return false;
	}
	int offs = GetEntSendPropOffs(client, "m_AttributeList", true);
	if (offs < 1)
	{
		return false;
	}
	Address pEntity = GetEntityAddress(client)+view_as<Address>(offs);
	if (pEntity == Address_Null) return false;
	Address pSchema = SDKCall(hSDKSchema);
	if (pSchema == Address_Null) return false;
	Address pAttribDef = SDKCall(hSDKGetAttributeDefByName, pSchema, attrname);
	if (pAttribDef == Address_Null) return false;
	if (remove != true) {
		SDKCall(hSDKAddCustomAttribute, pEntity, pAttribDef, value);
	} else {
		SDKCall(hSDKRemoveCustomAttribute, pEntity, pAttribDef);
	}
	return true;
}