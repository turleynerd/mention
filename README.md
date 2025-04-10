# Mention

A World of Warcraft addon that enhances chat with player name mentions.

## Features

- Type `@` followed by part of a player's name to mention them (prefix is customizable)
- Tab cycles through available names
- Press Enter to select a name and continue typing your message
- Options to play a sound when your name is mentioned in chat
- Works with group, raid, and guild members

## Usage

- Type `/mention` for a list of commands
- Type `/mention options` to open the configuration panel
- Type `/mention sound on|off` to enable/disable sound notifications
- Type `/mention prefix X` to change the mention prefix (default: @)

## Sound Files

To get full functionality, you'll need to download sound files and place them in the Sounds folder:

1. Create `.ogg` or `.mp3` sound files 
2. Place them in `Interface\AddOns\Mention\Sounds\`
3. Recommended: `Mention.ogg` and `Whisper.ogg`

You can use any WoW game sound in OGG format as well.

## Support

Created for World of Warcraft Classic Era

## Development

### GitHub Actions

This addon includes a GitHub Actions workflow that automatically packages the addon when you create a new release:

1. **Creating a Release**:
   - Create a new tag following semantic versioning: `git tag v1.0.1`
   - Push the tag to GitHub: `git push origin v1.0.1`
   - The workflow will automatically run and create a release with a packaged ZIP file

2. **Manual Package Creation**:
   - You can also manually trigger the workflow from the Actions tab in GitHub
   - Optionally specify a custom version number

3. **CurseForge Upload**:
   - Download the ZIP from the GitHub release
   - Upload to CurseForge as a new file
   - The ZIP structure matches CurseForge's required format
