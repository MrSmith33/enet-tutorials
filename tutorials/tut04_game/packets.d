module packets;

import connection;

enum Command
{
	expand,
	explore,
	exterminate,
}

void registerPackets(Connection c)
{
	// Common
	c.registerPacket!MessagePacket;
	
	// Server -> Client
	c.registerPacket!LoginPacket;
	c.registerPacket!SessionInfoPacket;
	c.registerPacket!ClientLoggedInPacket;
	c.registerPacket!ClientLoggedOutPacket;
	c.registerPacket!ClientTurnPacket;
	c.registerPacket!BoardDataPacket;
	c.registerPacket!HexDataPacket;

	// Client -> Server
	c.registerPacket!ReadyPacket;
	c.registerPacket!DeployShipsPacket;
	c.registerPacket!PlanPacket;
	c.registerPacket!EndTurnPacket;
}

// client request
struct LoginPacket
{
	string clientName;
}

// server response
struct SessionInfoPacket
{
	ClientId yourId;
	string[ClientId] clientNames;
}

struct ClientLoggedInPacket
{
	ClientId clientId;
	string clientName;
}

struct ClientLoggedOutPacket
{
	ClientId clientId;
}

// sent from client with peer == 0 and from server with userId of sender.
struct MessagePacket
{
	ClientId clientId; // from. Set to 0 when sending from client
	string msg;
}

// Game packets

struct ReadyPacket
{
	bool isReady;
}

struct BoardDataPacket
{
	uint[54] systemLevels;
}

struct HexDataPacket
{
	uint hexId;
	size_t playerId;
	uint numShips;
}

struct EndTurnPacket{}

enum ClientTurn
{
	deployShips,
	plan,
	expand,
	explore,
	exterminate,
	chooseScoreSector,

}

struct ClientTurnPacket
{
	ClientTurn turn; // What turn should be made.
	ClientId id; // Who makes turn.
}

struct DeployShipsPacket
{
	// hex coords of level I hex in unoccupied system.
	uint x, y;
}

struct PlanPacket
{
	Command[3] commands;
}

struct ExpandPacket
{
	// hex coords of occupied hex.
	uint x, y;
}

struct ExplorePacket
{
	// hex coords of occupied hex.
	uint x, y;
}