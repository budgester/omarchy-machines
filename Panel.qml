import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Machines in the bar: one icon that says whether this machine matches its
// machines repo, and a panel to set it up, check it or apply the repo.
Panel {
  id: root
  moduleName: "budgester.machines"
  ipcTarget: "budgester.machines"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color amberColor: mix(urgent, foreground)
  readonly property color barAmberColor: mix(urgent, barForeground)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property bool attention: machines.state === "unprovisioned" || machines.state === "error"
  readonly property bool amber: machines.state === "drift"
  readonly property bool quiet: machines.state === "checking"

  readonly property color barIconColor: amber ? barAmberColor
    : (quiet ? Qt.darker(barForeground, 1.55) : barForeground)
  readonly property color iconColor: attention ? urgent : (amber ? amberColor : (quiet ? dim : foreground))

  function glyph() {
    if (attention) return String.fromCodePoint(0xF0026)          // alert
    if (amber) return String.fromCodePoint(0xF002A)              // alert, in outline
    if (machines.checking) return String.fromCodePoint(0xF04E6)  // sync
    return String.fromCodePoint(0xF0322)                         // laptop
  }

  function mix(a, b) {
    return Qt.rgba((a.r + b.r) / 2, (a.g + b.g) / 2, (a.b + b.b) / 2, 1)
  }

  function count(n, one, many) {
    return n + " " + (n === 1 ? one : many)
  }

  function headline() {
    switch (machines.state) {
      case "checking": return "Checking…"
      case "unprovisioned": return "This machine isn't set up"
      case "in-step": return "Matches " + machines.repo
      case "drift": return count(machines.changes.length + machines.missingPackages.length,
        "difference", "differences") + " from " + machines.repo
      default: return "The check failed"
    }
  }

  // "2026-10-26T17:43:58+00:00" as "26 Oct 17:43"; the commit after it, if any.
  function when(stamp) {
    var parts = String(stamp || "").split(" ")
    var d = new Date(parts[0])
    if (isNaN(d.getTime())) return "never"
    var said = Qt.formatDateTime(d, "d MMM HH:mm")
    return parts.length > 1 ? said + " (" + parts[1] + ")" : said
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    machines.refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Service {
    id: machines
    settings: root.settings
    panelOpen: root.opened
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { machines.refresh(); return "ok" }
    function status(): string { return machines.state }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.glyph()
    foreground: root.barIconColor
    active: root.attention
    tooltipText: "Machines: " + root.headline()
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) machines.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") machines.refresh()
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(10)

          PanelHero {
            width: parent.width
            title: "Machines"
            meta: root.headline()
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                textFormat: Text.PlainText
                text: root.glyph()
                color: root.iconColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
          }

          Note {
            visible: machines.state === "unprovisioned"
            text: "Nothing from " + machines.repo + " is at " + machines.repoPath
              + ". Setting up logs in to GitHub if needed, clones the repo and runs its bootstrap, which asks for your password."
          }

          Note {
            visible: machines.state === "error" && machines.lastError !== ""
            text: machines.lastError
          }

          Repeater {
            model: machines.changes
            delegate: ActionRow {
              width: column.width
              acts: false
              icon: String.fromCodePoint(0xF03EB) // pencil
              title: String(modelData.task || "")
              detail: "would change · " + String(modelData.role || "")
            }
          }

          Repeater {
            model: machines.missingPackages
            delegate: ActionRow {
              width: column.width
              acts: false
              icon: String.fromCodePoint(0xF03D3) // package
              title: String(modelData)
              detail: "package not installed"
            }
          }

          ActionRow {
            visible: machines.state === "unprovisioned"
            width: column.width
            icon: String.fromCodePoint(0xF0322)
            title: "Set up this machine"
            detail: "Opens a terminal"
            actionIcon: String.fromCodePoint(0xF0142) // chevron right
            onActivated: { root.close(); machines.setUp() }
          }

          ActionRow {
            visible: machines.state === "drift" || machines.state === "error"
            width: column.width
            icon: String.fromCodePoint(0xF040A) // play
            title: "Apply " + machines.repo
            detail: "Runs bootstrap.sh in a terminal"
            actionIcon: String.fromCodePoint(0xF0142)
            onActivated: { root.close(); machines.apply() }
          }

          ActionRow {
            visible: machines.state !== "unprovisioned"
            width: column.width
            acts: !machines.checking
            icon: String.fromCodePoint(0xF0450) // refresh
            title: machines.checking ? "Checking…" : "Check now"
            detail: machines.checkedAt !== "" ? "Last checked " + root.when(machines.checkedAt) : ""
            onActivated: machines.refresh()
          }

          Note {
            visible: machines.state !== "unprovisioned" && machines.state !== "checking"
            text: "Last applied " + root.when(machines.lastApply)
          }
        }
      }
    }
  }

  component Note: Text {
    textFormat: Text.PlainText
    width: parent ? parent.width : implicitWidth
    leftPadding: Style.space(10)
    rightPadding: Style.space(10)
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WordWrap
  }

  // A row that does one thing when clicked; `acts: false` makes it a plain line.
  component ActionRow: CursorSurface {
    id: actionRow
    property string icon: ""
    property string title: ""
    property string detail: ""
    property string actionIcon: ""
    property bool acts: true
    signal activated()

    hasCursor: actionRow.acts && rowMouse.containsMouse
    foreground: root.foreground
    implicitHeight: rowContent.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      id: rowMouse
      anchors.fill: parent
      visible: actionRow.acts
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: actionRow.activated()
    }

    RowLayout {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      Text {
        textFormat: Text.PlainText
        text: actionRow.icon
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        Layout.alignment: Qt.AlignVCenter
      }

      ColumnLayout {
        id: rowContent
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: actionRow.title
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }
        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          visible: actionRow.detail !== ""
          text: actionRow.detail
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      Text {
        textFormat: Text.PlainText
        visible: actionRow.acts && actionRow.actionIcon !== ""
        text: actionRow.actionIcon
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        Layout.alignment: Qt.AlignVCenter
      }
    }
  }
}
