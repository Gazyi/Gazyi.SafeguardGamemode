global function ClGamemodeSafeguard_Init
global function ClSafeguard_RegisterNetworkFunctions
global function ServerCallback_SafeguardOvertimeAnnouncement
global function ServerCallback_SafeguardBatterySpawnersEnabled

const float AR_EFFECT_SIZE = 192.0 // coresponds with the size of the sphere model used for the AR effect
const float SAFEGUARD_ESCORT_DISTANCE = 512.0

struct 
{
	int nukeTitanStatus = 0
	entity clNukeTitan = null
	bool nukeTitanIsTalking = false
	int fxNukeTitan = 0
	bool nukeTitanBlinking = false
} file

void function ClGamemodeSafeguard_Init()
{
    RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_INTRO, "music_mp_fd_intro_hard", TEAM_IMC ) // music_mp_fd_intro_hard - music_mp_fd_intro_02
	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_INTRO, "music_mp_coliseum_intro", TEAM_MILITIA )

	RegisterLevelMusicForTeam( eMusicPieceID.ROUND_BASED_GAME_WON, "music_mp_freeagents_outro_win", TEAM_IMC ) // music_mp_freeagents_outro_win - music_mp_win_sting03
	RegisterLevelMusicForTeam( eMusicPieceID.ROUND_BASED_GAME_WON, "music_mp_speedball_game_win", TEAM_MILITIA ) // music_mp_speedball_game_win - music_mp_livefire_game_win_01

	RegisterLevelMusicForTeam( eMusicPieceID.ROUND_BASED_GAME_LOST, "music_mp_lts_outro_lose", TEAM_IMC ) // music_mp_lts_outro_lose - music_mp_lose_sting02
	RegisterLevelMusicForTeam( eMusicPieceID.ROUND_BASED_GAME_LOST, "music_mp_coliseum_round_lose", TEAM_MILITIA )

	//RegisterLevelMusicForBothTeams is not global for some reason...
	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_LAST_MINUTE, "music_mp_speedball_intro", TEAM_IMC )
	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_LAST_MINUTE, "music_mp_speedball_intro", TEAM_MILITIA )

	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_DRAW, "music_mp_lts_outro_lose", TEAM_IMC ) // music_mp_lts_outro_lose - music_mp_lose_sting02
	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_DRAW, "music_mp_coliseum_round_lose", TEAM_MILITIA )

	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_LOSS, "music_mp_lts_outro_lose", TEAM_IMC ) // music_mp_lts_outro_lose - music_mp_lose_sting02
	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_LOSS, "music_mp_coliseum_round_lose", TEAM_MILITIA )

	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_WIN, "music_mp_freeagents_outro_win", TEAM_IMC ) // music_mp_freeagents_outro_win - music_mp_win_sting03
	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_WIN, "music_mp_speedball_game_win", TEAM_MILITIA ) // music_mp_speedball_game_win - music_mp_livefire_game_win_01
	
	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_SUDDEN_DEATH, "music_mp_pilothunt_epilogue_lose", TEAM_IMC ) // music_mp_pilothunt_epilogue_lose - music_mp_mcor_epilogue_lose01
	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_SUDDEN_DEATH, "music_mp_pilothunt_epilogue_win", TEAM_MILITIA ) // music_mp_pilothunt_epilogue_win - music_mp_imc_epilogue_win02

	ClGameState_RegisterGameStateAsset( $"ui/gamestate_info_coliseum.rpak" ) // Shows rounds, time and score. Status replaces round text.
	SetGameModeScoreBarUpdateRules( GameModeScoreBarRules_Safeguard )
	AddCallback_OnClientScriptInit( ClGamemodeSafeguard_OnClientScriptInit )
	AddCallback_OnPlayerLifeStateChanged( ClGamemodeSafeguard_OnPlayerLifeStateChanged )

    // Score events strings
	ScoreEvent_SetSplashText( GetScoreEvent( "HardpointAssault" ), "#SCORE_EVENT_KILLED_DEFENDER" )
	ScoreEvent_SetMedalText( GetScoreEvent( "HardpointAssault" ), "#SCORE_EVENT_KILLED_DEFENDER" )
	ScoreEvent_SetSplashText( GetScoreEvent( "HardpointDefense" ), "#SCORE_EVENT_KILLED_ATTACKER" )
	ScoreEvent_SetMedalText( GetScoreEvent( "HardpointDefense" ), "#SCORE_EVENT_KILLED_ATTACKER" )
	ScoreEvent_SetSplashText( GetScoreEvent( "HardpointPerimeterDefense" ), "#SCORE_EVENT_KILLED_DEFENDER" )
	ScoreEvent_SetMedalText( GetScoreEvent( "HardpointPerimeterDefense" ), "#SCORE_EVENT_KILLED_DEFENDER" )
	ScoreEvent_SetSplashText( GetScoreEvent( "HardpointSiege" ), "#SCORE_EVENT_KILLED_ATTACKER" )
	ScoreEvent_SetMedalText( GetScoreEvent( "HardpointSiege" ), "#SCORE_EVENT_KILLED_ATTACKER" )
	ScoreEvent_SetSplashText( GetScoreEvent( "FDShieldHarvester" ), "#SCORE_EVENT_TITAN_REPAIRED" )
	ScoreEvent_SetMedalText( GetScoreEvent( "FDShieldHarvester" ), "#SCORE_EVENT_TITAN_REPAIRED" )
	ScoreEvent_SetSplashText( GetScoreEvent( "PilotBatteryStolen" ), "#SCORE_EVENT_BATTERY_DESTROYED" )
	ScoreEvent_SetMedalText( GetScoreEvent( "PilotBatteryStolen" ), "#SCORE_EVENT_BATTERY_DESTROYED" )
    ScoreEvent_SetSplashText( GetScoreEvent( "MarkedEscort" ), "#SCORE_EVENT_TITAN_ESCORT" )
	ScoreEvent_SetMedalText( GetScoreEvent( "MarkedEscort" ), "#SCORE_EVENT_TITAN_ESCORT" )

	AddCreateCallback( "npc_titan", OnNukeTitanSpawn )
	RegisterServerVarChangeCallback( "gameState", Safeguard_OnGameStateChanged )
	AddServerToClientStringCommandCallback( "SFG_SayTitanVoiceline", SafeguardEmitNukeTitanVoiceline )
	RegisterSignal( "NukeTitanStopSonarFX" )
	PrecacheParticleSystem( $"P_ar_holopulse_CP" )
}
// ========================== Gamemode Callbacks and Configuration ========================== //
// BUG: Titan status doesn't update when local player is dead.
void function ClSafeguard_RegisterNetworkFunctions()
{
	RegisterNetworkedVariableChangeCallback_int( "nukeTitanState", OnNukeTitanStateChange )
}

void function OnNukeTitanStateChange( entity player, int old, int new, bool actuallyChanged )
{
	if ( !IsValid( GetLocalClientPlayer() ) )
		return

	#if DEV
	printt( "Titan State changed!" )
	#endif

	int gameState = GetGameState()

	if ( gameState < 0 || gameState > eGameState.Playing )
	{
		file.nukeTitanStatus = 0
		return
	}
	else
	{
		if ( old != new )
		{
			file.nukeTitanStatus = new
			#if DEV
			printt( "New Titan Status: ", file.nukeTitanStatus )
			#endif
		}

		NukeTitanUpdateSonarEffect( file.nukeTitanStatus )
	}
}

void function GameModeScoreBarRules_Safeguard( var rui )
{
	if ( !IsValid( GetLocalClientPlayer() ) )
		return

	if ( GetGameState() == eGameState.Playing && ( Time() - expect float( GetServerVar( "gameStateChangeTime" ) ) >= 6.0 ) )
	{
		array<string> TitanStatusSub = [ "", "#SAFEGUARD_TITAN_STATE_MOVING", "#SAFEGUARD_TITAN_STATE_RODEOED", "#SAFEGUARD_TITAN_STATE_DOOMED" ]
		string subText = TitanStatusSub[ file.nukeTitanStatus ]
		RuiSetString( rui, "roundText", Localize( subText ) )
	}
	else
	{
		if ( GetRoundsPlayed() == 0 )
			RuiSetString( rui, "roundText", Localize( "#FIRST_HALF" ) )
		else if ( GetRoundsPlayed() == 1 )
			RuiSetString( rui, "roundText", Localize( "#SECOND_HALF" ) )
		else
			RuiSetString( rui, "roundText", Localize( "#GAMEMODE_FFA_SUDDEN_DEATH_ANNOUNCE" ) ) // Overtime
	}
}

void function ClGamemodeSafeguard_OnClientScriptInit( entity player )
{
	RegisterMinimapPackage( "npc_titan", eMinimapObject_npc_titan.AT_BOUNTY_BOSS, $"ui/minimap_object.rpak", Safeguard_MinimapNukeTitanInit )
}

void function ClGamemodeSafeguard_OnPlayerLifeStateChanged( entity player, int oldLifeState, int newLifeState )
{
	if ( player != GetLocalViewPlayer() )
		return
		
	if ( newLifeState == LIFE_ALIVE )
	{
		#if DEV
		printt( "Player respawned! Titan Status: ", file.nukeTitanStatus )
		#endif
	}
}

void function Safeguard_OnGameStateChanged()
{
	if ( GetGameState() == eGameState.Prematch )
	{
		file.nukeTitanIsTalking = false
		file.nukeTitanBlinking = false
		file.clNukeTitan = null
	}
	
	if ( GetGameState() == eGameState.SwitchingSides )
		thread RegisterTeamRoundMusic()
}

void function RegisterTeamRoundMusic()
{
	WaitFrame()
	
	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_INTRO, "music_mp_fd_intro_hard", GetGlobalNetInt( "attackerTeam" ) ) // music_mp_fd_intro_hard - music_mp_fd_intro_02
	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_INTRO, "music_mp_coliseum_intro", GetGlobalNetInt( "defenderTeam" ) )

	RegisterLevelMusicForTeam( eMusicPieceID.ROUND_BASED_GAME_WON, "music_mp_freeagents_outro_win", GetGlobalNetInt( "attackerTeam" ) ) // music_mp_freeagents_outro_win - music_mp_win_sting03
	RegisterLevelMusicForTeam( eMusicPieceID.ROUND_BASED_GAME_WON, "music_mp_speedball_game_win", GetGlobalNetInt( "defenderTeam" ) ) // music_mp_speedball_game_win - music_mp_livefire_game_win_01

	RegisterLevelMusicForTeam( eMusicPieceID.ROUND_BASED_GAME_LOST, "music_mp_lts_outro_lose", GetGlobalNetInt( "attackerTeam" ) ) // music_mp_lts_outro_lose - music_mp_lose_sting02
	RegisterLevelMusicForTeam( eMusicPieceID.ROUND_BASED_GAME_LOST, "music_mp_coliseum_round_lose", GetGlobalNetInt( "defenderTeam" ) )

	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_DRAW, "music_mp_lts_outro_lose", GetGlobalNetInt( "attackerTeam" ) ) // music_mp_lts_outro_lose - music_mp_lose_sting02
	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_DRAW, "music_mp_coliseum_round_lose", GetGlobalNetInt( "defenderTeam" ) )

	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_LOSS, "music_mp_pilothunt_epilogue_lose", GetGlobalNetInt( "attackerTeam" ) ) // music_mp_pilothunt_epilogue_lose - music_mp_mcor_epilogue_lose01
	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_LOSS, "music_mp_pilothunt_epilogue_lose", GetGlobalNetInt( "defenderTeam" ) )

	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_WIN, "music_mp_pilothunt_epilogue_win", GetGlobalNetInt( "attackerTeam" ) ) // music_mp_pilothunt_epilogue_win - music_mp_imc_epilogue_win02
	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_WIN, "music_mp_pilothunt_epilogue_win", GetGlobalNetInt( "defenderTeam" ) )
}

void function ServerCallback_SafeguardOvertimeAnnouncement( bool switchSides )
{
	if ( !IsValid( GetLocalClientPlayer()) )
		return

	float announcementDuration = SWITCHING_SIDES_DELAY
	AnnouncementData announcement = Announcement_Create( "#GAMEMODE_FFA_SUDDEN_DEATH_ANNOUNCE" )

	if ( switchSides )
		Announcement_SetSubText( announcement, "#GameState_SWITCHING_SIDES" )

	announcement.sortKey = RUI_SORT_SCREENFADE + 1 // Draw over screen fade
	announcement.drawOverScreenFade = true
	Announcement_SetPriority( announcement, 200 ) //Be higher priority than Titanfall ready indicator etc
	Announcement_SetHideOnDeath( announcement, false )
	Announcement_SetDuration( announcement, announcementDuration )
	Announcement_SetPurge( announcement, true )
	AnnouncementFromClass( GetLocalClientPlayer(), announcement )

	EmitSoundOnEntity( GetLocalClientPlayer(), "UI_InGame_HalftimeText_Enter" )
	EmitSoundOnEntityAfterDelay( GetLocalClientPlayer(), "UI_InGame_HalftimeText_Exit", announcementDuration )

	thread RegisterTeamRoundMusic()
}

void function ServerCallback_SafeguardBatterySpawnersEnabled()
{
	if ( !IsValid( GetLocalViewPlayer() ) )
		return

	AddGenericQueueMessage( "#SAFEGUARD_BATTERY_SPAWNERS_ENABLED", true )
	EmitSoundOnEntity( GetLocalClientPlayer(), "UI_InGame_LevelUp" )
}

// ========================== NUKE TITAN ========================== //
void function Safeguard_MinimapNukeTitanInit( entity ent, var rui )
{
	if ( ent.GetTargetName() == "payloadNukeTitan" )
	{
		//RuiSetImage( rui, "defaultIcon", $"rui/hud/gametype_icons/fd/fd_icon_titan_nuke" )
		//RuiSetImage( rui, "clampedDefaultIcon", $"rui/hud/gametype_icons/fd/fd_icon_titan_nuke" )
		RuiSetImage( rui, "defaultIcon", $"rui/hud/gametype_icons/fd/nuke_titan_minimap_orange" )
		RuiSetImage( rui, "clampedDefaultIcon", $"rui/hud/gametype_icons/fd/nuke_titan_minimap_orange" )
		RuiSetBool( rui, "useTeamColor", false )
		RuiSetBool( rui, "overrideTitanIcon", true )
	}
	
	RuiSetFloat( rui, "sonarDetectedFrac", 1.0 )
	RuiSetGameTime( rui, "lastFireTime", Time() + ( GetCurrentPlaylistVarFloat( "timelimit", 10 ) * 60.0 ) + 999.0 )
	RuiSetBool( rui, "showOnMinimapOnFire", true )
}

void function OnNukeTitanSpawn( entity titan )
{
	if ( titan.GetTargetName() == "payloadNukeTitan" )
	{
		file.clNukeTitan = titan
		thread AddOverheadIcon( titan, $"rui/hud/gametype_icons/fd/fd_icon_titan_nuke" )
	}
}
// Taken from cl_gamemode_fd.nut
var function AddOverheadIcon( entity prop, asset icon, bool pinToEdge = true, asset ruiFile = $"ui/overhead_icon_generic.rpak" )
{
	var rui = CreateCockpitRui( ruiFile, MINIMAP_Z_BASE - 20 )
	RuiSetImage( rui, "icon", icon )
	RuiSetBool( rui, "isVisible", true )
	RuiSetBool( rui, "pinToEdge", pinToEdge )
	RuiTrackFloat3( rui, "pos", prop, RUI_TRACK_OVERHEAD_FOLLOW )

	thread AddOverheadIconThread( prop, rui )
	return rui
}
// Taken from cl_gamemode_fd.nut
void function AddOverheadIconThread( entity prop, var rui )
{
	prop.EndSignal( "OnDestroy" )

	if ( prop.IsTitan() )
		prop.EndSignal( "OnDeath" )

	OnThreadEnd
	(
		function() : ( rui )
		{
			RuiDestroy( rui )
		}
	)

	if ( prop.IsTitan() )
	{
		while ( true )
		{
			bool showIcon = !IsCloaked( prop )

			if ( IsValid( prop.GetTitanSoul() ) )
				showIcon = showIcon && prop.GetTitanSoul().GetTitanSoulNetBool( "showOverheadIcon" )

			RuiSetBool( rui, "isVisible", showIcon )
			wait 0.5
		}
	}

	WaitForever()
}

void function SafeguardEmitNukeTitanVoiceline( array<string> args )
{
	if ( args.len() )
	{
		thread SafeguardEmitNukeTitanVoiceline_Internal( args[0] )
	}
}

void function SafeguardEmitNukeTitanVoiceline_Internal( string soundName )
{
	entity nukeTitan = file.clNukeTitan

	if ( IsValid( nukeTitan ) )
	{
		if ( IsAlive( nukeTitan ) && !file.nukeTitanIsTalking )
		{
			file.nukeTitanIsTalking = true

			var handle = EmitSoundOnEntity( nukeTitan, soundName )
			WaitSignal( handle, "OnSoundFinished" )

			file.nukeTitanIsTalking = false
		}
	}
}

void function NukeTitanUpdateSonarEffect( int nukeTitanStatus )
{
	if ( !IsValid( GetLocalViewPlayer() ) )
		return

	entity nukeTitan = file.clNukeTitan

	if ( IsValid( nukeTitan ) )
	{
		entity soul = nukeTitan.GetTitanSoul()

		if ( IsValid( soul ) )
		{
			if ( IsAlive( nukeTitan ) && GetLocalViewPlayer().GetTeam() == nukeTitan.GetTeam() )
			{
				//printt( "Client Team: ", GetLocalViewPlayer().GetTeam() )
				//printt( "Titan Team: ", nukeTitan.GetTeam() )
				
				if ( nukeTitanStatus == SAFEGUARD_TITAN_STATE_STAND )
				{
					thread NukeTitanEmitSonarFX( nukeTitan )
				}
				else
				{
					nukeTitan.Signal( "NukeTitanStopSonarFX" )
				}
			}
			else
			{
				nukeTitan.Signal( "NukeTitanStopSonarFX" )
			}
		}
	}
}

void function NukeTitanEmitSonarFX( entity nukeTitan )
{
	nukeTitan.EndSignal( "NukeTitanStopSonarFX" )
	
	while ( true )
	{
		if ( IsValid( nukeTitan ) )
		{
			int fxHandle = StartParticleEffectInWorldWithHandle( GetParticleSystemIndex( $"P_ar_holopulse_CP" ), nukeTitan.GetOrigin(), <0,0,0> )
			vector controlPoint = <SAFEGUARD_ESCORT_DISTANCE / ( SONAR_PULSE_SPACE + SONAR_PULSE_SPEED ), SAFEGUARD_ESCORT_DISTANCE / AR_EFFECT_SIZE, 0.0>
			EffectSetControlPointVector( fxHandle, 1, controlPoint )
		}
		wait 2.0
	}
}