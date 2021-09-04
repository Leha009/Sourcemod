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
 * @param 		int clientID - client's ID in clan database
 * @param 		int clanid - client clan's index
 * @noreturn
*/
forward void Clans_OnClientAdded(int clientID, int clanid);

/**
 * Calls when clan client has been deleted
 *
 * @param 		int clientID - client's ID in clan database
 * @param 		int clanid - clan's index, where clan client was
 * @noreturn
*/
forward void Clans_OnClientDeleted(int clientID, int clanid);