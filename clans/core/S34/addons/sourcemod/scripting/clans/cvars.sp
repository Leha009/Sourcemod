void RegCVars()
{
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

	g_hLogs = CreateConVar("sm_clans_logs", "0", "Flag for logging players' actions: 2 - log to file, 1 - log to sqlite, 0 - not to log", 0, true, 0.0, true, 2.0);
	g_iLogs = GetConVarInt(g_hLogs);
	HookConVarChange(g_hLogs, OnConVarChange);

	g_hLogFlags = CreateConVar("sm_clans_logflags", "0", "Flags for logging players' actions");
	g_iLogFlags = GetConVarInt(g_hLogFlags);
	HookConVarChange(g_hLogFlags, OnConVarChange);

	g_hLogExpireDays = CreateConVar("sm_clans_logexpire", "30", "How many days a recond can be in database", 0, true, 1.0);
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

	g_hLeaderChange = CreateConVar("sm_clans_leaderchange", "1", "Can leader set a new leader in clan (1 - yes, 0 - no)", 0, true, 0.0, true, 1.0);
	g_bLeaderChange = GetConVarBool(g_hLeaderChange);
	HookConVarChange(g_hLeaderChange, OnConVarChange);

	g_hCoinsTransfer = CreateConVar("sm_clans_coinstransfer", "1", "Can clan transfer coins to other clan (1 - yes, 0 - no)", 0, true, 0.0, true, 1.0);
	g_bCoinsTransfer = GetConVarBool(g_hCoinsTransfer);
	HookConVarChange(g_hCoinsTransfer, OnConVarChange);
	
	g_hLeaderLeave = CreateConVar("sm_clans_leaderleave", "1", "Can clan leader leave a clan (1 - yes, 0 - no)", 0, true, 0.0, true, 1.0);
	g_bLeaderLeave = GetConVarBool(g_hLeaderLeave);
	HookConVarChange(g_hLeaderLeave, OnConVarChange);
	
	g_hClanCreationCD = CreateConVar("sm_clans_cclancd", "1440", "Clan creation cooldown", 0, true, 0.0);
	g_iClanCreationCD = GetConVarInt(g_hClanCreationCD);
	HookConVarChange(g_hClanCreationCD, OnConVarChange);
	
	g_hNoClanTag = CreateConVar("sm_clans_noclan_notag", "0", "Set an empty clan tag to player, who isn't in any clan (1 - yes, 0 - no)", 0, true, 0.0, true, 1.0);
	g_bNoClanTag = GetConVarBool(g_hNoClanTag);
	HookConVarChange(g_hNoClanTag, OnConVarChange);
	
	g_hRenameClanPrice = CreateConVar("sm_clans_renameprice", "0", "Clan rename price", 0, true, 0.0);
	g_iRenameClanPrice = GetConVarInt(g_hRenameClanPrice);
	HookConVarChange(g_hRenameClanPrice, OnConVarChange);
	
	AutoExecConfig(true, "clans_settings", "clans");
}

void OnConVarChange(Handle hCvar, const char[] oldValue, const char[] newValue)
{
	if(hCvar == g_hExpandingCost) 
		g_iExpandingCost = StringToInt(newValue);
		
	else if(hCvar == g_hMaxClanMembers)
		g_iMaxClanMembers = StringToInt(newValue);
		
	else if(hCvar == g_hExpandValue)
		g_iExpandValue = StringToInt(newValue);
		
	else if(hCvar == g_hStartSlotsInClan)
		g_iStartSlotsInClan = StringToInt(newValue);
		
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
			PrepareDatabaseToLog();
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
		g_bNoClanTag = StringToInt(newValue) == 1;
		
	else if(hCvar == g_hLeaderChange)
		g_bLeaderChange = StringToInt(newValue) == 1;
		
	else if(hCvar == g_hCoinsTransfer)
		g_bCoinsTransfer = StringToInt(newValue) == 1;
		
	else if(hCvar == g_hLeaderLeave)
		g_bLeaderLeave = StringToInt(newValue) == 1;
		
	else if(hCvar == g_hClanCreationCD)	//1.7
		g_iClanCreationCD = StringToInt(newValue);
		
	else if(hCvar == g_hRenameClanPrice) //1.7
		g_iRenameClanPrice = StringToInt(newValue);
}