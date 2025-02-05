# ASA - Media Player
ASA Media Player is a Garry's Mod addon that allows players to play youtube videos within the game.

## Requirements
- Garry's Mod x64 branch (Chromium/CEF)

## How it works
1. The video ID is sent to the server
2. Server calls the YT-DLP API to request the video information and strictly requests video and audio format, which the x64 branch of Garry's Mod supports (VP9 video with Opus audio - WebM)
3. Server returns the Google's direct CDN media links to all players
4. Clientside HTML plays both video and audio, synchronizes them so that you don't have offseted video or audio

## Features
- **No Youtube Ads**: Videos are played directly, no Youtube Embed API.
- **Emissive Lighting**: Projector screen emits light, similar to ambient light on TVs in real life.
- **Synchronized Playback**: Playback is synchronized with other players.

## Clientside ConVars
- `asa_mediaplayer_max_distance`: Maximum distance to draw any media player screen.
- `asa_mediaplayer_sync_delay`: Media player sync check delay.
- `asa_mediaplayer_sync_threshold`: Media player sync threshold.
- `asa_mediaplayer_emissive_light`: Enable or disable emissive light.
- `asa_mediaplayer_emissive_size`: Size of the emissive light render target.
- `asa_mediaplayer_volume`: Volume of the media player.

## Serverside ConVars
- `sv_asa_mediaplayer_api`: YT-DLP API URL to use, defaults to my hosted instance (which is not guaranteed to work 100% of the time)

## Self-hosting the API
The PHP script is located in the `api` directory

## Contributing
Contributions are welcome! Please submit a pull request or open an issue to discuss any changes.

## License
This project is licensed under the MIT License.