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

// 6 x 9
struct GameBoard
{
	// 6
	private Hex[54] data;

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
		assert(x < boardWidth - (y % 2));

		if (isTriPrime(x, y))
			return triPrime;

		return data[x + y * boardWidth];
	}

	ref Hex opIndexAssign(Hex newData, size_t x, size_t y)
	{
		// x < 6 on even row, x < 5 on odd row.
		assert(x < boardWidth - (y % 2));

		if (isTriPrime(x, y))
			return triPrime = newData;

		return data[x + y * boardWidth] = newData;
	}
}