#include <sourcemod>
#include <cstrike>
#include <sdktools>

#undef REQUIRE_PLUGIN
#tryinclude <sourcebanspp>
#define REQUIRE_PLUGIN

StringMap BansMap;

Handle TimerRespawn;
ConVar cvarBanType, cvarScoutEnable, cvarRespawnMode, cvarRespawnCD, cvarDisconnectBan;

int RespawnMode;
bool Sourcebans, RoundIsEnd;

//ArrayList RespawnList;

public Plugin myinfo = 
{
	name		= "DeathRun",
	version		= "1.0",
	description	= "Another version of DeathRun mode",
	author		= "hEl",
	url			= ""
};

public void OnPluginStart()
{
	//RespawnList = new ArrayList(ByteCountToCells(4));
	BansMap = new StringMap();
	HookEvent("player_team", OnPlayerTeam, EventHookMode_Pre);
	HookEvent("player_disconnect", OnPlayerDisconnect);
	HookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", OnRoundEnd, EventHookMode_PostNoCopy);
	/*HookEvent("player_spawn", OnPlayerSpawn);
	HookEvent("player_death", OnPlayerDeath);*/
	//cvarAntiRespawnBug = CreateConVar("dr_anti_respawn_bug", "1");
	cvarBanType = CreateConVar("dr_ban_type", "1", "0 - Bans/Sourcebans, 1 - Deathrun ban");
	cvarDisconnectBan = CreateConVar("dr_disconnect_ban", "60");
	cvarRespawnMode = CreateConVar("dr_respawn", "2");
	cvarRespawnCD = CreateConVar("dr_respawn_cd", "20");
	cvarScoutEnable = CreateConVar("dr_scout", "1");
	AutoExecConfig(true, "deathrun_swb");
	RegConsoleCmd("sm_scout", Command_Scout);
	AddCommandListener(Command_Block, "kill");
	AddCommandListener(Command_Block, "explode");
	AddCommandListener(Command_Block, "spectate");
	AddCommandListener(Command_Block, "jointeam");
	AddCommandListener(Command_Block, "joinclass");
	Sourcebans = LibraryExists("sourcebans++");
	LoadTranslations("deathrun_swb.phrases");
	RegAdminCmd("sm_dbans", Command_DeathRunBans, ADMFLAG_UNBAN);
}

public void OnPluginEnd()
{
	char szBuffer[256];
	int iEntity = -1;
	while((iEntity = FindEntityByClassname(iEntity, "func_hostage_rescue")) != -1)
	{
		if(GetEntPropString(iEntity, Prop_Data, "m_iName", szBuffer, 256) && !strcmp(szBuffer, "dr_roundend", false))
		{
			RemoveEntity(iEntity);
		}	
	}
}

public void OnMapStart()
{
	AddHostageZone();
	
	if(BansMap.Size > 0)
	{
		char szBuffer[256];
		StringMapSnapshot snapshot = BansMap.Snapshot();
		int iLength = snapshot.Length, iExpired, iTime = GetTime();
		for(int i; i < iLength; i++)
		{
			snapshot.GetKey(i, szBuffer, 256);
			if(BansMap.GetValue(szBuffer, iExpired) && iTime >= iExpired)
			{
				BansMap.Remove(szBuffer);
			}
			
		}
		delete snapshot;
	}
	
}

public void OnMapEnd()
{
	//RespawnList.Clear();
}

public Action Command_DeathRunBans(int iClient, int iArgs)
{
	if(iClient)
	{
		DeathRunBansMenu(iClient);
	}
	return Plugin_Handled;
}

void DeathRunBansMenu(int iClient, int iStartItem = 0)
{
	if(BansMap.Size == 0)
	{
		PrintToChat2(iClient, "Бан-лист пустой.");
		return;
	}
		
	char szBuffer[256], szBuffer2[256];
	Menu hMenu = new Menu(DeathRunBansMenuH, MenuAction_End | MenuAction_Select);
	hMenu.SetTitle("DeathRun bans menu");
	StringMapSnapshot snapshot = BansMap.Snapshot();
	int iLength = snapshot.Length, iExpired, iTime = GetTime();
	for(int i; i < iLength; i++)
	{
		snapshot.GetKey(i, szBuffer, 256);
		if(BansMap.GetValue(szBuffer, iExpired) && iExpired > iTime)
		{
			FormatEx(szBuffer2, 256, "%s\nИстекает через: %i сек", szBuffer, iExpired - iTime);
			hMenu.AddItem(szBuffer, szBuffer2);
		}
		
	}
	delete snapshot;
	hMenu.DisplayAt(iClient, iStartItem, 0);
}

public int DeathRunBansMenuH(Menu hMenu, MenuAction action, int iClient, int iItem)
{
	switch(action)
	{
		case MenuAction_End:
		{
			delete hMenu;
		}
		case MenuAction_Select:
		{
			char szBuffer[256];
			hMenu.GetItem(iItem, szBuffer, 256);
			int iExpired;
			if(BansMap.GetValue(szBuffer, iExpired))
			{
				BansMap.Remove(szBuffer);
				PrintToChat2(iClient, "Бан удален по идентификатору %s", szBuffer);
			}
			DeathRunBansMenu(iClient, hMenu.Selection);
		}
	}
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual("sourcebans++", name))
	{
		Sourcebans = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual("sourcebans++", name))
	{
		Sourcebans = false;
	}
}

public void OnClientAuthorized(int client, const char[] auth)
{
	if(cvarBanType.IntValue != 1 || BansMap.Size == 0 || strcmp(auth, "BOT", false) == 0)
		return;
	
	int iExpired, iTime = GetTime();
	char szBuffer[64];
	if(BansMap.GetValue(auth, iExpired) || (GetClientIP(client, szBuffer, 64) && BansMap.GetValue(szBuffer, iExpired)))
	{
		if(iExpired > iTime)
		{
			KickClient(client, "Disconnect for T - Wait: %i sec", iExpired - iTime);
		}
	}
}

/*public void OnPlayerSpawn(Event hEvent, const char[] event, bool bDontBroadcast)
{
	RequestFrame(OnPlayerSpawnNextTick, GetClientOfUserId(hEvent.GetInt("userid")));
}

void OnPlayerSpawnNextTick(int iClient)
{
	if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
	{
		return;
	}
	
	RespawnBug_OnPlayerSpawn(iClient);
}
public void OnPlayerDeath(Event hEvent, const char[] event, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	
	RespawnBug_OnPlayerDeath(iClient);
}

void RespawnBug_OnPlayerSpawn(int iClient)
{
	if(!cvarAntiRespawnBug.BoolValue || RoundIsEnd || !iClient || !IsClientInGame(iClient) || GetClientTeam(iClient) != 3 || !IsPlayerAlive(iClient))
		return;
		
	switch(RespawnMode)
	{
		case 2:
		{
			int iAccount = GetSteamAccountID(iClient);
	
			if(iAccount != 0)
			{
				if(RespawnList.FindValue(iAccount) == -1)
				{
					RespawnList.Push(iAccount);
				}
			}
		}
	}
}

bool RespawnBug_JoinClass(int iClient)
{
	if(!cvarAntiRespawnBug.BoolValue || RoundIsEnd || IsFakeClient(iClient))
		return false;
		
	switch(RespawnMode)
	{
		case 2:
		{
			int iAccount = GetSteamAccountID(iClient);
	
			if(iAccount != 0 && RespawnList.FindValue(iAccount) != -1)
			{
				FakeClientCommandEx(iClient, "spec_mode");
				return true;
			}
		}
	}
	return false;
}

stock void RespawnBug_OnPlayerDeath(int iClient)
{
	if(!cvarAntiRespawnBug.BoolValue || RoundIsEnd)
		return;
		
	switch(RespawnMode)
	{
		case 2:
		{
			int iAccount = GetSteamAccountID(iClient);
	
			if(iAccount != 0 && RespawnList.FindValue(iAccount) == -1)
			{
				RespawnList.Push(iAccount);
			}
		}
	}

}*/

void AddHostageZone()
{
	char sName[64];
	int iMax = GetMaxEntities();
	
	for (int i = MaxClients;i <= iMax; i++)	if(IsValidEntity(i) && GetEdictClassname(i, sName, 64) && strcmp(sName, "func_hostage_rescue", false) == 0)
		return;

	int iEnt = CreateEntityByName("func_hostage_rescue");
	if (iEnt > 0)
	{
		DispatchKeyValue(iEnt, "targetname", "dr_roundend");
		DispatchKeyValueVector(iEnt, "orign", view_as<float>({-1000.0, -1000.0, -1000.0}));
		DispatchSpawn(iEnt);
	}
}

public Action Command_Block(int iClient, const char[] command, int iArgs)
{
	if(iClient == 0)
		return Plugin_Continue;
	
	int iTeam = GetClientTeam(iClient), iCT = GetClientsCount2(3);
	switch(command[0])
	{
		case 'k', 'e', 's': // kill, explode, spectate
		{
			return (iTeam == 2 && iCT) ? Plugin_Handled:Plugin_Continue;
		}
		case 'j':
		{
			switch(command[4])
			{
				case 't': // jointeam
				{
					if(iTeam == 2)
					{
						return !iCT ? Plugin_Continue:Plugin_Handled;
					}
					if(!iArgs)
					{
						ChangeClientTeam(iClient, iTeam == 3 ? 1:3);
					}
					else
					{
						int iNewTeam;
						char szTeam[4];
						GetCmdArg(1, szTeam, 4);
						iNewTeam = StringToInt(szTeam);
						if(!(0 < iNewTeam <= 3))
						{
							iNewTeam = (iTeam == 3) ? 1:3;
						}
						else if(iNewTeam == 2)
						{
							if(!GetClientsCount2(2))
							{
								ChangeClientTeam(iClient, 2);
							}
						}
						else
						{
							return iNewTeam != iTeam ? Plugin_Continue:Plugin_Handled;
						}
						
					}
					return Plugin_Handled;
				}
				case 'c': // joinclass
				{
					switch(iTeam)
					{
						case 2:
						{
							return (IsPlayerAlive(iClient) && iCT) ? Plugin_Handled:Plugin_Continue;
						}
						case 3:
						{
							/*if(RespawnBug_JoinClass(iClient))
							{
								return Plugin_Handled;
							}*/
						}
					}
				}
			}
			
		}
	}
	return Plugin_Continue;
}

public Action Command_Scout(int iClient, int iArgs)
{
	if(cvarScoutEnable.BoolValue && Cmd_IsValidClient(iClient) && IsPlayerAlive(iClient) && GetClientTeam(iClient) == 3 && GetPlayerWeaponSlot(iClient, 0) == -1)
	{
		int iScout = GivePlayerItem(iClient, "weapon_scout");
		if(iScout > 0)
		{
			SetEntData(iClient, (FindSendPropInfo("CCSPlayer", "m_iAmmo") + (2 * 4)), 0);
			SetEntData(iScout, FindSendPropInfo("CBaseCombatWeapon", "m_iClip1"), 0, _, true);
		}
	}
	return Plugin_Handled;
}

bool Cmd_IsValidClient(int iClient)
{
	return (iClient && !IsFakeClient(iClient));
}

public Action OnPlayerTeam(Event hEvent, const char[] event, bool bDontBroadcast)
{
	return Plugin_Handled;
}

public void OnPlayerDisconnect(Event hEvent, const char[] event, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	if(iClient && IsClientInGame(iClient) && GetClientTeam(iClient) == 2 && !IsFakeClient(iClient) && GetClientsCount2(3) > 0)
	{
		SetNewTerrorist(false);
		if(!RoundIsEnd)
		{
			CS_TerminateRound(3.0, CSRoundEnd_Draw, true);
		}
		int iDuration = cvarDisconnectBan.IntValue;
		if(iDuration > 0)
		{
			char szReason[64];
			hEvent.GetString("reason", szReason, 64);
			if(strcmp(szReason, "Disconnect by user.", false) == 0)
			{
				switch(cvarBanType.IntValue)
				{
					case 0:
					{
						if(Sourcebans)
						{
							SBPP_BanPlayer(0, iClient, iDuration, "Terrorists cant disconnect");
						}
						else
						{
							BanClient(iClient, iDuration, BANFLAG_AUTHID, "Terrorists cant disconnect");
						}
					}
					case 1:
					{
						iDuration = GetTime() + iDuration * 60;
						char szBuffer[64];
						GetClientAuthId(iClient, AuthId_Steam2, szBuffer, 64, true);
						if(strcmp(szBuffer, "STEAM_ID_PENDING", false))
						{
							BansMap.SetValue(szBuffer, iDuration);
						}
						if(GetClientIP(iClient, szBuffer, 16))
						{
							BansMap.SetValue(szBuffer, iDuration);
						}
					}
				}

			}
		}
	}
}

public void OnRoundEnd(Event hEvent, const char[] event, bool bDontBroadcast)
{
	RoundIsEnd = true;
	//RespawnList.Clear();
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i))
		{
			SetEntProp(i, Prop_Data, "m_takedamage", 0, 1);
		}
	}
}
public void OnRoundStart(Event hEvent, const char[] event, bool bDontBroadcast)
{
	//RespawnList.Clear();
	RoundIsEnd = false;
	delete TimerRespawn;
	RespawnMode = cvarRespawnMode.IntValue;
	int iCD = cvarRespawnCD.IntValue;
	if(iCD > 0 && 0 < RespawnMode < 3)
	{
		TimerRespawn = CreateTimer(0.0, Timer_Respawn, iCD);
	}
}

public Action Timer_Respawn(Handle hTimer, int iCD)
{
	TimerRespawn = null;
	
	if(iCD > 0)
	{
		switch(RespawnMode)
		{
			case 1: PrintHintTextToAll("%t", "Auto Respawn 1: Left", iCD);
			case 2: PrintHintTextToAll("%t", "Auto Respawn 2: Left", iCD);
		}
		TimerRespawn = CreateTimer(1.0, Timer_Respawn, iCD - 1);
	}
	else
	{
		/*switch(RespawnMode)
		{
			case 2: RespawnList.Clear();
		}*/
		PrintHintTextToAll("%t", "Auto Respawn Disabled");
	}
	if(RespawnMode == 1 || iCD <= 0)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && !IsPlayerAlive(i) && GetClientTeam(i) == 3)
			{
				CS_RespawnPlayer(i);
			}
		}
	}
}

public Action CS_OnTerminateRound(float& delay, CSRoundEndReason& reason)
{
	CSRoundEndReason reasonCopy = reason;
	if(reason == CSRoundEnd_HostagesNotRescued)
	{
		reason = CSRoundEnd_TerroristWin;
	}
	if(reason != CSRoundEnd_GameStart && reason != CSRoundEnd_Draw)
	{
		CreateTimer(2.0, Timer_ChoseNewT);
	}
	
	return reasonCopy != reason ? Plugin_Changed:Plugin_Continue;
}

public Action Timer_ChoseNewT(Handle hTimer)
{
	SetNewTerrorist(true);
}

int SetNewTerrorist(bool bNotify)
{
	if(GetClientsCount2(2) + GetClientsCount2(3) < 2)
	{
		return -1;
	}
	int iNewT = -1;
	int iTeam;
	int iCount[2];
	int[][] Players = new int[2][MaxClients];
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || (iTeam = GetClientTeam(i) - 2) < 0)
			continue;
			
		Players[iTeam][iCount[iTeam]++] = i;
	}
	if(iCount[1])
	{
		iNewT = Players[1][GetRandomInt(0, iCount[1] - 1)];
		CS_SwitchTeam(iNewT, 2);
		if(bNotify)
		{
			PrintToChatAll2("%t", "New terrorist chosed", iNewT);
		}
	}
	
	for(int i; i < iCount[0]; i++)
	{
		CS_SwitchTeam(Players[0][i], 3);
	}
	return iNewT;
}

stock void PrintToChat2(int iClient, const char[] message, any ...)
{
	int iLen = strlen(message) + 255;
	char[] szBuffer = new char[iLen];
	SetGlobalTransTarget(iClient);
	VFormat(szBuffer, iLen, message, 3);
	if(iClient == 0)
	{
		PrintToConsole(iClient, szBuffer);
	}
	else
	{
		SendMessage(iClient, szBuffer, iLen);
	}
}


stock void PrintToChatAll2(const char[] message, any ...)
{
	int iLen = strlen(message) + 255;
	char[] szBuffer = new char[iLen];
	for(int i = 1;i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			SetGlobalTransTarget(i);
			VFormat(szBuffer, iLen, message, 2);
			SendMessage(i, szBuffer, iLen);
		}
	}
}


void SendMessage(int iClient, char[] szBuffer, int iSize)
{
	static int mode = -1;
	if(mode == -1)
	{
		mode = view_as<int>(GetUserMessageType() == UM_Protobuf);
	}
	SetGlobalTransTarget(iClient);
	Format(szBuffer, iSize, "\x01%t %s", "Tag", szBuffer);
	ReplaceString(szBuffer, iSize, "{C}", "\x07");

	
	Handle hMessage = StartMessageOne("SayText2", iClient, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS);
	switch(mode)
	{
		case 0:
		{
			BfWrite bfWrite = UserMessageToBfWrite(hMessage);
			bfWrite.WriteByte(iClient);
			bfWrite.WriteByte(true);
			bfWrite.WriteString(szBuffer);
		}
		case 1:
		{
			Protobuf protoBuf = UserMessageToProtobuf(hMessage);
			protoBuf.SetInt("ent_idx", iClient);
			protoBuf.SetBool("chat", true);
			protoBuf.SetString("msg_name", szBuffer);
			for(int k;k < 4;k++)	
				protoBuf.AddString("params", "");
		}
	}
	EndMessage();
}

stock int GetClientsCount2(int iTeam = -1)
{
	int iCount;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && (iTeam == -1 || GetClientTeam(i) == iTeam))
		{
			iCount++;
		}
	}
	
	return iCount;
}