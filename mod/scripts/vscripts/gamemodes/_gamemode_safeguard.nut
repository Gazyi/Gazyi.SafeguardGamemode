untyped
global function GamemodeSafeguard_Init
global function AddCallback_OnSafeguardMode
global function Safeguard_SetHarvesterLocation
global function Safeguard_SetHarvesterStartDelay
global function Safeguard_SetNukeTitanSpawnLocation
global function AddSafeguardRouteNode
global function AddSafeguardCustomShipStart
global function AddSafeguardFixedSpawnZoneForTeam
global function AddSafeguardCustomMapProp
global function AddSafeguardBatterySpawner
global function RateSpawnpoints_Safeguard
#if DEV
global function SafeguardSpawnBatterySpawner
#endif

// Score values
const int SCORE_KILL = 50 // Generic player kill.
const int SCORE_KILL_ASSIST = 25 // Generic player kill assist.
const int SCORE_KILL_HEADSHOT = 10 // Headshot player kill.
const int SCORE_KILL_EXECUTION = 100 // Execution player kill.
const int SCORE_ATTACKER_KILL_BONUS = 50 // Escort player kills defender player.
const int SCORE_DEFENDER_KILL_BONUS = 50 // Defender player kills escorting player.
const int SCORE_ATTACKER_KILL_NPC = 10 // Escort player kills defender NPC.
const int SCORE_DEFENDER_KILL_NPC = 10 // Defender player kills escorting NPC.

const int SCORE_TITAN_ESCORT = 10 // Player escorting Titan ( 20/s ).
const int SCORE_TITAN_REACHED_GOAL = 300 // Titan reached Harvester.
const int SCORE_DEFENDER_RODEO = 15 // Defender player rodeoing escort Titan ( 30/s ).
const int SCORE_TITAN_DOOMED = 150 // Player Doomed Titan.
const int SCORE_TITAN_REPAIR = 100 // Player repairing non-doomed Titan.
const int SCORE_TITAN_REPAIR_DOOMED = 150 // Player repairing doomed Titan.
// Score values end

const float SAFEGUARD_ESCORT_DISTANCE = 512.0
const float SAFEGUARD_HARVESTER_WARNING_DISTANCE = 2048.0
const float SAFEGUARD_HARVESTER_ALERT_DISTANCE = 1800.0
const float PATH_TRACKER_REFRESH_FREQUENCY = 2.0
const float PATH_TRACKER_MOVE_TIME_BETWEEN_POINTS = 1.0

const float CROSSHAIR_VERT_OFFSET = 32

struct SafeguardPlayer
{
	float escortDistance = 0.0 // For stats
	bool nearNukeTitan = false // For logic
	float escortTime = 0.0 // For boosts
	float rodeoTime = 0.0 // For boosts
	float titanDamageScore = 0.0 // For boosts
}

struct 
{
	// Gamemode
	array< void functionref() > safeguardCallbacks
	array< entity > safeguardSpawnZones
	table< entity, SafeguardPlayer > matchPlayers
	int stopwatchRules = 0
	float bestAttackTime = 0.0
	int bestAttackTeam = TEAM_UNASSIGNED
	int bestNumRouteNodes = 0
	float bestTitanDistanceCovered = 0.0
	int bestTitanDistanceTeam = TEAM_UNASSIGNED
	// Harvester
	HarvesterStruct& militiaHarvester
	vector harvesterSpawnSpot = < 0, 0, 0 >
	vector harvesterSpawnAngle = < 0, 0, 0 >
	string harvesterNoSpawnArea
	float harvesterStartDelay = 13.5
	// Nuke Titan
	entity theNukeTitan = null
	vector nukeTitanSpawnSpot = < 0, 0, 0 >
	vector nukeTitanSpawnAngle = < 0, 0, 0 >
	//int nukeTitanShieldHack = 0
	int nukeTitanMaxShield = SAFEGUARD_TITAN_MAX_SHIELD
	float nukeTitanAutoRepairTime = SAFEGUARD_TITAN_AUTOREPAIR_TIME
	entity nukeTitanMarker = null
	bool nukeTitanIsMoving = false
	bool nukeTitanIsDoomed = false
	bool nukeTitanIsNearHarvester = false
	float nukeTitanDistanceCovered = 0.0
	array< vector > titanRoute
	int currentRouteNode
	// Battery spawners
	array< vector > batterySpawnerSpots
	array< vector > batterySpawnerAngles
	int batterySpawnersEnabled = SAFEGUARD_BATTERY_SPAWNERS
	float batterySpawnDelay = SAFEGUARD_BATTERY_SPAWN_DELAY
	float batteryRespawnDelay = SAFEGUARD_BATTERY_RESPAWN_DELAY
	// Custom props
	array< vector > mapPropSpots
	array< vector > mapPropAngles
	array< asset > mapPropAsset
	// Other
	int attackerTeam = TEAM_IMC
	int defenderTeam = TEAM_MILITIA
	float attackerRoundTime = 0.0

} file

void function GamemodeSafeguard_Init()
{
	// Precache
	PrecacheModel( CTF_FLAG_BASE_MODEL )
	PrecacheParticleSystem( BATTERY_FX_FRIENDLY )
	// Gamemode parameters
	SetRoundBased( true ) // Start as round based.
	SetSwitchSidesBased( true )
	//ClassicMP_SetLevelIntro( ClassicMP_DefaultNoIntro_Setup, ClassicMP_DefaultNoIntro_GetLength() )
	// No SetAttackDefendBased?
	level.attackDefendBased = true
	level.nv.attackingTeam = TEAM_IMC
	// Signals
	RegisterSignal( "FD_ReachedHarvester" ) //For Nuke Titan navigation
	RegisterSignal( "SafeguardNukeTitanStopped" )
	RegisterSignal( "SafeguardNukeTitanRepaired" )
	RegisterSignal( "HealthChanged" ) // For Harvester
	// Gamestate callbacks
	AddCallback_EntitiesDidLoad( SafeguardOnEntitiesDidLoad )
	AddCallback_OnRoundEndCleanup( SafeguardOnRoundEndCleanup )
	AddCallback_GameStateEnter( eGameState.PickLoadout, SafeguardOnPickLoadout )
	AddCallback_GameStateEnter( eGameState.Prematch, SafeguardOnPrematch )
	AddCallback_GameStateEnter( eGameState.SwitchingSides, SafeguardOnSwitchingSides )
	AddCallback_GameStateEnter( eGameState.Playing, SafeguardOnPlayingState )
	AddCallback_GameStateEnter( eGameState.WinnerDetermined, SafeguardOnWinnerDetermined )
	SetTimeoutWinnerDecisionFunc( Safeguard_TimeoutWinner )
	// Client callbacks
	AddCallback_OnClientConnected( SafeguardOnClientConnected )
	AddCallback_OnClientDisconnected( SafeguardOnPlayerDisconnected )
	//AddCallback_OnPlayerRespawned( SafeguardOnPlayerRespawned )
	// Entity callbacks
	AddCallback_OnNPCKilled( SafeguardOnKilledNPCPlayer )
	AddCallback_OnPlayerKilled( SafeguardOnKilledNPCPlayer )
	// Titan callbacks
	AddOnRodeoStartedCallback( SafeguardOnRodeoStarted )
	AddOnRodeoEndedCallback( SafeguardOnRodeoEnded )
	AddCallback_OnTitanDoomed( SafeguardOnTitanDoomed )
	// Battery callbacks
	#if NORTHSTARCUSTOM
	AddOnApplyBatteryCallback( SafeguardOnApplyBattery )
	#else
	SetApplyBatteryCallback( SafeguardOnApplyBattery ) // There's only 1 apply battery callback, higher priority mods will override that!
	#endif
	svGlobal.onTouchHealthKitCallbacks[ "item_titan_battery" ].clear() 	// HACK: Removing Rodeo_OnTouchBatteryPack from global callbacks
	AddCallback_OnTouchHealthKit( "item_titan_battery", SafeguardOnBatteryTouch )
	// Earn Meter
	SetTitanMeterGainScale( 0.00006 ) //( 0.00008 ) // Full health Titan ( 12500 ) should give ~100% of Earn Meter
	// Earn Meter Scores
	// Pilots
	ScoreEvent_SetEarnMeterValues( "KillPilot", 0.1, 0.1 ) // Generic Pilot kill
	ScoreEvent_SetEarnMeterValues( "PilotAssist", 0.02, 0.03 ) // Generic Pilot kill assist
	ScoreEvent_SetEarnMeterValues( "Headshot", 0.0, 0.02 ) // Headshot Pilot kill
	ScoreEvent_SetEarnMeterValues( "FirstStrike", 0.0, 0.05 ) // First strike Pilot kill
	ScoreEvent_SetEarnMeterValues( "Execution", 0.01, 0.05 ) // Execution Pilot kill
	ScoreEvent_SetEarnMeterValues( "Nemesis", 0.01, 0.05 ) // Nemesis Pilot kill
	ScoreEvent_SetEarnMeterValues( "Comeback", 0.01, 0.05 ) // Comeback Pilot kill
	ScoreEvent_SetEarnMeterValues( "KilledMVP", 0.01, 0.05 ) // MVP Pilot kill
	ScoreEvent_SetEarnMeterValues( "HardpointAssault", 0.05, 0.05 ) // Bonus - Attacker Pilot kills defender Pilot when escorting Titan
	ScoreEvent_SetEarnMeterValues( "HardpointDefense", 0.05, 0.05 ) // Bonus - Defender Pilot kills attacker Pilot escorting Titan
	// AI
	ScoreEvent_SetEarnMeterValues( "KillGrunt", 0.02, 0.02 ) // Pilot kills Grunt
	ScoreEvent_SetEarnMeterValues( "KillSpectre", 0.02, 0.02 ) // Pilot kills Spectre
	ScoreEvent_SetEarnMeterValues( "LeechSpectre", 0.02, 0.02 ) // Pilot leech Spectre
	ScoreEvent_SetEarnMeterValues( "KillStalker", 0.02, 0.02 ) // Pilot kills Stalker
	ScoreEvent_SetEarnMeterValues( "KillSuperSpectre", 0.05, 0.05 ) // Pilot kills Reaper
	ScoreEvent_SetEarnMeterValues( "KillLightTurret", 0.02, 0.02 ) // Pilot kills Turret
	// Bonus - Attacker Pilot kills defender NPC when escorting Titan
	ScoreEvent_SetEarnMeterValues( "HardpointPerimeterDefense", 0.03, 0.03 )
	// Bonus - Defender Pilot kills attacker NPC escorting Titan
	ScoreEvent_SetEarnMeterValues( "HardpointSiege", 0.03, 0.03 )
	// Titan
	// Titan Damage
	ScoreEvent_SetEarnMeterValues( "PilotBatteryPickup", 0.0, 0.1 ) // Attacker picks up Battery
	ScoreEvent_SetEarnMeterValues( "PilotBatteryApplied", 0.0, 0.25 ) // Battery applied to Titan
	// FDShieldHarvester - Battery applied to Doomed Titan bonus
	ScoreEvent_SetDisplayType( GetScoreEvent( "FDShieldHarvester" ), eEventDisplayType.GAMEMODE | eEventDisplayType.MEDAL )
	ScoreEvent_SetEarnMeterValues( "FDShieldHarvester", 0.0, 0.1 )
	ScoreEvent_SetEarnMeterValues( "PilotBatteryStolen", 0.0, 0.25 ) // PilotBatteryStolen - Defender destroyed Battery
	ScoreEvent_SetDisplayType( GetScoreEvent( "DoomAutoTitan" ), eEventDisplayType.GAMEMODE | eEventDisplayType.MEDAL ) // Can't use calling card, because it returns Titan, not attacker
	ScoreEvent_SetEarnMeterValues( "DoomAutoTitan", 0.1, 0.15 ) // Titan is doomed
	// Defender rodeoing Titan for 5 seconds
	ScoreEvent_SetDisplayType( GetScoreEvent( "RodeoEnemyTitan" ), eEventDisplayType.GAMEMODE | eEventDisplayType.MEDAL )
	ScoreEvent_SetEarnMeterValues( "RodeoEnemyTitan", 0.05, 0.05 )
	// Escorting Titan for 5 seconds.
	ScoreEvent_SetDisplayType( GetScoreEvent( "MarkedEscort" ), eEventDisplayType.GAMEMODE | eEventDisplayType.MEDAL )
	ScoreEvent_SetEarnMeterValues( "MarkedEscort", 0.05, 0.05 )
	
	// Caching gamemode ConVars
	file.nukeTitanMaxShield = GetCurrentPlaylistVarInt( "safeguard_titan_maxshield", SAFEGUARD_TITAN_MAX_SHIELD )
	file.nukeTitanAutoRepairTime = GetCurrentPlaylistVarFloat( "safeguard_titan_autorepair_time", SAFEGUARD_TITAN_AUTOREPAIR_TIME )
	file.batterySpawnersEnabled = GetCurrentPlaylistVarInt( "safeguard_battery_spawners", SAFEGUARD_BATTERY_SPAWNERS )
	file.batterySpawnDelay = GetCurrentPlaylistVarFloat( "safeguard_battery_spawn_delay", SAFEGUARD_BATTERY_SPAWN_DELAY )
	file.batteryRespawnDelay = GetCurrentPlaylistVarFloat( "safeguard_battery_respawn_delay", SAFEGUARD_BATTERY_RESPAWN_DELAY )
	file.stopwatchRules = GetCurrentPlaylistVarInt( "safeguard_stopwatch", 0 )
}
// ========================== Gamemode Callbacks and Configuration ========================== //
void function AddCallback_OnSafeguardMode( void functionref() callback )
{
	file.safeguardCallbacks.append( callback )
}

void function Safeguard_SetHarvesterLocation( vector origin, vector angles )
{
	file.harvesterSpawnSpot = origin
	file.harvesterSpawnAngle = angles
}

void function Safeguard_SetHarvesterStartDelay( float delayTime )
{
	file.harvesterStartDelay = delayTime
}

void function Safeguard_SetNukeTitanSpawnLocation( vector origin, vector angles )
{
	file.nukeTitanSpawnSpot = origin
	file.nukeTitanSpawnAngle = angles
}

void function AddSafeguardRouteNode( vector origin )
{
	file.titanRoute.append( origin )
	#if DEV
	DebugDrawSphere( origin, 32, 255, 0, 0, true, 600 )
	#endif
}

void function AddSafeguardCustomShipStart( vector origin, vector angles, int team )
{
	entity shipSpawn = CreateEntity( "info_spawnpoint_dropship_start" )
	shipSpawn.SetOrigin( origin )
	shipSpawn.SetAngles( angles )
	SetTeam( shipSpawn, team )
	DispatchSpawn( shipSpawn )
	#if DEV
	DebugDrawSpawnpoint( shipSpawn, 0, 255, 255, true, 100.0 )
	#endif
}

void function AddSafeguardFixedSpawnZoneForTeam( int team, vector zoneLoc, float zoneRadius )
{
	entity zone = CreatePropScript( $"models/dev/empty_model.mdl", zoneLoc )
	zone.s.zoneRadius <- zoneRadius
	SetTeamSpawnZoneMinimapMarker( zone, team )
	file.safeguardSpawnZones.append( zone )
}

void function AddSafeguardCustomMapProp( asset modelasset, vector origin, vector angles )
{
	file.mapPropAsset.append( modelasset )
	file.mapPropSpots.append( origin )
	file.mapPropAngles.append( angles )
	PrecacheModel( modelasset )
}

void function AddSafeguardBatterySpawner( vector origin, vector angles )
{
	file.batterySpawnerSpots.append( origin )
	file.batterySpawnerAngles.append( angles )
}

// ========================== GAMESTATE CALLBACKS ========================== //
void function SafeguardOnEntitiesDidLoad()
{
	SafeguardCallback_MapInit()
	
	foreach ( callback in file.safeguardCallbacks )
		callback()

	// clean up original spawn zones
	mapSpawnZones.clear()
}

void function SafeguardOnRoundEndCleanup()
{
	#if DEV
	printt( "SafeguardOnRoundEndCleanup called!" )
	#endif
	
	// Clean up harvester effects and remove it.
	HarvesterStruct harvester = file.militiaHarvester

	if ( IsValid( harvester.particleBeam ) )
		harvester.particleBeam.Destroy()

	if( IsValid( harvester.particleSparks ) )
		harvester.particleSparks.Destroy()

	foreach( entity pFX in harvester.particleFXArray )
	{
		if( IsValid( pFX ) )
			pFX.Destroy()
	}

	harvester.particleFXArray.clear()

	if ( IsValid( harvester.harvester ) )
	{
		StopSoundOnEntity( harvester.harvester, HARVESTER_SND_HEALTHY )
		harvester.harvester.Destroy()
	}

	DeleteNoSpawnArea( file.harvesterNoSpawnArea )

	// Reset Game mode variables
	file.nukeTitanIsMoving = false
	file.nukeTitanIsDoomed = false
	file.nukeTitanIsNearHarvester = false
	file.currentRouteNode = 0
	file.nukeTitanDistanceCovered = 0.0
	// Reset player variables
	foreach ( player in GetPlayerArray() )
	{
		file.matchPlayers[player].nearNukeTitan = false
		file.matchPlayers[player].escortTime = 0.0
		file.matchPlayers[player].rodeoTime = 0.0
		file.matchPlayers[player].titanDamageScore = 0.0
	}

	#if DEV
	printt( "SafeguardOnRoundEndCleanup end!" )
	#endif
}

void function SafeguardOnPickLoadout()
{	
	if ( file.stopwatchRules == 0 && GetRoundsPlayed() > 1 )
	{
		waitthread SafeguardOvertimeSetupThread()
	}
}

void function SafeguardOnPrematch()
{
	SetGlobalNetInt( "attackerTeam", file.attackerTeam )
	SetGlobalNetInt( "defenderTeam", file.defenderTeam )
	SetGlobalNetInt( "nukeTitanState", SAFEGUARD_TITAN_STATE_STAND )

	Safeguard_SpawnHarvester()
	thread Safeguard_StartUpHarvester()

	if ( file.batterySpawnersEnabled > 0 && file.batterySpawnerSpots.len() > 0 )
		SafeguardCreateBatterySpawners()

	if ( file.mapPropSpots.len() > 0 )
		SafeguardCreateMapProps()
}

void function SafeguardOnPlayingState()
{
	// Additional game mod announcement
	if ( GetRoundsPlayed() > 0 )
	{
		foreach ( player in GetPlayerArray() )
		{
			thread ShowGameModeAnnouncementOnLand( player )
		}

		// Modify round time
		if ( file.bestAttackTeam != TEAM_UNASSIGNED )
		{
			if ( file.stopwatchRules > 0 ) // Change round time after first round
				SetRoundEndTime( file.bestAttackTime )
			else if ( GetRoundsPlayed() > 1 ) // Change round after second round
				SetRoundEndTime( file.bestAttackTime )
		}
	}
	
	Safeguard_SpawnNukeTitan()
	thread WaitForThirtySecondsLeftThreaded()

	if ( file.batterySpawnersEnabled > 0 && file.batterySpawnerSpots.len() > 0 )	
		thread WaitToAnnounceBatterySpawners()
}

void function ShowGameModeAnnouncementOnLand( entity player )
{
	player.EndSignal( "OnDeath" )
	player.EndSignal( "OnDestroy" )

	while ( !player.IsOnGround() && !player.IsWallRunning() && !player.IsWallHanging() )
		WaitFrame()

	TryGameModeAnnouncement( player )
}

void function WaitToAnnounceBatterySpawners()
{
	wait file.batterySpawnDelay - 7 // HACK
	foreach ( entity player in GetPlayerArray() )
	{
		Remote_CallFunction_NonReplay( player, "ServerCallback_SafeguardBatterySpawnersEnabled" )
	}
}

void function WaitForThirtySecondsLeftThreaded()
{
	svGlobal.levelEnt.EndSignal( "RoundEnd" ) // end this on round end
	float endTime = expect float ( GetServerVar( "roundEndTime" ) )
	// wait until 60sec left
	wait ( endTime - 60 ) - Time()
	if ( GamePlaying() )
		PlayMusicToAll( eMusicPieceID.LEVEL_LAST_MINUTE )
	// wait until 30sec left
	wait 30
	if ( GamePlaying() )
	{
		PlayFactionDialogueToTeam( "lts_atk30", file.attackerTeam )
		PlayFactionDialogueToTeam( "lts_def30", file.defenderTeam )
	}
}

void function RateSpawnpoints_Safeguard( int checkClass, array<entity> spawnpoints, int team, entity player )
{
	if ( HasSwitchedSides() )
		team = GetOtherTeam( team )

	foreach ( entity spawn in spawnpoints )
	{
		float rating = 0.0
		float nukeTitanDistance = 0.0
		float harvesterDistance = 0.0
		
		bool isDefender = player.GetTeam() == file.defenderTeam
		float nextWaypointDistance = Distance2D( spawn.GetOrigin(), file.titanRoute[file.currentRouteNode] )

		if ( IsAlive( file.theNukeTitan ) )
			nukeTitanDistance = Distance2D( spawn.GetOrigin(), file.theNukeTitan.GetOrigin() )

		if ( IsValid( file.militiaHarvester.harvester ) )
			harvesterDistance = Distance2D( spawn.GetOrigin(), file.militiaHarvester.harvester.GetOrigin() )

		if ( isDefender )
		{
			float distance = 0.0
			
			// Defender team use only spawnzones
			foreach ( entity zone in file.safeguardSpawnZones )
			{			
				if ( zone.GetTeam() == team )
				{
					distance = Distance2D( spawn.GetOrigin(), zone.GetOrigin() )
					
					if ( distance < zone.s.zoneRadius )
					{
						//rating += 1.0 - ( Distance2D( spawn.GetOrigin(), zone.GetOrigin() ) / 100.0 )
						rating += spawn.NearbyAllyScore( player.GetTeam(), "ai" )
						rating += spawn.NearbyAllyScore( player.GetTeam(), "pilot" )
						rating += spawn.NearbyAllyScore( player.GetTeam(), "titan" )
						rating += spawn.NearbyEnemyScore( player.GetTeam(), "ai" )
						rating += spawn.NearbyEnemyScore( player.GetTeam(), "pilot" )
						rating += spawn.NearbyEnemyScore( player.GetTeam(), "titan" )

						// Keep distance from Nuke Titan
						if ( IsAlive( file.theNukeTitan ) )
						{
							if ( nukeTitanDistance <= 2048 )
								rating += nukeTitanDistance / 2048
							else if ( nextWaypointDistance > 2048 )
								rating += nextWaypointDistance / 2048
							else
								rating += 10
						}
					}
					else
					{
						rating -= 100
					}
				}
			}
		}
		else
		{
			float distance = 0.0
			
			rating += spawn.NearbyAllyScore( player.GetTeam(), "ai" )
			rating += spawn.NearbyAllyScore( player.GetTeam(), "pilot" )
			rating -= spawn.NearbyAllyScore( player.GetTeam(), "titan" ) * 0.5 // Keep distance from Nuke Titan
			rating += spawn.NearbyEnemyScore( player.GetTeam(), "ai" )
			rating += spawn.NearbyEnemyScore( player.GetTeam(), "pilot" )
			rating += spawn.NearbyEnemyScore( player.GetTeam(), "titan" )
			
			foreach ( entity zone in file.safeguardSpawnZones )
			{
				if ( zone.GetTeam() != team )
				{
					distance = Distance2D( spawn.GetOrigin(), zone.GetOrigin() )
					
					if ( distance < zone.s.zoneRadius )
					{
						rating -= 10.0
					}
				}
				else
				{
					distance = Distance2D( spawn.GetOrigin(), zone.GetOrigin() )

					if ( distance < zone.s.zoneRadius )
					{
						rating += 2.0
					}
				}
			}

			// Keep distance from Nuke Titan
			if ( IsAlive( file.theNukeTitan ) )
				rating += nukeTitanDistance / 1024
			
			// Spawn closer to Titan than to Harvester
			if ( nukeTitanDistance > harvesterDistance )
				rating -= 10.0

			// Spawn closer to Titan than to next waypoint
			if ( nukeTitanDistance > nextWaypointDistance )
				rating -= 5.0

			// Keep distance from Harvester
			if ( harvesterDistance <= 3192 )
				rating -= 10.0

			// Don't spawn too far from Nuke Titan, but keep some distance
			if ( nukeTitanDistance > 3192 )
				rating -= 10.0
		}

		// Don't spawn too close to battery spawners when they're active
		if ( file.batterySpawnerSpots.len() > 0 )
		{
			if ( Time() - expect float( GetServerVar( "roundStartTime" ) ) > file.batterySpawnDelay * 0.75 )
			{
				foreach ( origin in file.batterySpawnerSpots )
				{
					float distance = Distance2D( spawn.GetOrigin(), origin )

					if ( distance < 256 )
						rating -= 5.0
				}
			}
		}

		if ( spawn == player.p.lastSpawnPoint )
			rating += GetConVarFloat( "spawnpoint_last_spawn_rating" )

		float spawnrating = spawn.CalculateRating( checkClass, player.GetTeam(), rating, rating * 0.25 )

		#if DEV
		if ( spawnrating > 0 && !player.IsBot() )
		{
			printt( "Spawn:", spawn.GetOrigin(), " Rating: ", spawnrating, isDefender ? "Team: Defenders" : "Team: Attackers" )
			printt( "Distance to Nuke Titan:", nukeTitanDistance )			
			printt( "Distance to Harvester:", harvesterDistance )
			DebugDrawSpawnpoint( spawn, 0, 0, 255, true, 30.0 )
		}
		#endif
	}
}

void function SafeguardOnWinnerDetermined()
{
	// If attackers failed to deliver Nuke Titan, detonate it.
	entity nukeTitan = file.theNukeTitan

	if ( IsValid( nukeTitan ) )
	{
		if ( IsAlive( nukeTitan ) )
		{
			if ( nukeTitan.IsFrozen() )
				nukeTitan.Unfreeze()
			
			thread AutoTitan_SelfDestruct( nukeTitan )
		}
	}

	// If game hits score limit, disable round based for epilogue.
	int winTeam = GetWinningTeam()

	#if DEV
	printt( "====================================" )
	printt( "Round number: ", GetRoundsPlayed() )
	printt( "Winning team: ", winTeam )
	printt( "Winning team score: ", GameRules_GetTeamScore( winTeam ) )
	printt( "Round time: ", Time() - expect float( GetServerVar( "roundStartTime" ) ) )
	printt( "Titan distance: ", file.nukeTitanDistanceCovered )
	printt( "Nodes passed: ", file.currentRouteNode )
	printt( "====================================" )
	printt( "Best time: ", file.bestAttackTime )
	printt( "Best nodes passed: ", file.bestNumRouteNodes )
	printt( "Best distance: ", file.bestTitanDistanceCovered )
	printt( "====================================" )
	#endif
	
	if ( GameRules_GetTeamScore( winTeam ) >= GetScoreLimit_FromPlaylist() )
	{
		SetRoundBased( false )
		return
	}
	
	// Save best amount of passed nodes
	if ( file.bestNumRouteNodes < file.currentRouteNode )
	{
		file.bestNumRouteNodes = file.currentRouteNode
		file.bestTitanDistanceTeam = file.attackerTeam
		#if DEV
		printt( "New best nodes passed: ", file.bestNumRouteNodes )
		#endif
	}
	
	// Save best Titan escort distance
	if ( file.bestTitanDistanceCovered < file.nukeTitanDistanceCovered )
	{
		file.bestTitanDistanceCovered = file.nukeTitanDistanceCovered
		file.bestTitanDistanceTeam = file.attackerTeam
		#if DEV
		printt( "New best Titan distance: ", file.bestTitanDistanceCovered, " Team: ", file.bestTitanDistanceTeam )
		#endif
	}
	
	// Save best attack time
	if ( winTeam == file.attackerTeam )
	{
		file.attackerRoundTime = Time() - expect float( GetServerVar( "roundStartTime" ) )

		// Save best attack time
		if ( file.bestAttackTime <= 0.0 )
		{
			file.bestAttackTime = file.attackerRoundTime
			file.bestAttackTeam = winTeam
			#if DEV
			printt( "New best attack time: ", file.bestAttackTime, " Team: ", file.bestAttackTeam )
			#endif
		}
		else
		{
			if ( file.attackerRoundTime < file.bestAttackTime )
			{
				file.bestAttackTime = file.attackerRoundTime
				file.bestAttackTeam = winTeam
				#if DEV
				printt( "New best attack time: ", file.bestAttackTime, " Team: ", file.bestAttackTeam )
				#endif
			}
		}
	}
	#if DEV
	printt( "====================================" )
	#endif
}

void function SafeguardOvertimeSetupThread()
{
	WaitFrame()

	// Already switch sided - IMC defending, Militia attacking
	bool overtimeSwitchingSides = false

	#if DEV
	printt( "Overtime setup!" )
	printt( "Current Attacker Team: ", file.attackerTeam )
	printt( "Best Attack Time Team: ", file.bestAttackTeam )
	printt( "Best Attack Distance Team: ", file.bestTitanDistanceTeam )
	#endif

	if ( file.bestAttackTeam != TEAM_UNASSIGNED )
	{
		if ( file.bestAttackTeam == file.attackerTeam )
		{
			// Revert side switch
			//level.nv.switchedSides = false
			SetServerVar( "switchedSides", 0 )
			overtimeSwitchingSides = true
			SafeguardOnSwitchingSides()
		}
	}
	else
	{
		// Checkpoint and distance check
		if ( file.bestTitanDistanceTeam == file.attackerTeam )
		{
			// Revert side switch
			//level.nv.switchedSides = false
			SetServerVar( "switchedSides", 0 )
			overtimeSwitchingSides = true
			SafeguardOnSwitchingSides()
		}
	}

	foreach ( player in GetPlayerArray() )
	{
		Remote_CallFunction_NonReplay( player, "ServerCallback_SafeguardOvertimeAnnouncement", overtimeSwitchingSides )
	}

	wait ROUND_WINNING_KILL_REPLAY_SCREEN_FADE_TIME // 4 seconds
}
// Switching sides doesn't change team index
void function SafeguardOnSwitchingSides()
{
	int oldAttackerTeam = file.attackerTeam
	int oldDefenderTeam = file.defenderTeam

	file.attackerTeam = oldDefenderTeam
	file.defenderTeam = oldAttackerTeam

	level.nv.attackingTeam = oldDefenderTeam

	SetGlobalNetInt( "attackerTeam", file.attackerTeam ) 
	SetGlobalNetInt( "defenderTeam", file.defenderTeam )
}

int function Safeguard_TimeoutWinner()
{
	// Stopwatch rules
	if ( file.stopwatchRules > 0 )
	{
		// If attackers didn't win in first round, compare Titan escort distance.
		if ( GetRoundsPlayed() > 0 && file.bestAttackTeam == TEAM_UNASSIGNED ) // Second round
		{
			SetRoundBased( false )
			int winnerTeam = TEAM_UNASSIGNED

			if ( file.bestNumRouteNodes > file.currentRouteNode ) // First, check amount of route nodes Titan passed.
				winnerTeam = file.defenderTeam
			else if ( file.bestNumRouteNodes < file.currentRouteNode )
				winnerTeam = file.attackerTeam

			if ( file.bestTitanDistanceCovered > file.nukeTitanDistanceCovered ) // Check escort distance
				winnerTeam = file.defenderTeam
			else if ( file.bestTitanDistanceCovered < file.nukeTitanDistanceCovered )
				winnerTeam = file.attackerTeam

			AddTeamScore( winnerTeam, 2 ) // Manually update score
			return winnerTeam
		}
	}

	if ( !IsRoundBased() )
		AddTeamScore( file.defenderTeam, 1 ) // Manually update score

	return file.defenderTeam
}
// ========================== ENTITY CALLBACKS ========================== //
void function SafeguardOnClientConnected( entity player )
{
	SafeguardPlayer playerData
	file.matchPlayers[player] <- playerData
	
	thread TrackNearTitan( player )
}

void function TrackNearTitan( entity player )
{	
	player.EndSignal( "OnDestroy" )
	
	if ( !IsValidPlayer( player ) )
		return

	while ( !IsValid( file.theNukeTitan ) ) // Wait for the Nuke Titan to spawn in
		WaitFrame()
		
	#if DEV
	printt( "Nuke Titan spawned:", file.theNukeTitan )
	#endif
	float lastTime = Time()

	while ( IsValidPlayer( player ) )
	{
		if ( GamePlaying() && IsValid( file.theNukeTitan ) )
		{
			float currentTime = Time()
			float deltaTime = currentTime - lastTime
			/*
			#if DEV
			printt( "Player: ", player )
			printt( "Team:", player.GetTeam() )
			#endif
			*/
			if ( player.GetTeam() == file.attackerTeam && file.matchPlayers[player].nearNukeTitan )
			{
				// Get rounded distance from score, add rounded amount escortDistance to it.	
				int scoreDistance = player.GetPlayerGameStat( PGS_DISTANCE_SCORE )
				float newDistance = file.matchPlayers[player].escortDistance
				int deltaDistance = floor(newDistance - scoreDistance).tointeger()
				#if DEV
				//printt( "Player: ", player, " scoreDistance: ", scoreDistance, " newDistance: ", newDistance, " deltaDistance: ", deltaDistance )
				#endif
				if ( deltaDistance > 0 )
					player.AddToPlayerGameStat( PGS_DISTANCE_SCORE, deltaDistance )

				file.matchPlayers[player].escortTime += deltaTime
				/*
				#if DEV
				printt( "Escorting Titan! Time to medal:", file.matchPlayers[player].escortTime )
				#endif
				*/
				if ( file.matchPlayers[player].escortTime >= 5 )
				{
					#if DEV
					printt( "Player:", player, "earned MarkedEscort" )
					#endif
					file.matchPlayers[player].escortTime -= 5
					AddPlayerScore( player, "MarkedEscort" )
				}
			}
			else if ( player.GetTeam() == file.defenderTeam && Rodeo_IsAttached( player ) )
			{
				file.matchPlayers[player].rodeoTime += deltaTime
				/*
				#if DEV
				printt( "Rodeoing Titan. Time to medal: ", file.matchPlayers[player].rodeoTime )
				#endif
				*/
				if ( file.matchPlayers[player].rodeoTime >= 5 )
				{
					#if DEV
					printt( "Player:", player, "earned RodeoEnemyTitan" )
					#endif
					file.matchPlayers[player].rodeoTime -= 5
					AddPlayerScore( player, "RodeoEnemyTitan" )
				}
			}

			lastTime = currentTime
		}

		WaitFrame()
	}
}

void function SafeguardOnPlayerDisconnected( entity player )
{
	if ( player in file.matchPlayers )
		delete file.matchPlayers[player]
}

bool function SafeguardOnBatteryTouch( entity player, entity batteryPickup )
{	
	#if DEV
	printt( "Battery touched: ", batteryPickup )
	#endif

	// Attackers can destroy dropped batteries.
	if ( player.GetTeam() != file.attackerTeam )
	{
		if ( IsAlive( player ) && !player.IsPhaseShifted() && !IsValid( batteryPickup.GetParent() ) && batteryPickup.s.pickedOnce )
		{
			AddPlayerScore( player, "PilotBatteryStolen" )
			EmitSoundAtPosition( TEAM_UNASSIGNED, batteryPickup.GetOrigin(), "Object_Dissolve" )
			// Fancy destroy effect
			entity batteryProp = CreatePropDynamicLightweight( RODEO_BATTERY_MODEL, batteryPickup.GetOrigin(), batteryPickup.GetAngles() )
			batteryProp.SetSkin( batteryPickup.GetSkin() )
			batteryProp.Dissolve( ENTITY_DISSOLVE_NORMAL, < 0, 0, 0 >, 0 )
			return true // Destroy real battery or it'll be touched again.
		}
	}

	Safeguard_OnTouchBatteryPack_Internal( player, batteryPickup )
	//Basically always return false since we don't want the battery pack to go away when being touched. ApplyBatteryToTitan() etc will deal with lifetime of battery
	return false
}
// Modified Rodeo_OnTouchBatteryPack_Internal
void function Safeguard_OnTouchBatteryPack_Internal( entity player, entity batteryPickup )
{
	float currentTime = Time()

	#if DEV
	printt( "currentTime: ", currentTime )
	printt( "spawnTime: ", batteryPickup.e.spawnTime )
	printt( "touchEnabledTime: ", batteryPickup.s.touchEnabledTime )
	#endif
	
	/*
	if ( currentTime < batteryPickup.e.spawnTime + 0.3 )
		return
	*/
	
	if ( currentTime < batteryPickup.s.touchEnabledTime )
		return

	if ( player.GetTeam() != file.attackerTeam )
		return

	if ( !IsAlive( player ) )
		return

	if ( player.IsPhaseShifted() )
		return

	if ( IsValid( batteryPickup.GetParent() ) )
		return

	if ( PlayerHasMaxBatteryCount( player ) )
		return

	if ( IsCloaked( player ) )
		Battery_StopFX( batteryPickup )

	batteryPickup.SetPhysics( MOVETYPE_FLYGRAVITY )
	Rodeo_PilotPicksUpBattery_Silent( player, batteryPickup ) // Normal one is not global...
	batteryPickup.s.pickedOnce = true
	EmitSoundOnEntityOnlyToPlayer( player, player, "UI_TitanBattery_Pilot_PickUp" )
	AddPlayerScore( player, "PilotBatteryPickup", player )
	return
}

void function SafeguardOnRodeoStarted( entity rider, entity titan )
{
	if ( !IsAlive( titan ) )
		return
	
	if ( titan.GetTargetName() == "payloadNukeTitan" )
	{		
		if ( GetDoomedState( titan ) )
		{
			if ( rider.GetTeam() != titan.GetTeam() )
			{
				ForceTitanRodeoToEnd( titan )
				return
			}

			if ( !PlayerHasBattery( rider ) )
			{
				ForceTitanRodeoToEnd( titan )
				return
			}
		}

		Highlight_SetFriendlyHighlight( rider, "sp_friendly_pilot" )
		Highlight_SetEnemyHighlight( rider, "battery_thief" )

		if ( rider.GetTeam() != titan.GetTeam() )
		{
			SafeguardEmitNukeTitanVoiceLineToAttackers( "diag_gs_titanLegion_prime_rodeoWarning" )
		}
		else
		{
			SafeguardEmitNukeTitanVoiceLineToAttackers( "diag_gs_titanLegion_prime_allyRodeoAttach" )
		}
	}
}

void function SafeguardOnRodeoEnded( entity rider, entity titan )
{
	if ( IsValid( rider ) )
	{
		Highlight_ClearEnemyHighlight( rider )
		Highlight_ClearFriendlyHighlight( rider )
		
		if ( !GetDoomedState( titan ) )
		{
			if ( rider.GetTeam() != titan.GetTeam() )
			{
				if ( IsAlive( rider ) )
				{
					SafeguardEmitNukeTitanVoiceLineToAttackers( "diag_gs_titanLegion_prime_hostileLeftHull" )
				}
				else
				{
					SafeguardEmitNukeTitanVoiceLineToAttackers( "diag_gs_titanLegion_prime_killEnemyRodeo" )
				}
			}
		}	
	}
}

void function SafeguardOnApplyBattery( entity rider, entity titan, entity battery )
{
	#if DEV
	printt( "SafeguardOnApplyBattery called!" )
	#endif
	
	if ( file.nukeTitanIsDoomed )
	{
		#if DEV
		printt( "Titan was doomed, restore to full health!" )
		#endif
		
		RestoreTitan( titan, 1.0 ) // Full health with shields.
		titan.Signal( "SafeguardNukeTitanRepaired" )
		rider.AddToPlayerGameStat( PGS_SCORE, SCORE_TITAN_REPAIR_DOOMED )
	}
	else
	{
		rider.AddToPlayerGameStat( PGS_SCORE, SCORE_TITAN_REPAIR )
	}

	if ( IsValid( battery ) )
		battery.Destroy()

	SafeguardEmitNukeTitanVoiceLineToAttackers( "diag_gs_titanLegion_prime_batteryGot" )
}

void function SafeguardOnTitanDoomed( entity titan, var damageInfo )
{
	if ( !IsAlive( titan ) )
		return

	entity soul = titan.GetTitanSoul()
	
	if ( !IsValid( soul ) ) //Ejecting
		return

	if ( titan.GetTargetName() == "payloadNukeTitan" )
	{
		#if DEV
		printt( "Nuke Titan is doomed!" )
		#endif
		soul.SetShieldHealth( 0 )
		file.nukeTitanIsDoomed = true

		titan.SetNoTarget( true )
		titan.SetNoTargetSmartAmmo( true )

		if ( IsValid( file.nukeTitanMarker ) )
			file.nukeTitanMarker.Minimap_Hide( file.attackerTeam, null )

		// Throw current rider off
		SafeguardTitanThrowRiderOff( titan )
		#if DEV
		printt( "Calling SafeguardTitanDoomedThink!" )
		#endif

		entity attacker = DamageInfo_GetAttacker( damageInfo )
		if ( attacker.IsPlayer() )
		{
			attacker.AddToPlayerGameStat( PGS_SCORE, SCORE_TITAN_DOOMED )
			attacker.AddToPlayerGameStat( PGS_DEFENSE_SCORE, 1 )
		}

		SafeguardEmitNukeTitanVoiceLineToAttackers( "diag_gs_titanLegion_prime_doomState" )
		thread SafeguardTitanDoomedThink( soul )
	}
}

void function SafeguardTitanDoomedThink( entity soul )
{
	#if DEV
	printt( "Starting SafeguardTitanDoomedThink!" )
	#endif
	soul.EndSignal( "OnDeath" )
	soul.EndSignal( "OnDestroy" )

	entity titan = soul.GetTitan()
	titan.EndSignal( "OnDeath" )
	titan.EndSignal( "OnDestroy" )

	//titan.Signal( "TitanStopsThinking" )
	#if DEV
	printt( "Calling SafeguardTitanKneel!" )
	#endif
	waitthread SafeguardTitanKneel( titan )
	#if DEV
	printt( "Calling SafeguardTitanAutoRepair!" )
	#endif
	thread SafeguardTitanAutoRepair( titan )
	titan.WaitSignal( "SafeguardNukeTitanRepaired" )
	#if DEV
	printt( "Titan repaired!" )
	#endif
	file.nukeTitanIsDoomed = false
	#if DEV
	printt( "Calling SafeguardTitanStandUp!" )
	#endif
	waitthread SafeguardTitanStandUp( titan )

	titan.SetNoTarget( false )
	titan.SetNoTargetSmartAmmo( false )

	if ( IsValid( file.nukeTitanMarker ) )
		file.nukeTitanMarker.Minimap_AlwaysShow( file.attackerTeam, null )

	//thread TitanNPC_Think( titan )
	thread SafeguardNukeTitanSeekOutGenerator( titan, file.militiaHarvester.harvester )
}
void function SafeguardOnKilledNPCPlayer( entity victim, entity attacker, var damageInfo )
{
	// Basic checks
	if ( victim == attacker || !attacker.IsPlayer() || !GamePlaying() )
		return
	// Hacked spectre filter
	if ( victim.GetOwner() == attacker )
		return
	
	if ( victim.IsPlayer() )
	{
		attacker.AddToPlayerGameStat( PGS_SCORE, SCORE_KILL )
		
		if ( attacker.GetTeam == file.attackerTeam )
		{
			if ( file.matchPlayers[ attacker ].nearNukeTitan )
			{
				AddPlayerScore( attacker, "HardpointAssault", victim )
				attacker.AddToPlayerGameStat( PGS_SCORE, SCORE_ATTACKER_KILL_BONUS )
			}
		}
		else if ( attacker.GetTeam == file.defenderTeam )
		{
			if ( file.matchPlayers[ victim ].nearNukeTitan )
			{
				AddPlayerScore( attacker, "HardpointDefense", victim )
				attacker.AddToPlayerGameStat( PGS_SCORE, SCORE_DEFENDER_KILL_BONUS )
			}
		}
	}

	if ( victim.IsNPC() && ( IsMinion( victim ) || IsStalker( victim ) || IsSuperSpectre( victim ) ) )
	{	
		if ( attacker.GetTeam == file.attackerTeam )
		{
			if ( file.matchPlayers[ attacker ].nearNukeTitan )
			{
				AddPlayerScore( attacker, "HardpointPerimeterDefense", victim )
				attacker.AddToPlayerGameStat( PGS_SCORE, SCORE_ATTACKER_KILL_NPC )
			}
		}
		else if ( attacker.GetTeam == file.defenderTeam )
		{
			if ( ( DistanceSqr( victim.GetOrigin(), file.theNukeTitan.GetOrigin() ) <= SAFEGUARD_ESCORT_DISTANCE * SAFEGUARD_ESCORT_DISTANCE ) )
			{
				AddPlayerScore( attacker, "HardpointSiege", victim )
				attacker.AddToPlayerGameStat( PGS_SCORE, SCORE_DEFENDER_KILL_NPC )
			}
		}
	}
}
// ========================== NUKE TITAN ========================== //
void function Safeguard_SpawnNukeTitan()
{
	entity npc = CreateNPCTitan( "titan_ogre", file.attackerTeam, file.nukeTitanSpawnSpot, file.nukeTitanSpawnAngle )
	SetSpawnOption_AISettings( npc, "npc_titan_ogre_minigun_nuke" )
	SetSpawnOption_Titanfall( npc )
	//SetSpawnOption_Alert( npc )
	SetTargetName( npc, "payloadNukeTitan" )
	DispatchSpawn( npc )
	//npc.SetNoTarget( true )
	HideName( npc )
	npc.EnableNPCFlag( NPC_DISABLE_SENSING | NPC_IGNORE_ALL | NPC_NO_GESTURE_PAIN | NPC_NO_PAIN )
	npc.EnableNPCMoveFlag( NPCMF_WALK_ALWAYS | NPCMF_WALK_NONCOMBAT | NPCMF_DISABLE_DANGEROUS_AREA_DISPLACEMENT )
	npc.DisableNPCMoveFlag( NPCMF_PREFER_SPRINT )
	npc.DisableNPCFlag( NPC_ALLOW_FLEE | NPC_DIRECTIONAL_MELEE | NPC_ALLOW_INVESTIGATE )
	npc.SetCapabilityFlag( bits_CAP_INNATE_MELEE_ATTACK1 | bits_CAP_INNATE_MELEE_ATTACK2 | bits_CAP_SYNCED_MELEE_ATTACK | bits_CAP_WEAPON_RANGE_ATTACK1 , false )
	npc.SetValidHealthBarTarget( true )
	npc.TakeOffhandWeapon( OFFHAND_LEFT ) // No gun shield
	AddEntityCallback_OnDamaged( npc, OnNukeTitanDamaged )

	file.theNukeTitan = npc
	
	entity soul = npc.GetTitanSoul()
	soul.SetPreventCrits( true )
	soul.SetDamageNotifications( false )
	soul.SetShieldHealthMax( file.nukeTitanMaxShield )
	SetGlobalNetEnt( "nukeTitanSoul", soul )
	
	npc.SetBehaviorSelector( "behavior_frag_drone" ) // Disables flinch anims. Still uses gun shield.
	npc.AssaultSetFightRadius( 0 )
	npc.SetDangerousAreaReactionTime( 30 )
	
	npc.Minimap_AlwaysShow( TEAM_IMC, null )
	npc.Minimap_AlwaysShow( TEAM_MILITIA, null )
	npc.Minimap_SetHeightTracking( true )
	npc.Minimap_SetAlignUpright( true )
	npc.Minimap_SetZOrder( MINIMAP_Z_NPC )
	npc.Minimap_SetCustomState( eMinimapObject_npc_titan.AT_BOUNTY_BOSS )

	npc.EndSignal( "OnDeath" )
	npc.EndSignal( "OnDestroy" )

	//SafeguardNukeTitanThink( npc, file.militiaHarvester.harvester )
	NPC_SetNuclearPayload( npc )
	waitthread WaitTillHotDropComplete( npc )
	npc.GetTitanSoul().SetTitanSoulNetBool( "showOverheadIcon", true )
	file.nukeTitanMarker = CreateTitanEscortZoneOnEntity( npc, SAFEGUARD_ESCORT_DISTANCE )
	thread SafeguardNukeTitanSeekOutGenerator( npc, file.militiaHarvester.harvester )
	thread SafeguardNukeTitanProximityChecker( npc )
	thread SafeguardNukeTitanStatusTracker( npc )
	thread Safeguard_RouteHologramRepeater()
}

void function SafeguardNukeTitanStatusTracker( entity titan )
{
	svGlobal.levelEnt.EndSignal( "GameStateChanged" ) // Stop this for any change game state, timeout or winner determined in case
	titan.EndSignal( "OnDeath" )
	titan.EndSignal( "OnDestroy" )

	while ( true )
	{
		if ( file.nukeTitanIsDoomed )
			SetGlobalNetInt( "nukeTitanState", SAFEGUARD_TITAN_STATE_DOOMED )
		else if ( file.nukeTitanIsMoving && Length( titan.GetNPCVelocity() ) > 0 )
			SetGlobalNetInt( "nukeTitanState", SAFEGUARD_TITAN_STATE_MOVING )
		else if ( IsValid( GetEnemyRodeoPilot( titan ) ) )
			SetGlobalNetInt( "nukeTitanState", SAFEGUARD_TITAN_STATE_RODEOED )
		else
			SetGlobalNetInt( "nukeTitanState", SAFEGUARD_TITAN_STATE_STAND )
		
		wait 0.1
	}
}

void function SafeguardNukeTitanThink( entity titan, entity generator )
{
	//Function assumes that given Titan is spawned as npc_titan_ogre_meteor_nuke. Changing the Titan's AISettings post-spawn
	//disrupts the Titan's titanfall animations and can result in the Titan landing outside the level.
	NPC_SetNuclearPayload( titan )
	WaitTillHotDropComplete( titan )
	//titan.GetTitanSoul().SetTitanSoulNetBool( "showOverheadIcon", true )
	thread SafeguardNukeTitanSeekOutGenerator( titan, generator )
}

// Taken from _ai_nuke_titans.gnut
void function SafeguardNukeTitanSeekOutGenerator( entity titan, entity generator )
{
	titan.EndSignal( "OnDeath" )
	titan.EndSignal( "OnDestroy" )
	titan.EndSignal( "Doomed" )

	//WaitSignal( titan, "FD_ReachedHarvester", "OnFailedToPath" )
	// "OnFailedToPath" causes Nuke Titan to ignore path and escorting player.
	WaitSignal( titan, "FD_ReachedHarvester" )

	float goalRadius = 100
	float checkRadiusSqr = 400 * 400

	array<vector> pos = NavMesh_GetNeighborPositions( generator.GetOrigin(), HULL_TITAN, 5 )
	pos = ArrayClosestVector( pos, titan.GetOrigin() )

	array<vector> validPos
	foreach ( point in pos )
	{
		if ( DistanceSqr( generator.GetOrigin(), point ) <= checkRadiusSqr && NavMesh_IsPosReachableForAI( titan, point ) )
		{
			validPos.append( point )
		}
	}

	int posLen = validPos.len()
	while ( posLen >= 1 )
	{
		titan.SetEnemy( generator )
		thread AssaultOrigin( titan, validPos[0], goalRadius )
		titan.AssaultSetFightRadius( goalRadius )

		wait 0.5

		if ( DistanceSqr( titan.GetOrigin(), generator.GetOrigin() ) > checkRadiusSqr )
			continue

		break
	}

	thread AutoTitan_SelfDestruct( titan )
}

void function SafeguardNukeTitanProximityChecker( entity titan )
{
	svGlobal.levelEnt.EndSignal( "GameStateChanged" ) // Stop this for any change game state, timeout or winner determined in case
	
	titan.EndSignal( "OnDeath" )
	titan.EndSignal( "OnDestroy" )
	titan.EndSignal( "TitanEjectionStarted" ) // We only stop this if the Titan is successfully nuking nearby the Harvester
	
	entity soul = titan.GetTitanSoul()
	soul.EndSignal( "OnDeath" )
	soul.EndSignal( "OnDestroy" )
	
	titan.AssaultSetGoalRadius( titan.GetMinGoalRadius() )
	titan.AssaultPointClamped( titan.GetOrigin() )
	titan.AssaultSetFightRadius( 0 )
	titan.SetNPCMoveSpeedScale( 0.55 )
	titan.s.lastPosForDistanceStat <- titan.GetOrigin()

	while ( true )
	{	
		if ( !GetDoomedState( titan ) )
		{
			array<entity> nearbyFriendlies
			entity rider = GetEnemyRodeoPilot( titan )

			if ( IsValid( GetEnemyRodeoPilot( titan ) ) )
			{
				rider.AddToPlayerGameStat( PGS_SCORE, SCORE_DEFENDER_RODEO )

				if ( file.nukeTitanIsMoving )
				{
					titan.Signal( "SafeguardNukeTitanStopped" )
					titan.AssaultPointClamped( titan.GetOrigin() )
					file.nukeTitanIsMoving = false
				}
			}
			else
			{
				// Calculate escort distance
				float distInches = Distance2D( titan.s.lastPosForDistanceStat, titan.GetOrigin() )
				float distMeters = distInches / 39.37 // Sorry, imperial gang.

				foreach ( player in GetPlayerArrayOfTeam_Alive( titan.GetTeam() ) )
				{
					if ( ( DistanceSqr( player.GetOrigin(), titan.GetOrigin() ) <= SAFEGUARD_ESCORT_DISTANCE * SAFEGUARD_ESCORT_DISTANCE ) && !player.IsPhaseShifted() )
					{
						nearbyFriendlies.append( player )
						player.AddToPlayerGameStat( PGS_SCORE, SCORE_TITAN_ESCORT )
						file.matchPlayers[player].nearNukeTitan = true
						file.matchPlayers[player].escortDistance += distMeters
					}
					else
					{
						file.matchPlayers[player].nearNukeTitan = false
					}
				}

				if ( soul.GetShieldHealth() == 0 )
				{
					if ( !nearbyFriendlies.len() && file.nukeTitanIsMoving )
					{
						titan.Signal( "SafeguardNukeTitanStopped" )
						titan.AssaultPointClamped( titan.GetOrigin() )
						file.nukeTitanIsMoving = false
					}
					else if ( nearbyFriendlies.len() )
					{
						if ( !file.nukeTitanIsMoving )
						{
							file.nukeTitanIsMoving = true
							thread SafeguardMoveNukeTitan( titan, file.currentRouteNode )
						}
						else
						{
							file.nukeTitanDistanceCovered += distInches
						}
					}
				}
				else
				{			
					if ( !file.nukeTitanIsMoving )
					{
						file.nukeTitanIsMoving = true
						thread SafeguardMoveNukeTitan( titan, file.currentRouteNode )
					}
					else
					{
						file.nukeTitanDistanceCovered += distInches
					}
				}

				titan.s.lastPosForDistanceStat = titan.GetOrigin()
			}
		}

		wait 0.5
	}
}

void function SafeguardMoveNukeTitan( entity titan, int routeindex )
{
	svGlobal.levelEnt.EndSignal( "GameStateChanged" )
	titan.EndSignal( "SafeguardNukeTitanStopped" )
	titan.EndSignal( "OnDeath" )
	titan.EndSignal( "OnDestroy" )
	titan.EndSignal( "Doomed" )
	
	vector routepoint = file.titanRoute[routeindex]
	
	while ( true )
	{
		titan.AssaultPointClamped( routepoint )

		table result = titan.WaitSignal( "OnFinishedAssault" )
		routeindex++
		if ( routeindex < file.titanRoute.len() )
		{
			routepoint = file.titanRoute[routeindex]
			file.currentRouteNode = routeindex
		}
		else
		{
			break
		}
	}

	titan.AssaultSetGoalHeight( 128 )
	titan.Signal( "FD_ReachedHarvester" )
}

void function OnNukeTitanDamaged( entity titan, var damageInfo )
{	
	if ( GetDoomedState( titan ) )
	{
		DamageInfo_SetDamage( damageInfo, 0.0 ) // No damage when doomed.
	}
	else
	{
		entity attacker = DamageInfo_GetAttacker( damageInfo )

		if ( !GamePlaying() || attacker.GetTeam() == titan.GetTeam() )
			return
		
		if ( IsValid( attacker ) && attacker.IsPlayer() )
		{
			float damage = min( titan.GetHealth(), DamageInfo_GetDamage( damageInfo ) )			
			float scoreAmount = damage * 0.05 // Full health gives 625 //1250
			file.matchPlayers[attacker].titanDamageScore += scoreAmount
			#if DEV
			printt( "Damage: ", damage )
			printt( "Score: ", scoreAmount )
			printt( "Attacker: ", attacker )
			#endif
			if ( file.matchPlayers[attacker].titanDamageScore >= 1.0 )
			{
				int playerScore = floor( file.matchPlayers[attacker].titanDamageScore ).tointeger()
				attacker.AddToPlayerGameStat( PGS_SCORE, playerScore )
				file.matchPlayers[attacker].titanDamageScore = file.matchPlayers[attacker].titanDamageScore - playerScore
			}
		}
	}
}

void function SafeguardTitanStandUp( entity titan )
{
	titan.EndSignal( "OnDestroy" )
	titan.EndSignal( "OnDeath" )

	if ( titan.IsFrozen() )
		titan.Unfreeze()
	
	entity soul = titan.GetTitanSoul()

	WaitFrame()
	// stand up
	titan.s.standQueued = false
	titan.Anim_Stop()
	waitthread PlayAnimGravity( titan, "at_mortar_knee2stand" )

	SetStanceStand( soul )
}

void function SafeguardTitanKneel( entity titan )
{
	#if DEV
	printt( "Starting SafeguardTitanKneel!" )
	#endif
	titan.EndSignal( "TitanStopsThinking" )
	titan.EndSignal( "OnDestroy" )
	titan.EndSignal( "OnDeath" )

	entity soul = titan.GetTitanSoul()
	#if DEV
	printt( "Playing Kneel Anim!" )
	#endif
	//waitthread SafeguardTitanKneelAnim( titan )

	// For some reason, animation DOESN'T PLAY when Titan is hit is received damage by projectile weapon from rodeo attack.
	// unless you wait a frame, animation won't play and waitthread will stuck.
	WaitFrame()
	titan.Anim_Stop()
	waitthread PlayAnimGravity( titan, "at_mortar_stand2knee" )
	#if DEV
	printt( "Anim is done!" )
	#endif
	SetStanceKneel( soul )
	titan.Freeze()
}

void function SafeguardTitanKneelAnim( entity titan )
{
	#if DEV
	printt( "Starting SafeguardTitanKneelAnim!" )
	#endif
	entity soul = titan.GetTitanSoul()
	entity player = soul.GetBossPlayer()
	string animation = "at_mortar_stand2knee"

	vector titanOrg = titan.GetOrigin()
	vector angles = titan.GetAngles()


	//waitthread PlayAnimGravity( titan, animation, titan )
	thread PlayAnimGravity( titan, animation, titan ) // This way, at least it doesn't stuck waiting.

	//titan.Anim_ScriptedPlayWithRefPoint( animation, titanOrg, angles, 0.5 )
	//titan.Anim_PlayWithRefPoint( animation, titanOrg, angles, 0.5 ) // This way, at least it doesn't stuck waiting.
	//titan.Anim_EnablePlanting()
	//#if DEV
	//printt( "Waiting till anim done!" )
	//#endif
	//WaittillAnimDone( titan )
	#if DEV
	printt( "Anim is done!" )
	#endif
}

void function SafeguardTitanThrowRiderOff( entity titan )
{
	entity rodeoPilot = GetRodeoPilot( titan )

	if ( IsValid( rodeoPilot ) )
	{
		vector ejectAngles = titan.GetAngles()
		ejectAngles.x = 270
		vector riderEjectAngles = AnglesCompose( ejectAngles, < 5, 0, 0 > )
		float speed = RandomFloatRange( 1900, 2100 )
		float gravityScale = expect float ( rodeoPilot.GetPlayerSettingsField( "gravityscale" ) )
		vector riderVelocity = AnglesToForward( riderEjectAngles ) * (speed * gravityScale) * 0.95
		ThrowRiderOff( rodeoPilot, titan, riderVelocity )
	}
}

void function SafeguardTitanAutoRepair( entity titan )
{
	titan.EndSignal( "TitanStopsThinking" )
	titan.EndSignal( "OnDeath" )
	titan.EndSignal( "OnDestroy" )
	titan.EndSignal( "SafeguardNukeTitanRepaired" )

	wait file.nukeTitanAutoRepairTime
	UndoomTitan( titan, 5 ) // Full health without shields.
	titan.Signal( "SafeguardNukeTitanRepaired" )
}

void function SafeguardEmitNukeTitanVoiceLineToAttackers( string voiceLine )
{
	foreach ( entity player in GetPlayerArrayOfTeam( file.attackerTeam ) )
	{
		ServerToClientStringCommand( player, "SFG_SayTitanVoiceline " + voiceLine )
	}
}
// ========================== HARVESTER ========================== //
void function Safeguard_SpawnHarvester()
{
	file.militiaHarvester = SpawnHarvester( file.harvesterSpawnSpot, file.harvesterSpawnAngle, 10, 1, file.defenderTeam )
	SetTargetName( file.militiaHarvester.harvester, "militiaHarvester" )
	SetGlobalNetEnt( "militiaHarvester", file.militiaHarvester.harvester )

	file.militiaHarvester.harvester.SetShieldHealthMax( 1 )
	file.militiaHarvester.harvester.Minimap_SetAlignUpright( true )
	file.militiaHarvester.harvester.Minimap_AlwaysShow( TEAM_IMC, null )
	file.militiaHarvester.harvester.Minimap_AlwaysShow( TEAM_MILITIA, null )
	file.militiaHarvester.harvester.Minimap_SetHeightTracking( true )
	file.militiaHarvester.harvester.Minimap_SetZOrder( MINIMAP_Z_OBJECT )
	file.militiaHarvester.harvester.Minimap_SetCustomState( eMinimapObject_prop_script.FD_HARVESTER )
	file.militiaHarvester.harvester.SetTakeDamageType( DAMAGE_EVENTS_ONLY )
	file.militiaHarvester.harvester.SetArmorType( ARMOR_TYPE_HEAVY )
	file.militiaHarvester.harvester.SetAIObstacle( true )
	file.militiaHarvester.harvester.SetScriptPropFlags( SPF_DISABLE_CAN_BE_MELEED )
	NPC_NoTarget( file.militiaHarvester.harvester )
	file.harvesterNoSpawnArea = CreateNoSpawnArea( file.attackerTeam, file.defenderTeam, file.harvesterSpawnSpot, -1, 2048 )
	
	ToggleNPCPathsForEntity( file.militiaHarvester.harvester, false )
	AddEntityCallback_OnDamaged( file.militiaHarvester.harvester, OnHarvesterDamaged )
	//AddEntityCallback_OnFinalDamaged( file.militiaHarvester.harvester, OnHarvesterDamaged )

	thread SafeguardHarvesterProximityChecker( file.militiaHarvester.harvester )
}

void function SafeguardHarvesterProximityChecker( entity harvester )
{	
	harvester.EndSignal( "HealthChanged" )
	harvester.EndSignal( "OnDeath" )
	harvester.EndSignal( "OnDestroy" )

	while ( true )
	{
		entity nukeTitan = file.theNukeTitan
		
		if ( IsValid( nukeTitan ) )
		{
			if ( DistanceSqr( harvester.GetOrigin(), nukeTitan.GetOrigin() ) <= SAFEGUARD_HARVESTER_WARNING_DISTANCE * SAFEGUARD_HARVESTER_WARNING_DISTANCE )
			{
				if ( !file.nukeTitanIsNearHarvester )
				{
					PlayFactionDialogueToTeam( "fortwar_terEnteredEnemyTitan", file.defenderTeam )
					file.nukeTitanIsNearHarvester = true
				}
			}

			if ( DistanceSqr( harvester.GetOrigin(), nukeTitan.GetOrigin() ) <= SAFEGUARD_HARVESTER_ALERT_DISTANCE * SAFEGUARD_HARVESTER_ALERT_DISTANCE )
				wait EmitSoundOnEntity( harvester, HARVESTER_SND_KLAXON )
		}

		WaitFrame()
	}
}

void function Safeguard_StartUpHarvester()
{
	entity harvester = file.militiaHarvester.harvester
	wait file.harvesterStartDelay
	file.militiaHarvester.rings.Anim_Play( HARVESTER_ANIM_ACTIVATING )
	EmitSoundOnEntity( harvester, HARVESTER_SND_STARTUP )
	wait 4.0
	file.militiaHarvester.rings.Anim_Play( HARVESTER_ANIM_ACTIVE )
	generateBeamFX( file.militiaHarvester )
	generateShieldFX( file.militiaHarvester )
	EmitSoundOnEntity( harvester, HARVESTER_SND_HEALTHY )
}

void function OnHarvesterDamaged( entity harvester, var damageInfo )
{
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	//int damageSourceID = DamageInfo_GetDamageSourceIdentifier( damageInfo )

	if( !GamePlaying() || attacker.GetTeam() == harvester.GetTeam() )
	{
		DamageInfo_SetDamage( damageInfo, 0.0 )
		return
	}

	if ( attacker.IsNPC() && attacker == file.theNukeTitan )
	{
		harvester.SetInvulnerable()
		DamageInfo_SetDamage( damageInfo, 0.0 )
		file.militiaHarvester.rings.Anim_Play( HARVESTER_ANIM_DESTROYED )
		playHarvesterDestructionFX( file.militiaHarvester )
		harvester.SetHealth( 1 )
			
		if ( IsValid( file.militiaHarvester.particleShield ) )
			file.militiaHarvester.particleShield.Destroy()
			
		if ( IsRoundBased() )
			SetWinner( file.attackerTeam, "#GAMEMODE_SUR_WIN_ANNOUNCEMENT", "#GAMEMODE_SUR_LOSS_ANNOUNCEMENT" )
		else
			AddTeamScore( file.attackerTeam, 1 )
	}
	else
	{
		DamageInfo_SetDamage( damageInfo, 0.0 )
	}
}
// ======================== PATH TRACKER ======================= //
void function Safeguard_RouteHologramRepeater()
{
	svGlobal.levelEnt.EndSignal( "GameStateChanged" )
	
	while( true )
	{
		thread Safeguard_ShowRouteHologram()
		wait PATH_TRACKER_REFRESH_FREQUENCY
	}
}

void function Safeguard_ShowRouteHologram()
{
	svGlobal.levelEnt.EndSignal( "GameStateChanged" )
	
	int routeindex = 0
	vector routepoint = file.titanRoute[routeindex] + < 0, 0, 64 >
	entity mover = CreateScriptMover( file.nukeTitanSpawnSpot + < 0, 0, 64 > )
	entity fx = PlayLoopFXOnEntity( BATTERY_FX_FRIENDLY, mover )

	OnThreadEnd
	( 
		function() : ( mover, fx )
		{
			if ( IsValid( fx ) )
				fx.Destroy()

			if ( IsValid( mover ) )
				mover.Destroy()
		}
	)
	
	while( true )
	{		
		mover.NonPhysicsMoveTo( routepoint, PATH_TRACKER_MOVE_TIME_BETWEEN_POINTS, 0.0, 0.0 )
		wait PATH_TRACKER_MOVE_TIME_BETWEEN_POINTS
		routeindex++

		if ( routeindex < file.titanRoute.len() )
			routepoint = file.titanRoute[routeindex] + < 0, 0, 64 >
		else
		{
			fx.Destroy()
			mover.Destroy()
			break
		}
	}
}
// ====================== BATTERY SPAWNER ====================== //
void function SafeguardCreateBatterySpawners()
{
	foreach ( id, origin in file.batterySpawnerSpots )
	{
		thread SafeguardBatterySpawnerThink( origin, file.batterySpawnerAngles[ id ] )
	}
}

void function SafeguardSpawnBatterySpawner()
{
	entity player = GetPlayerArray()[ 0 ]
	if ( !IsValid( player ) )
		return

	vector origin = GetPlayerCrosshairOrigin( player )
	origin.z = origin.z - 32
	thread SafeguardBatterySpawnerThink( origin, <0,0,0> )
	printt( "Spawner Pos: <", origin.x,",", origin.y,",", origin.z,">" )
}

void function SafeguardBatterySpawnerThink( vector origin, vector angles )
{
	svGlobal.levelEnt.EndSignal( "CleanUpEntitiesForRoundEnd" )

	entity baseModel = CreatePropDynamic( CTF_FLAG_BASE_MODEL, origin, angles, 0 )
	baseModel.s.firstSpawn <- true

	while ( true )
	{
		if ( !GamePlayingOrSuddenDeath() )
		{
			wait 1
			continue
		}

		if ( baseModel.s.firstSpawn )
		{
			wait file.batterySpawnDelay
			baseModel.s.firstSpawn = false
		}
		
		entity batteryPickup = Rodeo_CreateBatteryPack()
		batteryPickup.SetScriptName( "batteryPickup" )
		batteryPickup.e.spawnTime = Time()
		batteryPickup.s.pickedOnce <- false
		//batteryPickup.s.touchEnabledTime = Time() + 9999.0 // HACK: Overriding "Rodeo_OnTouchBatteryPack_Internal"
		batteryPickup.SetSkin( 2 ) // Amped battery
		batteryPickup.StopPhysics()
		batteryPickup.SetOrigin( origin + < 0, 0, 32 > )
		batteryPickup.SetAngles( angles )
		batteryPickup.Minimap_Hide( file.defenderTeam, null )
		PlayFXOnEntity( $"P_phase_shift_main", batteryPickup )
		EmitSoundOnEntity( batteryPickup, "Pilot_PhaseShift_End_3P" )
		Battery_StartFX( batteryPickup )

		OnThreadEnd
		( 
			function() : ( batteryPickup, baseModel )
			{
				if ( IsValid( batteryPickup ) )
					batteryPickup.Destroy()

				if ( IsValid( baseModel ) )
					baseModel.Destroy()
			}
		)

		batteryPickup.WaitSignal( "OnDestroy" ) // It will not respawn until previous battery is applied.
		wait file.batteryRespawnDelay
	}
}
// ======================= CUSTOM PROPS ======================== //
void function SafeguardCreateMapProps()
{
	foreach ( id, origin in file.mapPropSpots )
	{
		SafeguardSpawnProp( origin, file.mapPropAngles[ id ], file.mapPropAsset[ id ] )
	}
}

void function SafeguardSpawnProp( vector origin, vector angles, asset modelasset )
{
	entity prop = CreateEntity( "prop_script" )
	prop.SetValueForModelKey( modelasset )
	prop.SetOrigin( origin )
	prop.SetAngles( angles )
	prop.kv.fadedist = -1
	prop.kv.renderamt = 255
	prop.kv.rendercolor = "255 255 255"
	prop.kv.solid = 6
	ToggleNPCPathsForEntity( prop, false )
	prop.SetAIObstacle( true )
	prop.SetTakeDamageType( DAMAGE_NO )
	prop.SetScriptPropFlags( SPF_BLOCKS_AI_NAVIGATION | SPF_CUSTOM_SCRIPT_3 )
	prop.AllowMantle()
	DispatchSpawn( prop )
}

// ========================== UTILITY ========================== //
entity function CreateTitanEscortZoneOnEntity( entity ent, float radius )
{
	int entTeam = ent.GetTeam()
	entity entRadius = CreatePropScript( $"models/dev/empty_model.mdl", ent.GetOrigin() )
	entRadius.Minimap_SetObjectScale( radius / 16000.0 )
	entRadius.Minimap_SetAlignUpright( true )
	entRadius.Minimap_SetHeightTracking( true )
	entRadius.Minimap_SetZOrder( MINIMAP_Z_OBJECT )
	entRadius.Minimap_AlwaysShow( file.attackerTeam, null )
	entRadius.Minimap_Hide( file.defenderTeam, null )
	SetTeam( entRadius, entTeam )
	entRadius.SetParent( ent )

	if ( entTeam == TEAM_IMC )
		entRadius.Minimap_SetCustomState( eMinimapObject_prop_script.SPAWNZONE_IMC )
	else
		entRadius.Minimap_SetCustomState( eMinimapObject_prop_script.SPAWNZONE_MIL )

	return entRadius
}

void function SetTeamSpawnZoneMinimapMarker( entity marker, int team )
{
	marker.Minimap_SetObjectScale( marker.s.zoneRadius / 16000 )
	marker.Minimap_SetAlignUpright( true )
	marker.Minimap_Hide( TEAM_IMC, null )
	marker.Minimap_Hide( TEAM_MILITIA, null )
	#if DEV
	marker.Minimap_AlwaysShow( TEAM_IMC, null )
	marker.Minimap_AlwaysShow( TEAM_MILITIA, null )
	#endif
	marker.Minimap_SetHeightTracking( true )
	marker.Minimap_SetZOrder( MINIMAP_Z_OBJECT )
	
	SetTeam( marker, team )
	
	if ( team == TEAM_IMC )
		marker.Minimap_SetCustomState( eMinimapObject_prop_script.SPAWNZONE_IMC )
	else
		marker.Minimap_SetCustomState( eMinimapObject_prop_script.SPAWNZONE_MIL )
}