#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <clans>
//#include <morecolors>
#include <colors>		//For CSS v34

#pragma newdecls required

#define ClanClient playerID[client]
#define BUFF_SIZE 200
#define LOG_SIZE 100
#define PLUGIN_VERSION "1.63"
#define MAX_CLAN_NAME 10

//====================LOGS========================
#define LOG_KILLS 1
#define LOG_COINS 2
#define LOG_RENAMES 4
#define LOG_CLANACTION 8
#define LOG_CLIENTACTION 16
#define LOG_CHANGETYPE 32
#define LOG_CHANGEROLE 64
#define LOG_SLOTS 128
#define LOG_CLANCHAT 256
//================================================

Handle g_hClansDB;
Handle g_hLogDB;

/* Clan data (int)
	0 - Number of members in clan
	1 - Maximum number of members in clan
	2 - Kills
	3 - Deaths
	4 - Time of creating
	5 - Coins
	6 - Type
*/
int g_iClanData[MAX_CLANS][7];

/* Clan data (string)
	0 - Name
	1 - Clan Leader
	2 - Clan Leader Steam ID
	3 - Date of creating
*/
char g_sClanData[MAX_CLANS][4][MAX_NAME_LENGTH+1];

/* Client data (int)
	0 - Clan ID
	1 - Role
	2 - Kills
	3 - Deaths
	4 - time of joining
*/
int g_iClientData[MAX_PLAYERSINCLANES][5];

/* Client data (String)
	0 - Name
	1 - Steam ID
*/
char g_sClientData[MAX_PLAYERSINCLANES][2][MAX_NAME_LENGTH+1];

//Leaders' id, who invite player, and invitation's time
int invitedBy[MAXPLAYERS+1][2];

//Players' id in DB
int playerID[MAXPLAYERS+1];

/*
Mode of watching members in clan
Also contains id of player to kick or to select as a leader (it is after choosing 1 or 2 mode)
	0 - See stats
	1 - Kick player
	2 - Select as a leader
	3 - Transfer coins
	4 - Change role
		id of clan/members
*/
int clan_SelectMode[MAXPLAYERS+1][2];

bool renameClan[MAXPLAYERS+1];
bool createClan[MAXPLAYERS+1];

/*
Admin modes of watching clans/members in clans. Contains type and ID
	Types [0]:
		0 - Select clan to set coins
		1 - Reset client
		2 - Reset clan
		3 - Delete client
		4 - Delete clan
		5 - Create clan
		6 - Change leader
		7 - Rename clan
		8 - Change slots
		9 - Change type
		10 - Change role
	ID [1] - contains clan's / player ID in database
*/
int admin_SelectMode[MAXPLAYERS+1][2];

/* Tops of clans
	0 - By kills
	1 - By deaths
	2 - By exist time
	3 - By number of members
	4 - By number of clan coins
*/
int TopClans[5][MAX_CLANS];

Handle 	g_hExpandingCost, 		//Price of expansion
		g_hMaxClanMembers, 		//Maximum number of players in any clan
		g_hExpandValue, 		//Number of slots clan gets buying the expansion
		g_hStartSlotsInClan, 	//Start number of slots for clans
		g_hTopUpdateTime,		//Timer for top updating
		g_hLogs,				//Logs of players' actions
		g_hLogFlags,			//Log flags
		g_hLogExpireDays,		//How many days a recond can be in DB
		g_hNoClanTag,			//Player's tag will be empty if player isn't in a clan (true or false)
		g_hLeaderChange,		//Flag: can leader set a new leader
		g_hCoinsTransfer,		//Flag: can clan transfer coins to other clan
		g_hLeaderLeave;		//Flag: can leader leave his/her clan
		
int 	g_iExpandingCost, 		//Price of expansion
		g_iMaxClanMembers, 		//Maximum number of players in any clan
		g_iExpandValue, 		//Number of slots clan gets buying the expansion
		g_iStartSlotsInClan,	//Start number of slots for clans
		g_iLogs,				//Flag for logs: 2 - to DB, 1 - to file, 0 - not to log
		g_iLogFlags,			//Log flags
		g_iLogExpireDays;		//How many days a recond can be in DB

float 	g_fTopUpdateTime;		//Timer for top updating in seconds
bool	g_bCSS34 = true,		//Flag for CSS v34
		mySQL = true,			//Flag for mySQL connection
		g_bNoClanTag,			//Player's tag will be empty if player isn't in a clan (true or false)
		g_bLeaderChange,		//Flag: can leader set a new leader
		g_bCoinsTransfer,		//Flag: can clan transfer coins to other clan
		g_bLeaderLeave;		//Flag: can leader leave his/her clan

Handle g_tUpdateTops = null;	//Timer for updating tops
		
//Forwards below
Handle	g_hACMOpened, 		//AdminClanMenuOpened
		g_hACMSelected,		//AdminClanMenuSelected
		g_hCMOpened, 		//ClanMenuOpened
		g_hCMSelected,		//ClanMenuSelected
		g_hCSOpened, 		//ClanStatsOpened
		g_hPSOpened, 		//PlayerStatsOpened
		g_hClansLoaded,		//ClansLoaded
		g_hClanAdded,		//ClansAdded
		g_hClanDeleted,		//ClansDeleted
		g_hClientAdded,		//ClientAdded
		g_hClientDeleted;	//ClientDeleted
//=====================Permissions=====================//
Handle	g_hRInvitePerm,				//Invite players to clan
		g_hRGiveCoinsToClan,		//Give coins to other clan
		g_hRExpandClan,				//Expand clan
		g_hRKickPlayer,				//Kick player
		g_hRChangeType,				//Change clan's type
		g_hRChangeRole;				//Change role of player

int		g_iRInvitePerm,
		g_iRGiveCoinsToClan,
		g_iRExpandClan,
		g_iRKickPlayer,
		g_iRChangeType,
		g_iRChangeRole;
//=====================Permissions END=====================//

//=====================ClanChatColors=====================//
Handle 	g_hCCLeader,		//Color for leader in clan chat
		g_hCCColeader,		//Color for co-leader in clan chat
		g_hCCElder,			//Color for elder in clan chat
		g_hCCMember;		//Color for member in clan chat

char	g_cCCLeader[20],		//Color for leader in clan chat
		g_cCCColeader[20],		//Color for co-leader in clan chat
		g_cCCElder[20],			//Color for elder in clan chat
		g_cCCMember[20];		//Color for member in clan chat
//=====================ClanChatColorsEND=====================//

public Plugin myinfo = 
{ 
	name = "Clan system", 
	author = "Dream", 
	description = "", 
	version = PLUGIN_VERSION, 
} 

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	//Clients
	CreateNative("Clans_IsClanLeader", Native_IsClanLeader);
	CreateNative("Clans_IsClanCoLeader", Native_IsClanCoLeader);
	CreateNative("Clans_IsClanElder", Native_IsClanElder);
	CreateNative("Clans_GetClientRole", Native_GetClientRole);
	CreateNative("Clans_GetClientID", Native_GetClientID);
	CreateNative("Clans_GetClientClan", Native_GetClientClan);
	CreateNative("Clans_GetOnlineClientClan", Native_GetOnlineClientClan);
	CreateNative("Clans_GetClientKills", Native_GetClientKills);
	CreateNative("Clans_SetClientKills", Native_SetClientKills);
	CreateNative("Clans_GetClientDeaths", Native_GetClientDeaths);
	CreateNative("Clans_SetClientDeaths", Native_SetClientDeaths);
	CreateNative("Clans_AreInDifferentClans", Native_AreInDifferentClans);
	CreateNative("Clans_IsClientInClan", Native_IsClientInClan);
	CreateNative("Clans_ShowPlayerInfo", Native_ShowPlayerInfo);
	CreateNative("Clans_GetCreatePerm", Native_GetCreatePerm);
	CreateNative("Clans_SetCreatePerm", Native_SetCreatePerm);
	//Clans
	CreateNative("Clans_IsClanValid", Native_IsClanValid);
	CreateNative("Clans_GetClanName", Native_GetClanName);
	CreateNative("Clans_GetClanKills", Native_GetClanKills);
	CreateNative("Clans_SetClanKills", Native_SetClanKills);
	CreateNative("Clans_GetClanDeaths", Native_GetClanDeaths);
	CreateNative("Clans_SetClanDeaths", Native_SetClanDeaths);
	CreateNative("Clans_GetClanCoins", Native_GetClanCoins);
	CreateNative("Clans_SetClanCoins", Native_SetClanCoins);
	CreateNative("Clans_GetClanMembers", Native_GetClanMembers);
	CreateNative("Clans_SetClanMembers", Native_SetClanMembers);
	CreateNative("Clans_GetClanMaxMembers", Native_GetClanMaxMembers);
	CreateNative("Clans_SetClanMaxMembers", Native_SetClanMaxMembers);
	CreateNative("Clans_ShowClanInfo", Native_ShowClanInfo);
	CreateNative("Clans_ShowClanMembers", Native_ShowClanMembers);
	CreateNative("Clans_ShowClanList", Native_ShowClanList);
	//Forwards
	g_hACMOpened = CreateGlobalForward("Clans_OnAdminClanMenuOpened", ET_Ignore, Param_Any, Param_Cell);
	g_hACMSelected = CreateGlobalForward("Clans_OnAdminClanMenuSelected", ET_Ignore, Param_Any, Param_Cell, Param_Cell);
	g_hCMOpened = CreateGlobalForward("Clans_OnClanMenuOpened", ET_Ignore, Param_Any, Param_Cell);
	g_hCMSelected = CreateGlobalForward("Clans_OnClanMenuSelected", ET_Ignore, Param_Any, Param_Cell, Param_Cell);
	g_hCSOpened = CreateGlobalForward("Clans_OnClanStatsOpened", ET_Ignore, Param_Any, Param_Cell);
	g_hPSOpened = CreateGlobalForward("Clans_OnPlayerStatsOpened", ET_Ignore, Param_Any, Param_Cell);
	g_hClansLoaded = CreateGlobalForward("Clans_OnClansLoaded", ET_Ignore);
	g_hClanAdded = CreateGlobalForward("Clans_OnClanAdded", ET_Ignore, Param_Cell, Param_Cell);
	g_hClanDeleted = CreateGlobalForward("Clans_OnClanDeleted", ET_Ignore, Param_Cell);
	g_hClientAdded = CreateGlobalForward("Clans_OnClientAdded", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_hClientDeleted = CreateGlobalForward("Clans_OnClientDeleted", ET_Ignore, Param_Cell, Param_Cell);
	return APLRes_Success;
}

public void OnPluginStart()
{
	//Admin commands
	RegAdminCmd("sm_aclans", Command_AdminClansMenu, ADMFLAG_ROOT);
	RegAdminCmd("sm_cdump", Command_ClansDump, ADMFLAG_ROOT);
	RegAdminCmd("sm_pdump", Command_PlayersDump, ADMFLAG_ROOT);
	RegAdminCmd("sm_ptoclan", Command_AddPlayerToClan, ADMFLAG_ROOT);
	RegAdminCmd("sm_poutofclan", Command_RemovePlayerFromClan, ADMFLAG_ROOT);
	RegAdminCmd("sm_adclan", Command_AdminDeleteClan, ADMFLAG_ROOT);
	RegAdminCmd("sm_asetcoins", Command_AdminSetCoins, ADMFLAG_ROOT);
	RegAdminCmd("sm_arclan", Command_AdminResetClan, ADMFLAG_ROOT);
	RegAdminCmd("sm_arclient", Command_AdminResetClient, ADMFLAG_ROOT);
	RegAdminCmd("sm_achelp", Command_AdminClanHelp, ADMFLAG_ROOT);
	
	//Player commands
	RegConsoleCmd("sm_cclan", Command_CreateClan);
	RegConsoleCmd("sm_dclan", Command_DeleteClan);
	RegConsoleCmd("sm_leaveclan", Command_LeaveClan);
	RegConsoleCmd("sm_myclan", Command_MyClan);
	RegConsoleCmd("sm_mcl", Command_MyClan);
	RegConsoleCmd("sm_clan", Command_MyClan);
	RegConsoleCmd("sm_invite", Command_Invite);
	RegConsoleCmd("sm_caccept", Command_AcceptClanInvitation);
	RegConsoleCmd("sm_ctop", Command_TopClans);
	RegConsoleCmd("sm_mystats", Command_MyStats);
	RegConsoleCmd("sm_chelp", Command_ClanHelp);
	RegConsoleCmd("sm_cchat", Command_ClanChat);
	RegConsoleCmd("sm_cct", Command_ClanChat);
	RegConsoleCmd("sm_jclan", Command_JoinClan);

	char DB_Error[256];
	DB_Error[0] = '\0';
	if (SQL_CheckConfig("clans"))
	{
		char buff[50];
		g_hClansDB = SQL_Connect("clans", true, DB_Error, sizeof(DB_Error));
		SQL_ReadDriver(g_hClansDB, buff, sizeof(buff));
		if(strcmp(buff,"mysql"))
			mySQL = false;
		//SetFailState("\"clans\" не найдена в databases.cfg");
	}
	else
	{
		g_hClansDB = SQLite_UseDatabase("clans", DB_Error, sizeof(DB_Error));
		mySQL = false;
	}
	if(g_hClansDB == INVALID_HANDLE)
	{
		SetFailState("[Clans] Unable to connect to database (%s)", DB_Error);
		return;
	}
	
	SQL_FastQuery(g_hClansDB, "CREATE TABLE IF NOT EXISTS `clans_table` (`clan_id` INTEGER NOT NULL PRIMARY KEY, `clan_name` TEXT, `leader_steam` TEXT, `leader_name` TEXT, `date_creation` TEXT, `time_creation` INTEGER NOT NULL default '0', `members` INTEGER NOT NULL default '0', `maxmembers` INTEGER NOT NULL default '0', `clan_kills` INTEGER NOT NULL default '0', `clan_deaths` INTEGER NOT NULL default '0', `clan_coins` INTEGER NOT NULL default '0', `clan_type` INTEGER default '0')");
	SQL_FastQuery(g_hClansDB, "CREATE TABLE IF NOT EXISTS `players_table` (`player_id` INTEGER NOT NULL PRIMARY KEY, `player_name` TEXT, `player_steam` TEXT, `player_clanid` INTEGER NOT NULL, `player_role` INTEGER NOT NULL, `player_kills` INTEGER NOT NULL default '0', `player_deaths` INTEGER NOT NULL default '0', `player_timejoining` INTEGER NOT NULL)");

	SQL_SetCharset(g_hClansDB, "utf8");	//ох, без этой строки бедные русские игроки становились ?????

	for(int i = 0; i < MAX_CLANS; ++i)
	{
		g_iClanData[i][CLAN_MEMBERS] = 0;
		g_iClanData[i][CLAN_MAXMEMBERS] = 0;
		g_iClanData[i][CLAN_KILLS] = 0;
		g_iClanData[i][CLAN_DEATHS] = 0;
		g_iClanData[i][CLAN_TIME] = 0;
		g_iClanData[i][CLAN_COINS] = 0;
		g_iClanData[i][CLAN_TYPE] = 0;
		g_sClanData[i][CLAN_NAME] = "";
		g_sClanData[i][CLAN_LEADERNAME] = "";
		g_sClanData[i][CLAN_LEADERID] = "";
		g_sClanData[i][CLAN_DATE] = "";
	}
		
	for(int i = 0; i < MAX_PLAYERSINCLANES; i++)
	{
		g_sClientData[i][CLIENT_NAME] = "";
		g_sClientData[i][CLIENT_STEAMID] = "";
		g_iClientData[i][CLIENT_CLANID] = -1;
		g_iClientData[i][CLIENT_ROLE] = 0;
		g_iClientData[i][CLIENT_KILLS] = 0;
		g_iClientData[i][CLIENT_DEATHS] = 0;
		g_iClientData[i][CLIENT_TIME] = 0;
	}

	Upgrade1();
	
	//SQL_LoadAll();
	
	g_hExpandingCost = CreateConVar("sm_clans_expansioncost", "10", "Number of coins needed to expand the clan.");
	g_iExpandingCost = GetConVarInt(g_hExpandingCost);
	HookConVarChange(g_hExpandingCost, OnConVarChange);
	
	g_hMaxClanMembers = CreateConVar("sm_clans_maxclanmembers", "50", "Maximum number of members in any clan.");
	g_iMaxClanMembers = GetConVarInt(g_hMaxClanMembers);
	HookConVarChange(g_hMaxClanMembers, OnConVarChange);
	
	g_hExpandValue = CreateConVar("sm_clans_expandvalue", "5", "Number of slots that are added when a clan is expanding.");
	g_iExpandValue = GetConVarInt(g_hExpandValue);
	HookConVarChange(g_hExpandValue, OnConVarChange);
	
	g_hStartSlotsInClan = CreateConVar("sm_clans_startslotsinclan", "10", "Number of start slots for members in clan.");
	g_iStartSlotsInClan = GetConVarInt(g_hStartSlotsInClan);
	HookConVarChange(g_hStartSlotsInClan, OnConVarChange);
	
	g_hTopUpdateTime = CreateConVar("sm_clans_topupdatetime", "120.0", "Period of updating the tops of clans in seconds.");
	g_fTopUpdateTime = GetConVarFloat(g_hTopUpdateTime);
	HookConVarChange(g_hTopUpdateTime, OnConVarChange);

	g_hRInvitePerm = CreateConVar("sm_clans_inviteperm", "7", "Role which is allowed invite players to clan");
	g_iRInvitePerm = GetConVarInt(g_hRInvitePerm);
	HookConVarChange(g_hRInvitePerm, OnConVarChange);

	g_hRGiveCoinsToClan = CreateConVar("sm_clans_transfercoinsperm", "6", "Role which is allowed transfer coins to other clans");
	g_iRGiveCoinsToClan = GetConVarInt(g_hRGiveCoinsToClan);
	HookConVarChange(g_hRGiveCoinsToClan, OnConVarChange);

	g_hRExpandClan = CreateConVar("sm_clans_expandperm", "6", "Role which is allowed expand clan");
	g_iRExpandClan = GetConVarInt(g_hRExpandClan);
	HookConVarChange(g_hRExpandClan, OnConVarChange);

	g_hRKickPlayer = CreateConVar("sm_clans_kickperm", "6", "Role which is allowed kick players from clan");
	g_iRKickPlayer = GetConVarInt(g_hRKickPlayer);
	HookConVarChange(g_hRKickPlayer, OnConVarChange);

	g_hRChangeType = CreateConVar("sm_clans_changetypeperm", "4", "Role which is allowed change clan's type");
	g_iRChangeType = GetConVarInt(g_hRChangeType);
	HookConVarChange(g_hRChangeType, OnConVarChange);

	g_hRChangeRole = CreateConVar("sm_clans_changeroleperm", "4", "Role which is allowed change player's role in clan");
	g_iRChangeRole = GetConVarInt(g_hRChangeRole);
	HookConVarChange(g_hRChangeRole, OnConVarChange);

	g_hLogs = CreateConVar("sm_clans_logs", "0", "Flag for logging players' actions: 1 - to log, 0 - not to log");
	g_iLogs = GetConVarInt(g_hLogs);
	HookConVarChange(g_hLogs, OnConVarChange);

	g_hLogFlags = CreateConVar("sm_clans_logflags", "0", "Flags for logging players' actions");
	g_iLogFlags = GetConVarInt(g_hLogFlags);
	HookConVarChange(g_hLogFlags, OnConVarChange);

	g_hLogExpireDays = CreateConVar("sm_clans_logexpire", "30", "How many days a recond can be in database");
	g_iLogExpireDays = GetConVarInt(g_hLogExpireDays);
	HookConVarChange(g_hLogExpireDays, OnConVarChange);
	
	g_hCCLeader = CreateConVar("sm_clans_ccleader", "red", "Color for leader in clan chat");
	GetConVarString(g_hCCLeader, g_cCCLeader, sizeof(g_cCCLeader));
	HookConVarChange(g_hCCLeader, OnConVarChange);

	g_hCCColeader = CreateConVar("sm_clans_cccoleader", "blue", "Color for co-leader in clan chat");
	GetConVarString(g_hCCColeader, g_cCCColeader, sizeof(g_cCCColeader));
	HookConVarChange(g_hCCColeader, OnConVarChange);

	g_hCCElder = CreateConVar("sm_clans_ccelder", "olive", "Color for elder in clan chat");
	GetConVarString(g_hCCElder, g_cCCElder, sizeof(g_cCCElder));
	HookConVarChange(g_hCCElder, OnConVarChange);

	g_hCCMember = CreateConVar("sm_clans_ccmember", "gray", "Color for member in clan chat");
	GetConVarString(g_hCCMember, g_cCCMember, sizeof(g_cCCMember));
	HookConVarChange(g_hCCMember, OnConVarChange);
	
	/*g_hNoClanTag = CreateConVar("sm_clans_noclantag", "1", "Player's tag will be empty if player isn't in a clan (1 - yes, 0 - no)");
	g_bNoClanTag = GetConVarBool(g_hNoClanTag);
	HookConVarChange(g_hNoClanTag, OnConVarChange);*/

	g_hLeaderChange = CreateConVar("sm_clans_leaderchange", "1", "Can leader set a new leader in clan (1 - yes, 0 - no)");
	g_bLeaderChange = GetConVarBool(g_hLeaderChange);
	HookConVarChange(g_hLeaderChange, OnConVarChange);

	g_hCoinsTransfer = CreateConVar("sm_clans_coinstransfer", "1", "Can clan transfer coins to other clan (1 - yes, 0 - no)");
	g_bCoinsTransfer = GetConVarBool(g_hCoinsTransfer);
	HookConVarChange(g_hCoinsTransfer, OnConVarChange);
	
	g_hLeaderLeave = CreateConVar("sm_clans_leaderleave", "1", "Can clan leader leave a clan (1 - yes, 0 - no)");
	g_bLeaderLeave = GetConVarBool(g_hLeaderLeave);
	HookConVarChange(g_hLeaderLeave, OnConVarChange);

	if(g_iLogs)
	{
		ReadyToLog();
	}
	
	AutoExecConfig(true, "clans_settings", "clans");
	
	HookEvent("player_death", Death);
	HookEvent("player_spawn", Spawn);
	
	AddCommandListener(SayHook, "say");
	
	LoadTranslations("clans.phrases");
	LoadTranslations("clans_menus.phrases");
	LoadTranslations("clans_log.phrases");
	
	ClansLoaded();
	
	CreateTimer(5.0, Timer_UpdateTopsOfClans, _, TIMER_FLAG_NO_MAPCHANGE);
	g_tUpdateTops = CreateTimer(g_fTopUpdateTime, Timer_UpdateTopsOfClans, _, TIMER_REPEAT);
}

void Upgrade1()
{
	char query[200];
	if(mySQL)
		FormatEx(query, sizeof(query), "SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'players_table' AND COLUMN_NAME = 'player_isleader';");
	else
		FormatEx(query, sizeof(query), "SELECT COUNT(*) AS CNTREC FROM pragma_table_info('players_table') WHERE name='player_isleader';");
	DBResultSet hQuery = SQL_Query(g_hClansDB, query, sizeof(query));
	if(hQuery == null)
	{
		char error[255];
		SQL_GetError(g_hClansDB, error, sizeof(error));
		LogError("[CLANS] Unable to upgrade. Error: 1, %s", error);
	}
	else
	{
		if(SQL_FetchRow(hQuery))
		{
			if(SQL_FetchInt(hQuery, 0) == 1)	//If 1.51 or low version
			{
				if(mySQL)
					FormatEx(query, sizeof(query), "ALTER TABLE `players_table` CHANGE `player_isleader` `player_role` INTEGER");
				else
					FormatEx(query, sizeof(query), "ALTER TABLE `players_table` RENAME COLUMN `player_isleader` TO `player_role`");
				SQL_TQuery(g_hClansDB, SQL_LogError, query, 8);
				FormatEx(query, sizeof(query), "ALTER TABLE `clans_table` ADD `clan_type` INTEGER default '0'");
				SQL_TQuery(g_hClansDB, SQL_LogError, query, 9);
				FormatEx(query, sizeof(query), "UPDATE `players_table` SET `player_role` = '4' WHERE `player_role` = '1'");
				SQL_TQuery(g_hClansDB, SQL_LogError, query, 4);
			}
		}
	}
	delete hQuery;
	SQL_LoadAll();
}

void ReadyToLog()
{
	char DB_Error[255];
	g_hLogDB = SQLite_UseDatabase("clans_log", DB_Error, sizeof(DB_Error));
	if(g_hLogDB == INVALID_HANDLE)
	{
		SetFailState("[Clans] Unable to connect to database (%s)", DB_Error);
		return;
	}
	SQL_FastQuery(g_hLogDB, "CREATE TABLE IF NOT EXISTS `logs` (`playerid` INTEGER, `pname` VARCHAR(255), `clanid` INTEGER, `cname` VARCHAR(255), `action` TEXT, `toWhomPID` INTEGER, `toWhomPName` VARCHAR(255), `toWhomCID` INTEGER, `toWhomCName` VARCHAR(255), `type` INTEGER, `itime` INTEGER, `time` VARCHAR(50))");
	DeleteExpiredRecords();
}

void DeleteExpiredRecords()
{
	int time = GetTime();
	char query[100];
	time = time = g_iLogExpireDays*24*60*60;
	FormatEx(query, sizeof(query), "DELETE FROM `logs` WHERE `time` < '%d'", time);
	SQL_TQuery(g_hLogDB, SQL_LogError, query, 11);
}

public void OnPluginEnd()
{
	SQL_SaveClans();
	SQL_SaveClients();
	if(g_tUpdateTops != INVALID_HANDLE)
		KillTimer(g_tUpdateTops);
}

void ClansLoaded()
{
	Call_StartForward(g_hClansLoaded);	//Clans_OnClansLoaded forward
	Call_Finish();
}

public void OnConVarChange(Handle hCvar, const char[] oldValue, const char[] newValue)
{
	if(hCvar == g_hExpandingCost) 
		g_iExpandingCost = StringToInt(newValue);
	else if(hCvar == g_hMaxClanMembers)
		g_iMaxClanMembers = StringToInt(newValue);
	else if(hCvar == g_hExpandValue)
		g_iExpandValue = StringToInt(newValue);
	else if(hCvar == g_hStartSlotsInClan)
		g_iStartSlotsInClan = StringToInt(newValue);
	else if(hCvar == g_hTopUpdateTime)
		g_fTopUpdateTime = StringToFloat(newValue);
	else if(hCvar == g_hRInvitePerm)
		g_iRInvitePerm = StringToInt(newValue);
	else if(hCvar == g_hRGiveCoinsToClan)
		g_iRGiveCoinsToClan = StringToInt(newValue);
	else if(hCvar == g_hRExpandClan)
		g_iRExpandClan = StringToInt(newValue);
	else if(hCvar == g_hRKickPlayer)
		g_iRKickPlayer = StringToInt(newValue);
	else if(hCvar == g_hRChangeType)
		g_iRChangeType = StringToInt(newValue);
	else if(hCvar == g_hRChangeRole)
		g_iRChangeRole = StringToInt(newValue);
	else if(hCvar == g_hLogs)
	{
		g_iLogs = StringToInt(newValue);
		if(g_iLogs == 1)
			ReadyToLog();
	}
	else if(hCvar == g_hLogFlags)
		g_iLogFlags = StringToInt(newValue);
	else if(hCvar == g_hLogExpireDays)
		g_iLogExpireDays = StringToInt(newValue);
	else if(hCvar == g_hCCLeader)
		FormatEx(g_cCCLeader, sizeof(g_cCCLeader), "%s", newValue);
	else if(hCvar == g_hCCColeader)
		FormatEx(g_cCCColeader, sizeof(g_cCCColeader), "%s", newValue);
	else if(hCvar == g_hCCElder)
		FormatEx(g_cCCElder, sizeof(g_cCCElder), "%s", newValue);
	else if(hCvar == g_hCCMember)
		FormatEx(g_cCCMember, sizeof(g_cCCMember), "%s", newValue);
	else if(hCvar == g_hNoClanTag)
		g_bNoClanTag = StringToInt(newValue) == 1 ? true : false;
	else if(hCvar == g_hLeaderChange)
		g_bLeaderChange = StringToInt(newValue) == 1 ? true : false;
	else if(hCvar == g_hCoinsTransfer)
		g_bCoinsTransfer = StringToInt(newValue) == 1 ? true : false;
	else if(hCvar == g_hLeaderLeave)
		g_bLeaderLeave = StringToInt(newValue) == 1 ? true : false;
}

public void OnClientPostAdminCheck(int client)
{
	renameClan[client] = false;
	createClan[client] = true;
	char auth[33], userName[MAX_NAME_LENGTH+1];
	GetClientAuthId(client, AuthId_Steam3, auth, sizeof(auth));
	GetClientName(client, userName, sizeof(userName));
	ClanClient = GetClientIDinDBbySteam(auth);
	if(ClanClient != -1 && strcmp(g_sClientData[ClanClient][CLIENT_NAME], userName) != 0)
	{
		g_sClientData[ClanClient][CLIENT_NAME] = userName;
		if(IsClientClanLeader(ClanClient))
			g_sClanData[g_iClientData[ClanClient][CLIENT_CLANID]][CLAN_LEADERNAME] = userName;
	}
	invitedBy[client][0] = -1;
	invitedBy[client][1] = -1;
	admin_SelectMode[client][0] = -1;
	admin_SelectMode[client][1] = -1;
	clan_SelectMode[client][0] = -1;
	clan_SelectMode[client][1] = -1;
	if(!g_bCSS34)
		UpdatePlayerClanTag(client);
}

public void OnClientDisconnect(int client)
{
	if(ClanClient != -1)
	{
		SQL_SaveClient(ClanClient);
		ClanClient = -1;
	}
}

public void OnMapEnd()
{
	SQL_SaveClans();
	SQL_SaveClients();
}

public Action Death(Handle event, const char[] name, bool db)
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	int victimDB = GetClientIDinDB(victim);
	int attackerDB = GetClientIDinDB(attacker);
	
	if (victim && attacker && (GetClientTeam(victim) != GetClientTeam(attacker)) && AreClientsInDifferentClans(victimDB, attackerDB))
	{
		if(IsClientInClan(victimDB))
		{
			g_iClientData[victimDB][CLIENT_DEATHS]++;
			g_iClanData[g_iClientData[victimDB][CLIENT_CLANID]][CLAN_DEATHS]++;
		}
		if(IsClientInClan(attackerDB))
		{
			g_iClientData[attackerDB][CLIENT_KILLS]++;
			g_iClanData[g_iClientData[attackerDB][CLIENT_CLANID]][CLAN_KILLS]++;
		}
		if(CheckForLog(LOG_KILLS) && (victimDB != -1 || attackerDB != -1))
		{
			char log_buff[LOG_SIZE];
			FormatEx(log_buff, sizeof(log_buff), "%T", "L_Kill", LANG_SERVER);
			SQL_LogAction(attacker, false, GetClientClan(attackerDB), log_buff, victim, false, GetClientClan(victimDB), LOG_KILLS);
		}
	}
	return Plugin_Continue;
}

public Action Spawn(Handle event, const char[] name, bool db)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!g_bCSS34)
		UpdatePlayerClanTag(client);
	return Plugin_Handled;
}

public Action SayHook(int client, const char[] command, int args)
{
	if(client && IsClientInGame(client))
	{
		if(admin_SelectMode[client][0] >= 0 && admin_SelectMode[client][0] != 7)
		{
			char adminName[MAX_NAME_LENGTH+1];
			GetClientName(client, adminName, sizeof(adminName));
			switch(admin_SelectMode[client][0])
			{
				case 0:	//set coins
				{
					char str_coins[30], print_buff[BUFF_SIZE];
					int coins = 0;
					int type = 1;	//0 - take, 1 - set, 2 - give
					GetCmdArg(1, str_coins, sizeof(str_coins));
					TrimString(str_coins);
					if(!strcmp(str_coins, "отмена") || !strcmp(str_coins, "cancel"))
					{
						admin_SelectMode[client][0] = -1;
						admin_SelectMode[client][1] = -1;
						return Plugin_Handled;
					}
					if(str_coins[0] == '+')
						type = 2;
					else if(str_coins[0] == '-')
						type = 0;
					ReplaceString(str_coins, sizeof(str_coins), "+", "");
					ReplaceString(str_coins, sizeof(str_coins), "-", "");
					coins = StringToInt(str_coins);
					if(type == 0)
					{
						if(g_iClanData[admin_SelectMode[client][1]][CLAN_COINS]-coins < 0)
						{
							FormatEx(print_buff, sizeof(print_buff), "%T", "c_CoinsIncorrect", client);
							CPrintToChat(client, print_buff);
							admin_SelectMode[client][0] = -1;
							admin_SelectMode[client][1] = -1;
							return Plugin_Handled;
						}
						else
						{
							SetClanCoins(admin_SelectMode[client][1], g_iClanData[admin_SelectMode[client][1]][CLAN_COINS]-coins);
							if(CheckForLog(LOG_COINS))
							{
								char log_buff[LOG_SIZE];
								FormatEx(log_buff, sizeof(log_buff), "%T", "L_TakeCoins", LANG_SERVER, coins, g_sClanData[admin_SelectMode[client][1]][CLAN_NAME]);
								SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, -1, true, admin_SelectMode[client][1], LOG_COINS);
							}
							for(int i = 1; i <= MaxClients; i++)
							{
								if(IsClientInGame(i) && GetClientClan(playerID[i]) == admin_SelectMode[client][1])
								{
									FormatEx(print_buff, sizeof(print_buff), "%T", "c_AdminTookCoins", i, adminName, coins);
									CPrintToChat(i, print_buff);
								}
							}
						}
					}
					else if(type == 1)
					{
						if(coins < 0)
						{
							FormatEx(print_buff, sizeof(print_buff), "%T", "c_CoinsIncorrect", client);
							CPrintToChat(client, print_buff);
							admin_SelectMode[client][0] = -1;
							admin_SelectMode[client][1] = -1;
							return Plugin_Handled;
						}
						else
						{
							SetClanCoins(admin_SelectMode[client][1], coins);
							if(CheckForLog(LOG_COINS))
							{
								char log_buff[LOG_SIZE];
								FormatEx(log_buff, sizeof(log_buff), "%T", "L_SetCoins", LANG_SERVER, coins, g_sClanData[admin_SelectMode[client][1]][CLAN_NAME]);
								SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, -1, true, admin_SelectMode[client][1], LOG_COINS);
							}
							for(int i = 1; i <= MaxClients; i++)
							{
								if(IsClientInGame(i) && GetClientClan(playerID[i]) == admin_SelectMode[client][1])
								{
									FormatEx(print_buff, sizeof(print_buff), "%T", "c_AdminSetCoins", i, adminName, coins);
									CPrintToChat(i, print_buff);
								}
							}
						}
					}
					else
					{
						if(g_iClanData[admin_SelectMode[client][1]][CLAN_COINS]+coins < 0)
						{
							FormatEx(print_buff, sizeof(print_buff), "%T", "c_CoinsIncorrect", client);
							CPrintToChat(client, print_buff);
							admin_SelectMode[client][0] = -1;
							admin_SelectMode[client][1] = -1;
							return Plugin_Handled;
						}
						else
						{
							SetClanCoins(admin_SelectMode[client][1], g_iClanData[admin_SelectMode[client][1]][CLAN_COINS]+coins);
							if(CheckForLog(LOG_COINS))
							{
								char log_buff[LOG_SIZE];
								FormatEx(log_buff, sizeof(log_buff), "%T", "L_GiveCoins", LANG_SERVER, coins, g_sClanData[admin_SelectMode[client][1]][CLAN_NAME]);
								SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, -1, true, admin_SelectMode[client][1], LOG_COINS);
							}
							for(int i = 1; i <= MaxClients; i++)
							{
								if(IsClientInGame(i) && GetClientClan(playerID[i]) == admin_SelectMode[client][1])
								{
									FormatEx(print_buff, sizeof(print_buff), "%T", "c_AdminGaveCoins", i, adminName, coins);
									CPrintToChat(i, print_buff);
								}
							}
						}
					}
					FormatEx(print_buff, sizeof(print_buff), "%T", "c_CoinsNow", client, g_sClanData[admin_SelectMode[client][1]][CLAN_NAME], g_iClanData[admin_SelectMode[client][1]][CLAN_COINS]);
					CPrintToChat(client, print_buff);
				}
				case 1: //reset client
				{
					char str_clientID[20];
					int clientID = -1;
					GetCmdArg(1, str_clientID, sizeof(str_clientID));
					TrimString(str_clientID);
					clientID = StringToInt(str_clientID);
					if(clientID == admin_SelectMode[client][1])
					{
						char print_buff[BUFF_SIZE];
						FormatEx(print_buff, sizeof(print_buff), "%T", "c_PlayerReset", client, g_sClientData[clientID][CLIENT_NAME]);
						CPrintToChat(client, print_buff);
						if(CheckForLog(LOG_CLIENTACTION))
						{
							char log_buff[LOG_SIZE];
							FormatEx(log_buff, sizeof(log_buff), "%T", "L_ResetPlayer", LANG_SERVER, g_sClientData[clientID][CLIENT_NAME]);
							SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, clientID, true, GetClientClan(clientID), LOG_CLIENTACTION);
						}
						for(int i = 1; i <= MaxClients; i++)
						{
							if(IsClientInGame(i) && playerID[i] == clientID)
							{
								FormatEx(print_buff, sizeof(print_buff), "%T", "c_AdminResetPlayer", i, adminName);
								CPrintToChat(i, print_buff);
								i = MaxClients+1;
							}
						}
						ResetClient(clientID);
					}
				}
				case 2:	//reset clan
				{
					char str_clanid[20];
					int clanid = -1;
					GetCmdArg(1, str_clanid, sizeof(str_clanid));
					TrimString(str_clanid);
					clanid = StringToInt(str_clanid);
					if(clanid == admin_SelectMode[client][1])
					{
						char print_buff[BUFF_SIZE];
						FormatEx(print_buff, sizeof(print_buff), "%T", "c_ClanReset", client, g_sClanData[clanid][CLAN_NAME]);
						CPrintToChat(client, print_buff);
						if(CheckForLog(LOG_CLANACTION))
						{
							char log_buff[LOG_SIZE];
							FormatEx(log_buff, sizeof(log_buff), "%T", "L_ResetClan", LANG_SERVER, g_sClanData[clanid][CLAN_NAME]);
							SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, -1, true, clanid, LOG_CLANACTION);
						}
						for(int i = 1; i <= MaxClients; i++)
						{
							if(IsClientInGame(i) && GetClientClan(playerID[i]) == clanid)
							{
								FormatEx(print_buff, sizeof(print_buff), "%T", "c_AdminResetClan", i, adminName);
								CPrintToChat(i, print_buff);
							}
						}
						ResetClan(clanid);
					}
				}
				case 3: //delete client
				{
					char str_clientID[20];
					int clientID = -1;
					GetCmdArg(1, str_clientID, sizeof(str_clientID));
					TrimString(str_clientID);
					clientID = StringToInt(str_clientID);
					if(clientID == admin_SelectMode[client][1])
					{
						char print_buff[BUFF_SIZE];
						FormatEx(print_buff, sizeof(print_buff), "%T", "c_PlayerDelete", client, g_sClientData[clientID][CLIENT_NAME]);
						CPrintToChat(client, print_buff);
						if(CheckForLog(LOG_CLIENTACTION))
						{
							char log_buff[LOG_SIZE];
							FormatEx(log_buff, sizeof(log_buff), "%T", "L_DeletePlayer", LANG_SERVER, g_sClientData[clientID][CLIENT_NAME], g_sClanData[GetClientClan(clientID)][CLAN_NAME]);
							SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, clientID, true, GetClientClan(clientID), LOG_CLIENTACTION);
						}
						for(int i = 1; i <= MaxClients; i++)
						{
							if(IsClientInGame(i) && playerID[i] == clientID)
							{
								FormatEx(print_buff, sizeof(print_buff), "%T", "c_AdminDeletePlayer", i, adminName);
								CPrintToChat(i, print_buff);
								i = MaxClients+1;
							}
						}
						DeleteClient(clientID);
					}
				}
				case 4:	//delete clan
				{
					char str_clanid[20];
					int clanid = -1;
					GetCmdArg(1, str_clanid, sizeof(str_clanid));
					TrimString(str_clanid);
					clanid = StringToInt(str_clanid);
					if(clanid == admin_SelectMode[client][1])
					{
						char print_buff[BUFF_SIZE];
						FormatEx(print_buff, sizeof(print_buff), "%T", "c_ClanDelete", client, g_sClanData[clanid][CLAN_NAME]);
						CPrintToChat(client, print_buff);
						if(CheckForLog(LOG_CLANACTION))
						{
							char log_buff[LOG_SIZE];
							FormatEx(log_buff, sizeof(log_buff), "%T", "L_DeleteClan", LANG_SERVER, g_sClanData[clanid][CLAN_NAME]);
							SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, -1, true, clanid, LOG_CLANACTION);
						}
						for(int i = 1; i <= MaxClients; i++)
						{
							if(IsClientInGame(i) && GetClientClan(playerID[i]) == clanid)
							{
								FormatEx(print_buff, sizeof(print_buff), "%T", "c_AdminDeleteClan", i, adminName);
								CPrintToChat(i, print_buff);
							}
						}
						DeleteClan(clanid);
					}
				}
				case 5:	//create clan
				{
					char clanName[MAX_CLAN_NAME+1], userName[MAX_NAME_LENGTH], auth[33], date[11], buff[50];
					int clanid = -1;
					int clientID = admin_SelectMode[client][1];
					GetCmdArg(1, buff, sizeof(buff));
					TrimString(buff);
					if(strlen(buff) < 1 || strlen(buff) > MAX_CLAN_NAME)
					{
						char print_buff[BUFF_SIZE];
						FormatEx(print_buff, sizeof(print_buff), "%T", "c_WrongClanName", client, MAX_CLAN_NAME);
						CPrintToChat(client, print_buff);
						admin_SelectMode[client][0] = -1;
						admin_SelectMode[client][1] = -1;
						return Plugin_Handled;
					}
					else
					{
						for(int i = 0; i < MAX_CLAN_NAME; i++)
							clanName[i] = buff[i];
						clanName[MAX_CLAN_NAME] = '\0';
					}
					
					for(int i = 0; i < MAX_CLANS; i++)
					{
						if(!strcmp(clanName, g_sClanData[i][CLAN_NAME]))
						{
							admin_SelectMode[client][0] = -1;
							admin_SelectMode[client][1] = -1;
							char print_buff[BUFF_SIZE];
							FormatEx(print_buff, sizeof(print_buff), "%T", "c_ClanAlreadyExists", client);
							CPrintToChat(client, print_buff);
							return Plugin_Handled;
						}
					}
					
					if(playerID[clientID] != -1)
						DeleteClient(playerID[clientID]);
					
					for(int i = 0; clanid == -1 && i < MAX_CLANS; i++)
					{
						if(g_iClanData[i][CLAN_MEMBERS] < 1)
							clanid = i;
					}
					
					if(clanid == -1)
					{
						char print_buff[BUFF_SIZE];
						FormatEx(print_buff, sizeof(print_buff), "%T", "c_ClanLimit", client);
						CPrintToChat(client, print_buff);
						admin_SelectMode[client][0] = -1;
						admin_SelectMode[client][1] = -1;
						return Plugin_Handled;
					}
						
					GetClientName(clientID, userName, sizeof(userName));
					GetClientAuthId(clientID, AuthId_Steam3, auth, sizeof(auth));
					FormatTime(date, 10, "%D");
					date[10] = '\0';
					
					g_sClanData[clanid][CLAN_NAME] = clanName;
					g_sClanData[clanid][CLAN_LEADERNAME] = userName;
					g_sClanData[clanid][CLAN_LEADERID] = auth;
					g_sClanData[clanid][CLAN_DATE] = date;
					
					g_iClanData[clanid][CLAN_MEMBERS] = 1;
					g_iClanData[clanid][CLAN_MAXMEMBERS] = g_iStartSlotsInClan;
					g_iClanData[clanid][CLAN_KILLS] = 0;
					g_iClanData[clanid][CLAN_DEATHS] = 0;
					g_iClanData[clanid][CLAN_TIME] = GetTime();
					g_iClanData[clanid][CLAN_COINS] = 0;
					
					for(int i = 0; i < MAX_PLAYERSINCLANES; i++)
						if(g_iClientData[i][CLIENT_CLANID] == -1)
						{
							playerID[clientID] = i;
							i = MAX_PLAYERSINCLANES;
						}
					g_iClientData[playerID[clientID]][CLIENT_CLANID] = clanid;		
					g_iClientData[playerID[clientID]][CLIENT_ROLE] = CLIENT_LEADER;
					g_iClientData[playerID[clientID]][CLIENT_KILLS] = 0;
					g_iClientData[playerID[clientID]][CLIENT_DEATHS] = 0;
					g_iClientData[playerID[clientID]][CLIENT_TIME] = GetTime();
					g_sClientData[playerID[clientID]][CLIENT_NAME] = userName;
					g_sClientData[playerID[clientID]][CLIENT_STEAMID] = auth;
					char print_buff[BUFF_SIZE];
					FormatEx(print_buff, sizeof(print_buff), "%T", "c_CreationSuccess", client);
					CPrintToChat(client, print_buff);
					SQL_CreateClan(clanid);
					SQL_CreateClient(playerID[clientID]);
					if(!g_bCSS34)
						UpdatePlayerClanTag(clientID);
					Call_StartForward(g_hClanAdded);	//Clans_OnClanAdded forward
					Call_PushCell(clanid);
					Call_PushCell(clientID);
					Call_Finish();
					Call_StartForward(g_hClientAdded);	//Clans_OnClientAdded forward
					Call_PushCell(clientID);
					Call_PushCell(playerID[clientID]);
					Call_PushCell(clanid);
					Call_Finish();
					if(CheckForLog(LOG_CLANACTION))
					{
						char log_buff[LOG_SIZE];
						FormatEx(log_buff, sizeof(log_buff), "%T", "L_CreateClan", LANG_SERVER, clanName);
						SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, playerID[clientID], true, clanid, LOG_CLANACTION);
					}

				}
				case 8:	//set slots
				{
					char str_slots[30], print_buff[BUFF_SIZE];
					int slots = 0;
					int type = 1;	//0 - take, 1 - set, 2 - give
					GetCmdArg(1, str_slots, sizeof(str_slots));
					TrimString(str_slots);
					if(!strcmp(str_slots, "отмена") || !strcmp(str_slots, "cancel"))
					{
						admin_SelectMode[client][0] = -1;
						admin_SelectMode[client][1] = -1;
						return Plugin_Handled;
					}
					if(str_slots[0] == '+')
						type = 2;
					else if(str_slots[0] == '-')
						type = 0;
					ReplaceString(str_slots, sizeof(str_slots), "+", "");
					ReplaceString(str_slots, sizeof(str_slots), "-", "");
					slots = StringToInt(str_slots);
					if(type == 0)
					{
						if(g_iClanData[admin_SelectMode[client][1]][CLAN_MAXMEMBERS]-slots < 1)
						{
							FormatEx(print_buff, sizeof(print_buff), "%T", "c_SlotsIncorrect", client);
							CPrintToChat(client, print_buff);
							admin_SelectMode[client][0] = -1;
							admin_SelectMode[client][1] = -1;
							return Plugin_Handled;
						}
						else
						{
							SetClanMaxMembers(admin_SelectMode[client][1], g_iClanData[admin_SelectMode[client][1]][CLAN_MAXMEMBERS]-slots);
							if(CheckForLog(LOG_SLOTS))
							{
								char log_buff[LOG_SIZE];
								FormatEx(log_buff, sizeof(log_buff), "%T", "L_TakeSlots", LANG_SERVER, slots, g_sClanData[admin_SelectMode[client][1]][CLAN_NAME]);
								SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, -1, true, admin_SelectMode[client][1], LOG_SLOTS);
							}
							for(int i = 1; i <= MaxClients; i++)
							{
								if(IsClientInGame(i) && GetClientClan(playerID[i]) == admin_SelectMode[client][1])
								{
									FormatEx(print_buff, sizeof(print_buff), "%T", "c_AdminTookSlots", i, adminName, slots);
									CPrintToChat(i, print_buff);
								}
							}
						}
					}
					else if(type == 1)
					{
						if(slots < 1)
						{
							FormatEx(print_buff, sizeof(print_buff), "%T", "c_SlotsIncorrect", client);
							CPrintToChat(client, print_buff);
							admin_SelectMode[client][0] = -1;
							admin_SelectMode[client][1] = -1;
							return Plugin_Handled;
						}
						else
						{
							SetClanMaxMembers(admin_SelectMode[client][1], slots);
							if(CheckForLog(LOG_SLOTS))
							{
								char log_buff[LOG_SIZE];
								FormatEx(log_buff, sizeof(log_buff), "%T", "L_SetSlots", LANG_SERVER, slots, g_sClanData[admin_SelectMode[client][1]][CLAN_NAME]);
								SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, -1, true, admin_SelectMode[client][1], LOG_SLOTS);
							}
							for(int i = 1; i <= MaxClients; i++)
							{
								if(IsClientInGame(i) && GetClientClan(playerID[i]) == admin_SelectMode[client][1])
								{
									FormatEx(print_buff, sizeof(print_buff), "%T", "c_AdminSetSlots", i, adminName, slots);
									CPrintToChat(i, print_buff);
								}
							}
						}
					}
					else
					{
						if(g_iClanData[admin_SelectMode[client][1]][CLAN_MAXMEMBERS]+slots < 1)
						{
							FormatEx(print_buff, sizeof(print_buff), "%T", "c_SlotsIncorrect", client);
							CPrintToChat(client, print_buff);
							admin_SelectMode[client][0] = -1;
							admin_SelectMode[client][1] = -1;
							return Plugin_Handled;
						}
						else
						{
							SetClanMaxMembers(admin_SelectMode[client][1], g_iClanData[admin_SelectMode[client][1]][CLAN_MAXMEMBERS]+slots);
							if(CheckForLog(LOG_SLOTS))
							{
								char log_buff[LOG_SIZE];
								FormatEx(log_buff, sizeof(log_buff), "%T", "L_GiveSlots", LANG_SERVER, slots, g_sClanData[admin_SelectMode[client][1]][CLAN_NAME]);
								SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, -1, true, admin_SelectMode[client][1], LOG_SLOTS);
							}
							for(int i = 1; i <= MaxClients; i++)
							{
								if(IsClientInGame(i) && GetClientClan(playerID[i]) == admin_SelectMode[client][1])
								{
									FormatEx(print_buff, sizeof(print_buff), "%T", "c_AdminGaveSlots", i, adminName, slots);
									CPrintToChat(i, print_buff);
								}
							}
						}
					}
					FormatEx(print_buff, sizeof(print_buff), "%T", "c_SlotsNow", client, g_sClanData[admin_SelectMode[client][1]][CLAN_NAME], g_iClanData[admin_SelectMode[client][1]][CLAN_MAXMEMBERS]);
					CPrintToChat(client, print_buff);
				}
			}
			admin_SelectMode[client][0] = -1;
			admin_SelectMode[client][1] = -1;
			return Plugin_Handled;
		}
		else if(renameClan[client])
		{
			char clanName[MAX_CLAN_NAME+1], buff[50];
			char print_buff[BUFF_SIZE];
			int clanid;
			if(admin_SelectMode[client][0] == 7)
			{
				clanid = admin_SelectMode[client][1];
				admin_SelectMode[client][0] = -1;
				admin_SelectMode[client][1] = -1;
			}
			else
				clanid = g_iClientData[ClanClient][CLIENT_CLANID];
			GetCmdArg(1, buff, sizeof(buff));
			TrimString(buff);
			if(!strcmp(buff, "отмена") || !strcmp(buff, "cancel"))
			{
				renameClan[client] = false;
				return Plugin_Handled;
			}
			if(strlen(buff) < 1 || strlen(buff) > MAX_CLAN_NAME)
			{
				FormatEx(print_buff, sizeof(print_buff), "%T", "c_WrongClanName", client, MAX_CLAN_NAME);
				CPrintToChat(client, print_buff);
				renameClan[client] = false;
				return Plugin_Handled;
			}
			else
			{
				for(int i = 0; i < MAX_CLAN_NAME; i++)
					clanName[i] = buff[i];
				clanName[MAX_CLAN_NAME] = '\0';
			}
			
			for(int i = 0; i < MAX_CLANS; i++)
			{
				if(!strcmp(clanName, g_sClanData[i][CLAN_NAME]))
				{
					renameClan[client] = false;
					FormatEx(print_buff, sizeof(print_buff), "%T", "c_ClanAlreadyExists", client);
					CPrintToChat(client, print_buff);
					return Plugin_Handled;
				}
			}
			char lastName[MAX_NAME_LENGTH+1];
			lastName = g_sClanData[clanid][CLAN_NAME];
			g_sClanData[clanid][CLAN_NAME] = clanName;
			SQL_UpdateClan(clanid);
			renameClan[client] = false;
			if(!g_bCSS34)
				UpdatePlayersClanTag();
			FormatEx(print_buff, sizeof(print_buff), "%T", "c_RenameClanSuccess", client);
			CPrintToChat(client, print_buff);
			if(CheckForLog(LOG_CLANACTION))
			{
				char log_buff[LOG_SIZE];
				FormatEx(log_buff, sizeof(log_buff), "%T", "L_RenameClan", LANG_SERVER, lastName, clanName);
				SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, -1, true, clanid, LOG_CLANACTION);
			}
			return Plugin_Handled;
		}
		else if(clan_SelectMode[client][0] == 3)	//Transfer coins
		{
			char str_coins[30], print_buff[BUFF_SIZE];
			int coins = 0;
			GetCmdArg(1, str_coins, sizeof(str_coins));
			TrimString(str_coins);
			if(!strcmp(str_coins, "отмена") || !strcmp(str_coins, "cancel"))
			{
				clan_SelectMode[client][0] = -1;
				clan_SelectMode[client][1] = -1;
				return Plugin_Handled;
			}
			coins = StringToInt(str_coins);
			if(coins <= 0 || g_iClanData[GetClientClan(ClanClient)][CLAN_COINS] < coins)
			{
				FormatEx(print_buff, sizeof(print_buff), "%T", "c_TranferFailed", client);
				CPrintToChat(client, print_buff);
				clan_SelectMode[client][0] = -1;
				clan_SelectMode[client][1] = -1;
				return Plugin_Handled;
			}
			else
			{
				SetClanCoins(GetClientClan(ClanClient), g_iClanData[GetClientClan(ClanClient)][CLAN_COINS]-coins);
				SetClanCoins(clan_SelectMode[client][1], g_iClanData[clan_SelectMode[client][1]][CLAN_COINS]+coins);
				if(CheckForLog(LOG_CLANACTION))
				{
					char log_buff[LOG_SIZE];
					FormatEx(log_buff, sizeof(log_buff), "%T", "L_TransferCoins", LANG_SERVER, coins, g_sClanData[clan_SelectMode[client][1]][CLAN_NAME]);
					SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, -1, true, clan_SelectMode[client][1], LOG_CLANACTION);
				}
				for(int i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && GetClientClan(playerID[i]) == clan_SelectMode[client][1])
					{
						FormatEx(print_buff, sizeof(print_buff), "%T", "c_TranferFrom", i, g_sClanData[GetClientClan(ClanClient)][CLAN_NAME], coins);
						CPrintToChat(i, print_buff);
					}
				}
			}
			FormatEx(print_buff, sizeof(print_buff), "%T", "c_TranferSuccess", client);
			CPrintToChat(client, print_buff);
			clan_SelectMode[client][0] = -1;
			clan_SelectMode[client][1] = -1;
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}
//=============================== Commands for clans for users ===============================//
public Action Command_CreateClan(int client, int args)
{
	char print_buff[BUFF_SIZE], buff[50];
	if(!createClan[client])
	{
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_YouCantCreateClan", client);
		CPrintToChat(client, print_buff);
		return Plugin_Handled;
	}
	if(GetClientClan(ClanClient) != -1)
	{
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_YouAreAlreadyInClan", client);
		CPrintToChat(client, print_buff);
		return Plugin_Handled;
	}
	int clanId = -1;
	bool nameIsValid = true;
	char clanName[MAX_CLAN_NAME+1], userName[MAX_NAME_LENGTH], auth[33], date[11];
	if(args != 1)
	{
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_Wrongcclan", client);
		CPrintToChat(client, print_buff);
		return Plugin_Handled;
	}
	GetCmdArg(1, buff, sizeof(buff));
	TrimString(buff);
	
	if(strlen(buff) < 1 || strlen(buff) > MAX_CLAN_NAME)
	{
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_WrongClanName", client, MAX_CLAN_NAME);
		CPrintToChat(client, print_buff);
		admin_SelectMode[client][0] = -1;
		admin_SelectMode[client][1] = -1;
		return Plugin_Handled;
	}
	else
	{
		for(int i = 0; i < MAX_CLAN_NAME; i++)
			clanName[i] = buff[i];
		clanName[MAX_CLAN_NAME] = '\0';
	}
	
	GetClientName(client, userName, sizeof(userName));
	GetClientAuthId(client, AuthId_Steam3, auth, sizeof(auth));
	FormatTime(date, 10, "%D");
	date[10] = '\0';
	
	for(int i = 0; i < MAX_CLANS; i++)
	{
		if(clanId == -1 && g_iClanData[i][CLAN_MEMBERS] < 1)
			clanId = i;
		if(!strcmp(g_sClanData[i][CLAN_NAME], clanName))
			nameIsValid = false;
	}
	if(clanId == -1)
	{
		
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_ClanLimit", client);
		CPrintToChat(client, print_buff);
		return Plugin_Handled;
	}
	if(nameIsValid)
	{
		g_sClanData[clanId][CLAN_NAME] = clanName;
		g_sClanData[clanId][CLAN_LEADERNAME] = userName;
		g_sClanData[clanId][CLAN_LEADERID] = auth;
		g_sClanData[clanId][CLAN_DATE] = date;
		
		g_iClanData[clanId][CLAN_MEMBERS] = 1;
		g_iClanData[clanId][CLAN_MAXMEMBERS] = g_iStartSlotsInClan;
		g_iClanData[clanId][CLAN_KILLS] = 0;
		g_iClanData[clanId][CLAN_DEATHS] = 0;
		g_iClanData[clanId][CLAN_TIME] = GetTime();
		g_iClanData[clanId][CLAN_COINS] = 0;
		
		for(int i = 0; i < MAX_PLAYERSINCLANES; i++)
			if(g_iClientData[i][CLIENT_CLANID] == -1)
			{
				ClanClient = i;
				i = MAX_PLAYERSINCLANES;
			}
		g_iClientData[ClanClient][CLIENT_CLANID] = clanId;		
		g_iClientData[ClanClient][CLIENT_ROLE] = CLIENT_LEADER;
		g_iClientData[ClanClient][CLIENT_KILLS] = 0;
		g_iClientData[ClanClient][CLIENT_DEATHS] = 0;
		g_iClientData[ClanClient][CLIENT_TIME] = GetTime();
		g_sClientData[ClanClient][CLIENT_NAME] = userName;
		g_sClientData[ClanClient][CLIENT_STEAMID] = auth;
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_CreationSuccess", client);
		CPrintToChat(client, print_buff);
		SQL_CreateClan(clanId);
		SQL_CreateClient(ClanClient);
		if(!g_bCSS34)
			UpdatePlayerClanTag(client);
		Call_StartForward(g_hClanAdded);	//Clans_OnClanAdded forward
		Call_PushCell(clanId);
		Call_PushCell(client);
		Call_Finish();
		Call_StartForward(g_hClientAdded);	//Clans_OnClientAdded forward
		Call_PushCell(client);
		Call_PushCell(ClanClient);
		Call_PushCell(clanId);
		Call_Finish();
		if(CheckForLog(LOG_CLANACTION))
		{
			char log_buff[LOG_SIZE];
			FormatEx(log_buff, sizeof(log_buff), "%T", "L_CreateClan", LANG_SERVER, clanName);
			SQL_LogAction(ClanClient, true, clanId, log_buff, -1, true, -1, LOG_CLANACTION);
		}
		return Plugin_Handled;
	}
	else
	{
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_ClanAlreadyExists", client);
		CPrintToChat(client, print_buff);
	}
	return Plugin_Handled;
}

public Action Command_DeleteClan(int client, int args)
{
	if(!IsClientClanLeader(ClanClient))
		return Plugin_Handled;
	int clanId = GetClientClan(ClanClient);
	if(CheckForLog(LOG_CLANACTION))
	{
		char log_buff[LOG_SIZE];
		FormatEx(log_buff, sizeof(log_buff), "%T", "L_DeleteClan", LANG_SERVER, g_sClanData[clanId][CLAN_NAME]);
		SQL_LogAction(ClanClient, true, clanId, log_buff, -1, true, clanId, LOG_CLANACTION);
	}
	DeleteClan(clanId);
	char print_buff[BUFF_SIZE];
	FormatEx(print_buff, sizeof(print_buff), "%T", "c_DisbandSuccess", client);
	CPrintToChat(client, print_buff);
	if(!g_bCSS34)
		UpdatePlayersClanTag();
	return Plugin_Handled;
}

public Action Command_LeaveClan(int client, int args)
{
	char print_buff[BUFF_SIZE];
	int clanid = GetClientClan(ClanClient);
	if(clanid == -1)
	{
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_YouAreNotInClan", client);
		CPrintToChat(client, print_buff);
		return Plugin_Handled;
	}
	if(CheckForLog(LOG_CLIENTACTION))
	{
		char log_buff[LOG_SIZE];
		FormatEx(log_buff, sizeof(log_buff), "%T", "L_LeaveClan", LANG_SERVER, g_sClanData[clanid][CLAN_NAME]);
		SQL_LogAction(ClanClient, true, clanid, log_buff, -1, true, clanid, LOG_CLIENTACTION);
	}
	DeleteClient(ClanClient);
	SQL_UpdateClan(clanid);
	FormatEx(print_buff, sizeof(print_buff), "%T", "c_LeftClan", client);
	CPrintToChat(client, print_buff);
	return Plugin_Handled;
}

public Action Command_MyClan(int client, int args)
{
	int clanId = GetClientClan(ClanClient);
	if(clanId != -1)
		ThrowClanMenuToClient(client);
	else
	{
		char print_buff[BUFF_SIZE];
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_YouAreNotInClan", client);
		CPrintToChat(client, print_buff);
	}
	return Plugin_Handled;
}

public Action Command_MyStats(int client, int args)
{
	int clanId = GetClientClan(ClanClient);
	if(clanId != -1)
		ThrowPlayerStatsToClient(client, ClanClient);
	else
	{
		char print_buff[BUFF_SIZE];
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_YouAreNotInClan", client);
		CPrintToChat(client, print_buff);
	}
	return Plugin_Handled;
}

public Action Command_AcceptClanInvitation(int client, int args)
{
	char buff[BUFF_SIZE];
	if(invitedBy[client][0] == -1 || GetTime()-invitedBy[client][1] > MAX_INVITATION_TIME)
	{
		FormatEx(buff, sizeof(buff), "%T", "c_NotInvited", client);
		CPrintToChat(client, buff);
		return Plugin_Handled;
	}
	SetOnlineClientClan(client, g_iClientData[invitedBy[client][0]][CLIENT_CLANID], 0);
	FormatEx(buff, sizeof(buff), "%T", "c_JoinSuccess", client);
	CPrintToChat(client, buff);
	if(CheckForLog(LOG_CLIENTACTION))
	{
		char log_buff[LOG_SIZE];
		FormatEx(log_buff, sizeof(log_buff), "%T", "L_CreatePlayer", LANG_SERVER, g_sClanData[GetClientClan(invitedBy[client][0])][CLAN_NAME]);
		SQL_LogAction(ClanClient, true, GetClientClan(ClanClient), log_buff, -1, true, g_iClientData[invitedBy[client][0]][CLIENT_CLANID], LOG_CLIENTACTION);
	}
	invitedBy[client][0] = -1;
	return Plugin_Handled;
}

public Action Command_Invite(int client, int args)
{
	if(!CanPlayerDo(ClanClient, PERM_INVITE))
	{
		char print_buff[BUFF_SIZE];
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_CantInvite", client);
		CPrintToChat(client, print_buff);
		return Plugin_Handled;
	}
	if(g_iClanData[g_iClientData[ClanClient][CLIENT_CLANID]][CLAN_MEMBERS] >= g_iClanData[g_iClientData[ClanClient][CLIENT_CLANID]][CLAN_MAXMEMBERS])
	{
		char print_buff[BUFF_SIZE];
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_MaxMembersInClan", client);
		CPrintToChat(client, print_buff);
		return Plugin_Handled;
	}
	ThrowInviteList(client);
	return Plugin_Handled;
}

public Action Command_TopClans(int client, int args)
{
	ThrowTopsMenuToClient(client);
	return Plugin_Handled;
}

public Action Command_ClanHelp(int client, int args)
{
	Handle helpPanel = CreatePanel();
	char helpText[500];
	FormatEx(helpText, sizeof(helpText), "%T", "m_ClanHelpCmds", client);
	SetPanelTitle(helpPanel, helpText);
	FormatEx(helpText, sizeof(helpText), "%T", "m_ClanHelp", client);
	DrawPanelText(helpPanel, helpText);
	FormatEx(helpText, sizeof(helpText), "%T", "m_Close", client);
	DrawPanelItem(helpPanel, helpText, 0);
	SendPanelToClient(helpPanel, client, Clan_HelpMenu, 0);
	return Plugin_Handled;
}

public Action Command_AdminClanHelp(int client, int args)
{
	Handle helpPanel = CreatePanel();
	char helpText[500];
	FormatEx(helpText, sizeof(helpText), "%T", "m_AdminClanHelp", client);
	SetPanelTitle(helpPanel, helpText);
	FormatEx(helpText, sizeof(helpText), "%T", "m_AdminClanHelpCmds", client);
	DrawPanelText(helpPanel, helpText);
	FormatEx(helpText, sizeof(helpText), "%T", "m_Close", client);
	DrawPanelItem(helpPanel, helpText, 0);
	SendPanelToClient(helpPanel, client, Clan_HelpMenu, 0);
	return Plugin_Handled;
}

public Action Command_ClanChat(int client, int args)
{
	char buff[BUFF_SIZE], userName[MAX_NAME_LENGTH+1], print_buff[350];
	if(ClanClient == -1)
	{
		FormatEx(buff, sizeof(buff), "%T", "c_YouAreNotInClan", client);
		CPrintToChat(client, buff);
		return Plugin_Handled;
	}
	int clanid = g_iClientData[ClanClient][CLIENT_CLANID];
	int role = GetClientRole(ClanClient);
	GetCmdArgString(buff, sizeof(buff));
	if(strlen(buff) < 1)
		return Plugin_Handled;
	GetClientName(client, userName, sizeof(userName));
	if(!g_bCSS34)
	{
		if(role == CLIENT_MEMBER)
			FormatEx(print_buff, sizeof(print_buff), "{%s}[%s] %s:{default} %s", g_cCCMember, g_sClanData[clanid][CLAN_NAME], userName, buff);
		else if(role == CLIENT_ELDER)
			FormatEx(print_buff, sizeof(print_buff), "{%s}[%s] %s:{default} %s", g_cCCElder, g_sClanData[clanid][CLAN_NAME], userName, buff);
		else if(role == CLIENT_COLEADER)
			FormatEx(print_buff, sizeof(print_buff), "{%s}[%s] %s:{lightgreen} %s", g_cCCColeader, g_sClanData[clanid][CLAN_NAME], userName, buff);
		else
			FormatEx(print_buff, sizeof(print_buff), "{%s}[%s] %s:{lightgreen} %s", g_cCCLeader, g_sClanData[clanid][CLAN_NAME], userName, buff);
	}
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && playerID[i] > -1 && g_iClientData[playerID[i]][CLIENT_CLANID] == clanid)
		{
			if(!g_bCSS34)
				CPrintToChat(i, print_buff);
			else
				CPrintToChat(i, "{green}[%s] %s: {lightgreen}%s", g_sClanData[clanid][CLAN_NAME], userName, buff);
			if(CheckForLog(LOG_CLANCHAT))
			{
				char log_buff[LOG_SIZE];
				FormatEx(log_buff, sizeof(log_buff), "%T", "L_ClanChat", LANG_SERVER, buff);
				SQL_LogAction(ClanClient, true, clanid, log_buff, -1, true, -1, LOG_CLANCHAT);
			}
		}
	}
	return Plugin_Handled;
}

Action Command_JoinClan(int client, int args)
{
	char print_buff[BUFF_SIZE];
	if(args != 1)
	{
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_Wrongjclan", client);
		CPrintToChat(client, print_buff);
		return Plugin_Handled;
	}
	if(ClanClient != -1)
	{
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_YouAreAlreadyInClan", client)
		CPrintToChat(client, print_buff);
		return Plugin_Handled;
	}
	int clanid, type;
	char buff[50];
	GetCmdArg(1, buff, sizeof(buff));
	TrimString(buff);
	clanid = StringToInt(buff);
	if(IsClanValid(clanid))
	{
		type = GetClanType(clanid);
		if(type == 0)
		{
			FormatEx(print_buff, sizeof(print_buff), "%T", "c_JoinClosedClan", client)
			CPrintToChat(client, print_buff);
			return Plugin_Handled;
		}
		if(GetClanMembers(clanid) >= GetClanMaxMembers(clanid))
		{
			FormatEx(print_buff, sizeof(print_buff), "%T", "c_MaxMembersInClan", client)
			CPrintToChat(client, print_buff);
			return Plugin_Handled;
		}
		SetOnlineClientClan(client, clanid, 0);
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_JoinSuccess", client)
		CPrintToChat(client, print_buff);
		if(CheckForLog(LOG_CLIENTACTION))
		{
			char log_buff[LOG_SIZE];
			FormatEx(log_buff, sizeof(log_buff), "%T", "L_CreatePlayer", LANG_SERVER, g_sClanData[clanid][CLAN_NAME]);
			SQL_LogAction(ClanClient, true, clanid, log_buff, -1, true, -1, LOG_CLIENTACTION);
		}
	}
	return Plugin_Handled;
}
//=============================== Admin commands for clans ===============================//
/**
 * Prints list of clans to console
 */
public Action Command_ClansDump(int client, int args)
{
	for(int i = 0; i < MAX_CLANS; i++)
		if(g_iClanData[i][CLAN_MEMBERS] > 0)
			PrintToConsole(client, "Clan ID: %d | Clan Name: %s | Clan Leader: %s | Clan Leader ID: %s | Members: %d/%d | Kills: %d | Deaths: %d | Date of creating: %s | Coins: %d", i, g_sClanData[i][CLAN_NAME], g_sClanData[i][CLAN_LEADERNAME], g_sClanData[i][CLAN_LEADERID], g_iClanData[i][CLAN_MEMBERS], g_iClanData[i][CLAN_MAXMEMBERS], g_iClanData[i][CLAN_KILLS], g_iClanData[i][CLAN_DEATHS], g_sClanData[i][CLAN_DATE], g_iClanData[i][CLAN_COINS]);
}

/**
 * Prints list of players to console
 */
public Action Command_PlayersDump(int client, int args)
{
	char time[60];
	int clanId;
	for(int i = 0; i < MAX_PLAYERSINCLANES; i++)
	{
		clanId = g_iClientData[i][CLIENT_CLANID];
		if(clanId != -1)
		{
			SecondsToTime(GetTime() - g_iClientData[i][CLIENT_TIME], time, sizeof(time), client);
			PrintToConsole(client, "Player %d: %s | Clan: %s (%d ID) %s| Kills: %d | Deaths: %d | Already in clan: %s", i, g_sClientData[i][CLIENT_NAME], g_sClanData[clanId][CLAN_NAME], clanId, IsClientClanLeader(i) == true ? "(Leader) " : "", g_iClientData[i][CLIENT_KILLS], g_iClientData[i][CLIENT_DEATHS], time);
		}
	}
}

/**
 * Add online player to clan by command
 * 
 * @param args 1 - player's userid in status
 * @param args 2 - clan id
 */
public Action Command_AddPlayerToClan(int client, int args)
{
	char print_buff[BUFF_SIZE];
	if(args != 3)
	{
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_WrongPToClan", client);
		CPrintToChat(client, print_buff);
		return Plugin_Handled;
	}
	char buff[10];
	int clientId, clanId, roleFlag;
	GetCmdArg(1, buff, sizeof(buff));
	clientId = GetClientOfUserId(StringToInt(buff));
	GetCmdArg(2, buff, sizeof(buff));
	clanId = StringToInt(buff);
	GetCmdArg(3, buff, sizeof(buff));
	roleFlag = StringToInt(buff);
	if(roleFlag < 0 || roleFlag > 4 || roleFlag == 3)
	{
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_WrongRoleFlag", client);
		CPrintToChat(client, print_buff);
		return Plugin_Handled;
	}
	if(g_iClanData[clanId][CLAN_MEMBERS] < 1)
	{
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_ClanDoesntExist", client);
		CPrintToChat(client, print_buff);
		return Plugin_Handled;
	}
	if(!clientId || !IsClientAuthorized(clientId))
	{
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_PlayerIsntAuth", client);
		CPrintToChat(client, print_buff);
		return Plugin_Handled;
	}
	if(GetClientClan(playerID[clientId]) == clanId)
	{
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_PlayerInThisClan", client);
		CPrintToChat(client, print_buff);
		return Plugin_Handled;
	}
	SetOnlineClientClan(clientId, clanId, roleFlag);
	FormatEx(print_buff, sizeof(print_buff), "%T", "c_PlayerAddedToClan", client, g_sClanData[clanId][CLAN_NAME]);
	CPrintToChat(client, print_buff);
	if(CheckForLog(LOG_CLIENTACTION))
	{
		char log_buff[LOG_SIZE], userName[MAX_NAME_LENGTH+1];
		GetClientName(clientId, userName, sizeof(userName));
		FormatEx(log_buff, sizeof(log_buff), "%T", "LA_CreatePlayer", LANG_SERVER, userName, g_sClanData[clanId][CLAN_NAME], roleFlag);
		SQL_LogAction(ClanClient, true, GetClientClan(ClanClient), log_buff, clientId, false, clanId, LOG_CLIENTACTION);
	}
	return Plugin_Handled;
}

/**
 * Remove player from a clan
 * 
 * @param args 1 - player's userid in status
 */
public Action Command_RemovePlayerFromClan(int client, int args)
{
	char print_buff[BUFF_SIZE];
	if(args != 1)
	{
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_WrongPOutOfClan", client);
		CPrintToChat(client, print_buff);
		return Plugin_Handled;
	}
	char buff[33];
	int clientID;
	GetCmdArg(1, buff, sizeof(buff));
	if(IsCharNumeric(buff[0]))
	{
		clientID = StringToInt(buff);
		if(clientID < 0 || clientID > MAX_PLAYERSINCLANES)
		{
			FormatEx(print_buff, sizeof(print_buff), "%T", "c_PlayerIDDoesntExist", client);
			CPrintToChat(client, print_buff);
			return Plugin_Handled;
		}
		if(g_iClientData[clientID][CLIENT_CLANID] == -1)
		{
			FormatEx(print_buff, sizeof(print_buff), "%T", "c_PlayerIDDoesntExist", client);
			CPrintToChat(client, print_buff);
			return Plugin_Handled;
		}
		if(CheckForLog(LOG_CLIENTACTION))
		{
			char log_buff[LOG_SIZE];
			FormatEx(log_buff, sizeof(log_buff), "%T", "LA_DeletePlayer", LANG_SERVER, g_sClientData[clientID][CLIENT_NAME], g_sClanData[GetClientClan(clientID)][CLAN_NAME]);
			SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, clientID, true, GetClientClan(clientID), LOG_CLIENTACTION);
		}
		if(DeleteClient(clientID))
		{
			FormatEx(print_buff, sizeof(print_buff), "%T", "c_PlayerDelete", client, buff);
			CPrintToChat(client, print_buff);
		}
	}
	else
	{
		clientID = GetClientIDinDBbySteam(buff);
		if(clientID != -1)
		{
			if(CheckForLog(LOG_CLIENTACTION))
			{
				char log_buff[LOG_SIZE];
				FormatEx(log_buff, sizeof(log_buff), "%T", "LA_DeletePlayer", LANG_SERVER, g_sClientData[clientID][CLIENT_NAME], g_sClanData[GetClientClan(clientID)][CLAN_NAME]);
				SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, clientID, true, GetClientClan(clientID), LOG_CLIENTACTION);
			}
			if(DeleteClient(clientID))
			{
				IntToString(clientID, buff, sizeof(buff));
				FormatEx(print_buff, sizeof(print_buff), "%T", "c_PlayerDelete", client, buff);
				CPrintToChat(client, print_buff);
			}
		}
		else
		{
			FormatEx(print_buff, sizeof(print_buff), "%T", "c_PlayerSteamDoesntExist", client);
			CPrintToChat(client, print_buff);
			return Plugin_Handled;
		}
	}
	return Plugin_Handled;
}

/**
 * Delete clan by it's id by admin command
 * 
 * @param args 1 - clan id
 */
public Action Command_AdminDeleteClan(int client, int args)
{
	char print_buff[BUFF_SIZE];
	if(args != 1)
	{
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_Wrongadclan", client);
		CPrintToChat(client, print_buff);
		return Plugin_Handled;
	}
	char buff[33];
	int clanId;
	GetCmdArg(1, buff, sizeof(buff));
	clanId = StringToInt(buff);
	if(!IsClanValid(clanId))
	{
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_ClanDoesntExist", client);
		CPrintToChat(client, print_buff);
		return Plugin_Handled;
	}
	if(CheckForLog(LOG_CLANACTION))
	{
		char log_buff[LOG_SIZE];
		FormatEx(log_buff, sizeof(log_buff), "%T", "L_DeleteClan", LANG_SERVER, g_sClanData[clanId][CLAN_NAME]);
		SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, -1, true, clanId, LOG_CLANACTION);
	}
	DeleteClan(clanId);
	FormatEx(print_buff, sizeof(print_buff), "%T", "c_ClanDelete", client, clanId);
	CPrintToChat(client, print_buff);
	return Plugin_Handled;
}

/**
 * Throws admin menu to client
 */
public Action Command_AdminClansMenu(int client, int args)
{
	ThrowAdminMenu(client);
	return Plugin_Handled;
}

/**
 * Set number of coins in clan
 */
public Action Command_AdminSetCoins(int client, int args)
{
	char print_buff[BUFF_SIZE];
	if(args != 2)
	{
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_Wrongasetcoins", client);
		CPrintToChat(client, print_buff);
		return Plugin_Handled;
	}
	char buff[33];
	int clanid, coins;
	int type = 1; //0 - take, 1 - set, 2 - give
	GetCmdArg(1, buff, sizeof(buff));
	clanid = StringToInt(buff);
	if(!IsClanValid(clanid))
	{
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_ClanDoesntExist", client);
		CPrintToChat(client, print_buff);
		return Plugin_Handled;
	}
	GetCmdArg(2, buff, sizeof(buff));
	if(buff[0] == '+')
		type = 2;
	else if(buff[0] == '-')
		type = 0;
	ReplaceString(buff, sizeof(buff), "+", "");
	ReplaceString(buff, sizeof(buff), "-", "");
	coins = StringToInt(buff);
	if(type == 0)
	{
		SetClanCoins(clanid, g_iClanData[clanid][CLAN_COINS]-coins);
		if(CheckForLog(LOG_COINS))
		{
			char log_buff[LOG_SIZE];
			FormatEx(log_buff, sizeof(log_buff), "%T", "L_TakeCoins", LANG_SERVER, coins, g_sClanData[clanid][CLAN_NAME]);
			SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, -1, true, clanid, LOG_COINS);
		}
	}
	else if(type == 1)
	{
		SetClanCoins(clanid, coins);
		if(CheckForLog(LOG_COINS))
		{
			char log_buff[LOG_SIZE];
			FormatEx(log_buff, sizeof(log_buff), "%T", "L_SetCoins", LANG_SERVER, coins, g_sClanData[clanid][CLAN_NAME]);
			SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, -1, true, clanid, LOG_COINS);
		}
	}
	else
	{
		SetClanCoins(clanid, g_iClanData[clanid][CLAN_COINS]+coins);
		if(CheckForLog(LOG_COINS))
		{
			char log_buff[LOG_SIZE];
			FormatEx(log_buff, sizeof(log_buff), "%T", "L_GiveCoins", LANG_SERVER, coins, g_sClanData[clanid][CLAN_NAME]);
			SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, -1, true, clanid, LOG_COINS);
		}
	}
	FormatEx(print_buff, sizeof(print_buff), "%T", "c_CoinsNow", client, g_sClanData[clanid][CLAN_NAME], g_iClanData[clanid][CLAN_COINS]);
	CPrintToChat(client, print_buff);
	return Plugin_Handled;
}

/**
 * Reset clan by its id
 */
public Action Command_AdminResetClan(int client, int args)
{
	char print_buff[BUFF_SIZE];
	if(args != 1)
	{
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_Wrongarclan", client);
		CPrintToChat(client, print_buff);
		return Plugin_Handled;
	}
	char buff[33];
	int clanid;
	GetCmdArg(1, buff, sizeof(buff));
	clanid = StringToInt(buff);
	if(!IsClanValid(clanid))
	{
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_ClanDoesntExist", client);
		CPrintToChat(client, print_buff);
		return Plugin_Handled;
	}
	if(ResetClan(clanid))
	{
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_ClanReset", client, g_sClanData[clanid][CLAN_NAME]);
		CPrintToChat(client, print_buff);
		if(CheckForLog(LOG_CLANACTION))
		{
			char log_buff[LOG_SIZE];
			FormatEx(log_buff, sizeof(log_buff), "%T", "L_ResetClan", LANG_SERVER, g_sClanData[clanid][CLAN_NAME]);
			SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, -1, true, clanid, LOG_CLANACTION);
		}
	}
	return Plugin_Handled;
}

/**
 * Reset client by id in database or by steam id
 */
public Action Command_AdminResetClient(int client, int args)
{
	char print_buff[BUFF_SIZE];
	if(args != 1)
	{
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_Wrongarclient", client);
		CPrintToChat(client, print_buff);
		return Plugin_Handled;
	}
	char buff[33];
	int clientID;
	GetCmdArg(1, buff, sizeof(buff));
	if(IsCharNumeric(buff[0]))
	{
		clientID = StringToInt(buff);
		if(ResetClient(clientID))
		{
			FormatEx(print_buff, sizeof(print_buff), "%T", "c_PlayerReset", client, g_sClientData[clientID][CLIENT_NAME]);
			CPrintToChat(client, print_buff);
			if(CheckForLog(LOG_CLANACTION))
			{
				char log_buff[LOG_SIZE];
				FormatEx(log_buff, sizeof(log_buff), "%T", "L_ResetPlayer", LANG_SERVER, g_sClientData[clientID][CLIENT_NAME]);
				SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, clientID, true, GetClientClan(clientID), LOG_CLANACTION);
			}
		}
	}
	else
	{
		clientID = GetClientIDinDBbySteam(buff);
		if(clientID != -1)
		{
			if(ResetClient(clientID))
			{
				if(CheckForLog(LOG_CLANACTION))
				{
					char log_buff[LOG_SIZE];
					FormatEx(log_buff, sizeof(log_buff), "%T", "L_ResetPlayer", LANG_SERVER, g_sClientData[clientID][CLIENT_NAME]);
					SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, clientID, true, GetClientClan(clientID), LOG_CLANACTION);
				}
				FormatEx(print_buff, sizeof(print_buff), "%T", "c_PlayerReset", client, g_sClientData[clientID][CLIENT_NAME]);
				CPrintToChat(client, print_buff);
			}
		}
		else
		{
			FormatEx(print_buff, sizeof(print_buff), "%T", "c_PlayerSteamDoesntExist", client);
			CPrintToChat(client, print_buff);
			return Plugin_Handled;
		}
	}
	return Plugin_Handled;
}
//=============================== MENUS ===============================//
/**
 * Calls when player selects any option in Invite Menu
 */
public int Clan_InvitePlayerSelectMenu(Handle inviteSelectMenu, MenuAction action, int client, int option)
{
	if (action == MenuAction_Select)
	{
		char print_buff[BUFF_SIZE], userid[15];
		userid[0] = '\0';
		GetMenuItem(inviteSelectMenu, option, userid, 15); 
		int target = GetClientOfUserId(StringToInt(userid)); 
		invitedBy[target][0] = ClanClient;
		invitedBy[target][1] = GetTime();
		MenuSource checkForMenus = GetClientMenu(target, INVALID_HANDLE);
		if(checkForMenus == MenuSource_None)	//target isn't viewing any menu
		{
			Handle inviteMenu = CreateMenu(Clans_InviteAcceptMenu);
			FormatEx(print_buff, sizeof(print_buff), "%T", "m_InvitedToClan", target, g_sClanData[GetClientClan(ClanClient)][CLAN_NAME]);
			SetMenuTitle(inviteMenu, print_buff);
			FormatEx(print_buff, sizeof(print_buff), "%T", "m_Yes", target);
			AddMenuItem(inviteMenu, "Yes", print_buff);
			FormatEx(print_buff, sizeof(print_buff), "%T", "m_No", target);
			AddMenuItem(inviteMenu, "No", print_buff);
			SetMenuExitButton(inviteMenu, true);
			DisplayMenu(inviteMenu, target, 0);
		}
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_YouAreInvited", client, g_sClanData[GetClientClan(GetClientIDinDB(client))][CLAN_NAME]);
		CPrintToChat(target, print_buff);
	}
	else if (action == MenuAction_End && action == MenuAction_Cancel)
	{
		CloseHandle(inviteSelectMenu);
	}
}

/**
 * Calls when player select any option in Clan Menu
 */
public int Clan_PlayerClanSelectMenu(Handle playerClanMenu, MenuAction action, int client, int option)
{
	if (action == MenuAction_Select)
	{
		char selectedItem[50], print_buff[BUFF_SIZE];
		int buff;
		GetMenuItem(playerClanMenu, option, selectedItem, sizeof(selectedItem), buff, "", 0);
		if(!strcmp(selectedItem, "ClanControl"))
		{
			ThrowClanControlMenu(client);
		}
		else if(!strcmp(selectedItem, "ClanStats"))
		{
			ThrowClanStatsToClient(client, GetClientClan(ClanClient));
		}
		else if(!strcmp(selectedItem, "PlayerStats"))
		{
			ThrowPlayerStatsToClient(client, ClanClient);
		}
		else if(!strcmp(selectedItem, "Members"))
		{
			clan_SelectMode[client][0] = 0;
			if(!ThrowClanMembersToClient(client, GetClientClan(ClanClient), 1))
				ThrowClanMenuToClient(client);
		}
		else if(!strcmp(selectedItem, "TopClans"))
		{
			ThrowTopsMenuToClient(client);
		}
		else if(!strcmp(selectedItem, "LeaveClan"))
		{
			Handle leaveClanMenu = CreateMenu(Clan_LeaveClanSelectMenu);
			FormatEx(print_buff, sizeof(print_buff), "%T", "m_SureLeaving", client);
			SetMenuTitle(leaveClanMenu, print_buff);
			FormatEx(print_buff, sizeof(print_buff), "%T", "m_Yes", client);
			AddMenuItem(leaveClanMenu, "Yes", print_buff);
			SetMenuExitButton(leaveClanMenu, true);
			DisplayMenu(leaveClanMenu, client, 0);
		}
		else
		{
			Call_StartForward(g_hCMSelected);	//Clans_OnClanMenuSelected	forward
			Call_PushCell(playerClanMenu);
			Call_PushCell(client);
			Call_PushCell(option);
			Call_Finish();
		}
	}
	else if (action == MenuAction_End && action == MenuAction_Cancel)
		CloseHandle(playerClanMenu);
}

/**
 * Calls when player closes his/her stats
 */
public int Clan_PlayerStatsMenu(Handle playerStatsMenu, MenuAction action, int client, int option)
{
	CloseHandle(playerStatsMenu);
	if(ClanClient == -1)
		ThrowTopsMenuToClient(client);
	else
		ThrowClanMenuToClient(client);
}

/**
 * Calls when player select a menu item in clan stats
 */
public int Clan_ClanStatsMenu(Handle clanStatsMenu, MenuAction action, int client, int option)
{
	if(action == MenuAction_Select)
	{
		int clanid = clan_SelectMode[client][1];
		char print_buff[BUFF_SIZE];
		if(option == 1)
		{
			clan_SelectMode[client][0] = 0;
			if(!ThrowClanMembersToClient(client, clanid, 1))
			{
				if(ClanClient == -1)
					ThrowTopsMenuToClient(client);
				else
					ThrowClanMenuToClient(client);
			}
		}
		else if(option == 2)	//Join or Close
		{
			if(GetClanType(clanid) == 1 && ClanClient == -1)
			{
				if(GetClanMembers(clanid) >= GetClanMaxMembers(clanid))
				{
					FormatEx(print_buff, sizeof(print_buff), "%T", "c_MaxMembersInClan", client)
					CPrintToChat(client, print_buff);
					clan_SelectMode[client][0] = -1;
					clan_SelectMode[client][1] = -1;
					ThrowClanStatsToClient(client, clanid);
				}
				else
				{
					SetOnlineClientClan(client, clanid, 0);
					FormatEx(print_buff, sizeof(print_buff), "%T", "c_JoinSuccess", client)
					CPrintToChat(client, print_buff);
					if(CheckForLog(LOG_CLIENTACTION))
					{
						char log_buff[LOG_SIZE];
						FormatEx(log_buff, sizeof(log_buff), "%T", "L_CreatePlayer", LANG_SERVER, g_sClanData[clanid][CLAN_NAME]);
						SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, -1, true, clanid, LOG_CLIENTACTION);
					}
					clan_SelectMode[client][0] = -1;
					clan_SelectMode[client][1] = -1;
					ThrowClanStatsToClient(client, clanid);
				}
			}
			else
			{
				if(clan_SelectMode[client][0] == -2 || ClanClient == -1)	//Came from top menu or isn't in any clan
					ThrowTopsMenuToClient(client);
				else
					ThrowClanMenuToClient(client);
				clan_SelectMode[client][0] = -1;
				clan_SelectMode[client][1] = -1;
			}
		}
		else	//Close
		{
			clan_SelectMode[client][0] = -1;
			clan_SelectMode[client][1] = -1;
			ThrowTopsMenuToClient(client);
		}
	}
	else
	{
		CloseHandle(clanStatsMenu);
		ThrowClanMenuToClient(client);
	}
}

/**
 * Player's dicision to leave the clan or not
 */
public int Clan_LeaveClanSelectMenu(Handle leaveClanMenu, MenuAction action, int client, int option)
{
	if(action == MenuAction_Select)
	{
		if(CheckForLog(LOG_CLIENTACTION))
		{
			char log_buff[LOG_SIZE];
			FormatEx(log_buff, sizeof(log_buff), "%T", "L_LeaveClan", LANG_SERVER, g_sClanData[GetClientClan(ClanClient)][CLAN_NAME]);
			SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, -1, true, GetClientClan(ClanClient), LOG_CLIENTACTION);
		}
		DeleteClient(ClanClient);
		char print_buff[BUFF_SIZE];
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_LeavingSuccess", client);
		CPrintToChat(client, print_buff);
	}
	else if (action == MenuAction_End)
		CloseHandle(leaveClanMenu);
}

/**
 * Action in members menu, which shows clan members' stats
 */
public int Clan_ClanMembersSelectMenu(Handle clanMembersMenu, MenuAction action, int client, int option)
{
	if(action == MenuAction_Select)
	{
		char auth[33], print_buff[BUFF_SIZE];
		int buff;
		if(admin_SelectMode[client][0] == 6)	//change leader
		{
			char userName[MAX_NAME_LENGTH+20];
			GetMenuItem(clanMembersMenu, option, auth, sizeof(auth), buff, userName, sizeof(userName));
			ReplaceString(userName, sizeof(userName), " (leader)", "");
			admin_SelectMode[client][1] = GetClientIDinDBbySteam(auth);
			Handle kickMenu = CreateMenu(Clan_LeaderSelectMenu);
			FormatEx(print_buff, sizeof(print_buff), "%T", "m_ChooseNewLeader", client);
			SetMenuTitle(kickMenu, print_buff);
			AddMenuItem(kickMenu, "Yes", userName);
			SetMenuExitButton(kickMenu, true);
			DisplayMenu(kickMenu, client, 0);
		}
		
		else if(clan_SelectMode[client][0] == 0)	//See stats
		{
			GetMenuItem(clanMembersMenu, option, auth, sizeof(auth), buff, "", 0);
			ThrowPlayerStatsToClient(client, GetClientIDinDBbySteam(auth));
		}
			
		else if(clan_SelectMode[client][0] == 1)	//Kick 
		{
			char userName[MAX_NAME_LENGTH+20];
			GetMenuItem(clanMembersMenu, option, auth, sizeof(auth), buff, userName, sizeof(userName));
			ReplaceString(userName, sizeof(userName), " (leader)", "");
			clan_SelectMode[client][1] = GetClientIDinDBbySteam(auth);
			Handle kickMenu = CreateMenu(Clan_KickSelectMenu);
			FormatEx(print_buff, sizeof(print_buff), "%T", "m_KickPlayerByNick", client);
			SetMenuTitle(kickMenu, print_buff);
			AddMenuItem(kickMenu, "Yes", userName);
			SetMenuExitButton(kickMenu, true);
			DisplayMenu(kickMenu, client, 0);
		}
		
		else if(clan_SelectMode[client][0] == 2)	//select new leader
		{
			char userName[MAX_NAME_LENGTH+20];
			GetMenuItem(clanMembersMenu, option, auth, sizeof(auth), buff, userName, sizeof(userName));
			ReplaceString(userName, sizeof(userName), " (leader)", "");
			clan_SelectMode[client][1] = GetClientIDinDBbySteam(auth);
			Handle kickMenu = CreateMenu(Clan_LeaderSelectMenu);
			FormatEx(print_buff, sizeof(print_buff), "%T", "m_ChooseNewLeader", client);
			SetMenuTitle(kickMenu, print_buff);
			AddMenuItem(kickMenu, "Yes", userName);
			SetMenuExitButton(kickMenu, true);
			DisplayMenu(kickMenu, client, 0);
		}

		else if(clan_SelectMode[client][0] == 4 || admin_SelectMode[client][0] == 10)	//change role
		{
			char userName[MAX_NAME_LENGTH+20];
			GetMenuItem(clanMembersMenu, option, auth, sizeof(auth), buff, userName, sizeof(userName));
			ReplaceString(userName, sizeof(userName), " (leader)", "");
			clan_SelectMode[client][1] = GetClientIDinDBbySteam(auth);
			ThrowChangeRoleMenu(client, clan_SelectMode[client][1]);
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(clanMembersMenu);
	}
	else if(option == MenuCancel_ExitBack && action == MenuAction_Cancel)
	{
		if(admin_SelectMode[client][0] == 10)
			ThrowClansToClient(client, true);
		else if(clan_SelectMode[client][0] == 4)
			ThrowClanControlMenu(client);
		else if(clan_SelectMode[client][1] != -1 && clan_SelectMode[client][0] != -1)
			ThrowClanStatsToClient(client, clan_SelectMode[client][1]);
		else
			ThrowClanMenuToClient(client);
	}
}

/**
 * Actions in clan control menu
 */
public int Clan_ClanControlSelectMenu(Handle clanControlMenu, MenuAction action, int client, int option)
{
	if(action == MenuAction_Select)
	{
		char selectedItem[50], print_buff[BUFF_SIZE];
		int buff;
		GetMenuItem(clanControlMenu, option, selectedItem, sizeof(selectedItem), buff, "", 0);
		if(!strcmp(selectedItem, "Expand"))
		{
			Handle expandClanPanel = CreatePanel();
			char info[150];
			FormatEx(print_buff, sizeof(print_buff), "%T", "m_BuySlots", client, g_iExpandValue, g_iExpandingCost, g_iClanData[g_iClientData[ClanClient][CLIENT_CLANID]][CLAN_COINS]);
			Format(info, sizeof(info), print_buff);
			FormatEx(print_buff, sizeof(print_buff), "%T", "m_BuySlotsSure", client);
			SetPanelTitle(expandClanPanel, print_buff);
			DrawPanelText(expandClanPanel, info);
			FormatEx(print_buff, sizeof(print_buff), "%T", "m_Yes", client);
			DrawPanelItem(expandClanPanel, print_buff, 0);
			FormatEx(print_buff, sizeof(print_buff), "%T", "m_No", client);
			DrawPanelItem(expandClanPanel, print_buff, 0);
			SendPanelToClient(expandClanPanel, client, Clan_ExpandClanSelectPanel, 0);
		}
		else if(!strcmp(selectedItem, "TransferCoins"))
		{
			clan_SelectMode[client][0] = 3;
			if(!ThrowClansToClient(client, false))
				ThrowClanControlMenu(client);
		}
		else if(!strcmp(selectedItem, "Invite"))
		{
			if(g_iClanData[GetClientClan(ClanClient)][CLAN_MEMBERS] < g_iClanData[GetClientClan(ClanClient)][CLAN_MAXMEMBERS])
			{
				if(!ThrowInviteList(client))
					ThrowClanControlMenu(client);
			}
			else
			{
				FormatEx(print_buff, sizeof(print_buff), "%T", "c_MaxMembersInClan", client);
				CPrintToChat(client, print_buff);
				ThrowClanControlMenu(client);
			}
		}
		else if(!strcmp(selectedItem, "Kick"))
		{
			clan_SelectMode[client][0] = 1;
			if(!ThrowClanMembersToClient(client, GetClientClan(ClanClient), 2))
				ThrowClanControlMenu(client);
		}
		else if(!strcmp(selectedItem, "SelectLeader"))
		{
			clan_SelectMode[client][0] = 2;
			if(!ThrowClanMembersToClient(client, GetClientClan(ClanClient), 0))
				ThrowClanControlMenu(client);
		}
		else if(!strcmp(selectedItem, "DeleteClan"))
		{
			Handle deleteClanMenu = CreateMenu(Clan_DeleteClanSelectMenu);
			FormatEx(print_buff, sizeof(print_buff), "%T", "m_DisbandSure", client);
			SetMenuTitle(deleteClanMenu, print_buff);
			FormatEx(print_buff, sizeof(print_buff), "%T", "m_Yes", client);
			AddMenuItem(deleteClanMenu, "Yes", print_buff);
			SetMenuExitButton(deleteClanMenu, true);
			DisplayMenu(deleteClanMenu, client, 0);
		}
		else if(!strcmp(selectedItem, "RenameClan"))
		{
			renameClan[client] = true;
			FormatEx(print_buff, sizeof(print_buff), "%T", "c_RenameClan", client);
			CPrintToChat(client, print_buff);
		}
		else if(!strcmp(selectedItem, "SetType"))
		{
			ThrowSetTypeMenu(client);
		}
		else if(!strcmp(selectedItem, "ChangeRole"))
		{
			clan_SelectMode[client][0] = 4;
			if(!ThrowClanMembersToClient(client, GetClientClan(ClanClient), 2))
				ThrowClanControlMenu(client);
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(clanControlMenu);
	}
	else if(option == MenuCancel_ExitBack && action == MenuAction_Cancel)
	{
		ThrowClanMenuToClient(client);
	}
}

/**
 * Calls when leader accept expansion the clan
 */
public int Clan_ExpandClanSelectPanel(Handle expandClanPanel, MenuAction action, int client, int option)
{
	if(action == MenuAction_Select)
	{
		if(option == 1)
		{
			char print_buff[BUFF_SIZE];
			if(g_iClanData[g_iClientData[ClanClient][CLIENT_CLANID]][CLAN_COINS] < g_iExpandingCost)
			{
				FormatEx(print_buff, sizeof(print_buff), "%T", "c_NotEnoughCoins", client);
				CPrintToChat(client, print_buff);
			}
			else if(g_iClanData[g_iClientData[ClanClient][CLIENT_CLANID]][CLAN_MAXMEMBERS]+g_iExpandValue > g_iMaxClanMembers)
			{
				FormatEx(print_buff, sizeof(print_buff), "%T", "c_ClanLimit", client);
				CPrintToChat(client, print_buff);
			}
			else
			{
				g_iClanData[g_iClientData[ClanClient][CLIENT_CLANID]][CLAN_COINS] -= g_iExpandingCost;
				g_iClanData[g_iClientData[ClanClient][CLIENT_CLANID]][CLAN_MAXMEMBERS] += g_iExpandValue;
				FormatEx(print_buff, sizeof(print_buff), "%T", "c_ExpandSuccess", client);
				CPrintToChat(client, print_buff);
				if(CheckForLog(LOG_SLOTS))
				{
					char log_buff[LOG_SIZE];
					FormatEx(log_buff, sizeof(log_buff), "%T", "L_ExpandClan", LANG_SERVER, g_iExpandValue);
					SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, -1, true, GetClientClan(ClanClient), LOG_SLOTS);
				}
				ThrowClanControlMenu(client);
			}
		}
	}
	else if (action == MenuAction_End)
		CloseHandle(expandClanPanel);
}

/**
 * Calls when leader select to delete clan or not
 */
public int Clan_DeleteClanSelectMenu(Handle deleteClanMenu, MenuAction action, int client, int option)
{
	if(action == MenuAction_Select)
	{
		if(CheckForLog(LOG_CLANACTION))
		{
			char log_buff[LOG_SIZE];
			FormatEx(log_buff, sizeof(log_buff), "%T", "L_DeleteClan", LANG_SERVER, g_sClanData[GetClientClan(ClanClient)][CLAN_NAME]);
			SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, -1, true, GetClientClan(ClanClient), LOG_CLANACTION);
		}
		DeleteClan(GetClientClan(ClanClient));
		char print_buff[BUFF_SIZE];
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_DisbandSuccess", client);
		CPrintToChat(client, print_buff);
	}
	else if (action == MenuAction_End && action == MenuAction_Cancel)
		CloseHandle(deleteClanMenu);
}

/**
 * Calls when leader select to kick a player
 */
public int Clan_KickSelectMenu(Handle kickMenu, MenuAction action, int client, int option)
{
	if(action == MenuAction_Select)
	{
		char print_buff[BUFF_SIZE];
		char userName[MAX_NAME_LENGTH+1];
		GetClientName(client, userName, sizeof(userName));
		if(clan_SelectMode[client][1] != -1)
		{
			FormatEx(print_buff, sizeof(print_buff), "%T", "c_PlayerDelete", client, g_sClientData[clan_SelectMode[client][1]][CLIENT_NAME]);
			CPrintToChat(client, print_buff);
			if(CheckForLog(LOG_CLIENTACTION))
			{
				char log_buff[LOG_SIZE];
				FormatEx(log_buff, sizeof(log_buff), "%T", "L_DeletePlayer", LANG_SERVER, g_sClientData[clan_SelectMode[client][1]][CLIENT_NAME], g_sClanData[GetClientClan(ClanClient)][CLAN_NAME]);
				SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, clan_SelectMode[client][1], true, GetClientClan(clan_SelectMode[client][1]), LOG_CLIENTACTION);
			}
			for(int i = 1; i <= MaxClients; i++)
			{
				if(i != client && IsClientInGame(i) && playerID[i] == clan_SelectMode[client][1])
				{
					FormatEx(print_buff, sizeof(print_buff), "%T", "c_KickYou", i, userName);
					CPrintToChat(i, print_buff);
					i = MaxClients+1;
				}
			}
			DeleteClient(clan_SelectMode[client][1]);
			clan_SelectMode[client][0] = -1;
			clan_SelectMode[client][1] = -1;
		}
		else
		{
			FormatEx(print_buff, sizeof(print_buff), "%T", "c_PlayerIsNotInClan", client);
			CPrintToChat(client, print_buff);
			clan_SelectMode[client][0] = -1;
			clan_SelectMode[client][1] = -1;
		}
	}
	else if (action == MenuAction_End)
		CloseHandle(kickMenu);
}

/**
 * Calls when leader select a new clan leader
 */
public int Clan_LeaderSelectMenu(Handle kickMenu, MenuAction action, int client, int option)
{
	if(action == MenuAction_Select)
	{
		char print_buff[BUFF_SIZE], userName[MAX_NAME_LENGTH+1];
		int clanid;
		GetClientName(client, userName, sizeof(userName));
		if(clan_SelectMode[client][1] != -1 || admin_SelectMode[client][0] == 6)
		{
			if(admin_SelectMode[client][0] == 6)
			{
				clanid = GetClientClan(admin_SelectMode[client][1]);
				if(CheckForLog(LOG_CHANGEROLE))
				{
					char log_buff[LOG_SIZE];
					FormatEx(log_buff, sizeof(log_buff), "%T", "L_SetLeader", LANG_SERVER, g_sClientData[admin_SelectMode[client][1]][CLIENT_NAME], g_sClanData[GetClientClan(admin_SelectMode[client][1])][CLAN_NAME]);
					SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, admin_SelectMode[client][1], true, GetClientClan(admin_SelectMode[client][1]), LOG_CHANGEROLE);
				}
				if(SetClanLeader(admin_SelectMode[client][1], clanid))
				{
					FormatEx(print_buff, sizeof(print_buff), "%T", "c_LeaderSuccess", client);
					CPrintToChat(client, print_buff);
				}
				for(int i = 1; i <= MaxClients; i++)
				{
					if(i != client && IsClientInGame(i) && GetClientClan(playerID[i]) == clanid)
					{
						FormatEx(print_buff, sizeof(print_buff), "%T", "c_AdminChangedLeader", i, userName, g_sClientData[admin_SelectMode[client][1]][CLIENT_NAME]);
						CPrintToChat(i, print_buff);
					}
				}
				admin_SelectMode[client][0] = -1;
				admin_SelectMode[client][1] = -1;
			}
			else
			{
				if(CheckForLog(LOG_CHANGEROLE))
				{
					char log_buff[LOG_SIZE];
					FormatEx(log_buff, sizeof(log_buff), "%T", "L_SetLeader", LANG_SERVER, g_sClientData[clan_SelectMode[client][1]][CLIENT_NAME], g_sClanData[GetClientClan(clan_SelectMode[client][1])][CLAN_NAME]);
					SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, clan_SelectMode[client][1], true, GetClientClan(clan_SelectMode[client][1]), LOG_CHANGEROLE);
				}
				if(SetClanLeader(clan_SelectMode[client][1], GetClientClan(ClanClient)))
				{
					FormatEx(print_buff, sizeof(print_buff), "%T", "c_LeaderSuccess", client);
					CPrintToChat(client, print_buff);
				}
				for(int i = 1; i <= MaxClients; i++)
				{
					if(i != client && IsClientInGame(i) && GetClientClan(playerID[i]) == clanid)
					{
						FormatEx(print_buff, sizeof(print_buff), "%T", "c_ChangedLeader", i, userName, g_sClientData[clan_SelectMode[client][1]][CLIENT_NAME]);
						CPrintToChat(i, print_buff);
					}
				}
				clan_SelectMode[client][0] = -1;
				clan_SelectMode[client][1] = -1;
			}
		}
		else
		{
			FormatEx(print_buff, sizeof(print_buff), "%T", "c_PlayerIsNotInClan", client);
			CPrintToChat(client, print_buff);
		}
	}
	else if (action == MenuAction_End)
		CloseHandle(kickMenu);
}

/**
 * Player select type of top of clans
 */
public int Clan_TopsSelectMenu(Handle topsMenu, MenuAction action, int client, int option)
{
	if(action == MenuAction_Select)
	{
		Handle topMenu = CreateMenu(Clan_TopClansSelectMenu);
		int clanId, clanInfo_type, topInfo_type;
		char print_buff[BUFF_SIZE], displayInfo[30], str_clanId[10];
		bool show = false;
		displayInfo[0] = '\0'; str_clanId[0] = '\0';
		if(option < 2)
		{
			clanInfo_type = CLAN_KILLS;
			topInfo_type = TOP_KILLS;
			if(option == 0)
			{
				FormatEx(print_buff, sizeof(print_buff), "%T", "t_KillsDesc", client);
				SetMenuTitle(topMenu, print_buff);
			}
			else
			{
				FormatEx(print_buff, sizeof(print_buff), "%T", "t_KillsAsc", client);
				SetMenuTitle(topMenu, print_buff);
			}
		}
		else if(option < 4)
		{
			clanInfo_type = CLAN_DEATHS;
			topInfo_type = TOP_DEATHS;
			if(option == 2)
			{
				FormatEx(print_buff, sizeof(print_buff), "%T", "t_DeathsDesc", client);
				SetMenuTitle(topMenu, print_buff);
			}
			else
			{
				FormatEx(print_buff, sizeof(print_buff), "%T", "t_DeathsAsc", client);
				SetMenuTitle(topMenu, print_buff);
			}
		}
		else if(option < 6)
		{
			clanInfo_type = CLAN_TIME;
			topInfo_type = TOP_EXISTTIME;
			if(option == 4)
			{
				FormatEx(print_buff, sizeof(print_buff), "%T", "t_TimeDesc", client);
				SetMenuTitle(topMenu, print_buff);
			}
			else
			{
				FormatEx(print_buff, sizeof(print_buff), "%T", "t_TimeAsc", client);
				SetMenuTitle(topMenu, print_buff);
			}
		}
		else if(option < 8)
		{
			clanInfo_type = CLAN_MEMBERS;
			topInfo_type = TOP_MEMBERS;
			if(option == 6)
			{
				FormatEx(print_buff, sizeof(print_buff), "%T", "t_MembersDesc", client);
				SetMenuTitle(topMenu, print_buff);
			}
			else
			{
				FormatEx(print_buff, sizeof(print_buff), "%T", "t_MembersAsc", client);
				SetMenuTitle(topMenu, print_buff);
			}
		}
		else
		{
			clanInfo_type = CLAN_COINS;
			topInfo_type = TOP_COINS;
			if(option == 8)
			{
				FormatEx(print_buff, sizeof(print_buff), "%T", "t_CoinsDesc", client);
				SetMenuTitle(topMenu, print_buff);
			}
			else
			{
				FormatEx(print_buff, sizeof(print_buff), "%T", "t_CoinsAsc", client);
				SetMenuTitle(topMenu, print_buff);
			}
		}
		if(option % 2 == 0)
		{
			if(option == 4)
			{
				for(clanId = MAX_CLANS-1; clanId >= 0; clanId--)
				{
					if(TopClans[topInfo_type][clanId] != -1 && g_iClanData[TopClans[topInfo_type][clanId]][CLAN_MEMBERS] > 0)
					{
						char time[60];
						SecondsToTime(GetTime()-g_iClanData[TopClans[topInfo_type][clanId]][CLAN_TIME], time, sizeof(time), client);
						IntToString(TopClans[topInfo_type][clanId], str_clanId, sizeof(str_clanId));
						Format(displayInfo, sizeof(displayInfo), "%s (%s)", g_sClanData[TopClans[topInfo_type][clanId]][CLAN_NAME], time);
						AddMenuItem(topMenu, str_clanId, displayInfo);
						show = true;
					}
				}
			}
			else
			{
				for(clanId = 0; clanId < MAX_CLANS; clanId++)
				{
					if(TopClans[topInfo_type][clanId] != -1 && g_iClanData[TopClans[topInfo_type][clanId]][CLAN_MEMBERS] > 0)
					{
						IntToString(TopClans[topInfo_type][clanId], str_clanId, sizeof(str_clanId));
						Format(displayInfo, sizeof(displayInfo), "%s (%d)", g_sClanData[TopClans[topInfo_type][clanId]][CLAN_NAME], g_iClanData[TopClans[topInfo_type][clanId]][clanInfo_type]);
						AddMenuItem(topMenu, str_clanId, displayInfo);
						show = true;
					}
				}
			}
		}
		else
		{
			if(option == 5)
			{
				for(clanId = 0; clanId < MAX_CLANS; clanId++)
				{
					if(TopClans[topInfo_type][clanId] != -1 && g_iClanData[TopClans[topInfo_type][clanId]][CLAN_MEMBERS] != 0)
					{
						char time[60];
						SecondsToTime(GetTime()-g_iClanData[TopClans[topInfo_type][clanId]][CLAN_TIME], time, sizeof(time), client);
						IntToString(TopClans[topInfo_type][clanId], str_clanId, sizeof(str_clanId));
						Format(displayInfo, sizeof(displayInfo), "%s (%s)", g_sClanData[TopClans[topInfo_type][clanId]][CLAN_NAME], time);
						AddMenuItem(topMenu, str_clanId, displayInfo);
						show = true;
					}
				}
			}
			else
			{
				for(clanId = MAX_CLANS-1; clanId >= 0; clanId--)
				{
					if(TopClans[topInfo_type][clanId] != -1 && g_iClanData[TopClans[topInfo_type][clanId]][CLAN_MEMBERS] != 0)
					{
						IntToString(TopClans[topInfo_type][clanId], str_clanId, sizeof(str_clanId));
						Format(displayInfo, sizeof(displayInfo), "%s (%d)", g_sClanData[TopClans[topInfo_type][clanId]][CLAN_NAME], g_iClanData[TopClans[topInfo_type][clanId]][clanInfo_type]);
						AddMenuItem(topMenu, str_clanId, displayInfo);
						show = true;
					}
				}
			}
		}
		if(show)
		{
			SetMenuExitBackButton(topMenu, true);
			DisplayMenu(topMenu, client, 0);
		}
		else
		{
			FormatEx(print_buff, sizeof(print_buff), "%T", "NoClans", client);
			CPrintToChat(client, print_buff);
			delete topMenu;
			ThrowTopsMenuToClient(client);
		}
		
	}
	else if (action == MenuAction_End)
		CloseHandle(topsMenu);
}

/**
 * Player select clan in top
 */
public int Clan_TopClansSelectMenu(Handle topMenu, MenuAction action, int client, int option)
{
	if(action == MenuAction_Select)
	{
		char str_clanid[10], displayInfo[10];
		int style, clanid;
		GetMenuItem(topMenu, option, str_clanid, sizeof(str_clanid), style, displayInfo, sizeof(displayInfo));
		clanid = StringToInt(str_clanid);
		clan_SelectMode[client][0] = -2;
		ThrowClanStatsToClient(client, clanid);
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(topMenu);
	}
	else if(option == MenuCancel_ExitBack && action == MenuAction_Cancel)
	{
		ThrowTopsMenuToClient(client);
	}
}

/**
 * Admin select action in admin menu
 */
public int Clan_AdminClansSelectMenu(Handle adminClansMenu, MenuAction action, int client, int option)
{
	if(action == MenuAction_Select)
	{
		char selectedItem[50];
		int style;
		GetMenuItem(adminClansMenu, option, selectedItem, sizeof(selectedItem), style, "", 0);
		if(!strcmp(selectedItem, "CreateClan"))
		{
			bool available = false;
			Handle newClanLeaderSelectMenu = CreateMenu(Clan_LeaderOfNewClanSelectMenu);
			char print_buff[BUFF_SIZE], name[MAX_NAME_LENGTH], userid[15];
			FormatEx(print_buff, sizeof(print_buff), "%T", "m_OnlinePlayers", client);
			SetMenuTitle(newClanLeaderSelectMenu, print_buff);
			for(int target = 1; target <= MaxClients; target++)
			{
				if(IsClientInGame(target))
				{
					available = true;
					GetClientName(target, name, sizeof(name));
					IntToString(target, userid, sizeof(userid));
					AddMenuItem(newClanLeaderSelectMenu, userid, name);
				}
			}
			SetMenuExitButton(newClanLeaderSelectMenu, true);
			DisplayMenu(newClanLeaderSelectMenu, client, 0);
			if(available)
				admin_SelectMode[client][0] = 5;
			else
				admin_SelectMode[client][0] = 5;
		}
		else if(!strcmp(selectedItem, "SetCoins"))
		{
			admin_SelectMode[client][0] = 0;
			if(!ThrowClansToClient(client, true))
				ThrowAdminMenu(client);
		}
		else if(!strcmp(selectedItem, "ResetClient"))
		{
			admin_SelectMode[client][0] = 1;
			if(!ThrowClanClientsToClient(client))
				ThrowAdminMenu(client);
		}
		else if(!strcmp(selectedItem, "ResetClan"))
		{
			admin_SelectMode[client][0] = 2;
			if(!ThrowClansToClient(client, true))
				ThrowAdminMenu(client);
		}
		else if(!strcmp(selectedItem, "DeleteClient"))
		{
			admin_SelectMode[client][0] = 3;
			if(!ThrowClanClientsToClient(client))
				ThrowAdminMenu(client);
		}
		else if(!strcmp(selectedItem, "DeleteClan"))
		{
			admin_SelectMode[client][0] = 4;
			if(!ThrowClansToClient(client, true))
				ThrowAdminMenu(client);
		}
		else if(!strcmp(selectedItem, "ChangeLeader"))
		{
			admin_SelectMode[client][0] = 6;
			if(!ThrowClansToClient(client, true))
				ThrowAdminMenu(client);
		}
		else if(!strcmp(selectedItem, "RenameClan"))
		{
			admin_SelectMode[client][0] = 7;
			renameClan[client] = true;
			if(!ThrowClansToClient(client, true))
				ThrowAdminMenu(client);
		}
		else if(!strcmp(selectedItem, "SetSlots"))
		{
			admin_SelectMode[client][0] = 8;
			if(!ThrowClansToClient(client, true))
				ThrowAdminMenu(client);
		}
		else if(!strcmp(selectedItem, "SetClanType"))
		{
			admin_SelectMode[client][0] = 9;
			if(!ThrowClansToClient(client, true))
				ThrowAdminMenu(client);
		}
		else if(!strcmp(selectedItem, "ChangeRole"))
		{
			admin_SelectMode[client][0] = 10;
			if(!ThrowClansToClient(client, true))
				ThrowAdminMenu(client);
		}
		else
		{
			Call_StartForward(g_hACMSelected);	//Clans_OnAdminClanMenuSelected forward
			Call_PushCell(adminClansMenu);
			Call_PushCell(client);
			Call_PushCell(option);
			Call_Finish();
		}
	}
	else if(action == MenuAction_End && action == MenuAction_Cancel)
	{
		CloseHandle(adminClansMenu);
	}
}

/**
 * Player selects any menu item in list of clans
 */
public int Clan_ClansSelectMenu(Handle clansMenu, MenuAction action, int client, int option)
{
	if(action == MenuAction_Select)
	{
		char str_clanid[10], print_buff[BUFF_SIZE];
		int style, clanid;
		GetMenuItem(clansMenu, option, str_clanid, sizeof(str_clanid), style, "", 0);
		clanid = StringToInt(str_clanid);
		if(admin_SelectMode[client][0] == 0)	//set coins
		{
			admin_SelectMode[client][1] = clanid;
			FormatEx(print_buff, sizeof(print_buff), "%T", "c_SetCoins1", client);
			CPrintToChat(client, print_buff);
			FormatEx(print_buff, sizeof(print_buff), "%T", "c_SetCoins2", client);
			CPrintToChat(client, print_buff);
		}
		else if(admin_SelectMode[client][0] == 2)	//reset clan
		{
			admin_SelectMode[client][1] = clanid;
			FormatEx(print_buff, sizeof(print_buff), "%T", "c_ClanResetCmd", client, clanid, g_sClanData[clanid][CLAN_NAME]);
			CPrintToChat(client, print_buff);
		}
		else if(admin_SelectMode[client][0] == 4)	//delete clan
		{
			admin_SelectMode[client][1] = clanid;
			FormatEx(print_buff, sizeof(print_buff), "%T", "c_ClanDeleteCmd", client, clanid, g_sClanData[clanid][CLAN_NAME]);
			CPrintToChat(client, print_buff);
		}
		else if(admin_SelectMode[client][0] == 6)	//change leader
		{
			admin_SelectMode[client][1] = clanid;
			if(!ThrowClanMembersToClient(client, clanid, 1))
				if(!ThrowClansToClient(client, true))
					ThrowAdminMenu(client);
		}
		else if(admin_SelectMode[client][0] == 7)	//rename clan
		{
			admin_SelectMode[client][1] = clanid;
			FormatEx(print_buff, sizeof(print_buff), "%T", "c_RenameClan", client);
			CPrintToChat(client, print_buff);
		}
		else if(admin_SelectMode[client][0] == 8)	//change slots
		{
			admin_SelectMode[client][1] = clanid;
			FormatEx(print_buff, sizeof(print_buff), "%T", "c_SetSlots1", client);
			CPrintToChat(client, print_buff);
			FormatEx(print_buff, sizeof(print_buff), "%T", "c_SetSlots2", client);
			CPrintToChat(client, print_buff);
		}
		else if(admin_SelectMode[client][0] == 9)	//set clan type
		{
			admin_SelectMode[client][1] = clanid;
			ThrowSetTypeMenu(client);
		}
		else if(admin_SelectMode[client][0] == 10)	//change player's role in clan
		{
			admin_SelectMode[client][1] = clanid;
			if(!ThrowClanMembersToClient(client, clanid, 1))
				if(!ThrowClansToClient(client, true))
					ThrowAdminMenu(client);
		}
		else if(clan_SelectMode[client][0] == 3)	//transfer coins
		{
			clan_SelectMode[client][1] = clanid;
			FormatEx(print_buff, sizeof(print_buff), "%T", "c_TranferCoins", client, g_iClanData[GetClientClan(ClanClient)][CLAN_COINS]);
			CPrintToChat(client, print_buff);
		}
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(clansMenu);
	}
	else if(option == MenuCancel_ExitBack && action == MenuAction_Cancel)
	{
		if(admin_SelectMode[client][0] != -1)
			ThrowAdminMenu(client);
		else
			ThrowClanControlMenu(client);
		admin_SelectMode[client][0] = -1;
		clan_SelectMode[client][0] = -1;
		clan_SelectMode[client][1] = -1;
	}
}

/**
 * Admin selects any menu item in list of clan clients
 */
public int Clan_ClanClientsSelectMenu(Handle clanClientsMenu, MenuAction action, int client, int option)
{
	if(action == MenuAction_Select)
	{
		char print_buff[BUFF_SIZE], str_clientID[10];
		int style, clientID;
		GetMenuItem(clanClientsMenu, option, str_clientID, sizeof(str_clientID), style, "", 0);
		clientID = StringToInt(str_clientID);
		if(admin_SelectMode[client][0] == 1)	//reset client
		{
			admin_SelectMode[client][1] = clientID;
			FormatEx(print_buff, sizeof(print_buff), "%T", "c_PlayerResetCmd", client, clientID, g_sClientData[clientID][CLIENT_NAME]);
			CPrintToChat(client, print_buff);
		}
		else if(admin_SelectMode[client][0] == 3)	//delete client
		{
			admin_SelectMode[client][1] = clientID;
			FormatEx(print_buff, sizeof(print_buff), "%T", "c_PlayerDeleteCmd", client, clientID, g_sClientData[clientID][CLIENT_NAME]);
			CPrintToChat(client, print_buff);
		}
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(clanClientsMenu);
	}
	else if(action == MenuAction_Cancel)
	{
		admin_SelectMode[client][0] = -1;
	}
}

/**
 * Calls when player open help menu
 */
public int Clan_HelpMenu(Handle helpMenu, MenuAction action, int client, int option)
{
	CloseHandle(helpMenu);
}

/**
 * Calls when admin select a player for new clan
 */
public int Clan_LeaderOfNewClanSelectMenu(Handle newClanLeaderSelectMenu, MenuAction action, int client, int option)
{
	if(action == MenuAction_Select)
	{
		char str_clientID[10], print_buff[BUFF_SIZE];
		int style;
		GetMenuItem(newClanLeaderSelectMenu, option, str_clientID, sizeof(str_clientID), style, "", 0);
		admin_SelectMode[client][1] = StringToInt(str_clientID);
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_EnterClanName", client);
		CPrintToChat(client, print_buff);
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(newClanLeaderSelectMenu);
	}
	else if(action == MenuAction_Cancel)
	{
		admin_SelectMode[client][0] = -1;
	}
}

/**
 * Calls when player got an invitation to clan
 */
public int Clans_InviteAcceptMenu(Handle inviteMenu, MenuAction action, int client, int option)
{
	if(action == MenuAction_Select)
	{
		char answer[10];
		int style;
		GetMenuItem(inviteMenu, option, answer, sizeof(answer), style, "", 0);
		if(!strcmp(answer, "Yes"))
		{
			char buff[BUFF_SIZE];
			if(g_iClanData[GetClientClan(invitedBy[client][0])][CLAN_MEMBERS] >= g_iClanData[GetClientClan(invitedBy[client][0])][CLAN_MAXMEMBERS])
			{
				FormatEx(buff, sizeof(buff), "%T", "c_MaxMembersInClan", client);
				CPrintToChat(client, buff);
				invitedBy[client][0] = -1;
			}
			else
			{
				SetOnlineClientClan(client, g_iClientData[invitedBy[client][0]][CLIENT_CLANID], 0);
				if(CheckForLog(LOG_CLIENTACTION))
				{
					char log_buff[LOG_SIZE];
					FormatEx(log_buff, sizeof(log_buff), "%T", "L_CreatePlayer", LANG_SERVER, g_sClanData[GetClientClan(invitedBy[client][0])][CLAN_NAME]);
					SQL_LogAction(client, false, -1, log_buff, invitedBy[client][0], false, GetClientClan(invitedBy[client][0]), LOG_CLIENTACTION);
				}
				invitedBy[client][0] = -1;
				FormatEx(buff, sizeof(buff), "%T", "c_JoinSuccess", client);
				CPrintToChat(client, buff);
			}
		}
		invitedBy[client][0] = -1;
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(inviteMenu);
	}
}

/**
 * Calls when player selects a type for a clan
 */
int Clan_SetTypeSelectMenu(Handle setTypeMenu, MenuAction action, int client, int option)
{
	if(action == MenuAction_Select)
	{
		char print_buff[BUFF_SIZE], userName[MAX_NAME_LENGTH+1], type[100];
		int clanid;
		GetClientName(client, userName, sizeof(userName));
		if(admin_SelectMode[client][0] == 9)
			clanid = admin_SelectMode[client][1];
		else
			clanid = GetClientClan(ClanClient);
		if(option == 0)			//Player selects closed clan
		{
			if(IsClanValid(clanid) && GetClanType(clanid) != 0)
			{
				SetClanType(clanid, 0);
				FormatEx(print_buff, sizeof(print_buff), "%T", "c_TypeChangeSuccess", client);
				CPrintToChat(client, print_buff);
				if(CheckForLog(LOG_CHANGETYPE))
				{
					char log_buff[LOG_SIZE];
					FormatEx(log_buff, sizeof(log_buff), "%T", "L_SetClanType", LANG_SERVER, 0, g_sClanData[clanid][CLAN_NAME]);
					SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, -1, true, clanid, LOG_CHANGETYPE);
				}
				for(int i = 1; i <= MaxClients; i++)
				{
					if(i != client && IsClientInGame(i) && GetClientClan(playerID[i]) == clanid)
					{
						FormatEx(type, sizeof(type), "%T", "m_TypeOpen", i);
						FormatEx(print_buff, sizeof(print_buff), "%T", "c_TypeChangedTo", i, userName, type);
						CPrintToChat(i, print_buff);
					}
				}
			}
		}
		else if(option == 1)	//Player selects open clan
		{
			if(IsClanValid(clanid) && GetClanType(clanid) != 1)
			{
				SetClanType(clanid, 1);
				FormatEx(print_buff, sizeof(print_buff), "%T", "c_TypeChangeSuccess", client);
				CPrintToChat(client, print_buff);
				if(CheckForLog(LOG_CHANGETYPE))
				{
					char log_buff[LOG_SIZE];
					FormatEx(log_buff, sizeof(log_buff), "%T", "L_SetClanType", LANG_SERVER, 1, g_sClanData[clanid][CLAN_NAME]);
					SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, -1, true, clanid, LOG_CHANGETYPE);
				}
				for(int i = 1; i <= MaxClients; i++)
				{
					if(i != client && IsClientInGame(i) && GetClientClan(playerID[i]) == clanid)
					{
						FormatEx(type, sizeof(type), "%T", "m_TypeInvite", i);
						FormatEx(print_buff, sizeof(print_buff), "%T", "c_TypeChangedTo", i, userName, type);
						CPrintToChat(i, print_buff);
					}
				}
			}
		}
		bool canDo = CanPlayerDo(ClanClient, PERM_TYPE)
		if(canDo || admin_SelectMode[client][0] == 9)
			ThrowSetTypeMenu(client);
		else
			ThrowClanMenuToClient(client);
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(setTypeMenu);
	}
	else if(option == MenuCancel_ExitBack && action == MenuAction_Cancel)
	{
		if(admin_SelectMode[client][0] == 9)
			ThrowClansToClient(client, true);
		else
			ThrowClanControlMenu(client);
	}
}

/**
 * Calls when player selects a new role for a clan member
 */
int Clan_ChangeRoleSelectMenu(Handle changeRoleMenu, MenuAction action, int client, int option)
{
	if(action == MenuAction_Select)
	{
		int target, role, newrole, style;
		char print_buff[BUFF_SIZE], selectedItem[50], c_newRole[50], userName[MAX_NAME_LENGTH+1];
		GetClientName(client, userName, sizeof(userName));
		if(admin_SelectMode[client][0] == 9)
			target = admin_SelectMode[client][1];
		else
			target = clan_SelectMode[client][1];
		role = GetClientRole(target);
		GetMenuItem(changeRoleMenu, option, selectedItem, sizeof(selectedItem), style, "", 0);
		if(!strcmp(selectedItem, "Member"))
		{
			newrole = CLIENT_MEMBER;
			if(role != newrole)
			{
				if(SetClientRole(target, newrole))
				{
					FormatEx(print_buff, sizeof(print_buff), "%T", "c_ChangeRoleSuccess", client);
					CPrintToChat(client, print_buff);
					if(CheckForLog(LOG_CHANGEROLE))
					{
						char log_buff[LOG_SIZE];
						FormatEx(log_buff, sizeof(log_buff), "%T", "L_SetRole", LANG_SERVER, g_sClientData[target][CLIENT_NAME], 0);
						SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, target, true, GetClientClan(target), LOG_CHANGEROLE);
					}
					for(int i = 1; i <= MaxClients; i++)
					{
						if(IsClientInGame(i) && playerID[i] == target)
						{
							FormatEx(c_newRole, sizeof(c_newRole), "%T", "Member", i);
							FormatEx(print_buff, sizeof(print_buff), "%T", "c_RoleChangedTo", i, userName, c_newRole);
							CPrintToChat(i, print_buff);
							i = MaxClients+1;
						}
					}
				}
			}
		}
		else if(!strcmp(selectedItem, "Elder"))
		{
			newrole = CLIENT_ELDER;
			if(role != newrole)
			{
				if(SetClientRole(target, newrole))
				{
					FormatEx(print_buff, sizeof(print_buff), "%T", "c_ChangeRoleSuccess", client);
					CPrintToChat(client, print_buff);
					if(CheckForLog(LOG_CHANGEROLE))
					{
						char log_buff[LOG_SIZE];
						FormatEx(log_buff, sizeof(log_buff), "%T", "L_SetRole", LANG_SERVER, g_sClientData[target][CLIENT_NAME], 1);
						SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, target, true, GetClientClan(target), LOG_CHANGEROLE);
					}
					for(int i = 1; i <= MaxClients; i++)
					{
						if(IsClientInGame(i) && playerID[i] == target)
						{
							FormatEx(c_newRole, sizeof(c_newRole), "%T", "Elder", i);
							FormatEx(print_buff, sizeof(print_buff), "%T", "c_RoleChangedTo", i, userName, c_newRole);
							CPrintToChat(i, print_buff);
							i = MaxClients+1;
						}
					}
				}
			}
		}
		else if(!strcmp(selectedItem, "Coleader"))
		{
			newrole = CLIENT_COLEADER;
			if(role != newrole)
			{
				if(SetClientRole(target, newrole))
				{
					FormatEx(print_buff, sizeof(print_buff), "%T", "c_ChangeRoleSuccess", client);
					CPrintToChat(client, print_buff);
					if(CheckForLog(LOG_CHANGEROLE))
					{
						char log_buff[LOG_SIZE];
						FormatEx(log_buff, sizeof(log_buff), "%T", "L_SetRole", LANG_SERVER, g_sClientData[target][CLIENT_NAME], 2);
						SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, target, true, GetClientClan(target), LOG_CHANGEROLE);
					}
					for(int i = 1; i <= MaxClients; i++)
					{
						if(IsClientInGame(i) && playerID[i] == target)
						{
							FormatEx(c_newRole, sizeof(c_newRole), "%T", "Coleader", i);
							FormatEx(print_buff, sizeof(print_buff), "%T", "c_RoleChangedTo", i, userName, c_newRole);
							CPrintToChat(i, print_buff);
							i = MaxClients+1;
						}
					}
				}
			}
		}
		else if(!strcmp(selectedItem, "Leader"))
		{
			newrole = CLIENT_LEADER;
			if(role != newrole)
			{
				if(SetClanLeader(target, GetClientClan(target)))
				{
					FormatEx(print_buff, sizeof(print_buff), "%T", "c_ChangeRoleSuccess", client);
					CPrintToChat(client, print_buff);
					if(CheckForLog(LOG_CHANGEROLE))
					{
						char log_buff[LOG_SIZE];
						FormatEx(log_buff, sizeof(log_buff), "%T", "L_SetRole", LANG_SERVER, g_sClientData[target][CLIENT_NAME], 4);
						SQL_LogAction(client, false, GetClientClan(ClanClient), log_buff, target, true, GetClientClan(target), LOG_CHANGEROLE);
					}
					for(int i = 1; i <= MaxClients; i++)
					{
						if(IsClientInGame(i) && playerID[i] == target)
						{
							FormatEx(c_newRole, sizeof(c_newRole), "%T", "Leader", i);
							FormatEx(print_buff, sizeof(print_buff), "%T", "c_RoleChangedTo", i, userName, c_newRole);
							CPrintToChat(i, print_buff);
							i = MaxClients+1;
						}
					}
				}
			}
		}
		bool canDo = CanPlayerDo(ClanClient, PERM_ROLE)
		if(canDo || admin_SelectMode[client][0] == 10)
			ThrowChangeRoleMenu(client, target);
		else
			ThrowClanMenuToClient(client);
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(changeRoleMenu);
	}
	else if(option == MenuCancel_ExitBack && action == MenuAction_Cancel)
	{
		int clanid, flags = 0;
		if(admin_SelectMode[client][0] == 10)
		{
			clanid = GetClientClan(admin_SelectMode[client][1]);
			flags = 1;
		}
		else
		{
			clanid = GetClientClan(clan_SelectMode[client][1]);
			flags = 2;
		}
		if(!ThrowClanMembersToClient(client, clanid, flags))
			ThrowClanControlMenu(client);
	}
}
//=============================== Funtions ===============================//
/**
 * Get client's id in database
 *
 * @param int client - player's id in game
 *
 * @return client's id in database
 */
int GetClientIDinDB(int client)
{
	if(client < 1 || client > MaxClients || !IsClientInGame(client))
		return -1;
	return ClanClient;
}

/**
 * Get client's id in database by steam id
 *
 * @param const char[] auth - player's steam id to search
 *
 * @return client's id in database. Returns -1 if client doesn't exist
 */
int GetClientIDinDBbySteam(const char[] auth)
{
	int i = 0;
	for(i = 0; i < MAX_PLAYERSINCLANES; i++)
		if(!strcmp(auth, g_sClientData[i][CLIENT_STEAMID]))
			return i;
	return -1;
}

/**
 * Get client's clan id in database
 *
 * @param int clientID - player's id in database (-1 if it doesn't exist)
 *
 * @return client's clan id
 */
int GetClientClan(int clientID)
{
	if(clientID == -1)
		return -1;
	return g_iClientData[clientID][CLIENT_CLANID];
}

/**
 * Set client's clan id (only if client is online)
 *
 * @param int client - player's id
 * @param int clanId - clan id
 * @param int role - role of player. 0 - member, 1 - elder, 2 - co-leader, 4 - leader
 *
 * @return true - success, false - failed
 */
bool SetOnlineClientClan(int client, int clanId, int role)
{
	if(client < 1 || client > MaxClients || !IsClientInGame(client) || !IsClanValid(clanId))
		return false;
	int curClan = GetClientClan(ClanClient);
	if(curClan != -1)
	{
		if(g_iClanData[curClan][CLAN_MEMBERS] == 1)
			DeleteClan(curClan);
		else
		{
			g_iClientData[ClanClient][CLIENT_CLANID] = -1;
			g_iClanData[curClan][CLAN_MEMBERS]--;
			g_iClanData[curClan][CLAN_KILLS] -= g_iClientData[ClanClient][CLIENT_KILLS];
			g_iClanData[curClan][CLAN_DEATHS] -= g_iClientData[ClanClient][CLIENT_DEATHS];
			if(IsClientClanLeader(ClanClient))
			{
				for(int i = 0; i < MAX_PLAYERSINCLANES; i++)
				if(g_iClientData[i][CLIENT_CLANID] == curClan)
				{
					g_iClientData[i][CLIENT_ROLE] = CLIENT_LEADER;
					g_sClanData[curClan][CLAN_LEADERNAME] = g_sClientData[i][CLIENT_NAME];
					g_sClanData[curClan][CLAN_LEADERID] = g_sClientData[i][CLIENT_STEAMID];
					i = MAX_PLAYERSINCLANES;
				}
			}
			SQL_UpdateClan(curClan);
		}
	}
	char userName[MAX_NAME_LENGTH], auth[33];
	bool exists = ClanClient != -1;
	if(!exists)
	{
		for(int i = 0; i < MAX_PLAYERSINCLANES; i++)
		{
			if(g_iClientData[i][CLIENT_CLANID] == -1)
			{
				ClanClient = i;
				i = MAX_PLAYERSINCLANES;
			}
		}
		GetClientName(client, userName, sizeof(userName));
		GetClientAuthId(client, AuthId_Steam3, auth, sizeof(auth));
		g_sClientData[ClanClient][CLIENT_NAME] = userName;
		g_sClientData[ClanClient][CLIENT_STEAMID] = auth;
	}
	if(role == CLIENT_LEADER)
		SetClanLeader(ClanClient, clanId);
	else
	{
		g_iClanData[clanId][CLAN_MEMBERS]++;
		g_iClientData[ClanClient][CLIENT_CLANID] = clanId;
		g_iClientData[ClanClient][CLIENT_ROLE] = role;
		g_iClientData[ClanClient][CLIENT_KILLS] = 0;
		g_iClientData[ClanClient][CLIENT_DEATHS] = 0;
		g_iClientData[ClanClient][CLIENT_TIME] = GetTime();
		SQL_UpdateClan(clanId);
	}
	if(exists)
		SQL_SaveClient(ClanClient);
	else
	{
		SQL_CreateClient(ClanClient);
		Call_StartForward(g_hClientAdded);	//Clans_OnClientAdded forward
		Call_PushCell(client);
		Call_PushCell(ClanClient);
		Call_PushCell(clanId);
		Call_Finish();
	}
	if(!g_bCSS34)
		UpdatePlayerClanTag(client);
	return true;
}

/**
 * Check if player is clan leader
 *
 * @param int clientID - player's id in database
 *
 * @return true - player is clan leader, otherwise - false
 */
bool IsClientClanLeader(int clientID)
{
	if(clientID == -1)
		return false;
	return g_iClientData[clientID][CLIENT_ROLE] == CLIENT_LEADER;
}

/**
 * Check if player is clan co-leader
 *
 * @param int clientID - player's id in database
 *
 * @return true - player is clan co-leader, otherwise - false
 */
bool IsClientClanCoLeader(int clientID)
{
	if(clientID == -1)
		return false;
	return g_iClientData[clientID][CLIENT_ROLE] == CLIENT_COLEADER;
}

/**
 * Check if player is clan elder
 *
 * @param int clientID - player's id in database
 *
 * @return true - player is clan elder, otherwise - false
 */
bool IsClientClanElder(int clientID)
{
	if(clientID == -1)
		return false;
	return g_iClientData[clientID][CLIENT_ROLE] == CLIENT_ELDER;
}

/**
 * Get player's role
 *
 * @param int clientID - player's id in database
 * @return player's role
*/
int GetClientRole(int clientID)
{
	if(clientID == -1)
		return -1;
	return g_iClientData[clientID][CLIENT_ROLE];
}

/**
 * Set player's role
 *
 * @param int clientID - player's id in database
 * @param int newRole - new role of the player
 * @return true if succeed, false otherwise
*/
int SetClientRole(int clientID, int newRole)
{
	if(clientID == -1 || newRole < 0 || newRole > 2)
		return false;
	g_iClientData[clientID][CLIENT_ROLE] = newRole;
	return true;
}

/**
 * Get client's kills in current clan
 *
 * @param int clientID - player's id in database
 *
 * @return number of client's kills
 */
int GetClientKillsInClan(int clientID)
{
	if(clientID == -1)
		return -1;
	return g_iClientData[clientID][CLIENT_KILLS];
}

/**
 * Set client kills in clan
 *
 * @param int clientID - player's id in database
 *
 * @param int kills - player's kills to set
 *
 * @return true - success, false - failed
 */
bool SetClientKillsInClan(int clientID, int kills)
{
	if(clientID == -1)
		return false;
	int clanId = GetClientClan(clientID);
	if(clanId == -1)
		return false;
	g_iClanData[clanId][CLAN_KILLS] -= g_iClientData[clientID][CLIENT_KILLS];
	g_iClientData[clientID][CLIENT_KILLS] = kills;
	g_iClanData[clanId][CLAN_KILLS] += g_iClientData[clientID][CLIENT_KILLS];
	return true;
}

/**
 * Get client's deaths in current clan
 *
 * @param int clientID - player's id in database
 *
 * @return number of client's deaths
 */
int GetClientDeathsInClan(int clientID)
{
	if(clientID == -1)
		return -1;
	return g_iClientData[clientID][CLIENT_DEATHS];
}

/**
 * Set client's deaths in current clan
 *
 * @param int clientID - player's id in database
 *
 * @param int deaths - client's deaths to set
 *
 * @return true - success, false - failed
 */
bool SetClientDeathsInClan(int clientID, int deaths)
{
	if(clientID == -1)
		return false;
	int clanId = GetClientClan(clientID);
	if(clanId == -1)
		return false;
	g_iClanData[clanId][CLAN_DEATHS] -= g_iClientData[clientID][CLIENT_DEATHS];
	g_iClientData[clientID][CLIENT_DEATHS] = deaths;
	g_iClanData[clanId][CLAN_DEATHS] += g_iClientData[clientID][CLIENT_DEATHS];
	return true;
}

/**
 * Delete clan by it's id
 *
 * @param int clanId - clan's id
 *
 * @return true - success, false - failed
 */
bool DeleteClan(int clanId)
{
	if(!IsClanValid(clanId))
		return false;
	g_iClanData[clanId][CLAN_MEMBERS] = 0;
	g_iClanData[clanId][CLAN_MAXMEMBERS] = 0;
	g_iClanData[clanId][CLAN_KILLS] = 0;
	g_iClanData[clanId][CLAN_DEATHS] = 0;
	g_iClanData[clanId][CLAN_COINS] = 0;
	g_iClanData[clanId][CLAN_TYPE] = 0;
	g_sClanData[clanId][CLAN_NAME] = "";
	g_sClanData[clanId][CLAN_LEADERNAME] = "";
	g_sClanData[clanId][CLAN_LEADERID] = "";
	g_sClanData[clanId][CLAN_DATE] = "";
	
	for(int clientID = 0; clientID < MAX_PLAYERSINCLANES; clientID++)
	{
		if(g_iClientData[clientID][CLIENT_CLANID] == clanId)
		{
			g_iClientData[clientID][CLIENT_CLANID] = -1;
			g_iClientData[clientID][CLIENT_ROLE] = 0;
			g_iClientData[clientID][CLIENT_KILLS] = 0;
			g_iClientData[clientID][CLIENT_DEATHS] = 0;
			g_iClientData[clientID][CLIENT_TIME] = 0;
			g_sClientData[clientID][CLIENT_NAME] = "";
			g_sClientData[clientID][CLIENT_STEAMID] = "";
			SQL_DeleteClient(clientID);
			Call_StartForward(g_hClientDeleted);	//Clans_OnClientDeleted forward
			Call_PushCell(clientID);
			Call_PushCell(clanId);
			Call_Finish();
		}
	}
	
	for(int client = 1; client <= MaxClients; client++)	//Online players
	{
		if(IsClientInGame(client) && playerID[client] != -1 && g_iClientData[playerID[client]][CLIENT_CLANID] == -1)
			playerID[client] = -1;
	}
	Call_StartForward(g_hClanDeleted);	//Clans_OnClanDeleted forward
	Call_PushCell(clanId);
	Call_Finish();
	SQL_DeleteClan(clanId);
	if(!g_bCSS34)
		UpdatePlayersClanTag();
	return true;
}

/**
 * Reset clan by it's id
 *
 * @param int clanId - clan's id
 *
 * @return true - success, false - failed
 */
bool ResetClan(int clanId)
{
	if(!IsClanValid(clanId))
		return false;
	g_iClanData[clanId][CLAN_KILLS] = 0;
	g_iClanData[clanId][CLAN_DEATHS] = 0;
	g_iClanData[clanId][CLAN_COINS] = 0;
	SQL_UpdateClan(clanId);
	return true;
}

/**
 * Delete online client by his/her id
 *
 * @param int clientID - player's id in database
 *
 * @return true - success, false - failed
 */
bool DeleteClient(int clientID)
{
	if(clientID < 0 || clientID > MAX_PLAYERSINCLANES)
		return false;
	int clanid = GetClientClan(clientID);
	if(IsClientClanLeader(clientID) && g_iClanData[clanid][CLAN_MEMBERS] > 1)
	{
		for(int i = 0; i < MAX_PLAYERSINCLANES; i++)
		{
			if(i != clientID && g_iClientData[i][CLIENT_CLANID] == clanid)
			{
				g_iClientData[i][CLIENT_ROLE] = CLIENT_LEADER;
				g_sClanData[clanid][CLAN_LEADERNAME] = g_sClientData[i][CLIENT_NAME];
				g_sClanData[clanid][CLAN_LEADERID] = g_sClientData[i][CLIENT_STEAMID];
				i = MAX_PLAYERSINCLANES;
			}
		}
	}
	
	if(g_iClanData[clanid][CLAN_MEMBERS] == 1)
		DeleteClan(clanid);
	else
	{
		g_iClanData[clanid][CLAN_MEMBERS]--;
		g_iClientData[clientID][CLIENT_CLANID] = -1;
		g_iClientData[clientID][CLIENT_ROLE] = 0;
		g_iClientData[clientID][CLIENT_KILLS] = 0;
		g_iClientData[clientID][CLIENT_DEATHS] = 0;
		g_iClientData[clientID][CLIENT_TIME] = 0;
		g_sClientData[clientID][CLIENT_NAME] = "";
		g_sClientData[clientID][CLIENT_STEAMID] = "";
		
		for(int i = 1; i <= MaxClients; i++)
			if(playerID[i] == clientID)
			{
				playerID[i] = -1;
				i = MaxClients;
			}
		
		if(g_iClanData[clanid][CLAN_MEMBERS] > 0)
		{
			SQL_DeleteClient(clientID);
			SQL_UpdateClan(clanid);
		}
	}
	Call_StartForward(g_hClientDeleted);	//Clans_OnClientDeleted forward
	Call_PushCell(clientID);
	Call_PushCell(clanid);
	Call_Finish();
	if(!g_bCSS34)
		UpdatePlayersClanTag();
	return true;
}

/**
 * Reset player's stats in clan by player's id
 *
 * @param int clientID - player's id in database
 *
 * @return true - success, false - failed
 */
bool ResetClient(int clientID)
{
	if(clientID == -1)
		return false;
	int clanId = GetClientClan(clientID);
	if(clanId == -1)
		return false;
	g_iClanData[clanId][CLAN_KILLS] -= g_iClientData[clientID][CLIENT_KILLS];
	g_iClanData[clanId][CLAN_DEATHS] -= g_iClientData[clientID][CLIENT_DEATHS];
	g_iClientData[clientID][CLIENT_KILLS] = 0;
	g_iClientData[clientID][CLIENT_DEATHS] = 0;
	return true;
}

/**
 * Check if player has a permission to do smth
 *
 * @param int clientID - player's id in database
 * @param int permission - permission id
 * @return true if player has the permission, false otherwise
*/
bool CanPlayerDo(int clientID, int permission)
{
	if(clientID < 0 || clientID > MAX_PLAYERSINCLANES)
		return false;
	switch(permission)
	{
		case 1:	//invite
			return g_iRInvitePerm & g_iClientData[clientID][CLIENT_ROLE] > 0 ? true : false;
		case 2: //givecoins
			return g_iRGiveCoinsToClan & g_iClientData[clientID][CLIENT_ROLE] > 0 ? true : false;
		case 3: //expand
			return g_iRExpandClan & g_iClientData[clientID][CLIENT_ROLE] > 0 ? true : false;
		case 4: //kick
			return g_iRKickPlayer & g_iClientData[clientID][CLIENT_ROLE] > 0 ? true : false;
		case 5: //change type
			return g_iRChangeType & g_iClientData[clientID][CLIENT_ROLE] > 0 ? true : false;
		case 6: //change role
			return g_iRChangeRole & g_iClientData[clientID][CLIENT_ROLE] > 0 ? true : false;
		default:
			return false;
	}
}

bool CanPlayerDoAnything(int clientID)
{
	if(clientID < 0 || clientID > MAX_PLAYERSINCLANES)
		return false;
	int check;
	check = g_iRInvitePerm & g_iClientData[clientID][CLIENT_ROLE];
	check |= g_iRGiveCoinsToClan & g_iClientData[clientID][CLIENT_ROLE];
	check |= g_iRExpandClan & g_iClientData[clientID][CLIENT_ROLE];
	check |= g_iRKickPlayer & g_iClientData[clientID][CLIENT_ROLE];
	check |= g_iRChangeType & g_iClientData[clientID][CLIENT_ROLE];
	check |= g_iRChangeRole & g_iClientData[clientID][CLIENT_ROLE];
	return check > 0 ? true : false;
}

/**
 * Check if players in different clans
 *
 * @param int clientID - player's id in database
 *
 * @param int otherId - other player's id in database
 *
 * @return true - players in different clans, otherwise - false
 */
bool AreClientsInDifferentClans(int clientID, int otherId)
{
	if(clientID == -1 || otherId == -1)
		return true;
	return g_iClientData[clientID][CLIENT_CLANID] != g_iClientData[otherId][CLIENT_CLANID];
}

/**
 * Check if player in clan
 *
 * @param int clientID - player's id in database
 *
 * @return true - players in different clans, otherwise - false
 */
bool IsClientInClan(int clientID)
{
	if(clientID == -1)
		return false;
	return g_iClientData[clientID][CLIENT_CLANID] != -1;
}

/**
 * Update online player's clan tag
 *
 * @param int client - player's id
 */
void UpdatePlayerClanTag(int client)
{
	if(ClanClient != -1 && g_iClientData[ClanClient][CLIENT_CLANID] != -1)
	{
		char ctag[16];
		if(g_iClientData[ClanClient][CLIENT_ROLE] == CLIENT_LEADER)
		{
			FormatEx(ctag, sizeof(ctag), "♦ %s", g_sClanData[g_iClientData[ClanClient][CLIENT_CLANID]][CLAN_NAME]);
			CS_SetClientClanTag(client, ctag);
		}
		else
		{
			FormatEx(ctag, sizeof(ctag), "%s", g_sClanData[g_iClientData[ClanClient][CLIENT_CLANID]][CLAN_NAME]);
			CS_SetClientClanTag(client, ctag);
		}
	}
	else if(g_bNoClanTag)
	{
		CS_SetClientClanTag(client, "");
	}
}

/**
 * Update all online players' clan tag
 */
void UpdatePlayersClanTag()
{
	for(int i = 1; i <= MaxClients; ++i)
		if(IsClientInGame(i))
			UpdatePlayerClanTag(i);
}

/**
 * Set leader in clan
 *
 * @param int leaderId - player's id in database
 * @param int clanId - clan's id
 *
 * @return true - success, false - failed
 */
bool SetClanLeader(int leaderId, int clanId)
{
	if(!IsClanValid(clanId) || (g_iClientData[leaderId][CLIENT_CLANID] == clanId && g_iClientData[leaderId][CLIENT_ROLE] == CLIENT_LEADER))
		return false;
	for(int i = 0; i < MAX_PLAYERSINCLANES; i++)
		if(g_iClientData[i][CLIENT_CLANID] == clanId && g_iClientData[i][CLIENT_ROLE] == CLIENT_LEADER)
		{
			g_iClientData[i][CLIENT_ROLE] = CLIENT_COLEADER;
			SQL_SaveClient(i);
			i = MAX_PLAYERSINCLANES;
		}
	int old_clan = GetClientClan(leaderId);
	g_iClientData[leaderId][CLIENT_CLANID] = clanId;
	if(old_clan != -1)
	{
		g_iClanData[old_clan][CLAN_MEMBERS]--;
		if(g_iClanData[old_clan][CLAN_MEMBERS] < 1)
			SQL_DeleteClan(old_clan);
		else
		{
			if(IsClientClanLeader(leaderId))
			{
				for(int i = 0; i < MAX_PLAYERSINCLANES; i++)
					if(g_iClientData[i][CLIENT_CLANID] == old_clan)
					{
						g_iClientData[i][CLIENT_ROLE] = CLIENT_LEADER;
						g_sClanData[old_clan][CLAN_LEADERNAME] = g_sClientData[i][CLIENT_NAME];
						g_sClanData[old_clan][CLAN_LEADERID] = g_sClientData[i][CLIENT_STEAMID];
						SQL_SaveClient(i);
						i = MAX_PLAYERSINCLANES;
					}
			}
			SQL_UpdateClan(old_clan);
		}
	}
	g_iClanData[clanId][CLAN_MEMBERS]++;
	g_iClientData[leaderId][CLIENT_TIME] = GetTime();
	g_iClientData[leaderId][CLIENT_ROLE] = CLIENT_LEADER;
	if(clanId != old_clan)
	{
		g_iClientData[leaderId][CLIENT_KILLS] = 0;
		g_iClientData[leaderId][CLIENT_DEATHS] = 0;
	}
	g_sClanData[clanId][CLAN_LEADERNAME] = g_sClientData[leaderId][CLIENT_NAME];
	g_sClanData[clanId][CLAN_LEADERID] = g_sClientData[leaderId][CLIENT_STEAMID];
	SQL_UpdateClan(clanId);
	SQL_SaveClient(leaderId);
	if(!g_bCSS34)
		UpdatePlayersClanTag();
	return true;
}

/**
 * Check if clan is valid
 *
 * @param int clanId - clan's id
 * 
 * @return true - clan is valid, false - otherwise
 */
bool IsClanValid(int clanId)
{
	return clanId >= 0 && clanId < MAX_CLANS && g_iClanData[clanId][CLAN_MEMBERS] > 0;
}

/**
 * Update Tops of clans
 **/
public Action Timer_UpdateTopsOfClans(Handle timer)
{
	UpdateTopsOfClans();
}
void UpdateTopsOfClans()
{
	for(int i = 0; i < MAX_CLANS; i++)
	{
		TopClans[TOP_KILLS][i] = g_iClanData[i][CLAN_MEMBERS] > 0 ? i : -1;
		TopClans[TOP_DEATHS][i] = g_iClanData[i][CLAN_MEMBERS] > 0 ? i : -1;
		TopClans[TOP_EXISTTIME][i] = g_iClanData[i][CLAN_MEMBERS] > 0 ? i : -1;
		TopClans[TOP_MEMBERS][i] = g_iClanData[i][CLAN_MEMBERS] > 0 ? i : -1;
		TopClans[TOP_COINS][i] = g_iClanData[i][CLAN_MEMBERS] > 0 ? i : -1;
	}
	int buff;
	for(int i = 0; i < MAX_CLANS-1; i++)
	{
		for(int j = i+1; j < MAX_CLANS; j++)
		{
			if( (TopClans[TOP_KILLS][i] != -1 && TopClans[TOP_KILLS][j] != -1 && g_iClanData[TopClans[TOP_KILLS][j]][CLAN_KILLS] > g_iClanData[TopClans[TOP_KILLS][i]][CLAN_KILLS]) || (TopClans[TOP_KILLS][i] == -1 && TopClans[TOP_KILLS][j] != -1) )
			{
				buff = TopClans[TOP_KILLS][i];
				TopClans[TOP_KILLS][i] = TopClans[TOP_KILLS][j];
				TopClans[TOP_KILLS][j] = buff;
			}
			if( (TopClans[TOP_DEATHS][i] != -1 && TopClans[TOP_DEATHS][j] != -1 && g_iClanData[TopClans[TOP_DEATHS][j]][CLAN_DEATHS] > g_iClanData[TopClans[TOP_DEATHS][i]][CLAN_DEATHS]) || (TopClans[TOP_DEATHS][i] == -1 && TopClans[TOP_DEATHS][j] != -1) )
			{
				buff = TopClans[TOP_DEATHS][i];
				TopClans[TOP_DEATHS][i] = TopClans[TOP_DEATHS][j];
				TopClans[TOP_DEATHS][j] = buff;
			}
			if( (TopClans[TOP_EXISTTIME][i] != -1 && TopClans[TOP_EXISTTIME][j] != -1 && g_iClanData[TopClans[TOP_EXISTTIME][j]][CLAN_TIME] > g_iClanData[TopClans[TOP_EXISTTIME][i]][CLAN_TIME]) || (TopClans[TOP_EXISTTIME][i] == -1 && TopClans[TOP_EXISTTIME][j] != -1) )
			{
				buff = TopClans[TOP_EXISTTIME][i];
				TopClans[TOP_EXISTTIME][i] = TopClans[TOP_EXISTTIME][j];
				TopClans[TOP_EXISTTIME][j] = buff;
			}
			if( (TopClans[TOP_MEMBERS][i] != -1 && TopClans[TOP_MEMBERS][j] != -1 && g_iClanData[TopClans[TOP_MEMBERS][j]][CLAN_MEMBERS] > g_iClanData[TopClans[TOP_MEMBERS][i]][CLAN_MEMBERS]) || (TopClans[TOP_MEMBERS][i] == -1 && TopClans[TOP_MEMBERS][j] != -1) )
			{
				buff = TopClans[TOP_MEMBERS][i];
				TopClans[TOP_MEMBERS][i] = TopClans[TOP_MEMBERS][j];
				TopClans[TOP_MEMBERS][j] = buff;
			}
			if( (TopClans[TOP_COINS][i] != -1 && TopClans[TOP_COINS][j] != -1 && g_iClanData[TopClans[TOP_COINS][j]][CLAN_COINS] > g_iClanData[TopClans[TOP_COINS][i]][CLAN_COINS]) || (TopClans[TOP_COINS][i] == -1 && TopClans[TOP_COINS][j] != -1) )
			{
				buff = TopClans[TOP_COINS][i];
				TopClans[TOP_COINS][i] = TopClans[TOP_COINS][j];
				TopClans[TOP_COINS][j] = buff;
			}
		}
	}
}

/**
 * Get number of clan's coins
 *
 * @param int clanId - clan's id
 * 
 * @return number of clan's coins
 */
int GetClanCoins(int clanId)
{
	if(!IsClanValid(clanId))
		return -1;
	return g_iClanData[clanId][CLAN_COINS];
}

/**
 * Set number of clan's coins
 *
 * @param int clanId - clan's id
 * @param int coins - number of coins to set
 * 
 * @return true - success, false - failed
 */
bool SetClanCoins(int clanId, int coins)
{
	if(!IsClanValid(clanId) || coins < 0)
		return false;
	g_iClanData[clanId][CLAN_COINS] = coins;
	return true;
}

/**
 * Get number of clan's kills
 *
 * @param int clanId - clan's id
 * 
 * @return number of clan's kills
 */
int GetClanKills(int clanId)
{
	if(!IsClanValid(clanId))
		return -1;
	return g_iClanData[clanId][CLAN_KILLS];
}

/**
 * Set number of clan's kills
 *
 * @param int clanId - clan's id
 * @param int kills - number of kills to set
 * 
 * @return true - success, false - failed
 */
bool SetClanKills(int clanId, int kills)
{
	if(!IsClanValid(clanId) || kills < 0)
		return false;
	g_iClanData[clanId][CLAN_KILLS] = kills;
	return true;
}

/**
 * Get number of clan's deaths
 *
 * @param int clanId - clan's id
 * 
 * @return number of clan's deaths
 */
int GetClanDeaths(int clanId)
{
	if(!IsClanValid(clanId))
		return -1;
	return g_iClanData[clanId][CLAN_DEATHS];
}

/**
 * Set number of clan's deaths
 *
 * @param int clanId - clan's id
 * @param int deaths - number of deaths to set
 * 
 * @return true - success, false - failed
 */
bool SetClanDeaths(int clanId, int deaths)
{
	if(!IsClanValid(clanId) || deaths < 0)
		return false;
	g_iClanData[clanId][CLAN_DEATHS] = deaths;
	return true;
}

/**
 * Get number of members in clan
 *
 * @param int clanId - clan's id
 * 
 * @return number of members in clan
 */
int GetClanMembers(int clanId)
{
	if(!IsClanValid(clanId))
		return -1;
	return g_iClanData[clanId][CLAN_MEMBERS];
}

/**
 * Set number of members in clan
 *
 * @param int clanId - clan's id
 * @param int members - number of members in clan to set
 * 
 * @return true - success, false - failed
 */
bool SetClanMembers(int clanId, int members)
{
	if(!IsClanValid(clanId) || members < 0)
		return false;
	g_iClanData[clanId][CLAN_MEMBERS] = members;
	return true;
}

/**
 * Get maximum number of members in clan
 *
 * @param int clanId - clan's id
 * 
 * @return maximum number of members in clan
 */
int GetClanMaxMembers(int clanId)
{
	if(!IsClanValid(clanId))
		return -1;
	return g_iClanData[clanId][CLAN_MAXMEMBERS];
}

/**
 * Set maximum number of members in clan
 *
 * @param int clanId - clan's id
 * @param int maxmembers - maximum number of members in clan to set
 * 
 * @return true - success, false - failed
 */
bool SetClanMaxMembers(int clanId, int maxmembers)
{
	if(!IsClanValid(clanId) || maxmembers < 0)
		return false;
	g_iClanData[clanId][CLAN_MAXMEMBERS] = maxmembers;
	return true;
}

/**
 * Get clan type
 *
 * @param int clanid - clan's id
 * 
 * @return 0 - closed clan, 1 - open clan
 */
int GetClanType(int clanid)
{
	if(!IsClanValid(clanid))
		return -1;
	return g_iClanData[clanid][CLAN_TYPE];
}

/**
 * Set clan type
 *
 * @param int clanid - clan's id
 * @param int type - 0 - closed clan, 1 - open clan
 * 
 * @return true - success, false - failed
 */
bool SetClanType(int clanid, int type)
{
	if(!IsClanValid(clanid) || type < 0 || type > 1)
		return false;
	g_iClanData[clanid][CLAN_TYPE] = type;
	return true;
}

/**
 * Converting seconds to time
 *
 * @param int seconds
 * @param char[] buffer - time, format: MONTHS:DAYS:HOURS:MINUTES:SECONDS
 * @param int maxlength - size of buffer
 * @param int client - who will see the time
 */
void SecondsToTime(int seconds, char[] buffer, int maxlength, int client)
{
	int months, days, hours, minutes;
	months = seconds/2678400;
	seconds -= 2678400*months;
	days = seconds/86400;
	seconds -= 86400*days;
	hours = seconds/3600;
	seconds -= 3600*hours;
	minutes = seconds/60;
	seconds -= 60*minutes;
	FormatEx(buffer, maxlength, "%T", "Time", client, months, days, hours, minutes, seconds);
}

/**
 * Check if the type of logging is available
 *
 * @param int type - type of logging
 * @return true if this type is available, false otherwise
*/
bool CheckForLog(int type)
{
	return type & g_iLogFlags > 0 ? true : false;
}

void NameToDB(char[] buff, int len)
{
	ReplaceString(buff, len, "'", "");
	ReplaceString(buff, len, "\\", "");
	ReplaceString(buff, len, "`", "");
	ReplaceString(buff, len, "\"", "");
}
//=============================== MENUS ===============================//
/**
 * Throws clan menu to player
 *
 * @param int client - player's id, who will see the clan menu
 *
 * @return true - success, false - failed
 */
bool ThrowClanMenuToClient(int client)
{
	if(client < 1 || client > MaxClients || !IsClientInClan(ClanClient))
		return false;
	Handle playerClanMenu = CreateMenu(Clan_PlayerClanSelectMenu);
	char print_buff[BUFF_SIZE];
	FormatEx(print_buff, sizeof(print_buff), "%T", "m_ClanMenu", client);
	SetMenuTitle(playerClanMenu, print_buff);
	if(CanPlayerDoAnything(ClanClient))
	{
		FormatEx(print_buff, sizeof(print_buff), "%T", "m_ClanControl", client);
		AddMenuItem(playerClanMenu, "ClanControl", print_buff);
	}
	FormatEx(print_buff, sizeof(print_buff), "%T", "m_ClanStatsMenu", client);
	AddMenuItem(playerClanMenu, "ClanStats", print_buff);
	FormatEx(print_buff, sizeof(print_buff), "%T", "m_MyStatsMenu", client);
	AddMenuItem(playerClanMenu, "PlayerStats", print_buff);
	FormatEx(print_buff, sizeof(print_buff), "%T", "m_Members", client);
	AddMenuItem(playerClanMenu, "Members", print_buff);
	FormatEx(print_buff, sizeof(print_buff), "%T", "m_Top", client);
	AddMenuItem(playerClanMenu, "TopClans", print_buff);
	if(!IsClientClanLeader(ClanClient) || (IsClientClanLeader(ClanClient) && g_bLeaderLeave))
	{
		FormatEx(print_buff, sizeof(print_buff), "%T", "m_LeaveClan", client);
		AddMenuItem(playerClanMenu, "LeaveClan", print_buff);
	}
	Call_StartForward(g_hCMOpened);	//Clans_OnClanMenuOpened forward
	Call_PushCell(playerClanMenu);
	Call_PushCell(client);
	Call_Finish();
	SetMenuExitButton(playerClanMenu, true);
	DisplayMenu(playerClanMenu, client, 0);
	return true;
}

/**
 * Throws player stats to client
 *
 * @param int client - player's id, who will see the stats
 * @param int target - player's id in database, whose stats will be shown
 *
 * @return true - success, false - failed
 */
bool ThrowPlayerStatsToClient(int client, int target)
{
	if(client < 1 || client > MaxClients || !IsClientInClan(target) || !IsClientInGame(client))
		return false;
	Handle playerStatsMenu = CreatePanel();
	char stats[350], time[60], status[30];
	int role = GetClientRole(target);
	FormatEx(stats, sizeof(stats), "%T", "m_PlayerStatsTitle", client);
	SetPanelTitle(playerStatsMenu, stats);
	FormatEx(stats, sizeof(stats), "%T", "m_Close", client);
	DrawPanelItem(playerStatsMenu, stats, 0);
	SecondsToTime(GetTime() - g_iClientData[target][CLIENT_TIME], time, sizeof(time), client);
	if(role == CLIENT_LEADER)
		FormatEx(status, sizeof(status), "%T", "Leader", client);
	else if(role == CLIENT_COLEADER)
		FormatEx(status, sizeof(status), "%T", "Coleader", client);
	else if(role == CLIENT_ELDER)
		FormatEx(status, sizeof(status), "%T", "Elder", client);
	else
		FormatEx(status, sizeof(status), "%T", "Member", client);
	FormatEx(stats, sizeof(stats), "%T", "m_PlayerStats", client, g_sClientData[target][CLIENT_NAME], target, g_sClanData[g_iClientData[target][CLIENT_CLANID]][CLAN_NAME], g_iClientData[target][CLIENT_CLANID], status, g_iClientData[target][CLIENT_KILLS], g_iClientData[target][CLIENT_DEATHS], time);
	DrawPanelText(playerStatsMenu, stats);
	Call_StartForward(g_hPSOpened);	//Clans_OnPlayerStatsOpened forward
	Call_PushCell(playerStatsMenu);
	Call_PushCell(client);
	Call_Finish();
	SendPanelToClient(playerStatsMenu, client, Clan_PlayerStatsMenu, 0);
	return true;
}

/**
 * Throws clan stats to client
 *
 * @param int client - player's id, who will see the stats
 * @param int clanId - clan's id, whose stats will be shown
 *
 * @return true - success, false - failed
 */
bool ThrowClanStatsToClient(int client, int clanId)
{
	if(client < 1 || client > MaxClients || !IsClanValid(clanId) || !IsClientInGame(client))
		return false;
	Handle clanStatsMenu = CreatePanel();
	char stats[400], type[100];
	FormatEx(stats, sizeof(stats), "%T", "m_ClanStatsTitle", client);
	SetPanelTitle(clanStatsMenu, stats);
	FormatEx(stats, sizeof(stats), "%T", "m_SeeMembers", client);
	DrawPanelItem(clanStatsMenu, stats, 0);
	if(GetClanType(clanId) == 1 && ClanClient == -1)
	{
		FormatEx(stats, sizeof(stats), "%T", "m_JoinClan", client);
		DrawPanelItem(clanStatsMenu, stats, 0);
	}
	FormatEx(stats, sizeof(stats), "%T", "m_Close", client);
	DrawPanelItem(clanStatsMenu, stats, 0);
	if(GetClanType(clanId) == 0)
		FormatEx(type, sizeof(type), "%T", "m_TypeInvite", client);
	else
		FormatEx(type, sizeof(type), "%T", "m_TypeOpen", client);
	FormatEx(stats, sizeof(stats), "%T", "m_ClanStats", client, 
		g_sClanData[clanId][CLAN_NAME], clanId, type, g_sClanData[clanId][CLAN_LEADERNAME], g_iClanData[clanId][CLAN_MEMBERS], g_iClanData[clanId][CLAN_MAXMEMBERS],
		g_iClanData[clanId][CLAN_KILLS], g_iClanData[clanId][CLAN_DEATHS], g_sClanData[clanId][CLAN_DATE], g_iClanData[clanId][CLAN_COINS]);
	DrawPanelText(clanStatsMenu, stats);
	Call_StartForward(g_hCSOpened);	//Clans_OnClanStatsOpened forward
	Call_PushCell(clanStatsMenu);
	Call_PushCell(client);
	Call_Finish();
	clan_SelectMode[client][1] = clanId;
	SendPanelToClient(clanStatsMenu, client, Clan_ClanStatsMenu, 0);
	return true;
}

/**
 * Throws clan members to client
 *
 * @param int client - player's id, who will see members
 * @param int clanId - clan's id, whose members will be shown
 * @param int showFlags - flags to members to show: 1st bit - client will be shown in menu, 2nd bit - don't show clients whose role is above client's one
 *
 * @return true - success, false - failed
 */
bool ThrowClanMembersToClient(int client, int clanId, int showFlags)
{
	if(client < 1 || client > MaxClients || !IsClanValid(clanId) || !IsClientInGame(client))
		return false;
	bool showClient = showFlags & 1 > 0 ? true : false;
	bool showHigher = showFlags & 2 > 0 ? true : false;
	bool show = false;
	Handle clanMembersMenu = CreateMenu(Clan_ClanMembersSelectMenu);
	SetMenuTitle(clanMembersMenu, "Участники клана");
	char userName[MAX_NAME_LENGTH], auth[33], status[30];
	for(int i = 0; i < MAX_PLAYERSINCLANES; i++)
	{
		if(g_iClientData[i][CLIENT_CLANID] == clanId && (showClient || (!showClient && i != ClanClient)) && (!showHigher || (showHigher && GetClientRole(i) < GetClientRole(ClanClient) )))
		{
			Format(auth, sizeof(auth), "%s", g_sClientData[i][CLIENT_STEAMID]);
			Format(userName, sizeof(userName), "%s", g_sClientData[i][CLIENT_NAME]);
			if(g_iClientData[i][CLIENT_ROLE] != 0)
			{
				if(g_iClientData[i][CLIENT_ROLE] == CLIENT_ELDER)
					FormatEx(status, sizeof(status), "%T", "Elder", client);
				else if(g_iClientData[i][CLIENT_ROLE] == CLIENT_COLEADER)
					FormatEx(status, sizeof(status), "%T", "Coleader", client);
				else
					FormatEx(status, sizeof(status), "%T", "Leader", client);
				Format(userName, sizeof(userName), "%s (%s)", userName, status);
			}
			show = true;
			AddMenuItem(clanMembersMenu, auth, userName);
		}
	}
	if(show)
	{
		SetMenuExitBackButton(clanMembersMenu, true);
		DisplayMenu(clanMembersMenu, client, 0);
	}
	else
	{
		char print_buff[BUFF_SIZE];
		FormatEx(print_buff, sizeof(print_buff), "%T", "NoPlayers", client);
		CPrintToChat(client, print_buff);
		delete clanMembersMenu;
		return false;
	}
	return true;
}

/**
 * Throws tops of clans menu to player
 *
 * @param int client - player's id, who will see tops of clans menu
 *
 * @return true - success, false - failed
 */
bool ThrowTopsMenuToClient(int client)
{
	if(client < 1 || client > MaxClients || !IsClientInGame(client))
		return false;
	Handle topsMenu = CreateMenu(Clan_TopsSelectMenu);
	char print_buff[100];
	FormatEx(print_buff, sizeof(print_buff), "%T", "m_Top", client);
	SetMenuTitle(topsMenu, print_buff);
	FormatEx(print_buff, sizeof(print_buff), "%T", "t_KillsDesc", client);
	AddMenuItem(topsMenu, "KillsDecrease", print_buff);
	FormatEx(print_buff, sizeof(print_buff), "%T", "t_KillsAsc", client);
	AddMenuItem(topsMenu, "KillsIncrease", print_buff);
	FormatEx(print_buff, sizeof(print_buff), "%T", "t_DeathsDesc", client);
	AddMenuItem(topsMenu, "DeathsDecrease", print_buff);
	FormatEx(print_buff, sizeof(print_buff), "%T", "t_DeathsAsc", client);
	AddMenuItem(topsMenu, "DeathsIncrease", print_buff);
	FormatEx(print_buff, sizeof(print_buff), "%T", "t_TimeDesc", client);
	AddMenuItem(topsMenu, "ExisttimeDecrease", print_buff);
	FormatEx(print_buff, sizeof(print_buff), "%T", "t_TimeAsc", client);
	AddMenuItem(topsMenu, "ExisttimeIncrease", print_buff);
	FormatEx(print_buff, sizeof(print_buff), "%T", "t_MembersDesc", client);
	AddMenuItem(topsMenu, "MembersDecrease", print_buff);
	FormatEx(print_buff, sizeof(print_buff), "%T", "t_MembersAsc", client);
	AddMenuItem(topsMenu, "MembersIncrease", print_buff);
	FormatEx(print_buff, sizeof(print_buff), "%T", "t_CoinsDesc", client);
	AddMenuItem(topsMenu, "CoinsDecrease", print_buff);
	FormatEx(print_buff, sizeof(print_buff), "%T", "t_CoinsAsc", client);
	AddMenuItem(topsMenu, "CoinsIncrease", print_buff);
	SetMenuExitButton(topsMenu, true);
	DisplayMenu(topsMenu, client, 0);
	return true;
}

/**
 * Throws clans to player
 *
 * @param int client - player's id, who will see clans
 * @param bool showClientClan - flag if client's clan will be shown in menu
 *
 * @return true - success, false - failed
 */
bool ThrowClansToClient(int client, bool showClientClan)
{
	if(client < 1 || client > MaxClients || !IsClientInGame(client))
		return false;
	Handle clansMenu = CreateMenu(Clan_ClansSelectMenu);
	char str_clanid[20];
	bool show = false;
	FormatEx(str_clanid, sizeof(str_clanid), "%T", "m_Clans", client);
	SetMenuTitle(clansMenu, str_clanid);
	for(int i = 0; i < MAX_CLANS; i++)
	{
		if(g_iClanData[i][CLAN_MEMBERS] != 0 && (showClientClan || (!showClientClan && i != GetClientClan(ClanClient))))
		{
			show = true;
			IntToString(i, str_clanid, sizeof(str_clanid));
			AddMenuItem(clansMenu, str_clanid, g_sClanData[i][CLAN_NAME]);
		}
	}
	if(show)
	{
		SetMenuExitBackButton(clansMenu, true);
		DisplayMenu(clansMenu, client, 0);
	}
	else
	{
		char print_buff[BUFF_SIZE];
		FormatEx(print_buff, sizeof(print_buff), "%T", "NoClans", client);
		CPrintToChat(client, print_buff);
		delete clansMenu;
		return false;
	}
	return true;
}

/**
 * Throws all clan clients to player
 *
 * @param int client - player's id, who will see clients
 * @return true - success, false - failed
 */
bool ThrowClanClientsToClient(int client)
{
	if(client < 1 || client > MaxClients || !IsClientInGame(client))
		return false;
	Handle clanClientsMenu = CreateMenu(Clan_ClanClientsSelectMenu);
	char str_clientid[20];
	bool show = false;
	FormatEx(str_clientid, sizeof(str_clientid), "%T", "m_Players", client);
	SetMenuTitle(clanClientsMenu, str_clientid);
	for(int i = 0; i < MAX_PLAYERSINCLANES; i++)
	{
		if(g_iClientData[i][CLIENT_CLANID] != -1)
		{
			show = true;
			IntToString(i, str_clientid, sizeof(str_clientid));
			AddMenuItem(clanClientsMenu, str_clientid, g_sClientData[i][CLIENT_NAME]);
		}
	}
	if(show)
	{
		SetMenuExitButton(clanClientsMenu, true);
		DisplayMenu(clanClientsMenu, client, 0);
	}
	else
	{
		char print_buff[BUFF_SIZE];
		FormatEx(print_buff, sizeof(print_buff), "%T", "NoPlayers", client);
		CPrintToChat(client, print_buff);
		delete clanClientsMenu;
		return false;
	}
	return true;
}

/**
 * Show all players available to invite
 *
 * @param int client - player's id
 * @return true - success, false - failed
 */
bool ThrowInviteList(int client)
{
	if(client < 1 || client > MaxClients || !IsClientInGame(client) || !CanPlayerDo(ClanClient, PERM_INVITE))
		return false;
	Handle inviteSelectMenu = CreateMenu(Clan_InvitePlayerSelectMenu);
	char print_buff[80], name[MAX_NAME_LENGTH], userid[15];
	FormatEx(print_buff, sizeof(print_buff), "%T", "m_WhomToInvite", client);
	SetMenuTitle(inviteSelectMenu, print_buff);
	bool allPlayersFree = true;
	for (int target = 1; target <= MaxClients; target++)
	{
		if(IsClientInGame(target) && !IsFakeClient(target) && !IsClientInClan(GetClientIDinDB(target)) && (invitedBy[target][0] == -1 || GetTime() - invitedBy[target][1] > MAX_INVITATION_TIME ))
		{
			allPlayersFree = false;
			GetClientName(target, name, sizeof(name));
			IntToString(GetClientUserId(target), userid, 15); 
			AddMenuItem(inviteSelectMenu, userid, name);
		}
	}
	SetMenuExitButton(inviteSelectMenu, true);
	DisplayMenu(inviteSelectMenu, client, 0);
	if(allPlayersFree)
	{
		FormatEx(print_buff, sizeof(print_buff), "%T", "c_NoOneToInvite", client);
		CPrintToChat(client, print_buff);
		return false;
	}
	return true;
}

/**
 * Throws clan control menu
 *
 * @param int client - player's id
 *
 * @return true - success, false - failed
 */
bool ThrowClanControlMenu(int client)
{
	if(client < 1 || client > MaxClients || !IsClientInGame(client) || !CanPlayerDoAnything(ClanClient))
		return false;
	Handle clanControlMenu = CreateMenu(Clan_ClanControlSelectMenu);
	char print_buff[80];
	FormatEx(print_buff, sizeof(print_buff), "%T", "m_ClanControl", client);
	SetMenuTitle(clanControlMenu, print_buff);
	if(CanPlayerDo(ClanClient, PERM_EXPAND))
	{
		FormatEx(print_buff, sizeof(print_buff), "%T", "m_ExpandClan", client);
		AddMenuItem(clanControlMenu, "Expand", print_buff);
	}
	if(CanPlayerDo(ClanClient, PERM_GIVECOINS) && g_bCoinsTransfer)
	{
		FormatEx(print_buff, sizeof(print_buff), "%T", "m_TransferCoins", client);
		AddMenuItem(clanControlMenu, "TransferCoins", print_buff);
	}
	if(CanPlayerDo(ClanClient, PERM_INVITE))
	{
		FormatEx(print_buff, sizeof(print_buff), "%T", "m_Invite", client);
		AddMenuItem(clanControlMenu, "Invite", print_buff);
	}
	if(CanPlayerDo(ClanClient, PERM_KICK))
	{
		FormatEx(print_buff, sizeof(print_buff), "%T", "m_KickPlayer", client);
		AddMenuItem(clanControlMenu, "Kick", print_buff);
	}
	if(CanPlayerDo(ClanClient, PERM_TYPE))
	{
		FormatEx(print_buff, sizeof(print_buff), "%T", "m_SetClanType", client);
		AddMenuItem(clanControlMenu, "SetType", print_buff);
	}
	if(CanPlayerDo(ClanClient, PERM_ROLE))
	{
		FormatEx(print_buff, sizeof(print_buff), "%T", "m_ChangeRole", client);
		AddMenuItem(clanControlMenu, "ChangeRole", print_buff);
	}
	if(IsClientClanLeader(ClanClient))
	{
		if(g_bLeaderChange)
		{
			FormatEx(print_buff, sizeof(print_buff), "%T", "m_NewLeader", client);
			AddMenuItem(clanControlMenu, "SelectLeader", print_buff);
		}
		FormatEx(print_buff, sizeof(print_buff), "%T", "m_RenameClan", client);
		AddMenuItem(clanControlMenu, "RenameClan", print_buff);
		FormatEx(print_buff, sizeof(print_buff), "%T", "m_Disband", client);
		AddMenuItem(clanControlMenu, "DeleteClan", print_buff);
	}
	SetMenuExitBackButton(clanControlMenu, true);
	DisplayMenu(clanControlMenu, client, 0);
	return true;
}

/**
 * Throws set type clan menu to client
 *
 * @param int client - player's id, who will see clients
 * @return true - success, false - failed
 */
bool ThrowSetTypeMenu(int client)
{
	if(client < 1 || client > MaxClients || !IsClientInGame(client))
		return false;
	int clanid;
	if(admin_SelectMode[client][0] == 9)
		clanid = admin_SelectMode[client][1];
	else
		clanid = GetClientClan(ClanClient);
	int type = GetClanType(clanid);
	char print_buff[100];
	Handle setTypeMenu = CreateMenu(Clan_SetTypeSelectMenu);
	FormatEx(print_buff, sizeof(print_buff), "%T", "m_SetClanType", client);
	SetMenuTitle(setTypeMenu, print_buff);
	FormatEx(print_buff, sizeof(print_buff), "%T", "m_TypeInvite", client);
	if(type == 0)
		Format(print_buff, sizeof(print_buff), "%s [✓]", print_buff);
	AddMenuItem(setTypeMenu, "Closed", print_buff);
	FormatEx(print_buff, sizeof(print_buff), "%T", "m_TypeOpen", client);
	if(type == 1)
		Format(print_buff, sizeof(print_buff), "%s [✓]", print_buff);
	AddMenuItem(setTypeMenu, "Open", print_buff);
	SetMenuExitBackButton(setTypeMenu, true);
	DisplayMenu(setTypeMenu, client, 0);
	return true;
}

/**
 * Throws change role menu to client
 *
 * @param int client - player's id, who will see clients
 * @param int targetID - target's id in database
 * @return true - success, false - failed
 */
bool ThrowChangeRoleMenu(int client, int targetID)
{
	if(client < 1 || client > MaxClients || !IsClientInGame(client) || targetID < 0 || targetID > MAX_PLAYERSINCLANES)
		return false;
	int role = GetClientRole(targetID);
	char print_buff[100];
	Handle changeRoleMenu = CreateMenu(Clan_ChangeRoleSelectMenu);
	FormatEx(print_buff, sizeof(print_buff), "%T", "m_ChangeRole", client);
	SetMenuTitle(changeRoleMenu, print_buff);
	FormatEx(print_buff, sizeof(print_buff), "%T", "Member", client);
	if(role == CLIENT_MEMBER)
		Format(print_buff, sizeof(print_buff), "%s [✓]", print_buff);
	AddMenuItem(changeRoleMenu, "Member", print_buff);
	FormatEx(print_buff, sizeof(print_buff), "%T", "Elder", client);
	if(role == CLIENT_ELDER)
		Format(print_buff, sizeof(print_buff), "%s [✓]", print_buff);
	AddMenuItem(changeRoleMenu, "Elder", print_buff);
	FormatEx(print_buff, sizeof(print_buff), "%T", "Coleader", client);
	if(role == CLIENT_COLEADER)
		Format(print_buff, sizeof(print_buff), "%s [✓]", print_buff);
	AddMenuItem(changeRoleMenu, "Coleader", print_buff);
	FormatEx(print_buff, sizeof(print_buff), "%T", "Leader", client);
	if(role == CLIENT_LEADER)
		Format(print_buff, sizeof(print_buff), "%s [✓]", print_buff);
	AddMenuItem(changeRoleMenu, "Leader", print_buff);
	SetMenuExitBackButton(changeRoleMenu, true);
	DisplayMenu(changeRoleMenu, client, 0);
	return true;
}

bool ThrowAdminMenu(int client)
{
	if(client < 1 || client > MaxClients)
		return false;
	AdminId adminid = GetUserAdmin(client);
	if(adminid == INVALID_ADMIN_ID)
		return false;
	char print_buff[BUFF_SIZE];
	Handle adminClansMenu = CreateMenu(Clan_AdminClansSelectMenu);
	FormatEx(print_buff, sizeof(print_buff), "%T", "m_AdminMenu", client);
	SetMenuTitle(adminClansMenu, print_buff);
	FormatEx(print_buff, sizeof(print_buff), "%T", "m_CreateClan", client);
	AddMenuItem(adminClansMenu, "CreateClan", print_buff);
	FormatEx(print_buff, sizeof(print_buff), "%T", "m_ChangeCoinsInClan", client);
	AddMenuItem(adminClansMenu, "SetCoins", print_buff);
	FormatEx(print_buff, sizeof(print_buff), "%T", "m_AdminChangeSlots", client);
	AddMenuItem(adminClansMenu, "SetSlots", print_buff);
	FormatEx(print_buff, sizeof(print_buff), "%T", "m_ResetPlayer", client);
	AddMenuItem(adminClansMenu, "ResetClient", print_buff);
	FormatEx(print_buff, sizeof(print_buff), "%T", "m_ResetClan", client);
	AddMenuItem(adminClansMenu, "ResetClan", print_buff);
	FormatEx(print_buff, sizeof(print_buff), "%T", "m_KickPlayer", client);
	AddMenuItem(adminClansMenu, "DeleteClient", print_buff);
	FormatEx(print_buff, sizeof(print_buff), "%T", "m_DeleteClan", client);
	AddMenuItem(adminClansMenu, "DeleteClan", print_buff);
	FormatEx(print_buff, sizeof(print_buff), "%T", "m_RenameClan", client);
	AddMenuItem(adminClansMenu, "RenameClan", print_buff);
	FormatEx(print_buff, sizeof(print_buff), "%T", "m_ChangeLeader", client);
	AddMenuItem(adminClansMenu, "ChangeLeader", print_buff);
	FormatEx(print_buff, sizeof(print_buff), "%T", "m_SetClanType", client);
	AddMenuItem(adminClansMenu, "SetClanType", print_buff);
	FormatEx(print_buff, sizeof(print_buff), "%T", "m_ChangeRole", client);
	AddMenuItem(adminClansMenu, "ChangeRole", print_buff);
	Call_StartForward(g_hACMOpened);	//Clans_OnAdminClanMenuOpened forward
	Call_PushCell(adminClansMenu);
	Call_PushCell(client);
	Call_Finish();
	SetMenuExitButton(adminClansMenu, true);
	DisplayMenu(adminClansMenu, client, 0);
	return true;
}
//=============================== SQL Functions ===============================//
void SQL_LoadAll()
{
	char query[200];
	Format(query, sizeof(query), "SELECT `clan_id`, `clan_name`, `leader_steam`, `leader_name`, `date_creation`, `time_creation`, `members`, `maxmembers`, `clan_kills`, `clan_deaths`, `clan_coins`, `clan_type` FROM `clans_table`");
	SQL_TQuery(g_hClansDB, SQL_LoadClansCallback, query, 0);
	Format(query, sizeof(query), "SELECT `player_id`, `player_name`, `player_steam`, `player_clanid`, `player_role`, `player_kills`, `player_deaths`, `player_timejoining` FROM `players_table`");
	SQL_TQuery(g_hClansDB, SQL_LoadPlayersCallback, query, 0);
}

void SQL_SaveClans()
{
	for(int i = 0; i < MAX_CLANS; i++)
		if(g_iClanData[i][CLAN_MEMBERS] > 0)
			SQL_UpdateClan(i);
}

void SQL_UpdateClan(int clanid)
{
	char query[600];
	char cName[MAX_NAME_LENGTH+1], lName[MAX_NAME_LENGTH+1];
	cName = g_sClanData[clanid][CLAN_NAME];
	lName = g_sClanData[clanid][CLAN_LEADERNAME];
	NameToDB(cName, sizeof(cName));
	NameToDB(lName, sizeof(lName));
	Format(query, sizeof(query), "UPDATE `clans_table` SET `clan_name` = '%s', `leader_steam` = '%s', `leader_name` = '%s', `date_creation` = '%s', `time_creation` = '%d', `members` = '%d', `maxmembers` = '%d', `clan_kills` = '%d', `clan_deaths` = '%d', `clan_coins` = '%d', `clan_type` = '%d' WHERE `clan_id` = '%d'",
					cName, g_sClanData[clanid][CLAN_LEADERID], lName, g_sClanData[clanid][CLAN_DATE],
					g_iClanData[clanid][CLAN_TIME], g_iClanData[clanid][CLAN_MEMBERS], g_iClanData[clanid][CLAN_MAXMEMBERS],
					g_iClanData[clanid][CLAN_KILLS], g_iClanData[clanid][CLAN_DEATHS], g_iClanData[clanid][CLAN_COINS], g_iClanData[clanid][CLAN_TYPE], clanid);
	SQL_TQuery(g_hClansDB, SQL_LogError, query, 1);
}

void SQL_CreateClan(int clanid)
{
	char query[600];
	char cName[MAX_NAME_LENGTH+1], lName[MAX_NAME_LENGTH+1];
	cName = g_sClanData[clanid][CLAN_NAME];
	lName = g_sClanData[clanid][CLAN_LEADERNAME];
	NameToDB(cName, sizeof(cName));
	NameToDB(lName, sizeof(lName));
	Format(query, sizeof(query), "INSERT INTO `clans_table` (`clan_id`, `clan_name`, `leader_steam`, `leader_name`, `date_creation`, `time_creation`, `members`, `maxmembers`, `clan_kills`, `clan_deaths`, `clan_coins`, `clan_type`) VALUES ('%d', '%s', '%s', '%s', '%s', '%d', '%d', '%d', '%d', '%d', '%d', '0')",
							clanid, cName, g_sClanData[clanid][CLAN_LEADERID],
							lName, g_sClanData[clanid][CLAN_DATE],
							g_iClanData[clanid][CLAN_TIME], g_iClanData[clanid][CLAN_MEMBERS],
							g_iClanData[clanid][CLAN_MAXMEMBERS], g_iClanData[clanid][CLAN_KILLS],
							g_iClanData[clanid][CLAN_DEATHS], g_iClanData[clanid][CLAN_COINS]);
	SQL_TQuery(g_hClansDB, SQL_LogError, query, 0);
}

void SQL_DeleteClan(int clanid)
{
	char query[90];
	Format(query, sizeof(query), "DELETE FROM `clans_table` WHERE `clan_id` = '%d'", clanid);
	SQL_TQuery(g_hClansDB, SQL_LogError, query, 2);
}

void SQL_SaveClients()
{
	for(int i = 0; i < MAX_PLAYERSINCLANES; i++)
		if(g_iClientData[i][CLIENT_CLANID] != -1)
			SQL_SaveClient(i);
}

void SQL_SaveClient(int clientID)
{
	char query[400];
	char userName[MAX_NAME_LENGTH+1];
	userName = g_sClientData[clientID][CLIENT_NAME];
	NameToDB(userName, sizeof(userName));
	Format(query, sizeof(query), "UPDATE `players_table` SET `player_name` = '%s', `player_clanid` = '%d', `player_role` = '%d', `player_kills` = '%d', `player_deaths` = '%d', `player_timejoining` = '%d' WHERE `player_id` = '%d'",
									userName, g_iClientData[clientID][CLIENT_CLANID],
									g_iClientData[clientID][CLIENT_ROLE], g_iClientData[clientID][CLIENT_KILLS],
									g_iClientData[clientID][CLIENT_DEATHS], g_iClientData[clientID][CLIENT_TIME], clientID);
	SQL_TQuery(g_hClansDB, SQL_LogError, query, 4);
}

void SQL_CreateClient(int clientID)
{
	char query[400];
	char userName[MAX_NAME_LENGTH+1];
	userName = g_sClientData[clientID][CLIENT_NAME];
	NameToDB(userName, sizeof(userName));
	Format(query, sizeof(query), "INSERT INTO `players_table` (`player_id`, `player_name`, `player_steam`, `player_clanid`, `player_role`, `player_kills`, `player_deaths`, `player_timejoining`) VALUES ('%d', '%s', '%s', '%d', '%d', '%d', '%d', '%d')",
							clientID, userName, g_sClientData[clientID][CLIENT_STEAMID],
							g_iClientData[clientID][CLIENT_CLANID], g_iClientData[clientID][CLIENT_ROLE],
							g_iClientData[clientID][CLIENT_KILLS], g_iClientData[clientID][CLIENT_DEATHS],
							g_iClientData[clientID][CLIENT_TIME]);
	SQL_TQuery(g_hClansDB, SQL_LogError, query, 3);
}

void SQL_DeleteClient(int clientID)
{
	char query[90];
	Format(query, sizeof(query), "DELETE FROM `players_table` WHERE `player_id` = '%d'", clientID);
	SQL_TQuery(g_hClansDB, SQL_LogError, query, 5);
}

void SQL_LogAction(int client, bool cid, int clanid, const char[] action, int toWhomP, bool wid, int toWhomCID, int type)
{
	char query[800];
	char clientName[MAX_NAME_LENGTH+1], clanName[MAX_NAME_LENGTH+1], toWhomPN[MAX_NAME_LENGTH+1], toWhomCN[MAX_NAME_LENGTH+1];
	int clientID = -1;
	if(cid)
		clientID = client;
	else if(client > 0 && client <= MaxClients)
		clientID = ClanClient;
	int toWhomPID = -1;
	if(wid)
		toWhomPID = toWhomP;
	else if(toWhomP > 0 && toWhomP <= MaxClients)
		toWhomPID = playerID[toWhomP];
	clientName = "None"; clanName = "None"; toWhomPN = "None"; toWhomCN = "None";
	if(clientID >= 0 && clientID < MAX_PLAYERSINCLANES)
	{
		clientName = g_sClientData[clientID][CLIENT_NAME];
	}
	else
	{
		if(client > 0 && client <= MaxClients && IsClientInGame(client))
		{
			GetClientName(client, clientName, sizeof(clientName));
		}
	}
	if(IsClanValid(clanid))
	{
		clanName = g_sClanData[clanid][CLAN_NAME];
	}
	if(toWhomPID >= 0 && toWhomPID < MAX_PLAYERSINCLANES)
	{
		toWhomPN = g_sClientData[toWhomPID][CLIENT_NAME];
	}
	else
	{
		if(toWhomP > 0 && toWhomP <= MaxClients && IsClientInGame(toWhomP))
		{
			GetClientName(toWhomP, toWhomPN, sizeof(toWhomPN));
		}
	}
	if(IsClanValid(toWhomCID))
	{
		toWhomCN = g_sClanData[toWhomCID][CLAN_NAME];
	}
	int time = GetTime();
	char c_time[50];
	FormatTime(c_time, sizeof(c_time), "%c", time);
	NameToDB(clientName, sizeof(clientName));
	NameToDB(clanName, sizeof(clanName));
	NameToDB(toWhomPN, sizeof(toWhomPN));
	NameToDB(toWhomCN, sizeof(toWhomCN));
	FormatEx(query, sizeof(query), "INSERT INTO `logs` VALUES ('%d', '%s', '%d', '%s', '%s', '%d', '%s', '%d', '%s', '%d', '%d', '%s')", clientID, clientName, clanid, clanName, action, toWhomPID, toWhomPN, toWhomCID, toWhomCN, type, time, c_time);
	SQL_TQuery(g_hLogDB, SQL_LogError, query, 10);
}
//=============================== SQL Callbacks ===============================//
public void SQL_LoadClansCallback(Handle owner, Handle hndl, const char[] error, any anyvar)
{
	if(hndl == INVALID_HANDLE) LogError("[CLANS] Query Fail load clans: %s", error);
	else
	{
		int clanid;
		while(SQL_FetchRow(hndl))
		{
			clanid = SQL_FetchInt(hndl, 0);
			SQL_FetchString(hndl, 1, g_sClanData[clanid][CLAN_NAME], MAX_NAME_LENGTH+1);
			SQL_FetchString(hndl, 2, g_sClanData[clanid][CLAN_LEADERID], MAX_NAME_LENGTH+1);
			SQL_FetchString(hndl, 3, g_sClanData[clanid][CLAN_LEADERNAME], MAX_NAME_LENGTH+1);
			SQL_FetchString(hndl, 4, g_sClanData[clanid][CLAN_DATE], MAX_NAME_LENGTH+1);
			g_iClanData[clanid][CLAN_TIME] = SQL_FetchInt(hndl, 5);
			g_iClanData[clanid][CLAN_MEMBERS] = SQL_FetchInt(hndl, 6);
			g_iClanData[clanid][CLAN_MAXMEMBERS] = SQL_FetchInt(hndl, 7);
			g_iClanData[clanid][CLAN_KILLS] = SQL_FetchInt(hndl, 8);
			g_iClanData[clanid][CLAN_DEATHS] = SQL_FetchInt(hndl, 9);
			g_iClanData[clanid][CLAN_COINS] = SQL_FetchInt(hndl, 10);
			g_iClanData[clanid][CLAN_TYPE] = SQL_FetchInt(hndl, 11);
		}
	}
}

public void SQL_LoadPlayersCallback(Handle owner, Handle hndl, const char[] error, any anyvar)
{
	if(hndl == INVALID_HANDLE) LogError("[CLANS] Query Fail load players: %s", error);
	else
	{
		int pID;
		while(SQL_FetchRow(hndl))
		{
			pID = SQL_FetchInt(hndl, 0);
			SQL_FetchString(hndl, 1, g_sClientData[pID][CLIENT_NAME], MAX_NAME_LENGTH+1);
			SQL_FetchString(hndl, 2, g_sClientData[pID][CLIENT_STEAMID], MAX_NAME_LENGTH+1);
			g_iClientData[pID][CLIENT_CLANID] = SQL_FetchInt(hndl, 3);
			g_iClientData[pID][CLIENT_ROLE] = SQL_FetchInt(hndl, 4);
			g_iClientData[pID][CLIENT_KILLS] = SQL_FetchInt(hndl, 5);
			g_iClientData[pID][CLIENT_DEATHS] = SQL_FetchInt(hndl, 6);
			g_iClientData[pID][CLIENT_TIME] = SQL_FetchInt(hndl, 7);
		}
	}
}

public void SQL_LogError(Handle owner, Handle hndl, const char[] error, any errorid)
{
	if(error[0] != 0)
	{
		char err[40];
		switch(errorid)
		{
			case 0: err = "Create clan";
			case 1: err = "Update clan";
			case 2: err = "Delete clan";
			case 3: err = "Save player";
			case 4: err = "Update player";
			case 5: err = "Delete player";
			case 6: err = "Create clans table";
			case 7: err = "Create players table";
			case 8: err = "Upgrade players table";
			case 9: err = "Upgrade clans table";
			case 10: err = "Insert action to logs";
			case 11: err = "Delete expired actions";
		}
		LogError("[CLANS] Query failed: %s (%d): %s", err, errorid, error);
	}
}
//=============================== NATIVES ===============================//
//Clients
public any Native_IsClanLeader(Handle plugin, int numParams)
{
	int clientID = GetNativeCell(1);
	if(clientID != -1)
	{
		return g_iClientData[clientID][CLIENT_ROLE] == CLIENT_LEADER;
	}
	return false;
}

public any Native_IsClanCoLeader(Handle plugin, int numParams)
{
	int clientID = GetNativeCell(1);
	if(clientID != -1)
	{
		return g_iClientData[clientID][CLIENT_ROLE] == CLIENT_COLEADER;
	}
	return false;
}

public any Native_IsClanElder(Handle plugin, int numParams)
{
	int clientID = GetNativeCell(1);
	if(clientID != -1)
	{
		return g_iClientData[clientID][CLIENT_ROLE] == CLIENT_ELDER;
	}
	return false;
}

public int Native_GetClientRole(Handle plugin, int numParams)
{
	int clientID = GetNativeCell(1);
	if(clientID != -1)
	{
		return g_iClientData[clientID][CLIENT_ROLE];
	}
	return -1;
}

public int Native_GetClientID(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		return ClanClient;
	}
	return -1;
}

public int Native_GetClientClan(Handle plugin, int numParams)
{
	int clientID = GetNativeCell(1);
	if(clientID >= 0 && clientID < MAX_PLAYERSINCLANES)
	{
		return g_iClientData[clientID][CLIENT_CLANID];
	}
	return -1;
}

public int Native_GetOnlineClientClan(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients || !IsClientInGame(client) || ClanClient < 0)
		return -1;
	return g_iClientData[ClanClient][CLIENT_CLANID];
}

public int Native_GetClientKills(Handle plugin, int numParams)
{
	int clientID = GetNativeCell(1);
	return GetClientKillsInClan(clientID);
}

public any Native_SetClientKills(Handle plugin, int numParams)
{
	int clientID = GetNativeCell(1);
	int kills = GetNativeCell(2);
	return SetClientKillsInClan(clientID, kills);
}

public int Native_GetClientDeaths(Handle plugin, int numParams)
{
	int clientID = GetNativeCell(1);
	return GetClientDeathsInClan(clientID);
}

public any Native_SetClientDeaths(Handle plugin, int numParams)
{
	int clientID = GetNativeCell(1);
	int deaths = GetNativeCell(2);
	return SetClientDeathsInClan(clientID, deaths);
}

public any Native_AreInDifferentClans(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int other = GetNativeCell(2);
	if(client > 0 && client <= MaxClients && other > 0 && other <=MaxClients && IsClientInGame(client) && IsClientInGame(other))
	{
		return AreClientsInDifferentClans(playerID[client], playerID[other]);
	}
	return false;
}

public any Native_IsClientInClan(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client > 0 && client <= MaxClients && IsClientInGame(client) && ClanClient != -1)
	{
		return g_iClientData[ClanClient][CLIENT_CLANID] != -1;
	}
	return false;
}

public any Native_ShowPlayerInfo(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int otherID = GetNativeCell(2);
	if(otherID >= 0 && otherID < MAX_PLAYERSINCLANES)
	{
		return ThrowPlayerStatsToClient(client, otherID);
	}
	return false;
}

public any Native_GetCreatePerm(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		return createClan[client];
	}
	return false;
}

public int Native_SetCreatePerm(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	bool status = GetNativeCell(2);
	if(client > 0 && client <= MaxClients)
	{
		createClan[client] = status;
	}
	return 0;
}

//Clans
public any Native_IsClanValid(Handle plugin, int numParams)
{
	int clanid = GetNativeCell(1);
	return IsClanValid(clanid);
}

public int Native_GetClanName(Handle plugin, int numParams)
{
	int clanid = GetNativeCell(1);
	int len = GetNativeCell(3);
	SetNativeString(2, g_sClanData[clanid][CLAN_NAME], len);
	return 0;
}

public int Native_GetClanCoins(Handle plugin, int numParams)
{
	int clanid = GetNativeCell(1);
	return GetClanCoins(clanid);
}

public any Native_SetClanCoins(Handle plugin, int numParams)
{
	int clanid = GetNativeCell(1);
	int coins = GetNativeCell(2);
	return SetClanCoins(clanid, coins);
}

public any Native_ShowClanInfo(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int clanid = GetNativeCell(2);
	return ThrowClanStatsToClient(client, clanid);
}

public any Native_ShowClanMembers(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int clanid = GetNativeCell(2);
	int showFlags = GetNativeCell(3);
	return ThrowClanMembersToClient(client, clanid, showFlags);
}

public any Native_ShowClanList(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	bool showClientClan = GetNativeCell(2);
	return ThrowClansToClient(client, showClientClan);
}

public int Native_GetClanKills(Handle plugin, int numParams)
{
	int clanid = GetNativeCell(1);
	return GetClanKills(clanid);
}

public any Native_SetClanKills(Handle plugin, int numParams)
{
	int clanid = GetNativeCell(1);
	int kills = GetNativeCell(2);
	return SetClanKills(clanid, kills);
}

public int Native_GetClanDeaths(Handle plugin, int numParams)
{
	int clanid = GetNativeCell(1);
	return GetClanDeaths(clanid);
}

public any Native_SetClanDeaths(Handle plugin, int numParams)
{
	int clanid = GetNativeCell(1);
	int kills = GetNativeCell(2);
	return SetClanDeaths(clanid, kills);
}

public int Native_GetClanMembers(Handle plugin, int numParams)
{
	int clanid = GetNativeCell(1);
	return GetClanMembers(clanid);
}

public any Native_SetClanMembers(Handle plugin, int numParams)
{
	int clanid = GetNativeCell(1);
	int members = GetNativeCell(2);
	return SetClanMembers(clanid, members);
}

public int Native_GetClanMaxMembers(Handle plugin, int numParams)
{
	int clanid = GetNativeCell(1);
	return GetClanMaxMembers(clanid);
}

public any Native_SetClanMaxMembers(Handle plugin, int numParams)
{
	int clanid = GetNativeCell(1);
	int maxmembers = GetNativeCell(2);
	return SetClanMaxMembers(clanid, maxmembers);
}