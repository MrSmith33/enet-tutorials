module packets;

enum Command
{
	expand,
	explore,
	exterminate,
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