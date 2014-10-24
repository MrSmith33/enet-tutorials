module userstorage;

import derelict.enet.enet;
import connection;

struct User
{
	string name;
	ENetPeer* peer;
}

struct UserStorage
{
	private User*[UserId] users;

	UserId addUser(ENetPeer* peer)
	{
		UserId id = nextPeerId;
		User* user = new User;
		user.peer = peer;
		users[id] = user;
		return id;
	}

	void removeUser(UserId id)
	{
		users.remove(id);
	}

	User* findUser(UserId id)
	{
		return users.get(id, null);
	}

	UserId nextPeerId() @property
	{
		return _nextPeerId++;
	}

	string[UserId] userNames()
	{
		string[UserId] names;
		foreach(id, user; users)
		{
			names[id] = user.name;
		}

		return names;
	}

	string userName(UserId id)
	{
		return users[id].name;
	}

	ENetPeer* userPeer(UserId id)
	{
		return users[id].peer;
	}

	auto byUser()
	{
		return users.byValue;
	}

	size_t length()
	{
		return users.length;
	}

	private UserId _nextPeerId = 1;
}