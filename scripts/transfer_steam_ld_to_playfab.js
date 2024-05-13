// To actually use this, you need to input the correct secret keys
// And make a npm node project and npm install axios
const https = require('https');
const axios = require('axios');

const steam_headers_get = { "x-webapi-key": "THE_STEAM_KEY" }
const steam_headers_post = { "Content-Type": "application/x-www-form-urlencoded", ...steam_headers_get }
const playfab_headers = { "X-SecretKey": "THE_PLAYFAB_KEY" }
const appid = 2716690;

async function transfer_steam_leaderboard(ld_name) {
    const ld_data = (await axios.post("https://partner.steam-api.com/ISteamLeaderboards/FindOrCreateLeaderboard/v2", { appid, name: ld_name }, { headers: steam_headers_post })).data.result.leaderboard
    const ld_steam_id = ld_data.leaderBoardID
    if (ld_data.leaderBoardEntries > 100) {
        console.error("Has more than 100 entries!! Need to refactor code.")
    }
    const data = (await axios.get(`https://partner.steam-api.com/ISteamLeaderboards/GetLeaderboardEntries/v1?appid=${appid}&rangestart=0&rangeend=100&leaderboardid=${ld_steam_id}&datarequest=RequestGlobal`, { headers: steam_headers_get })).data
    let id_req = {
        SteamStringIDs: data.leaderboardEntryInformation.leaderboardEntries.map(e => e.steamID)
    }
    const id_resp = (await axios.post("https://3D3A0.playfabapi.com/Server/GetPlayFabIDsFromSteamIDs", id_req, { headers: playfab_headers })).data.data.Data
    let id_map = {}
    for (let idm of id_resp) {
        if (idm.PlayFabId) {
            id_map[idm.SteamStringId] = idm.PlayFabId
        }
    }
    for (let entry of data.leaderboardEntryInformation.leaderboardEntries) {
        console.log(`Processing user ${entry.steamID}`)
        if (entry.steamID in id_map) {
            let req_data = {
                PlayFabId: id_map[entry.steamID],
                Statistics: [{
                    StatisticName: ld_name,
                    Value: -entry.score,
                }]
            }
            const upd_resp = (await axios.post("https://3D3A0.playfabapi.com/Server/UpdatePlayerStatistics", req_data, { headers: playfab_headers })).data
            if (upd_resp.status != "OK") {
                console.warn(`Couldn't submit request\nReq: ${req_data}\nResp: ${upd_resp}`);
            }
        } else {
            console.warn(`Not found user for ${entry.steamID}`)
        }
    }

}

async function main() {
    for (let dif of ["easy", "medium", "hard", "expert", "insane"]) {
        console.log(`Transfering difficulty ${dif}`)
        await transfer_steam_leaderboard(`${dif}_marathon_10`)
    }
}

main()
