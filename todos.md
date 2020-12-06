**Tasks to complete the basis POC/MVP**
- [x] Game can be started after reaching minimum players
- [x] Lobby owner changes when the original one disconnects
- [x] Countdown to start the match
- [x] Make basic map with camera points
- [x] Open camera and map walls after countdown starts
- [x] After the game starts one random player becomes the king
- [x] King can damage other players
- [x] Dead players are just disabled and can watch the game from their viewport
- [x] Server sends game countdown to players every sec
- [x] Everyone dead = king victory screen
- [x] 1 > guest alive = guests victory screen
- [x] Play again button sends back to lobby
  - Reset server, connect players to the lobby again if match didn't started
- [x] Refuse connection during a match
- [x] Implement auto patcher
- [x] Setup server repo
- [x] Setup server

**Tweaks**
- [x] Gun rotation lerp
- [x] Add players arts
- [x] Add fonts
- [ ] Add sounds
- [x] Server show how many seconds to match ends to players out of the game
- [x] HP Bar
- [x] Call randomize on king sorter
- [x] Server disconnected feedback
- [x] Spectation mode
- [x] Shoot after game ended


- [x] Make Logger to debug while there's no real game
- [ ] Proper export server and client builds
- [x] Move every static func to an Utils class
- [ ] Handle timeout
- [ ] Create a repository
- [ ] Create branch reproducing issue to report bug when consuming static data from a class and using a normal custom class
https://docs.godotengine.org/en/stable/getting_started/workflow/export/exporting_for_dedicated_servers.html
