untyped

global function SafeguardCallback_MapInit

void function SafeguardCallback_MapInit()
{
	if ( IsLobby() || GameRules_GetGameMode() != GAMEMODE_SAFEGUARD ) // Don't wanna this to trigger on menus nor outside payload mode itself
		return
	
	switch ( GetMapName() )
	{
		// Angel City - 85 seconds
		case "mp_angel_city":
			Safeguard_SetHarvesterLocation( < -2639, 4625, 119 >, < 0, 0, 0 > )
			Safeguard_SetNukeTitanSpawnLocation( < 2145, -3745, 192 >, < 0, 90, 0 > )
			AddCallback_OnSafeguardMode( ExecAngelCitySafeguard )
			break
		// Boom Town - 60 seconds
		case "mp_grave":
			Safeguard_SetHarvesterLocation( <2376, -4947, 2220>, < 0, 0, 0 > )
			Safeguard_SetNukeTitanSpawnLocation( <9607, -3472, 2132>, < 0, 180, 0 > )
			AddCallback_OnSafeguardMode( ExecBoomTownSafeguard )
			break
		// Complex - 85 seconds
		case "mp_complex3":
			Safeguard_SetHarvesterLocation( < -704, -1753, 524 >, < 0, 0, 0 > )
			Safeguard_SetNukeTitanSpawnLocation( < -9425, -4046, 580 >, < 0, 30, 0 > )
			AddCallback_OnSafeguardMode( ExecComplexSafeguard )
			break
		// Black Water Canal - 115 seconds
		case "mp_black_water_canal":
			Safeguard_SetHarvesterLocation( < 1750, -4870, -180 >, < 0, 0, 0 > )
			Safeguard_SetNukeTitanSpawnLocation( < -756, 4519, -230 >, < 0, 0, 0 > )
			AddCallback_OnSafeguardMode( ExecBlackWaterCanalSafeguard )
			break
		// Glitch - 95 seconds
		case "mp_glitch":
			Safeguard_SetHarvesterLocation( < -3767, -2019, 20 >, < 0, 0, 0 > )
			Safeguard_SetNukeTitanSpawnLocation( < 3506, 2175, 27 >, < 0, -90, 0 > )
			AddCallback_OnSafeguardMode( ExecGlitchSafeguard )
			break
		// Dry Dock - 90 seconds
		case "mp_drydock":
			Safeguard_SetHarvesterLocation( < 174, 3410, 120 >, < 0, 0, 0 > )
			Safeguard_SetNukeTitanSpawnLocation( < 575, -3348, 124 >, < 0, 180, 0 > )
			AddCallback_OnSafeguardMode( ExecDryDockSafeguard )
			break
		default:
			throw( "The map selected has no support for Safeguard gamemode" )
	}
}

void function ExecAngelCitySafeguard()
{
	array< entity > entitiesToDestroy = GetEntArrayByClass_Expensive( "info_spawnpoint_dropship_start" )
	
	foreach ( entity ent in entitiesToDestroy )
		ent.Destroy()
	
	AddSafeguardCustomShipStart( < -3993, 4948, 1024 >, < 0, 0, 0 >, TEAM_MILITIA )
	AddSafeguardCustomShipStart( < -4120, 4260, 1024 >, < 0, 0, 0 >, TEAM_MILITIA )
	AddSafeguardCustomShipStart( < 2676, -3600, 1024 >, < 0, 180, 0 >, TEAM_IMC )
	AddSafeguardCustomShipStart( < 1730, -3600, 1024 >, < 0, 0, 0 >, TEAM_IMC )
	
	AddSafeguardRouteNode( < 2130, -219, 120 > )
	AddSafeguardRouteNode( < 1586, 375, 120 > )
	AddSafeguardRouteNode( < -892, 499, 120 > )
	AddSafeguardRouteNode( < -902, 2612, 120 > )
	AddSafeguardRouteNode( < -2223, 3079, 120 > )
	AddSafeguardRouteNode( < -2642, 4377, 120 > )
	
	AddSafeguardFixedSpawnZoneForTeam( TEAM_IMC, < 3260, -2997, 199 >, 1024 )
	AddSafeguardFixedSpawnZoneForTeam( TEAM_IMC, < 1596, -2886, 208 >, 440 )
	AddSafeguardFixedSpawnZoneForTeam( TEAM_MILITIA, < -3383, 3683, 136 >, 512 )
	AddSafeguardFixedSpawnZoneForTeam( TEAM_MILITIA, < -3342, 2555, 128 >, 900 )
	AddSafeguardFixedSpawnZoneForTeam( TEAM_MILITIA, < -487, 4011, 200 >, 1024 )
}

void function ExecBoomTownSafeguard()
{
	array< entity > entitiesToDestroy = GetEntArrayByClass_Expensive( "info_spawnpoint_dropship_start" )
	
	foreach ( entity ent in entitiesToDestroy )
		ent.Destroy()

	AddSafeguardCustomShipStart( <1820, -3663, 2712>, < 0, -65, 0 >, TEAM_MILITIA )
	AddSafeguardCustomShipStart( <1884, -6452, 2712>, < 0, 45, 0 >, TEAM_MILITIA )
	AddSafeguardCustomShipStart( <10794, -4089, 2712>, < 0, 145, 0 >, TEAM_IMC )
	AddSafeguardCustomShipStart( <10035, -2689, 2712>, < 0, -115, 0 >, TEAM_IMC )
	
	AddSafeguardRouteNode( < 7222, -3497, 2238 > )
	AddSafeguardRouteNode( < 6721, -2901, 2238 > )
	AddSafeguardRouteNode( < 5542, -2912, 2238 > )
	AddSafeguardRouteNode( < 5014, -3837, 2260 > )
	AddSafeguardRouteNode( < 3835, -3840, 2238 > )
	AddSafeguardRouteNode( < 2692, -4906, 2238 > )

	AddSafeguardFixedSpawnZoneForTeam( TEAM_MILITIA, < 87, -4944, 2336 >, 1024 )
	AddSafeguardFixedSpawnZoneForTeam( TEAM_MILITIA, < 1340, -3144, 2132 >, 700 )
	AddSafeguardFixedSpawnZoneForTeam( TEAM_MILITIA, <1820, -6436, 2274>, 700 )
	AddSafeguardFixedSpawnZoneForTeam( TEAM_IMC, < 10809, -2656, 1989 >, 1024 )
	AddSafeguardFixedSpawnZoneForTeam( TEAM_IMC, < 10806, -4933, 1934>, 1024 )

	AddSafeguardBatterySpawner( <3866, -1446, 2306>, < 0, 0, 0 > )
	AddSafeguardBatterySpawner( <6500, -4652, 2375>, < 0, 45, 0 > )
}

void function ExecComplexSafeguard()
{
	array< entity > entitiesToDestroy = GetEntArrayByClass_Expensive( "info_spawnpoint_dropship_start" )
	
	foreach ( entity ent in entitiesToDestroy )
		ent.Destroy()

	AddSafeguardCustomShipStart( < -1956, 743, 1824 >, < 0, -45, 0 >, TEAM_MILITIA )
	AddSafeguardCustomShipStart( < -699, 940, 1824 >, < 0, -90, 0 >, TEAM_MILITIA )
	AddSafeguardCustomShipStart( < -9337, -4932, 1824 >, < 0, 110, 0 >, TEAM_IMC )
	AddSafeguardCustomShipStart( < -8972, -4716, 1824 >, < 0, 135, 0 >, TEAM_IMC )
	
	// Path - Variant 1
	AddSafeguardRouteNode( < -8734, -3362, 582 > )
	AddSafeguardRouteNode( < -7133, -3793, 615 > )
	AddSafeguardRouteNode( < -5911, -4134, 546 > )
	AddSafeguardRouteNode( < -5496, -3885, 586 > )
	AddSafeguardRouteNode( < -4134, -4563, 646 > )
	AddSafeguardRouteNode( < -3022, -3735, 646 > )
	AddSafeguardRouteNode( < -2462, -2771, 646 > )
	AddSafeguardRouteNode( < -1546, -2878, 646 > )
	AddSafeguardRouteNode( < -859, -2850, 514 > )
	AddSafeguardRouteNode( < -776, -1905, 514 > )

	AddSafeguardFixedSpawnZoneForTeam( TEAM_MILITIA, < -1230, 998, 590 >, 1700 )
	AddSafeguardFixedSpawnZoneForTeam( TEAM_IMC, < -9176, -4592, 6041 >, 1024 )

	AddSafeguardBatterySpawner( < -5293, -1734, 694 >, < 0, 45, 0 > )
	AddSafeguardBatterySpawner( < -3128, -1611, 652 >, < 0, 180, 0 > )
}

void function ExecBlackWaterCanalSafeguard()
{
	array< entity > entitiesToDestroy = GetEntArrayByClass_Expensive( "info_spawnpoint_dropship_start" )
	
	foreach ( entity ent in entitiesToDestroy )
		ent.Destroy()

	AddSafeguardCustomShipStart( < 0, -4125, 512 >, < 0, -25, 0 >, TEAM_MILITIA )
	AddSafeguardCustomShipStart( < 330, -3800, 512 >, < 0, -35, 0 >, TEAM_MILITIA )
	AddSafeguardCustomShipStart( < -1880, 3060, 512 >, < 0, 50, 0 >, TEAM_IMC )
	AddSafeguardCustomShipStart( < -705, 3115, 512 >, < 0, 90, 0 >, TEAM_IMC )
	
	AddSafeguardRouteNode( < 665, 4495, -262 > )
	AddSafeguardRouteNode( < 1685, 2854, -262 > )
	AddSafeguardRouteNode( < 1685, 1314, 0 > )
	AddSafeguardRouteNode( < 1106, 1293, 0 > )
	AddSafeguardRouteNode( < 356, 485, 0 > )
	AddSafeguardRouteNode( < 356, -990, -18 > )
	AddSafeguardRouteNode( < 961, -1534, -22 > )
	AddSafeguardRouteNode( < 1646, -1244, -52 > )
	AddSafeguardRouteNode( < 2495, -2116, -122 > )
	AddSafeguardRouteNode( < 2274, -3410, -202 > )
	AddSafeguardRouteNode( < 1777, -4540, -185 > )

	AddSafeguardFixedSpawnZoneForTeam( TEAM_MILITIA, < -300, -3384, 0 >, 1024 )
	AddSafeguardFixedSpawnZoneForTeam( TEAM_MILITIA, < 3672, -4922, -315 >, 1024 )
	AddSafeguardFixedSpawnZoneForTeam( TEAM_MILITIA, < 1005, -3245, -45 >, 512 )
	AddSafeguardFixedSpawnZoneForTeam( TEAM_IMC, < -1791, 3360, -323 >, 1024 )

	AddSafeguardBatterySpawner( < 3766, -2635, -300 >, < 0, 0, 0 > )
	AddSafeguardBatterySpawner( < 2352, 485, -255 >, < 0, 0, 0 > )
	AddSafeguardBatterySpawner( < -1340, 1653, -125 >, < 0, 0, 0 > )
}

void function ExecGlitchSafeguard()
{
	array< entity > entitiesToDestroy = GetEntArrayByClass_Expensive( "info_spawnpoint_dropship_start" )
	
	foreach ( entity ent in entitiesToDestroy )
		ent.Destroy()

	AddSafeguardCustomShipStart( < -4456, -766, 512 >, < 0, 0, 0 >, TEAM_MILITIA )
	AddSafeguardCustomShipStart( < -4456, -1456, 412 >, < 0, 0, 0 >, TEAM_MILITIA )
	AddSafeguardCustomShipStart( < 4103, 1054, 512 >, < 0, -180, 0 >, TEAM_IMC )
	AddSafeguardCustomShipStart( < 4082, 1712, 412 >, < 0, -180, 0 >, TEAM_IMC )
	
	AddSafeguardRouteNode( < 3437, 830, -8 > )
	AddSafeguardRouteNode( < 344, 1026, -8 > )
	AddSafeguardRouteNode( < -183, 488, -31 > )
	AddSafeguardRouteNode( < -209, -386, -24 > )
	AddSafeguardRouteNode( < -721, -762, -8 > )
	AddSafeguardRouteNode( < -3909, -646, -20 > )
	AddSafeguardRouteNode( < -3849, -1807, 14 > )

	AddSafeguardFixedSpawnZoneForTeam( TEAM_MILITIA, < -4789, -1456, 265 >, 512 )
	AddSafeguardFixedSpawnZoneForTeam( TEAM_MILITIA, < -4846, -400, 385 >, 800 )
	AddSafeguardFixedSpawnZoneForTeam( TEAM_IMC, < 4405, 1712, 265 >, 512 )
	AddSafeguardFixedSpawnZoneForTeam( TEAM_IMC, < 4463, 698, 385 >, 800 )

	AddSafeguardBatterySpawner( < 2170, -727, 62 >, < 0, 0, 0 > )
	AddSafeguardBatterySpawner( < -2586, 1004, 62 >, < 0, 0, 0 > )
}

void function ExecDryDockSafeguard()
{
	array< entity > entitiesToDestroy = GetEntArrayByClass_Expensive( "info_spawnpoint_dropship_start" )
	
	foreach ( entity ent in entitiesToDestroy )
		ent.Destroy()

	AddSafeguardCustomShipStart( < 1220, 5318, 624 >, < 0, -90, 0 >, TEAM_MILITIA )
	AddSafeguardCustomShipStart( < 439, 6290, 624 >, < 0, -90, 0 >, TEAM_MILITIA )
	AddSafeguardCustomShipStart( < 1775, -3428, 624 >, < 0, 180, 0 >, TEAM_IMC )
	AddSafeguardCustomShipStart( < 1775, -2872, 624 >, < 0, -160, 0 >, TEAM_IMC )

	AddSafeguardRouteNode( < -532, -2727, 162 > )
	AddSafeguardRouteNode( < -532, -1210, 256 > )
	AddSafeguardRouteNode( < 335, -1178, 256 > )
	AddSafeguardRouteNode( < 303, -331, 256 > )
	AddSafeguardRouteNode( < -58, -125, 256 > )
	AddSafeguardRouteNode( < 90, 1532, 256 > )
	AddSafeguardRouteNode( < 1279, 1571, 256 > )
	AddSafeguardRouteNode( < 1321, 2829, 83 > )
	AddSafeguardRouteNode( < 557, 3378, 81 > )
	
	AddSafeguardFixedSpawnZoneForTeam( TEAM_MILITIA, < 834, 4969, 303 >, 1200 )
	AddSafeguardFixedSpawnZoneForTeam( TEAM_IMC, < -75, -4927, 204 >, 1024 )
	AddSafeguardFixedSpawnZoneForTeam( TEAM_IMC, < 1903, -3328, 57 >, 512 )

	AddSafeguardBatterySpawner( < 1610, 337, 256 >, < 0, 0, 0 > )
	AddSafeguardBatterySpawner( < -1216, 75, 320 >, < 0, 0, 0 > )
}