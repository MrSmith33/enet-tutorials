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
	c.registerPacket!DeployShipsArgsPacket;

	// Client -> Server
	c.registerPacket!ReadyPacket;
	c.registerPacket!DeployShipsResultPacket;
	c.registerPacket!PlanResultPacket;
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
	uint[] systemLevels;
}

struct HexDataPacket
{
	uint x;
	uint y;
	size_t playerId;
	uint numShips;
}

enum ClientTurn
{
	deployShips,
	plan, // for all players, playerId == 0
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

struct DeployShipsArgsPacket
{
	uint[] freeSectors;
}

struct DeployShipsResultPacket
{
	// hex coords of level I hex in unoccupied system.
	uint x, y;
}

struct PlanResultPacket
{
	Command[] commands;
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

struct EndTurnPacket{}