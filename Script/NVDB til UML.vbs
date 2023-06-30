option explicit

!INC Local Scripts.EAConstants-VBScript
!INC NVDB._felles
!INC NVDB._parametre
!INC NVDB til UML.Dakat2UML 1_Datatyper
!INC NVDB til UML.Dakat2UML 2_Objekttyper
!INC NVDB til UML.Dakat2UML 3_Egenskapstyper
!INC NVDB til UML.Dakat2UML 4_Kodelister
!INC NVDB til UML.Dakat2UML 5_Kodelisteverdier
!INC NVDB til UML.Dakat2UML 6_Assosiasjoner
!INC NVDB til UML.Dakat2UML 7_Diagrammer
!INC NVDB til UML.DOC Export diagram images
!INC NVDB til UML.Publish Batch Export

' Script Name: NVDB til UML
' Author: Aslak Wold	
' Purpose: Run steps 1 and 2 of "Prosess for generering av UML og implemenatsjonsformater"
' Date: 20221121

function NVDBTilUML()

	'Make sure to set the correct filepath for the new version of the 
	'NVDB datakatakolg in the const FC_DB 
	'and version number in the const FC_versjon in the
	'_parametre script in the NVDB folder.
	Repository.WriteOutput "Script", Now & "Update of UML model for NVDB Datakatalogen", 0

	updateDatatyper
	updateObjekttyper
	updateEgenskapstyper

	updateKodelister

	updateKodelisteverdier
	updateAssosiasjoner
	updateDiagrammer
	exportDiagramsFromPackage
	exportPackages

Repository.WriteOutput "Script", "NVDB til UML ferdig med å kjøre...", 0
end function

NVDBTilUML

