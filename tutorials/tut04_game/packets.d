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
	c.registerPacket!LoginPacket;
	c.registerPacket!SessionInfoPacket;
	c.registerPacket!ClientLoggedInPacket;
	c.registerPacket!ClientLoggedOutPacket;
	c.registerPacket!MessagePacket;

	c.registerPacket!ReadyPacket;
	c.registerPacket!DeployShipsPacket;
	c.registerPacket!PlanPacket;
	c.registerPacket!BoardDataPacket;
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

struct DeployShipsPacket
{
	// hex coords of level I hex in unoccupied system.
	uint x, y;
}

struct PlanPacket
{
	Command[3] commands;
}

struct BoardDataPacket
{
	uint[54] systemLevels;
}