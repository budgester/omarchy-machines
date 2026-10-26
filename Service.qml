import QtQuick
import Quickshell
import Quickshell.Io

// Everything the panel shows comes from the machines repo's
// `status.sh --json`. Anything that needs a login or sudo (setting up,
// applying) runs in a floating terminal, never in the shell.
Item {
  id: root

  property var settings: ({})
  property bool panelOpen: false

  // "checking" until the first answer, then "unprovisioned" (no repo
  // here), "in-step", "drift" or "error".
  property string state: "checking"
  property var status: ({})
  property string lastError: ""
  property bool _invited: false

  readonly property string homeDir: String(Quickshell.env("HOME") || "")
  readonly property string repo: String(setting("repo", "budgester/machines")).trim()
  readonly property string repoPath: {
    var p = String(setting("repoPath", "~/Projects/machines")).trim()
    return p.indexOf("~/") === 0 ? homeDir + p.substring(1) : p
  }
  readonly property int checkIntervalMin: intSetting("checkIntervalMin", 60, 5, 1440)
  readonly property string pluginDir: String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/$/, "")

  readonly property bool checking: statusProcess.running
  readonly property var changes: status.changes instanceof Array ? status.changes : []
  readonly property var missingPackages: status.missing_packages instanceof Array ? status.missing_packages : []
  readonly property string checkedAt: String(status.checked_at || "")
  readonly property string lastApply: String(status.last_apply || "")

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null || value === "" ? fallback : value
  }

  function intSetting(name, fallback, min, max) {
    var n = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(n)) n = fallback
    return Math.max(min, Math.min(max, n))
  }

  function refresh() {
    if (statusProcess.running) return
    statusProcess.command = ["bash", "-c",
      'if [ -x "$1/status.sh" ]; then exec "$1/status.sh" --json; else exit 10; fi',
      "status", repoPath]
    statusProcess.running = true
  }

  function quoted(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'"
  }

  function inTerminal(script) {
    Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", script])
  }

  function setUp() {
    inTerminal(quoted(pluginDir + "/setup.sh") + " " + quoted(repo) + " " + quoted(repoPath))
  }

  function apply() {
    inTerminal(quoted(repoPath + "/bootstrap.sh") + "; omarchy-shell -q budgester.machines refresh")
  }

  // Once per machine, the way Omarchy's own first-run invitations work.
  function invite() {
    if (_invited) return
    _invited = true
    Quickshell.execDetached(["bash", "-c",
      'omarchy-done ensure machines-setup-invitation && ' +
      'omarchy-notification-send -u critical -g "$3" "Set up this machine" ' +
      '"Click to rebuild it from $1." --exec "$2"',
      "invite", repo, "omarchy-launch-floating-terminal-with-presentation "
        + quoted(pluginDir + "/setup.sh") + " " + quoted(repo) + " " + quoted(repoPath),
      String.fromCodePoint(0xF0322)]) // laptop
  }

  function applyStatus(exitCode, out, err) {
    if (exitCode === 10) {
      state = "unprovisioned"
      status = ({})
      lastError = ""
      invite()
      return
    }
    try {
      status = JSON.parse(String(out || ""))
      state = ["in-step", "drift", "error"].indexOf(status.state) >= 0 ? status.state : "error"
      lastError = String(status.error || "")
    } catch (e) {
      state = "error"
      lastError = String(err || "").trim().split("\n").pop() || "status.sh gave no answer"
    }
  }

  Component.onCompleted: refresh()
  onRepoPathChanged: refresh()

  Timer {
    interval: root.checkIntervalMin * 60 * 1000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProcess
    running: false
    command: []
    stdout: StdioCollector { id: statusOut; waitForEnd: true }
    stderr: StdioCollector { id: statusErr; waitForEnd: true }
    onExited: function(exitCode) { root.applyStatus(exitCode, statusOut.text, statusErr.text) }
  }
}
