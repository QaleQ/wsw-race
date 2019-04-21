const int MAX_RECORDS = 50;
const int DISPLAY_RECORDS = 20;
const int HUD_RECORDS = 3;

uint[] levelRecordSectors;
uint levelRecordFinishTime;
String levelRecordPlayerName;

// ch : MM
const uint RECORD_SEND_INTERVAL = 5 * 60 * 1000; // 5 minutes
uint lastRecordSent = 0;

RecordTime[] levelRecords( MAX_RECORDS );

class RecordTime
{
    bool saved;
    uint[] sectorTimes;
    uint finishTime;
    String playerName;
    String login;
    bool arraysSetUp;

    void setupArrays( int size )
    {
        this.sectorTimes.resize( size );

        for ( int i = 0; i < numCheckpoints; i++ )
            this.sectorTimes[i] = 0;

        this.arraysSetUp = true;
    }

    RecordTime()
    {
        this.saved = false;
        this.arraysSetUp = false;
        this.finishTime = 0;
    }

    ~RecordTime() {}

    void clear()
    {
        this.saved = false;
        this.playerName = "";
        this.login = "";
        this.finishTime = 0;

        for ( int i = 0; i < numCheckpoints; i++ )
            this.sectorTimes[i] = 0;
    }

    void Copy( RecordTime &other )
    {
        if ( !this.arraysSetUp )
            return;

        this.saved = other.saved;
        this.finishTime = other.finishTime;
        this.playerName = other.playerName;
        this.login = other.login;
        for ( int i = 0; i < numCheckpoints; i++ )
            this.sectorTimes[i] = other.sectorTimes[i];
    }

    void Store( Client @client )
    {
        if ( !this.arraysSetUp )
            return;

        Player @player = RACE_GetPlayer( client );

        this.saved = true;
        this.finishTime = player.finishTime;
        this.playerName = client.name;
        this.login = client.getMMLogin();
        for ( int i = 0; i < numCheckpoints; i++ )
            this.sectorTimes[i] = player.sectorTimes[i];
    }
}

void RACE_WriteTopScores()
{
    String topScores;
    Cvar mapNameVar( "mapname", "", 0 );
    String mapName = mapNameVar.string.tolower();

    topScores = "//" + mapName + " top scores\n\n";

    for ( int i = 0; i < MAX_RECORDS; i++ )
    {
        if ( levelRecords[i].saved && levelRecords[i].playerName.length() > 0 )
        {
            topScores += "\"" + int( levelRecords[i].finishTime );
            if ( levelRecords[i].login != "" )
                topScores += "|" + levelRecords[i].login; // optionally storing it in a token with another value provides backwards compatibility
            topScores += "\" \"" + levelRecords[i].playerName + "\" ";

            // add the sectors
            topScores += "\"" + numCheckpoints+ "\" ";

            for ( int j = 0; j < numCheckpoints; j++ )
                topScores += "\"" + int( levelRecords[i].sectorTimes[j] ) + "\" ";

            topScores += "\n";
        }
    }

    G_WriteFile( "topscores/race/" + mapName + ".txt", topScores );
}

void RACE_LoadTopScores()
{
    String topScores;
    Cvar mapNameVar( "mapname", "", 0 );
    String mapName = mapNameVar.string.tolower();

    topScores = G_LoadFile( "topscores/race/" + mapName + ".txt" );

    if ( topScores.length() > 0 )
    {
        String timeToken, loginToken, nameToken, sectorToken;
        int count = 0;
        uint sep;

        int i = 0;
        while ( i < MAX_RECORDS )
        {
            timeToken = topScores.getToken( count++ );
            if ( timeToken.length() == 0 )
                break;

            sep = timeToken.locate( "|", 0 );
            if ( sep == timeToken.length() )
            {
                loginToken = "";
            }
            else
            {
                loginToken = timeToken.substr( sep + 1 );
                timeToken = timeToken.substr( 0, sep );
            }

            nameToken = topScores.getToken( count++ );
            if ( nameToken.length() == 0 )
                break;

            sectorToken = topScores.getToken( count++ );
            if ( sectorToken.length() == 0 )
                break;

            int numSectors = sectorToken.toInt();

            // store this one
            for ( int j = 0; j < numSectors; j++ )
            {
                sectorToken = topScores.getToken( count++ );
                if ( sectorToken.length() == 0 )
                    break;

                levelRecords[i].sectorTimes[j] = uint( sectorToken.toInt() );
            }

            // check if he already has a score
            String cleanName = nameToken.removeColorTokens().tolower();
            bool exists = false;
            for ( int j = 0; j < i; j++ )
            {
                if ( ( loginToken != "" && levelRecords[j].login == loginToken )
                        || ( loginToken == "" && levelRecords[j].playerName.removeColorTokens().tolower() == cleanName ) )
                {
                    exists = true;
                    break;
                }
            }
            if ( exists )
            {
                levelRecords[i].clear();
                continue;
            }

            levelRecords[i].saved = true;
            levelRecords[i].finishTime = uint( timeToken.toInt() );
            levelRecords[i].playerName = nameToken;
            levelRecords[i].login = loginToken;

            i++;
        }

        RACE_UpdateHUDTopScores();
    }
}
