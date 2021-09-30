Die von mir programmierten Dateien können im Ordner „lib“ gefunden werden. Folgende Dateien sind enthalten:
-	main.dart: Wird beim Start des Programms aufgerufen
-	BeforeStartPage.dart: In dieser Datei ist die Startseite des Apps programmiert (ersichtlich in Abbildung 44 und 45).
-	SelectBondedDevicePage.dart: In dieser Datei ist der Bildschirm program-miert, auf welchem der Bluetooth Adapter ausgewählt werden kann (ersichtlich in Abbildung 47). Diese Datei ist auf dem Beispiel der Bibliothek flut-ter_bluetooth_serial und ist die einzige Datei, mit der Datie BluetoothDevice-ListEntry.dart, welche in diesem Ordner nicht vollständig selbst programmiert ist.
-	BluetoothDeviceListEntry.dart: Eine Helferklasse für den Bildschirm Select-BondedDevicePage. 
-	Speedometer.dart: Tachometer für das Variometer. Ersichtlich in Abbildung 49.
-	VariometerPage.dart: Bildschirm, welcher während dem Flug zu sehen ist (er-sichtlich in Abbildung 49). Auf diesem Bildschirm ist auch der Tachometer enthalten. 
-	chartSlider.dart: In dieser Datei sind die Anzeige und die Interaktion mit dem Ton Simulator abgespeichert(ersichtlich in Abbildung 46). Für das Ausgeben eines sinusförmigen Tones wurde die Bibliothek sound_generator verwendet. Für das Diagramm wurde die Bibliothek charts_flutter verwendet.
-	BackgroundCollectingTask.dart: Zuständig für das senden und bekommen von Bluetooth Paketen. Darin werden die Pakete auch ausgewertet. Dies wird im Hintergrund gemacht. Die Höhe wird auch hier ausgerechnet. DAs Bluetooth Protokoll läuft nur in dieser Datei ab.


