/*
 * Copyright (c) 2021 Meltytech, LLC
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import QtQuick.Dialogs 1.2
import QtQuick.Window 2.1
import Shotcut.Controls 1.0 as Shotcut
import org.shotcut.qml 1.0 as Shotcut
import QtQml.Models 2.12

Item {
	id: gpsTextRoot
	width: 300
	height: 800
	
	property url settingsOpenPath: 'file:///' + settings.openPath
	Shotcut.File { id: gpsFile }
	
	Component.onCompleted: {
		var resource = filter.get('gps.file')
		gpsFile.url = resource
		
		filter.blockSignals = true

		filter.set(textFilterUi.middleValue, Qt.rect(0, 0, profile.width, profile.height))
		filter.set(textFilterUi.startValue, Qt.rect(0, 0, profile.width, profile.height))
		filter.set(textFilterUi.endValue, Qt.rect(0, 0, profile.width, profile.height))
		if (filter.isNew) {
			var presetParams = preset.parameters.slice()
			var index = presetParams.indexOf('argument')
			if (index > -1)
				presetParams.splice(index, 1)

			if (application.OS === 'Windows')
				filter.set('family', 'Verdana')
			filter.set('fgcolour', '#ffffffff')
			filter.set('bgcolour', '#00000000')
			filter.set('olcolour', '#aa000000')
			filter.set('outline', 3)
			filter.set('weight', 10 * Font.Normal)
			filter.set('style', 'normal')
			filter.set(textFilterUi.useFontSizeProperty, false)
			filter.set('size', profile.height)
			
			// Add default preset.
			filter.set(textFilterUi.valignProperty, 'bottom')
			filter.set(textFilterUi.halignProperty, 'left')
			filter.set(textFilterUi.rectProperty, '10%/10%:80%x80%')
			filter.savePreset(presetParams)
			
			filter.set(textFilterUi.rectProperty, filter.getRect(textFilterUi.rectProperty))
		} else {
			filter.set(textFilterUi.middleValue, filter.getRect(textFilterUi.rectProperty, filter.animateIn + 1))
			if (filter.animateIn > 0)
				filter.set(textFilterUi.startValue, filter.getRect(textFilterUi.rectProperty, 0))
			if (filter.animateOut > 0)
				filter.set(textFilterUi.endValue, filter.getRect(textFilterUi.rectProperty, filter.duration - 1))
		}

		//gps properties
		if (filter.isNew) {
			filter.set('major_offset', 0);
			filter.set('minor_offset', 0);
			filter.set('majoroffset_sign', 1);
			filter.set('smoothing_value', 5);
			filter.set('videofile_timezone_seconds', 0);
			if (filter.get('gps_start_text') == '')
				filter.set('gps_processing_start_time', 'yyyy-MM-dd hh:mm:ss');
			else
				filter.set('gps_processing_start_time', filter.get('gps_start_text'));
			set_sec_offset_to_textfields(0);
			filter.set('speed_multiplier', 1)
			filter.set('updates_per_second', 1);
		}
		else {
			if (filter.get('gps_processing_start_time') == 'yyyy-MM-dd hh:mm:ss' && filter.get('gps_start_text') != '')
				filter.set('gps_processing_start_time', filter.get('gps_start_text'));
		}
		
		filter.blockSignals = false

		setControls();
		gps_setControls();
	}

	FileDialog {
		id: fileDialog
		modality: application.dialogModality
		selectMultiple: false
		selectFolder: false
		folder: settingsOpenPath
		nameFilters: ['Supported files (*.gpx *.tcx)', 'GPS Exchange Format (*.gpx)', 'Training Center XML (*.tcx)']
		onAccepted: {
			gpsFile.url = fileDialog.fileUrl
			fileLabel.text = gpsFile.fileName
			fileLabel.color = activePalette.text
			fileLabelTip.text = gpsFile.filePath
			filter.set('gps.file', gpsFile.url)
			filter.set('gps_start_text', '')
			filter.set('gps_processing_start_time', 'yyyy-MM-dd hh:mm:ss');
			gpsFinishParseTimer.restart()
			settings.openPath = path
		}
	}
	
	function smooth_value_to_index(val) {
		switch (parseInt(val)) {
			case 0: return 0;
			case 1: return 1;
			case 3: return 2;
			case 5: return 3;
			case 7: return 4;
			case 11: return 5;
			case 15: return 6;
			case 31: return 7;
			case 63: return 8;
			case 127: return 9;
			default: {
				console.log("default switch, val= " + val);
				return 0;
			}
		}
	}
	
	//timer to update UI after gps file is processed; max: 10x250ms
	Timer {
		id: gpsFinishParseTimer
		interval: 250
		repeat: true
		triggeredOnStart: false
		property int calls: 0
		onTriggered: {
			if (filter.get('gps_start_text') == '' || filter.get('gps_start_text') == '--') {
				calls += 1;
				if (calls > 10) {
					gpsFinishParseTimer.stop();
					calls = 0;
					gps_setControls();
				}
			}
			else {
				gpsFinishParseTimer.stop();
				calls = 0;
				filter.set('gps_processing_start_time', filter.get('gps_start_text'));
				gps_setControls();
			}
		}
	}

	function setControls() {
		textArea.text = filter.get('argument');
		textFilterUi.setControls();

		//gps properties
		if (filter.isNew) {
			set_sec_offset_to_textfields(0);
		}
		else {
			set_sec_offset_to_textfields(filter.get('major_offset'));
			combo_smoothing.currentIndex = smooth_value_to_index(filter.get('smoothing_value'));
		}

		if (filter.get('gps_start_text') == '')
			filter.set('gps_processing_start_time', 'yyyy-MM-dd hh:mm:ss');
		else
			filter.set('gps_processing_start_time', filter.get('gps_start_text'));

		speed_multiplier.text = filter.get('speed_multiplier');
		video_start.text = filter.get('video_start_text');
		gps_start.text = filter.get('gps_start_text');
		offset_slider.value = filter.get('minor_offset');
	}

	function gps_setControls() {
		if (gpsFile.exists()) {
			fileLabel.text = gpsFile.fileName
			fileLabelTip.text = gpsFile.filePath
		} else {
			fileLabel.text = qsTr("No File Loaded")
			fileLabel.color = 'red'
			fileLabelTip.text = qsTr('No GPS file loaded.\nClick "Open" to load a file.')
		}

		video_start.text = filter.get('video_start_text');
		gps_start.text = filter.get('gps_start_text');
		if (filter.get('gps_processing_start_time') == 'yyyy-MM-dd hh:mm:ss' && filter.get('gps_start_text') != '')
			filter.set('gps_processing_start_time', filter.get('gps_start_text'));
		gps_processing_start.text = filter.get('gps_processing_start_time');
	}
	
	//this function combines the text values from sign combobox * days/hours/mins/sec TextFields into an int
	function recompute_major_offset() {
		var offset_sec = parseInt(Number(offset_days.text), 10)*24*60*60 + 
						 parseInt(Number(offset_hours.text), 10)*60*60 +
						 parseInt(Number(offset_mins.text), 10)*60 +
						 parseInt(Number(offset_secs.text), 10);
		offset_sec *= parseInt(filter.get('majoroffset_sign'), 10);
		filter.set('major_offset', Number(offset_sec).toFixed(0))
	}
	
	//updates text values in each TextField.text to individual parts of the number 
	function set_sec_offset_to_textfields(secs) {
		if (secs === '')
			return; 
			
		if (secs < 0) {
			combo_majoroffset_sign.currentIndex = 1
			filter.set('majoroffset_sign', -1)
		}
		else {
			combo_majoroffset_sign.currentIndex = 0
			filter.set('majoroffset_sign', 1)
		}

		offset_days.text = parseInt( Math.abs(secs)/(24*60*60) , 10 )
		offset_hours.text = parseInt( Math.abs(secs)/(60*60)%24 , 10 )
		offset_mins.text = parseInt( Math.abs(secs)/60%60 , 10 )
		offset_secs.text = parseInt( Math.abs(secs)%60 , 10 )
		
		filter.set('major_offset', Number(secs).toFixed(0))
	}
	
	
	
	GridLayout {
		id: mainGrid
		columns: 2
		anchors.fill: parent
		anchors.margins: 8
		width: 300

		Shotcut.Button {
			id: openButton
			text: qsTr('Open')
			Layout.alignment: Qt.AlignRight
			onClicked: {
				fileDialog.selectExisting = true
				fileDialog.title = qsTr( "Open GPS File" )
				fileDialog.open()
			}
		}
		Label {
			id: fileLabel
			Layout.columnSpan: 1
			Layout.fillWidth: true
			Shotcut.HoverTip { id: fileLabelTip }
		}
		

		Label {
			topPadding: 10
			bottomPadding: 5
			text: qsTr('<b>Sync Options</b>')
			Layout.columnSpan: 2
		}
		
		RowLayout {
			width: 300
			Layout.columnSpan: 2
			
			Label {
				text: qsTr('Video start time:')
				leftPadding: 10
				Layout.alignment: Qt.AlignRight
				Shotcut.HoverTip { text: qsTr('DateTime for the video file') }
			} Label {
				id: video_start
				text: filter.get('video_start_text')
				Layout.alignment: Qt.AlignLeft
				Layout.columnSpan: 1
				Shotcut.HoverTip { text: "This time will be used for synchronization.\nLikely in UTC or local time." }
			}
			
			Label {
				id: start_location_datetime
				text: qsTr('GPS start time:')
				leftPadding: 20
				Layout.alignment: Qt.AlignRight
				Shotcut.HoverTip { text: qsTr('DateTime for the GPS file') }
			} Label {
				id: gps_start
				text: filter.get('gps_start_text')
				Layout.alignment: Qt.AlignLeft
				Layout.columnSpan: 1
				Shotcut.HoverTip { text: qsTr('This time will be used for synchronization.\nAlways in UTC timezone.') }
			}
		}
		
		Label {
			id: gps_sync_major
			text: qsTr('GPS major offset')
			Layout.alignment: Qt.AlignRight
			leftPadding: 10
			Shotcut.HoverTip { text: qsTr('This value is added to video time to sync with gps time.') }
		} 
		GridLayout {
			rows: 1
			columns: 2
			width: 300
			
			RowLayout {
				Layout.alignment: Qt.AlignLeft
				Shotcut.ComboBox {
					id: combo_majoroffset_sign
					implicitWidth: 40
					model: ListModel {
						id: sign_val
						ListElement { text: '+'; value: 1}
						ListElement { text: '-'; value: -1}
					}
					currentIndex: 0
					textRole: 'text'
					Shotcut.HoverTip { text: qsTr('+ : Adds time to video (use if GPS is ahead)\n - : Substracts time from video (use if video is ahead)') }
					onActivated: {
						filter.set('majoroffset_sign', sign_val.get(currentIndex).value)
						recompute_major_offset()
					}
				}
				Label {
					text: qsTr('days:')
					Layout.alignment: Qt.AlignRight
					Shotcut.HoverTip { text: qsTr('Number of days to add/substract to video time to sync them.') }
				}
				TextField {
					id: offset_days
					text: '0'
					horizontalAlignment: TextInput.AlignLeft
					validator: IntValidator {bottom: 0; top: 36600;}
					implicitWidth: 25
					onFocusChanged: if (focus) selectAll()
					onEditingFinished: recompute_major_offset()
				}
				Label {
					text: qsTr(' h:')
					Layout.alignment: Qt.AlignRight
					Shotcut.HoverTip { text: qsTr('Number of hours to add/substract to video time to sync them.') }
				} 
				TextField {
					id: offset_hours
					text: '0'
					horizontalAlignment: TextInput.AlignLeft
					validator: IntValidator {bottom: 0; top: 59;}
					implicitWidth: 20
					onFocusChanged: if (focus) selectAll()
					onEditingFinished: recompute_major_offset()
				}
				Label {
					text: qsTr(' m:')
					Layout.alignment: Qt.AlignRight
					Shotcut.HoverTip { text: qsTr('Number of minutes to add/substract to video time to sync them.') }
				} 
				TextField {
					id: offset_mins
					text: '0'
					horizontalAlignment: TextInput.AlignLeft
					validator: IntValidator {bottom: 0; top: 59;}
					implicitWidth: 20
					onFocusChanged: if (focus) selectAll()
					onEditingFinished: recompute_major_offset() 
				}
				Label {
					text: qsTr(' s:')
					Layout.alignment: Qt.AlignRight
					Shotcut.HoverTip { text: qsTr('Number of seconds to add/substract to video time to sync them.') }
				} 
				TextField {
					id: offset_secs
					text: '0'
					horizontalAlignment: TextInput.AlignLeft
					validator: IntValidator {bottom: 0; top: 59;}
					implicitWidth: 20
					onFocusChanged: if (focus) selectAll()
					onEditingFinished: recompute_major_offset()
				}
			}
			
			RowLayout {
				Layout.leftMargin: 18
				Layout.alignment: Qt.AlignRight
				Shotcut.Button {
					icon.source: 'qrc:///icons/dark/32x32/document-open-recent'
					Shotcut.HoverTip { text: 'Remove timezone time from video file (convert to UTC)' +
						'\n\nLocal timezone to remove: ' + filter.get('videofile_timezone_seconds') + ' seconds' +
						'\nNote: use this if your video camera doesn\'t have timezone settings as it usually  will set local time as UTC timezone.' }
					implicitWidth: 20
					implicitHeight: 20
					onClicked: { set_sec_offset_to_textfields(filter.get('videofile_timezone_seconds')) }
				}
				Shotcut.Button {
					icon.source: 'qrc:///icons/dark/32x32/media-skip-backward'
					Shotcut.HoverTip { text: 'Sync start of GPS to start of video file' +
						'\nNote: use this if you started GPS and video recording at the same time' }
					implicitWidth: 20
					implicitHeight: 20
					onClicked: { set_sec_offset_to_textfields(filter.get('auto_gps_offset_start')) }
				}
				Shotcut.Button {
					icon.source: 'qrc:///icons/dark/32x32/media-playback-pause'
					Shotcut.HoverTip { text: 'Sync start of GPS to current video file time at playhead' +
						'\nNote: use this if you started GPS recording after video recording and filmed the moment of first fix' }
					implicitWidth: 20
					implicitHeight: 20
					onClicked: { set_sec_offset_to_textfields(filter.get('auto_gps_offset_now')) }
				}
				Shotcut.UndoButton {
					onClicked: {
						set_sec_offset_to_textfields(0);
						//offset_secs.text = 0; 
					}
				}
			}
		}
		
		Label {
			id: gps_sync_minor
			text: qsTr('GPS minor offset')
			Layout.alignment: Qt.AlignRight
			leftPadding: 10
			Shotcut.HoverTip { text: qsTr('This value is also added to gps time to sync with video time') }
		} 
		RowLayout {
			Shotcut.SliderSpinner {
				id: offset_slider
				minimumValue: -60
				maximumValue: 60
				Layout.maximumWidth: 300
				implicitWidth: 300
				suffix: ' seconds'
				onValueChanged: {
					filter.set('minor_offset', value)
				}
			}
			Shotcut.Button {
				icon.source: 'qrc:///icons/dark/32x32/lift'
				Shotcut.HoverTip { text: qsTr('Move this offset into the major offset above') }
				implicitWidth: 20 
				implicitHeight: 20
				onClicked: {
					var new_offset = parseInt(Number(filter.get('minor_offset')), 10) + parseInt(Number(filter.get('major_offset')), 10); 
					set_sec_offset_to_textfields(new_offset); 
					offset_slider.value = 0;
					filter.set('minor_offset', 0);
				}
			}
			Shotcut.UndoButton {
				Layout.alignment: Qt.AlignLeft
				onClicked: { 
					offset_slider.value = 0; 
					filter.set('minor_offset', 0)
				}
			}
		}
				
		Label {
			topPadding: 10
			bottomPadding: 5
			text: qsTr('<b>Processing Options</b>')
			Layout.columnSpan: 2
		}
		
		Label {
			text: qsTr('GPS smoothing')
			leftPadding: 10
			Layout.alignment: Qt.AlignRight
			Shotcut.HoverTip { text: qsTr('Average nearby GPS points to smooth out errors.') }
		}
		RowLayout {
			Shotcut.ComboBox {
				implicitWidth: 300
				id: combo_smoothing
				model: 
					[	qsTr('0 (raw data)'),					//0
						qsTr('1 (interpolate missing data)'),	//1
						qsTr('3 points'),						//2
						qsTr('5 points'),						//3
						qsTr('7 points'),						//4
						qsTr('11 points'),						//5
						qsTr('15 points'),						//6
						qsTr('31 points'),						//7
						qsTr('63 points'),						//8
						qsTr('127 points')						//9
					]
				Shotcut.HoverTip { text: qsTr('Smoothing is done by taking the average of X points.\nInterpolation is linearly done for missing values of altitude or heart rate.\nGPS data (speed, distance etc) computing is done only for smoothing > 0') }
				currentIndex: 3
				onActivated: {
					switch (currentIndex) {
						case 0:
							onClicked: filter.set('smoothing_value', 0)
							break
						case 1:
							onClicked: filter.set('smoothing_value', 1)
							break
						case 2:
							onClicked: filter.set('smoothing_value', 3)
							break
						case 3:
							onClicked: filter.set('smoothing_value', 5)
							break
						case 4:
							onClicked: filter.set('smoothing_value', 7)
							break
						case 5:
							onClicked: filter.set('smoothing_value', 11)
							break;
						case 6:
							onClicked: filter.set('smoothing_value', 15)
							break;
						case 7:
							onClicked: filter.set('smoothing_value', 31)
							break;
						case 8:
							onClicked: filter.set('smoothing_value', 63)
							break;
						case 9:
							onClicked: filter.set('smoothing_value', 127)
							break;
						default:
							console.log('combo_smoothing: current index not supported: ' + currentIndex)
					}
				}
			}
			Shotcut.UndoButton {
				onClicked: {
					combo_smoothing.currentIndex = 3
					filter.set('smoothing_value', 5)
				}
			}
		}
		
		RowLayout {
			Layout.columnSpan: 2
			width: 250
			
			Label {
				text: qsTr('Start processing at')
				leftPadding: 10
				Layout.alignment: Qt.AlignRight
				Shotcut.HoverTip { text: qsTr('GPS distances are calculated since the start of gps file, if you want to ignore the begining (for example when tracking a single lap) you can set here the time to start processing (UTC).') }
			}
			TextField {
				id: gps_processing_start
				text: 'yyyy-MM-dd hh:mm:ss'
				horizontalAlignment: TextInput.AlignRight
				//TODO: regex to validate date yyyy-MM-dd hh:mm:ss
				implicitWidth: 128
				Shotcut.HoverTip { text: qsTr('Insert a date and time formatted as: YYYY-MM-DD HH:MM:SS (all fields mandatory), UTC timezone - same as GPS (use #gps_datetime_now# in filter to get current time).') }
				onEditingFinished: filter.set('gps_processing_start_time', gps_processing_start.text);
			}
			Shotcut.UndoButton {
				onClicked: {
					gps_processing_start.text = filter.get('gps_start_text');
					filter.set('gps_processing_start_time', filter.get('gps_start_text'));
				}
			}
			/*
			//TODO: button to set current time as processing start (need to somehow convert current gps time to proper datetime)
			Shotcut.Button {
				//icon.source: 'qrc:///icons/dark/32x32/media-skip-forward'
				icon.source: 'qrc:///icons/dark/32x32/media-playback-pause'
				Shotcut.HoverTip { 
					text: 'Sync start of GPS processing to current video file time at playhead'
				}
				implicitWidth: 20
				implicitHeight: 20
				onClicked: {
					var seconds = Date.parse(filter.get('gps_start_text'))/1000 + filter.get('auto_gps_offset_now');
					var d = new Date(seconds*1000)
					gps_processing_start.text = d.toUTCString();
				}
			}
			*/
		}
				
		Label {
			topPadding: 10
			bottomPadding: 5
			text: qsTr('<b>Text Options</b>')
			Layout.columnSpan: 2
		}
		
		Label {
			text: qsTr('Preset')
			Layout.alignment: Qt.AlignRight
		}
		Shotcut.Preset {
			id: preset
			Layout.columnSpan: 1
			parameters: textFilterUi.parameters.concat(['argument'])
			onBeforePresetLoaded: {
				filter.resetProperty(textFilterUi.rectProperty)
			}
			onPresetSelected: {
				setControls()
				filter.blockSignals = true
				filter.set(textFilterUi.middleValue, filter.getRect(textFilterUi.rectProperty, filter.animateIn + 1))
				if (filter.animateIn > 0)
					filter.set(textFilterUi.startValue, filter.getRect(textFilterUi.rectProperty, 0))
				if (filter.animateOut > 0)
					filter.set(textFilterUi.endValue, filter.getRect(textFilterUi.rectProperty, filter.duration - 1))
				filter.blockSignals = false
			}
		}
		
		Label {
			text: qsTr('Text')
			Layout.alignment: Qt.AlignRight | Qt.AlignTop
		}
		Item {
			Layout.columnSpan: 1
			FontMetrics {
				id: fontMetrics
				font: textArea.font
			}
			Layout.minimumHeight: fontMetrics.height * 6
			Layout.maximumHeight: Layout.minimumHeight
			Layout.minimumWidth: preset.width
			Layout.maximumWidth: preset.width

			ScrollView {
				id: scrollview
				width: preset.width - (ScrollBar.vertical.visible ? 16 : 0)
				height: parent.height - (ScrollBar.horizontal.visible ? 16 : 0)
				clip: true
				TextArea {
					id: textArea
					textFormat: TextEdit.PlainText
					wrapMode: TextEdit.NoWrap
					selectByMouse: true
					padding: 0
					background: Rectangle {
						anchors.fill: parent
						color: textArea.palette.base
					}
					text: '__empty__' // workaround initialization problem
					property int maxLength: 1024
					onTextChanged: {
						if (text === '__empty__') return
						if (length > maxLength) {
							text = text.substring(0, maxLength)
							cursorPosition = maxLength
						}
						if (!parseInt(filter.get(textFilterUi.useFontSizeProperty), 10))
							filter.set('size', profile.height / text.split('\n').length)
						filter.set('argument', text)
					}
				}
				ScrollBar.horizontal: ScrollBar {
					height: 16
					policy: ScrollBar.AlwaysOn
					visible: scrollview.contentWidth > scrollview.width
					parent: scrollview.parent
					anchors.top: scrollview.bottom
					anchors.left: scrollview.left
					anchors.right: scrollview.right
				}
				ScrollBar.vertical: ScrollBar {
					width: 16
					policy: ScrollBar.AlwaysOn
					visible: scrollview.contentHeight > scrollview.height
					parent: scrollview.parent
					anchors.top: scrollview.top
					anchors.left: scrollview.right
					anchors.bottom: scrollview.bottom
				}
			}
		}

		Label {
			text: qsTr('Insert GPS field')
			Layout.alignment: Qt.AlignRight
		}
		RowLayout {
			Shotcut.ComboBox {
				Shotcut.HoverTip { text: qsTr('Extra arguments can be added inside keywords:\nSupported distance units: m [km|ft|mi]\nSupported speed units: km/h [m/s|ft/s|mi/h]\nDefault time format is: %Y-%m-%d %H:%M:%S, time offset can be added with +/-seconds, ie: +3600\nUse RAW keyword to use the unprocessed values from file, #gps_lat RAW#') }
				implicitWidth: 300
				model: 
					[	qsTr('GPS latitude'),					//0
						qsTr('GPS longitude'),					//1
						qsTr('Elevation (m)'),					//2
						qsTr('Speed (km/h)'),					//3
						qsTr('Distance (m)'),					//4
						qsTr('GPS date-time'),					//5
						qsTr('Video file date-time'),			//6
						qsTr('Heart-rate (bpm)'),				//7
						qsTr('Bearing (degrees)'),				//8
						qsTr('Bearing (compass)'),				//9
						qsTr('Elevation gain (m)'),				//10
						qsTr('Elevation loss (m)'),				//11
						qsTr('Distance uphill (m)'),			//12
						qsTr('Distance downhill (m)'),			//13
						qsTr('Distance flat (m)')				//14
					]	
						
				onActivated: {
					switch (currentIndex) {
						case 0:
							onClicked: textArea.insert(textArea.cursorPosition, '#gps_lat#')
							break
						case 1:
							onClicked: textArea.insert(textArea.cursorPosition, '#gps_lon#')
							break
						case 2:
							onClicked: textArea.insert(textArea.cursorPosition, '#gps_elev m#')
							break
						case 3:
							onClicked: textArea.insert(textArea.cursorPosition, '#gps_speed kmh#')
							break
						case 4:
							onClicked: textArea.insert(textArea.cursorPosition, '#gps_dist m#')
							break;
						case 5:
							onClicked: textArea.insert(textArea.cursorPosition, '#gps_datetime_now#')
							break;
						case 6:
							onClicked: textArea.insert(textArea.cursorPosition, '#file_datetime_now#')
							break;
						case 7:
							onClicked: textArea.insert(textArea.cursorPosition, '#gps_hr#')
							break;
						case 8:
							onClicked: textArea.insert(textArea.cursorPosition, '#gps_bearing#')
							break;
						case 9:
							onClicked: textArea.insert(textArea.cursorPosition, '#gps_compass#')
							break;
						case 10:
							onClicked: textArea.insert(textArea.cursorPosition, '#gps_vdist_up#')
							break;
						case 11:
							onClicked: textArea.insert(textArea.cursorPosition, '#gps_vdist_down#')
							break;
						case 12:
							onClicked: textArea.insert(textArea.cursorPosition, '#gps_dist_uphill#')
							break;
						case 13:
							onClicked: textArea.insert(textArea.cursorPosition, '#gps_dist_downhill#')
							break;
						case 14:
							onClicked: textArea.insert(textArea.cursorPosition, '#gps_dist_flat#')
							break;
						default:
							console.log('gps_combobox: current index not supported: ' + currentIndex)
					}
				}
			}
		}

		Shotcut.TextFilterUi {
			id: textFilterUi
			Layout.leftMargin: 10
			Layout.columnSpan: 2
		}

		Label {
			topPadding: 10
			bottomPadding: 5
			text: qsTr('<b>Advanced Options</b>')
			Layout.columnSpan: 2
		}

		Label {
			text: qsTr('Video speed')
			leftPadding: 10
			Layout.alignment: Qt.AlignRight
			Shotcut.HoverTip { text: qsTr('If the current video is sped up (timelapse) or slowed down use this field to set the speed.') }
		}
		RowLayout {
			TextField {
				id: speed_multiplier
				text: '1'
				//TODO: restrict to type double
				horizontalAlignment: TextInput.AlignRight
				implicitWidth: 25
				onFocusChanged: if (focus) selectAll()
				Shotcut.HoverTip { text: qsTr('Fractional times are also allowed (0.25 = 4x slow motion, 5 = 5x timelapse).') }
				onEditingFinished: filter.set('speed_multiplier', speed_multiplier.text);
			}
			Label { text: 'x' }
			Shotcut.UndoButton {
				onClicked: {
					filter.set('speed_multiplier', 1)
					speed_multiplier.text = '1';
				}
			}
		}

		Label {
			text: qsTr('Update speed')
			leftPadding: 10
			Layout.alignment: Qt.AlignRight
			Shotcut.HoverTip { text: qsTr('Set how many text updates to show per second.\nNote: this can\'t be faster than gps frequency') }
		}
		RowLayout {
			TextField {
				id: updates_per_second
				text: '1'
				//TODO: restrict to type double
				horizontalAlignment: TextInput.AlignRight
				implicitWidth: 25
				onFocusChanged: if (focus) selectAll()
				Shotcut.HoverTip { text: qsTr('Fractional times are also allowed (0.25 = 1 update every 4 seconds, 2 = 2 updates per second).') }
				onEditingFinished: filter.set('updates_per_second', updates_per_second.text);
			}
			Label { text: qsTr(' per second') }
			Shotcut.UndoButton {
				onClicked: {
					filter.set('updates_per_second', 1)
					updates_per_second.text = '1';
				}
			}
		}
		
	}
}
