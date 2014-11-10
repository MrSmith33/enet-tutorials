module gameboard;

enum boardWidth = 6;
enum boardHeight = 9;
enum numRounds = 9;

struct Hex
{
	size_t playerId;
	uint numShips;
	uint systemLevel;
}

enum triPrimeX = 2;
enum triPrimeY = 3;

bool isTriPrime(size_t x, size_t y)
{
	return
		(y == 3 && x == 2) ||
		(y == 4 && (x == 2 || x == 3)) ||
		(y == 5 && x == 2);
}

struct HexCoords
{
	ubyte x;
	ubyte y;
}

uint sectorNumber(HexCoords hexCoords)
{
	return hexCoords.x / 2 + (hexCoords.y / 3) * 3; // [0..9)
}

HexCoords hexCoordsFromIndex(ubyte index) // [0..54)
{
	return HexCoords(index % boardWidth, index / boardWidth);
}

// 6 x 9
struct GameBoard
{
	Hex[54] data;

	ref Hex triPrime() @property
	{
		return data[triPrimeX + triPrimeY * boardWidth];
	}

	ref Hex triPrime(Hex newData) @property
	{
		return data[triPrimeX + triPrimeY * boardWidth] = newData;
	}

	ref Hex opIndex(size_t x, size_t y)
	{
		// x < 6 on even row, x < 5 on odd row.
		if (x >= boardWidth - (y % 2) || y >= boardHeight)
			return data[11]; // unused hex

		if (isTriPrime(x, y))
			return triPrime;

		return data[x + y * boardWidth];
	}

	ref Hex opIndexAssign(Hex newData, size_t x, size_t y)
	{
		// x < 6 on even row, x < 5 on odd row.
		if (x >= boardWidth - (y % 2) || y >= boardHeight)
			return data[11]; // unused hex

		if (isTriPrime(x, y))
			return triPrime = newData;

		return data[x + y * boardWidth] = newData;
	}

	auto sectorHexes(ubyte sectorId) // 0-8
	{
		HexCoords[] sectors;
		foreach(ubyte index, hex; data)
		{
			HexCoords coords = hexCoordsFromIndex(index);
			if (sectorNumber(coords) == sectorId)
				sectors ~= coords;
		}
		return sectors;
	}
}