/*
 * ArcShell
 * Copyright (C) 2026 arcxlo (ArchangelOS)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published
 * by the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../"
import "../theme"
import "../popups/"
import "../components"
import "../modules/Right/"
import "../modules/Center/"
import "../modules/Left/"
import "../modules/Bottom/"
import qs.arc.services as NSS

PanelWindow {
    id: root
    ClickShield { id: clickShield }
    readonly property real localScale: Math.max(0.75, Math.min(1.5, (screen ? screen.height : 1080.0) / 1080.0))

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    
    exclusionMode: ExclusionMode.Ignore
    
    color: "transparent"
    visible: !ShellState.shellHidden

    SurfaceInputManager {
        id: inputManager
        anchors.fill: parent
        localScale: root.localScale
        surfaceShape: surfaceShape
        clickShield: clickShield
        screenRecord: ShellState.screenRecord
        screenRecording: ScreenRecService.recording
        optionsExpanded: ScreenRecService.optionsExpanded
        isTopHovered: leftNotchHover.hovered || centerNotchHover.hovered || rightNotchHover.hovered
        isRightHovered: rightNotchHover.hovered
        isLeftCenterHovered: leftCenterNotchHover.hovered
        isRightCenterHovered: rightCenterNotchHover.hovered
        isBottomCenterHovered: bottomCenterNotchHover.hovered
        isBottomRightHovered: bottomRightNotchHover.hovered
    }
    
    WlrLayershell.layer: WlrLayer.Top
    readonly property bool dockResting: !NSS.Shell.launcherVisible && !ShellState.focusMode
    WlrLayershell.namespace: "arcshell-frame"
    WlrLayershell.keyboardFocus: ((SurfaceState.activeSurface !== "none" && !Popups.osdOpened) || (ShellState.screenRecord && !ScreenRecService.recording)) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Region {
        id: fullRegion
        x: 0; y: 0
        width: root.width
        height: root.height
    }

    BackgroundEffect.blurRegion: PrefsService.bgBlur ? fullRegion : null

    mask: Region {
        Region { item: clickShield.isActive ? clickShield : null }
        
        Region { x: 0; y: 0; width: root.width; height: Math.max(1, surfaceShape.frameThickness) }
        Region { x: 0; y: root.height - Math.max(1, surfaceShape.frameThickness); width: root.width; height: Math.max(1, surfaceShape.frameThickness) }
        
        Region { x: 0; y: 0; width: Math.max(1, surfaceShape.frameThickness); height: root.height }
        Region { x: root.width - Math.max(1, surfaceShape.frameThickness); y: 0; width: Math.max(1, surfaceShape.frameThickness); height: root.height }
        
        Region { x: 0; y: 0; width: surfaceShape.leftNotchWidth; height: surfaceShape.leftNotchHeight }
        Region { x: root.width / 2 - surfaceShape.centerNotchWidth / 2; y: 0; width: surfaceShape.centerNotchWidth; height: surfaceShape.centerNotchHeight }
        Region { x: root.width - surfaceShape.rightNotchWidth; y: 0; width: surfaceShape.rightNotchWidth; height: surfaceShape.rightNotchHeight }
        Region { x: Math.round(root.width / 2 - (160 * root.localScale) / 2); y: 0; width: Math.round(160 * root.localScale); height: 1 }
        
        Region { x: 0; y: (surfaceShape.lcnDepth > 1 ? surfaceShape.lcnCenterY : root.height / 2) - (surfaceShape.lcnDepth > 1 ? surfaceShape.lcnHeight : Math.round(200 * root.localScale)) / 2; width: surfaceShape.lcnDepth > 1 ? surfaceShape.le + surfaceShape.lcnDepth : Math.max(28, surfaceShape.frameThickness); height: surfaceShape.lcnDepth > 1 ? surfaceShape.lcnHeight : Math.round(200 * root.localScale) }
        Region { x: root.width - (surfaceShape.rcnDepth > 1 ? surfaceShape.rcnDepth : Math.max(1, surfaceShape.frameThickness)); y: root.height / 2 - (surfaceShape.rcnDepth > 1 ? surfaceShape.rcnHeight : Math.round(200 * root.localScale)) / 2; width: surfaceShape.rcnDepth > 1 ? surfaceShape.rcnDepth : Math.max(1, surfaceShape.frameThickness); height: surfaceShape.rcnDepth > 1 ? surfaceShape.rcnHeight : Math.round(200 * root.localScale) }
        
        Region { x: root.width / 2 - (surfaceShape.bcnDepth > 1 ? surfaceShape.bcnWidth : Math.round(300 * root.localScale)) / 2; y: root.height - (surfaceShape.bcnDepth > 1 ? surfaceShape.bcnDepth : Math.max(1, surfaceShape.frameThickness)); width: surfaceShape.bcnDepth > 1 ? surfaceShape.bcnWidth : Math.round(300 * root.localScale); height: surfaceShape.bcnDepth > 1 ? surfaceShape.bcnDepth : Math.max(1, surfaceShape.frameThickness) }
        Region { x: root.width - (surfaceShape.brnDepth > 1 ? surfaceShape.brnWidth : Math.round(200 * root.localScale)); y: root.height - (surfaceShape.brnDepth > 1 ? surfaceShape.brnDepth : Math.max(1, surfaceShape.frameThickness)); width: surfaceShape.brnDepth > 1 ? surfaceShape.brnWidth : Math.round(200 * root.localScale); height: surfaceShape.brnDepth > 1 ? surfaceShape.brnDepth : Math.max(1, surfaceShape.frameThickness) }
    }

    Item {
        id: topCenterTapTrigger
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: Math.round(160 * root.localScale)
        height: 1
        visible: !SurfaceState.isTopExpanded && (Theme.borderWidth === 0 || ShellState.focusMode)
        z: 9999

        TapHandler {
            onTapped: {
                Popups.closeAll()
                SurfaceState.open("top", "dashboard")
                Popups.dashboardPinned = true
            }
        }
    }

    Item {
        id: fmLeftTrigger
        anchors { left: parent.left; top: parent.top; leftMargin: Math.round(Theme.borderWidth * root.localScale) }
        width: Math.max(Math.round(Theme.lNotchMinWidth * localScale), Math.min(Math.round(Theme.lNotchMaxWidth * localScale), leftContent.implicitWidth + Math.round(Theme.notchPadding * 2 * localScale)))
        height: Math.round(Theme.notchHeight * root.localScale)
        visible: false
        z: -1
        HoverHandler { id: fmLeftHov }
    }
    Item {
        id: fmCenterTrigger
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top }
        width: centerContent.islandWidth
        height: Math.round(Theme.notchHeight * root.localScale)
        visible: false
        z: -1
        HoverHandler { id: fmCenterHov; onHoveredChanged: Popups.dashboardTriggerHovered = hovered }
        TapHandler {
            onTapped: {
                Popups.closeAll()
                SurfaceState.open("top", "dashboard")
                Popups.dashboardPinned = true
            }
        }
    }
    Item {
        id: fmRightTrigger
        anchors { right: parent.right; top: parent.top; rightMargin: Math.round(Theme.borderWidth * root.localScale) }
        width: Math.max(Math.round(Theme.rNotchMinWidth * localScale), Math.min(Math.round(Theme.rNotchMaxWidth * localScale), rightContent.implicitWidth + Math.round(Theme.notchPadding * 2 * localScale)))
        height: Math.round(Theme.notchHeight * root.localScale)
        visible: false
        z: -1
        HoverHandler { id: fmRightHov }
    }

    SurfaceShape {
        id: surfaceShape
        anchors.fill: parent
        localScale: root.localScale
        
        rcnDepth: { 
            if (!SurfaceState.isRightCenterExpanded) return 0.001; 
            if (SurfaceState.activeContent === "audio") return audioPopupView.popupWidth; 
            if (SurfaceState.activeContent === "quick") return quickControlPopupView.popupWidth; 
            return Math.round(Theme.popupMaxWidth * root.localScale); 
        } 
        rcnHeight: { 
            if (!SurfaceState.isRightCenterExpanded) return 0.001; 
            if (SurfaceState.activeContent === "audio") return audioPopupView.popupHeight; 
            if (SurfaceState.activeContent === "quick") return quickControlPopupView.popupHeight; 
            return Math.round(Theme.popupMaxHeight * root.localScale); 
        }
        brnWidth: {
            if (!SurfaceState.isBottomRightExpanded) return innerRadius;
            if (SurfaceState.activeContent === "clipboard") return clipboardPopupView.popupWidth + Math.round(Theme.cornerRadius * root.localScale);
            return Math.round(Theme.popupMaxWidth * root.localScale);
        }
        readonly property vector4d dockPane: NSS.PopoutState.owner === "bar" ? NSS.PopoutState.box : Qt.vector4d(0, 0, 0, 0)
        readonly property bool dockPaneOpen: !SurfaceState.isLeftCenterExpanded && dockPane.z > 1
        property real paneCY: root.height / 2
        onDockPaneChanged: if (dockPane.z > 1) paneCY = dockPane.y + dockPane.w / 2
        lcnCenterY: SurfaceState.isLeftCenterExpanded ? root.height / 2 : paneCY
        lcnDepth: { 
            if (dockPaneOpen) return dockPane.x + dockPane.z - le;
            if (!SurfaceState.isLeftCenterExpanded) return 0.001; 
            if (SurfaceState.activeContent === "archMenu") return archMenuPopupView.popupWidth + Math.round(Theme.cornerRadius * root.localScale); 
            return Math.round(Theme.popupMaxWidth * root.localScale); 
        } 
        lcnHeight: { 
            if (dockPaneOpen) return dockPane.w;
            if (!SurfaceState.isLeftCenterExpanded) return 0.001; 
            if (SurfaceState.activeContent === "archMenu") return archMenuPopupView.popupHeight + Math.round(Theme.cornerRadius * root.localScale * 2); 
            return Math.round(Theme.popupMaxHeight * root.localScale); 
        }
        bcnWidth: { 
            if (!SurfaceState.isBottomCenterExpanded) return (root.dockResting ? quickDock.implicitWidth + Math.round(Theme.notchPadding * 2 * root.localScale) : 0.001); 
            if (SurfaceState.activeContent === "wallpaper") return wallpaperPopupView.popupWidth + Math.round(Theme.cornerRadius * root.localScale * 2); 
            return Math.round(Theme.popupMaxWidth * root.localScale); 
        } 
        bcnDepth: { 
            if (!SurfaceState.isBottomCenterExpanded) return (root.dockResting ? Math.round(Theme.notchHeight * root.localScale) : 0.001); 
            if (SurfaceState.activeContent === "wallpaper") return wallpaperPopupView.popupHeight + Math.round(Theme.cornerRadius * root.localScale); 
            return Math.round(Theme.popupMaxHeight * root.localScale); 
        }
        brnDepth: {
            if (!SurfaceState.isBottomRightExpanded) return 0.001;
            if (SurfaceState.activeContent === "clipboard") return clipboardPopupView.popupHeight + Math.round(Theme.cornerRadius * root.localScale);
            return Math.round(Theme.popupMaxHeight * root.localScale);
        }
        
        leftEdge: ShellState.focusMode ? 0 : 56
        Behavior on leftEdge { NumberAnimation { duration: Anim.transition; easing.type: Easing.OutCubic } }
        leftNotchWidth: (ShellState.focusMode) ? 0.001 : Math.max(Math.round(Theme.lNotchMinWidth * localScale), Math.min(Math.round(Theme.lNotchMaxWidth * localScale), leftContent.implicitWidth + Math.round(Theme.notchPadding * 2 * localScale)))
        leftNotchHeight: (ShellState.focusMode) ? surfaceShape.innerRadius : Math.round(Theme.notchHeight * root.localScale)
        centerNotchWidth: (false && !SurfaceState.isTopExpanded && !ShellState.screenRecord && !ScreenRecService.recording && !Popups.miniPlayerOpen) ? 0.001 : (SurfaceState.isTopExpanded ? Math.round(Popups.dashboardPageWidth * root.localScale) : centerContent.islandWidth)
        centerNotchHeight: {
            if (false && !SurfaceState.isTopExpanded && !ShellState.screenRecord && !ScreenRecService.recording && !Popups.miniPlayerOpen) return 0.001;
            if (SurfaceState.isTopExpanded) return Math.round(Theme.dashboardHeight * root.localScale);
            if (Popups.miniPlayerOpen) return Math.round(Theme.notchHeight * root.localScale) + miniPlayerView.height + Math.round(16 * root.localScale);
            if (ShellState.screenRecord && !ScreenRecService.recording && ScreenRecService.optionsExpanded) return Math.round(Theme.notchHeight * root.localScale) + screenRecOptionsPopupView.height + Math.round(16 * root.localScale);
            return centerContent.islandHeight;
        }
        rightNotchWidth: {
            if (ShellState.focusMode && !SurfaceState.isRightExpanded && !Popups.notificationToastOpen) return 0.001;
            if (!SurfaceState.isRightExpanded) {
                if (Popups.notificationToastOpen) return notificationToastView.toastWidth + Math.round(Theme.cornerRadius * root.localScale);
                return Math.max(Math.round(Theme.rNotchMinWidth * localScale), Math.min(Math.round(Theme.rNotchMaxWidth * localScale), rightContent.implicitWidth + Math.round(Theme.notchPadding * 2 * localScale)));
            }
            if (SurfaceState.activeContent === "network") return Math.round(Theme.networkPopupWidth * root.localScale) + Math.round(Theme.cornerRadius * root.localScale);
            if (SurfaceState.activeContent === "notifications") return notifsPopupView.popupWidth + Math.round(Theme.cornerRadius * root.localScale);
            if (SurfaceState.activeContent === "power") return Math.round(248 * root.localScale);
            return Math.round(Theme.popupMaxWidth * root.localScale);
        }
        rightNotchHeight: {
            if (ShellState.focusMode && !SurfaceState.isRightExpanded && !Popups.notificationToastOpen) return surfaceShape.innerRadius;
            if (!SurfaceState.isRightExpanded) {
                if (Popups.notificationToastOpen) return notificationToastView.targetHeight;
                return Math.round(Theme.notchHeight * root.localScale);
            }
            if (SurfaceState.activeContent === "network") return Math.round(648 * root.localScale);
            if (SurfaceState.activeContent === "notifications") return notifsPopupView.targetHeight;
            if (SurfaceState.activeContent === "power") return Math.round(300 * root.localScale);
            return Math.round(Theme.popupMaxHeight * root.localScale);
        }
        
    }
    
    
    Item {
        id: leftNotchArea
        HoverHandler { id: leftNotchHover }
        width: surfaceShape.leftNotchWidth
        height: surfaceShape.leftNotchHeight
        anchors.left: parent.left
        anchors.leftMargin: Math.round(Theme.borderWidth * root.localScale)
        anchors.top: parent.top
        anchors.topMargin: Math.round(Theme.borderWidth * root.localScale)
        clip: true
        
        opacity: (ShellState.focusMode && !SurfaceState.isTopExpanded) ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Anim.transition; easing.type: Anim.globalCurve; easing.overshoot: Anim.globalOvershoot; easing.amplitude: Anim.globalAmplitude; easing.period: Anim.globalPeriod } }
        
        Item {
            id: leftNotchHead
            width: parent.width
            height: Math.round(Theme.notchHeight * root.localScale)
            anchors.top: parent.top
            
            LeftContent {
                localScale: root.localScale
                id: leftContent
                anchors.left: parent.left
                anchors.leftMargin: Math.round(Theme.borderWidth * root.localScale)
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Item {
        id: centerNotchArea
        HoverHandler { id: centerNotchHover }
        width: surfaceShape.centerNotchWidth
        height: surfaceShape.centerNotchHeight
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.round(Theme.borderWidth * root.localScale)
        clip: true
        
        opacity: (false && !SurfaceState.isTopExpanded && !ShellState.screenRecord && !ScreenRecService.recording) ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Anim.transition; easing.type: Anim.globalCurve; easing.overshoot: Anim.globalOvershoot; easing.amplitude: Anim.globalAmplitude; easing.period: Anim.globalPeriod } }
        
        Item {
            id: centerNotchHead
            width: parent.width
            height: (!SurfaceState.isTopExpanded && !Popups.miniPlayerOpen) ? parent.height : Math.round(Theme.notchHeight * root.localScale)
            anchors.top: parent.top
            
            CenterContent {
                localScale: root.localScale
                id: centerContent
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                notchHovered: centerNotchHover.hovered || fmCenterHov.hovered || ShellState.islandExpanded
            }
        }

        Dashboard {
            id: dashboardView
            layer.enabled: opacity > 0 && opacity < 1
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 40; blur: 1 - dashboardView.opacity; brightness: -0.5 * (1 - dashboardView.opacity) }

            localScale: root.localScale
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            screen: root.screen
            
            opacity: SurfaceState.activeContent === "dashboard" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Anim.transition; easing.type: Anim.globalCurve; easing.overshoot: Anim.globalOvershoot; easing.amplitude: Anim.globalAmplitude; easing.period: Anim.globalPeriod } }
        }
    ScreenRecOptionsPopup {
        id: screenRecOptionsPopupView
        localScale: root.localScale
        x: ScreenRecService.popupTargetX + (ScreenRecService.popupTargetWidth / 2) - (width / 2) - parent.x
        y: Math.round(8 * root.localScale) + Math.round(Theme.notchHeight * root.localScale)
        z: 999
    }
    MiniPlayer {
        id: miniPlayerView
        localScale: root.localScale
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(8 * root.localScale) + Math.round(Theme.notchHeight * root.localScale)
        z: 998
    }
    }

    Item {
        id: rightNotchArea
        HoverHandler { id: rightNotchHover }
        width: surfaceShape.rightNotchWidth
        height: surfaceShape.rightNotchHeight
        anchors.right: parent.right
        anchors.rightMargin: Math.round(Theme.borderWidth * root.localScale)
        anchors.top: parent.top
        anchors.topMargin: Math.round(Theme.borderWidth * root.localScale)
        clip: true
        
        opacity: (ShellState.focusMode && !SurfaceState.isRightExpanded && !Popups.notificationToastOpen) ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Anim.transition; easing.type: Anim.globalCurve; easing.overshoot: Anim.globalOvershoot; easing.amplitude: Anim.globalAmplitude; easing.period: Anim.globalPeriod } }
        
        Item {
            id: rightNotchHead
            width: parent.width
            height: Math.round(Theme.notchHeight * root.localScale)
            anchors.top: parent.top
            
            RightContent {
                localScale: root.localScale
                id: rightContent
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: Math.round(Theme.notchPadding * root.localScale)
            }
        }

        NetworkPopup {
            id: networkPopupView
            layer.enabled: opacity > 0 && opacity < 1
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 40; blur: 1 - networkPopupView.opacity; brightness: -0.5 * (1 - networkPopupView.opacity) }

            localScale: root.localScale
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            screen: root.screen
            
            opacity: SurfaceState.activeContent === "network" ? 1 : 0

            
            visible: opacity > 0

            
            Behavior on opacity { NumberAnimation { duration: Anim.transition; easing.type: Anim.globalCurve; easing.overshoot: Anim.globalOvershoot; easing.amplitude: Anim.globalAmplitude; easing.period: Anim.globalPeriod } }
        }

        Item {
            id: powerPopupView
            anchors.fill: parent
            opacity: SurfaceState.activeContent === "power" ? 1 : 0
            visible: opacity > 0
            layer.enabled: opacity > 0 && opacity < 1
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 40; blur: 1 - powerPopupView.opacity; brightness: -0.5 * (1 - powerPopupView.opacity) }
            Behavior on opacity { NumberAnimation { duration: Anim.transition; easing.type: Anim.globalCurve; easing.overshoot: Anim.globalOvershoot; easing.amplitude: Anim.globalAmplitude; easing.period: Anim.globalPeriod } }
            MouseArea { anchors.fill: parent; onClicked: Popups.powerPinned = true }
            PowerMenu {
                localScale: root.localScale
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: Math.round(28 * root.localScale)
                width: parent.width - Math.round(28 * root.localScale)
                transform: Translate {
                    id: powerMenuTranslate
                    x: SurfaceState.activeContent === "power" ? 0 : width
                    Behavior on x { NumberAnimation { duration: Anim.transition * 1.2; easing.type: Easing.OutCubic } }
                }
            }
        }

        NotificationsPopup {
            id: notifsPopupView
            layer.enabled: opacity > 0 && opacity < 1
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 40; blur: 1 - notifsPopupView.opacity; brightness: -0.5 * (1 - notifsPopupView.opacity) }

            localScale: root.localScale
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            
            opacity: SurfaceState.activeContent === "notifications" ? 1 : 0

            
            visible: opacity > 0

            
            Behavior on opacity { NumberAnimation { duration: Anim.transition; easing.type: Anim.globalCurve; easing.overshoot: Anim.globalOvershoot; easing.amplitude: Anim.globalAmplitude; easing.period: Anim.globalPeriod } }
        }

        NotificationToast {
            id: notificationToastView
            localScale: root.localScale
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            
            opacity: Popups.notificationToastOpen && !Popups.notificationsOpen ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Anim.transition; easing.type: Anim.globalCurve; easing.overshoot: Anim.globalOvershoot; easing.amplitude: Anim.globalAmplitude; easing.period: Anim.globalPeriod } }
        }
    }

    Item {
        id: leftCenterNotchArea
        HoverHandler { id: leftCenterNotchHover }
        width: surfaceShape.lcnDepth
        height: surfaceShape.lcnHeight
        anchors.left: parent.left
        anchors.leftMargin: surfaceShape.le     // ArchangelOS: out of the bar's edge
        anchors.verticalCenter: parent.verticalCenter

        ArchMenu {
            id: archMenuPopupView
            layer.enabled: opacity > 0 && opacity < 1
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 40; blur: 1 - archMenuPopupView.opacity; brightness: -0.5 * (1 - archMenuPopupView.opacity) }

            localScale: root.localScale
            anchors.fill: parent
            opacity: SurfaceState.activeContent === "archMenu" ? 1 : 0

            visible: opacity > 0

            Behavior on opacity { NumberAnimation { duration: Anim.transition; easing.type: Anim.globalCurve; easing.overshoot: Anim.globalOvershoot; easing.amplitude: Anim.globalAmplitude; easing.period: Anim.globalPeriod } }
        }
    }

    Item {
        id: rightCenterNotchArea
        HoverHandler { id: rightCenterNotchHover; onHoveredChanged: Popups.rightCenterHovered = hovered }
        width: surfaceShape.rcnDepth > 1 ? surfaceShape.rcnDepth : Math.max(1, surfaceShape.frameThickness)
        height: surfaceShape.rcnDepth > 1 ? surfaceShape.rcnHeight : Math.round(200 * root.localScale)
        anchors.right: parent.right
        anchors.rightMargin: Math.round(Theme.borderWidth * root.localScale)
        anchors.verticalCenter: parent.verticalCenter

        AudioPopup {
            id: audioPopupView
            layer.enabled: opacity > 0 && opacity < 1
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 40; blur: 1 - audioPopupView.opacity; brightness: -0.5 * (1 - audioPopupView.opacity) }

            localScale: root.localScale
            anchors.fill: parent
            opacity: SurfaceState.activeContent === "audio" ? 1 : 0

            visible: opacity > 0

            Behavior on opacity { NumberAnimation { duration: Anim.transition; easing.type: Anim.globalCurve; easing.overshoot: Anim.globalOvershoot; easing.amplitude: Anim.globalAmplitude; easing.period: Anim.globalPeriod } }
        }

        QuickControl {
            id: quickControlPopupView
            layer.enabled: opacity > 0 && opacity < 1
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 40; blur: 1 - quickControlPopupView.opacity; brightness: -0.5 * (1 - quickControlPopupView.opacity) }

            localScale: root.localScale
            anchors.fill: parent
            opacity: SurfaceState.activeContent === "quick" ? 1 : 0

            visible: opacity > 0

            Behavior on opacity { NumberAnimation { duration: Anim.transition; easing.type: Anim.globalCurve; easing.overshoot: Anim.globalOvershoot; easing.amplitude: Anim.globalAmplitude; easing.period: Anim.globalPeriod } }
        }
    }

    Item {
        id: bottomCenterNotchArea
        HoverHandler { id: bottomCenterNotchHover }
        width: surfaceShape.bcnWidth
        height: surfaceShape.bcnDepth
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(Theme.borderWidth * root.localScale)

        Item {
            id: bottomEdgeTrigger
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: Math.round(160 * root.localScale)
            height: Math.round(4 * root.localScale)
            visible: false
            z: 1
            HoverHandler { id: bottomEdgeHover; onHoveredChanged: Popups.bottomDockHovered = hovered }
        }

        QuickDock {
            id: quickDock
            localScale: root.localScale
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round((Theme.notchHeight * root.localScale - height) / 2)
            opacity: root.dockResting && !SurfaceState.isBottomCenterExpanded ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Anim.mediumFast } }
        }

        // sibling of quickDock so the anchors resolve; bottomCenterNotchArea does not clip
        TermThemePopup {
            id: termThemePopup
            localScale: root.localScale
            anchors.bottom: quickDock.top
            anchors.horizontalCenter: quickDock.horizontalCenter
            anchors.bottomMargin: Math.round(-6 * root.localScale)
            open: Popups.termThemeOpen
            z: 100
        }

        WallpaperFlow {
            id: wallpaperPopupView
            localScale: root.localScale
            anchors.fill: parent
            opacity: SurfaceState.activeContent === "wallpaper" ? 1 : 0

            visible: opacity > 0

            Behavior on opacity { NumberAnimation { duration: Anim.transition; easing.type: Anim.globalCurve; easing.overshoot: Anim.globalOvershoot; easing.amplitude: Anim.globalAmplitude; easing.period: Anim.globalPeriod } }
        }
    }

    Item {
        id: bottomRightNotchArea
        HoverHandler { id: bottomRightNotchHover }
        width: surfaceShape.brnWidth
        height: surfaceShape.brnDepth
        anchors.right: parent.right
        anchors.rightMargin: Math.round(Theme.borderWidth * root.localScale)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(Theme.borderWidth * root.localScale)

        ClipboardPopup {
            id: clipboardPopupView
            layer.enabled: opacity > 0 && opacity < 1
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 40; blur: 1 - clipboardPopupView.opacity; brightness: -0.5 * (1 - clipboardPopupView.opacity) }

            localScale: root.localScale
            anchors.fill: parent
            opacity: SurfaceState.activeContent === "clipboard" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Anim.transition; easing.type: Anim.globalCurve; easing.overshoot: Anim.globalOvershoot; easing.amplitude: Anim.globalAmplitude; easing.period: Anim.globalPeriod } }
        }
    }

}