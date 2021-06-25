#if defined _clans_included
	#endinput
#endif
#define _clans_included

#define MAX_CLANS 100									/*		Limit of clans 								*/
#define MAX_PLAYERSINCLANES 3000						/*		Limit of players in DB						*/
#define MAX_INVITATION_TIME 30							/*		Time in seconds to accept the invitation	*/

#define PERM_INVITE 1
#define PERM_GIVECOINS 2
#define PERM_EXPAND 3
#define PERM_KICK 4
#define PERM_TYPE 5
#define PERM_ROLE 6

/*				CLIENT DATA DEFINES		INTEGER			*/

#define CLIENT_CLANID 0									/*		Client clan's id							*/
#define CLIENT_ROLE 1									/*		Client' role								*/
#define CLIENT_KILLS 2									/*		Client's kills in his clan					*/
#define CLIENT_DEATHS 3									/*		Client's deaths in his clan					*/
#define CLIENT_TIME 4									/*		Client's time of joining clan				*/

#define CLIENT_MEMBER 0									/*		Client is clan member						*/
#define CLIENT_ELDER 1									/*		Client is elder of a clan					*/
#define CLIENT_COLEADER 2								/*		Client is co-leader of a clan				*/
#define CLIENT_LEADER 4									/*		Client is leader of a clan					*/


/*				CLIENT DATA DEFINES		STRING			*/

#define CLIENT_NAME 0									/*		Client's name in database					*/
#define CLIENT_STEAMID 1								/*		Client's STEAM ID in database				*/

/*				CLAN DATA DEFINES		INTEGER			*/

#define CLAN_MEMBERS 0									/*		Amount of members in clan					*/
#define CLAN_MAXMEMBERS 1								/*		Maximum amount of members in clan			*/
#define CLAN_KILLS 2									/*		Clan's kills								*/
#define CLAN_DEATHS 3									/*		Clan's deaths								*/
#define CLAN_TIME 4										/*		Clan's time of creating						*/
#define CLAN_COINS 5									/*		Clan's coins								*/
#define CLAN_TYPE 6										/*		Clan's type									*/

/*				CLAN DATA DEFINES		STRING			*/

#define CLAN_NAME 0										/*		Clan's name									*/
#define CLAN_LEADERNAME 1								/*		Clan leader's name 							*/
#define CLAN_LEADERID 2									/*		Clan leader's STEAMID						*/
#define CLAN_DATE 3										/*		Clan's date of creating						*/

/*				CLAN TOP DEFINES		INTEGER			*/

#define TOP_KILLS 0										/*		Top by kills								*/
#define TOP_DEATHS 1									/*		Top by deaths								*/
#define TOP_EXISTTIME 2									/*		Top by exist time							*/
#define TOP_MEMBERS 3									/*		Top by number of members					*/
#define TOP_COINS 4										/*		Top by number of clan coins					*/

/*							 			Forwards							 			*/

/**
 * Calls when client opens admin clan menu
 *
 * @param 		Handle adminClanMenu - adminMenu handle
 * @param 		int client - client's index
 * @noreturn
*/
forward void Clans_OnAdminClanMenuOpened(Handle adminClanMenu, int client);

/**
 * Calls when client selects menu item in admin clan menu
 *
 * @param 		Handle adminClanMenu - admin clan menu handle
 * @param 		int client - client's index
 * @param 		int option - selected option
 * @noreturn
*/
forward void Clans_OnAdminClanMenuSelected(Handle adminClanMenu, int client, int option);

/**
 * Calls when client opens main clan menu
 *
 * @param 		Handle clanMenu - clan menu handle
 * @param 		int client - client's index
 * @noreturn
*/
forward void Clans_OnClanMenuOpened(Handle clanMenu, int client);

/**
 * Calls when client selects menu item in main clan menu
 *
 * @param 		Handle clanMenu - main clan menu handle
 * @param 		int client - client's index
 * @param 		int option - selected option
 * @noreturn
*/
forward void Clans_OnClanMenuSelected(Handle clanMenu, int client, int option);

/**
 * Calls when client opens a clan's stats
 *
 * @param 		Handle clanStatsMenu - clan stats menu handle
 * @param 		int client - client's index
 * @noreturn
*/
forward void Clans_OnClanStatsOpened(Handle clanStatsMenu, int client);

/**
 * Calls when client opens a player's stats
 *
 * @param 		Handle playerStatsMenu - player stats menu handle
 * @param 		int client - client's index
 * @noreturn
*/
forward void Clans_OnPlayerStatsOpened(Handle playerStatsMenu, int client);

/**
 * Calls when clans have been loaded
 *
 * @noreturn
*/
forward void Clans_OnClansLoaded();

/**
 * Calls when clan has been added
 *
 * @param 		int clanid - clan's index
 * @param 		int client - client's index, who created the clan
 * @noreturn
*/
forward void Clans_OnClanAdded(int clanid, int client);

/**
 * Calls when clan has been deleted
 *
 * @param 		int clanid - clan's index
 * @noreturn
*/
forward void Clans_OnClanDeleted(int clanid);

/**
 * Calls when new clan client has been added
 *
 * @param 		int client - client's index
 * @param 		int clientID - client's ID in clan database
 * @param 		int clanid - client clan's index
 * @noreturn
*/
forward void Clans_OnClientAdded(int client, int clientID, int clanid);

/**
 * Calls when clan client has been deleted
 *
 * @param 		int clientID - client's ID in clan database
 * @param 		int clanid - clan's index, where clan client was
 * @noreturn
*/
forward void Clans_OnClientDeleted(int clientID, int clanid);


/*							 			CLIENTS							 			*/

/**
 * Get client's id in database
 *
 * @param		client - client's index
 * @return		client's id in database
 */
native int Clans_GetClientID(int client);

/**
 * Check if client is clan leader
 *
 * @param		clientID - client's id in database
 * @return		true - player is clan leader, false - otherwise
 */
native bool Clans_IsClanLeader(int clientID);

/**
 * Check if client is clan co-leader
 *
 * @param		clientID - client's id in database
 * @return		true - player is clan co-leader, false - otherwise
 */
native bool Clans_IsClanCoLeader(int clientID);

/**
 * Check if client is clan elder
 *
 * @param		clientID - client's id in database
 * @return		true - player is clan elder, false - otherwise
 */
native bool Clans_IsClanElder(int clientID);

/**
 * Get client's role in his/her clan
 *
 * @param		clientID - client's id in database
 * @return		client's role
 */
native int Clans_GetClientRole(int clientID);

/**
 * Get client clan's id in database
 *
 * @param		clientID - client's id in database
 * @return		client clan's id in database
 */
native int Clans_GetClientClan(int clientID);

/**
 * Get online client clan's id in database
 *
 * @param		clientID - client's id at server
 * @return		client clan's id in database, -1 if client isn't in any clan
 */
native int Clans_GetOnlineClientClan(int client);

/**
 * Get client's number of kills in current clan
 *
 * @param		clientID - client's id in database
 * @return		client's number of kills
 */
native int Clans_GetClientKills(int clientID);

/**
 * Set client's kills in clan
 *
 * @param		clientID - client's id in database
 * @param		kills - number of kills to set
 * @return 		true if successed, false otherwise
 */
native bool Clans_SetClientKills(int clientID, int kills);

/**
 * Get client's number of deaths in current clan
 *
 * @param		clientID - client's id in database
 * @return		client's number of deaths
 */
native int Clans_GetClientDeaths(int clientID);

/**
 * Set client's deaths in clan
 *
 * @param		clientID - client's id in database
 * @param		deaths - number of deaths to set
 * @return 		true if successed, false otherwise
 */
native bool Clans_SetClientDeaths(int clientID, int deaths);

/**
 * Check if online clients are in different clans
 *
 * @param		client - first client's index
 * @param		other - other client's index
 * @return		true if they are in different clans, false otherwise
 */
native bool Clans_AreInDifferentClans(int client, int other);

/**
 * Check if online client is in any clan
 *
 * @param		client - client's index
 * @return		true if client's in clan, false otherwise
 */
native bool Clans_IsClientInClan(int client);

/**
 * Show player's stats to client
 *
 * @param		client - client's index, who will see the stats
 * @param		otherID - player's id in database, whose stats will be seen
 * @return		true if successed, false otherwise
 */
native bool Clans_ShowPlayerInfo(int client, int otherID);

/**
 * Get a permission to create a clan for client
 *
 * @param		client - client's index, who will see the stats
 * @param		bool status - true to give permission, false to take it
 * @return		true if client has the permission, false otherwise
 */
native bool Clans_GetCreatePerm(int client);

/**
 * Set a permission to create a clan for client
 *
 * @param		client - client's index, who will see the stats
 * @param		bool status - true to give permission, false to take it
 * @noreturn
 */
native void Clans_SetCreatePerm(int client, bool status);
 
/*									CLANS									*/

/**
 * Check if clan is valid
 *
 * @param 		clanid - clan's index
 * @return 		true - valid, false - otherwise
 */
native bool Clans_IsClanValid(int clanid);

/**
 * Get name of clan
 *
 * @param		clanid - clan's index
 * @param 		buffer - buffer string to keep the name
 * @param 		bufflen - length of buffer string (MAX_NAME_LENGTH+1)
 * @noreturn
 */
native void Clans_GetClanName(int clanid, char[] buffer, int bufflen);

/**
 * Get clan's number of kills
 *
 * @param		clanid - clan's index
 * @return		number of clan kills
 */
native int Clans_GetClanKills(int clanid);

/**
 * Set number of kills in clan
 *
 * @param		clanid - clan's index
 * @param 		kills - clan kills to set
 * @return		true if successed, false otherwise
 */
native bool Clans_SetClanKills(int clanid, int kills);

/**
 * Get clan's number of deaths
 *
 * @param		clanid - clan's index
 * @return		number of clan deaths
 */
native int Clans_GetClanDeaths(int clanid);

/**
 * Set number of deaths in clan
 *
 * @param		clanid - clan's index
 * @param 		deaths - clan coins to set
 * @return		true if successed, false otherwise
 */
native bool Clans_SetClanDeaths(int clanid, int deaths);

/**
 * Get clan's number of coins
 *
 * @param		clanid - clan's index
 * @return		number of clan coins
 */
native int Clans_GetClanCoins(int clanid);

/**
 * Set number of coins in clan
 *
 * @param		clanid - clan's index
 * @param 		coins - clan coins to set
 * @return		true if successed, false otherwise
 */
native bool Clans_SetClanCoins(int clanid, int coins);

/**
 * Get number of players in clan
 *
 * @param		clanid - clan's index
 * @return		number of members in clan
 */
native int Clans_GetClanMembers(int clanid);

/**
 * Set number of players in clan
 *
 * @param		clanid - clan's index
 * @param 		members - number of players in clan to set
 * @return		true if successed, false otherwise
 */
native bool Clans_SetClanMembers(int clanid, int members);

/**
 * Get max number of players in clan
 *
 * @param		clanid - clan's index
 * @return		max number of members in clan
 */
native int Clans_GetClanMaxMembers(int clanid);

/**
 * Set max number of players in clan
 *
 * @param		clanid - clan's index
 * @param 		maxMembers - max number of players in clan to set
 * @return		true if successed, false otherwise
 */
native bool Clans_SetClanMaxMembers(int clanid, int maxMembers);

/**
 * Show clan's stats to client
 *
 * @param		client - client's index, who will see the stats
 * @param		clanid - clan's id, whose stats will be shown
 * @return		true if successed, false otherwise
 */
native bool Clans_ShowClanInfo(int client, int clanid);

/**
 * Show clan members to client
 *
 * @param		client - client's index, who will see members in clan
 * @param 		clanid - clan's id, whose members will be shown
 * @param 		showFlags - flags to members to show: 
 *							1st bit - client will be shown in menu, 
 *							2nd bit - don't show clients whose role is above client's one
 * info field in menu item - steam id of clan members
 * display field in menu item - member's name
 * @return		true if successed, false otherwise
 */
native bool Clans_ShowClanMembers(int client, int clanid, int showFlags);

/**
 * Show list of clans to client
 *
 * @param		client - client's index, who will see clans
 * @param bool showClientClan - flag if client's clan will be shown in menu
 * info field in menu item - clanid
 * display field in menu item - clan's name
 * @return		true if successed, false otherwise
 */
native bool Clans_ShowClanList(int client);