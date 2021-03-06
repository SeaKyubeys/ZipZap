import json
import flask

def user(endpoint):
    response = {
        "followCount": 0,
        "followerCount": 0,
        "follow": False,
        "follower": False,
        "blocked": False
    }
    with open('data/user/user.json', encoding='utf-8') as f:
        user = json.load(f)
    response['userName'] = user['loginName']
    response['lastAccessDate'] = user['lastLoginDate']

    if endpoint.split('/')[-1] != user['id']:
        flask.abort(501, description='User does not exist')

    with open('data/user/gameUser.json', encoding='utf-8') as f:
        gameUser = json.load(f)
    response['gameUser'] = gameUser
    response['userRank'] = gameUser['level']
    response['comment'] = gameUser['comment']
    response['inviteCode'] = gameUser['inviteCode']

    with open('data/user/userCardList.json', encoding='utf-8') as f:
        userCardList = json.load(f)
    response['userCardList'] = userCardList

    for userCard in userCardList:
        if userCard['id'] == gameUser['leaderId']:
            response['leaderUserCard'] = userCard
            response['cardId'] = userCard['cardId']
            response['charaName'] = userCard['card']['cardName']
            response['cardRank'] = userCard['card']['rank']
            response['attributeId'] = userCard['card']['attributeId']
            response['level'] = userCard['level']
            response['displayCardId'] = userCard['displayCardId']
            response['revision'] = userCard['revision']
            break
    
    userDeck = {}
    with open('data/user/userDeckList.json', encoding='utf-8') as f:
        userDeckList = json.load(f)
    for deck in userDeckList:
        if deck['deckType'] == 20:
            userDeck = deck
    response['userDeck'] = userDeck

    for key in ['userCharaList', 'userPieceList', 'userDoppelList', 'userArenaBattle']:
        with open('data/user/' + key + '.json', encoding='utf-8') as f:
            value = json.load(f)
        response[key] = value

    return flask.jsonify(response)

def handleFriend(endpoint):
    print(endpoint)
    if endpoint.startswith('user'):
        return user(endpoint)
    else:
        print(flask.request.path)
        flask.abort(501, description='Not implemented')
