# Security

Audio Resolver is an independent, unsandboxed Omarchy community plugin. It runs
with the current user's permissions. Marketplace review does not provide a
sandbox, certification, or guarantee.

## Runtime behavior

- Audio Resolver does not make network requests or require elevated privileges.
- The watcher reads media only from the selected source folder.
- Converted files are written only to the selected destination folder.
- Original media is never modified.
- Folder paths are passed as arguments to the picker, `ffmpeg`, `ffprobe`, and
  helper scripts; they are not interpolated into shell commands.
- The plugin depends on external tools including `ffmpeg`, `ffprobe`,
  `inotifywait`, and the Omarchy file picker. Only install those dependencies
  from sources you trust.
- Settings and import history are stored in the user's configuration and state
  directories outside the plugin directory.

## Reporting a vulnerability

Please do not report security vulnerabilities in a public issue. Use [GitHub's
private vulnerability reporting
feature](https://github.com/techwhispers/omarchy-audio-resolver/security/advisories/new)
to report a suspected vulnerability confidentially.

If private reporting is unavailable, contact the repository maintainer through
GitHub before disclosing the issue publicly. Include the affected file or
component, the steps needed to reproduce the issue, and any relevant impact.
