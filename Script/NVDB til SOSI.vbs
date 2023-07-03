option explicit

!INC Local Scripts.EAConstants-VBScript
!INC NVDB._felles
!INC NVDB._parametre
!INC NVDB til SOSI.DakatUML2SOSI_1_Pakker
!INC NVDB til SOSI.DakatUML2SOSI_24_Klasser
!INC NVDB til SOSI.DakatUML2SOSI_35_Attributter
!INC NVDB til SOSI.DakatUML2SOSI_36_Fix_Geometriattributter
!INC NVDB til SOSI.DakatUML2SOSI_6_Assosiasjoner
!INC NVDB til SOSI.DakatUML2SOSI_61_AbstrakteKlasser
!INC NVDB til SOSI.DakatUML2SOSI_7_Diagrammer
!INC NVDB til SOSI.DakatUML2SOSI_90_XMI
!INC NVDB til SOSI.DakatUML2SOSI2GML_0_Enkeltskjema
!INC NVDB til IFC.NVDB2IFCPSD
!INC NVDB til OWL.NVDB2OWL_0_KunOTL
!INC NVDB til OWL.NVDB2OWL_1_Vegobjekttypekategorier

' Script Name: NVDB til SOSI
' Author: Aslak Wold	
' Purpose: Run steps 3-9 of "Prosess for generering av UML og implemenatsjonsformater"
' Date: 20221121

function NVDBTilSOSI()

	Repository.WriteOutput "Script", Now & "Update of SOSI-version of the UML modell", 0

	dim shell, abstrakteKlasser, nvdbPackage, sosiNVDBDatakatalogPackage, problempakkerPackage, dokumentasjonPackage, kommentarPackage

	set nvdbPackage = Repository.GetPackageByGuid(nvdbPackageGuid) 'NVDB package under SOSI Modell Andre viktige komponenter
	set abstrakteKlasser = Repository.GetPackageByGuid(guidAbstrakteKlasser) '_AbstrakteKlasser
	set sosiNVDBDatakatalogPackage = Repository.GetPackageByGuid(guidSOSIDatakatalog) '"ApplicationSchema" NVDB Datakatalogen
	set problempakkerPackage = Repository.GetPackageByGuid(problempakkerGuid) 'Problempakker 
	
	'Moving _AbstrakteKlasser to NVDB package if it's not there already
	if abstrakteKlasser.ParentID <> nvdbPackage.PackageID then
		Repository.WriteOutput "Script", "_AbstrakteKlasser not in correct folder, moving to: NVDB...", 0
		abstrakteKlasser.ParentID = nvdbPackage.PackageID
		abstrakteKlasser.Update
	end if

	'3
	updatePackages
	updateClasses
	updateAttributes
	fixGeometricAttributes
	updateAssociations
	abstractClasses
	updateDiagrams

	'4
	'Moving _AbstrakteKlasser to NVDB Datakatlogen
	Repository.WriteOutput "Script", "Moving _AbstrakteKlasser package to: ApplicationSchema NVDB Datakatalogen...", 0
	abstrakteKlasser.ParentID = sosiNVDBDatakatalogPackage.PackageID 
	abstrakteKlasser.Update

	'Generate XMI for SOSI-UML model (GitHub)
	exportPackages
	
	'Finding dokumentasjon and kommentar packages - if this fails, Dokumentasjon and Kommentar do not exist...
	if problempakkerPackage.Packages.Count >= 2 then 
		Repository.WriteOutput "Script", Now & "Finding packages Dokumentasjon and Kommentar in Problempakker", 0
		set dokumentasjonPackage = getPackage(problempakkerPackage.Packages, "446") 'Dokumentasjon
		set kommentarPackage = getPackage(problempakkerPackage.Packages, "297") 'Kommentar
	else
		Repository.WriteOutput "Script", Now & "Finding packages Dokumentasjon and Kommentar in ApplicationSchema NVDB Datakatalogen", 0	
		set dokumentasjonPackage = getPackage(sosiNVDBDatakatalogPackage.Packages, "446")  'Dokumentasjon
		set kommentarPackage = getPackage(sosiNVDBDatakatalogPackage.Packages, "297") 'Kommentar
	end if 
	
	'5
	'Moving packages "Dokumentasjon" and "Kommentar" to "Problempakker"
	Repository.WriteOutput "Script", "Moving Dokumentasjon and Kommentar to Problempakker...", 0
	dokumentasjonPackage.ParentID = problempakkerPackage.PackageID
	dokumentasjonPackage.Update
	kommentarPackage.ParentID = problempakkerPackage.PackageID
	kommentarPackage.Update

	'Generate GML application schema for "ApplicationSchema" NVDB Datakatalogen (GitHub)
	'Enkeltskjema

	'Moving packages "Dokumentasjon" and "Kommentar" back to ApplicationSchema NVDB Datakatalogen
	Repository.WriteOutput "Script", "Moving Dokumentasjon and Kommentar back to ApplicationSchema NVDB Datakatlogen...", 0
	dokumentasjonPackage.ParentID = sosiNVDBDatakatalogPackage.PackageID
	dokumentasjonPackage.Update
	kommentarPackage.ParentID = sosiNVDBDatakatalogPackage.PackageID
	kommentarPackage.Update

	'6
	'Generate IFC-PSD, PropertySetDefinitions for IFC (GitHub)
	'generateIFC

	'7 and 8
	'Generate OWL ontologies (GitHub, BitBucket, ontologiserver and GraphDB)
	'generateOTL
	'generateOWLVegobjekttypekategorier

	'Run the python script from a shell...
	'runPython

	'Moving _AbstrakteKlasser back to NVDB - NB! Do this at the end of step 9.
	Repository.WriteOutput "Script", "Moving _AbstrakteKlasser package to: NVDB...", 0
	abstrakteKlasser.ParentID = nvdbPackage.PackageID 
	abstrakteKlasser.Update
	Repository.WriteOutput "Script", Now & "_AbstrakteKlasser in NVDB, PackageID: " & abstrakteKlasser.ParentID, 0 '1003
	
	'Moving packages "Dokumentasjon" and "Kommentar" back to ApplicationSchema NVDB Datakatalogen
	Repository.WriteOutput "Script", "Moving Dokumentasjon and Kommentar back to ApplicationSchema NVDB Datakatlogen...", 0
	dokumentasjonPackage.ParentID = sosiNVDBDatakatalogPackage.PackageID
	dokumentasjonPackage.Update
	kommentarPackage.ParentID = sosiNVDBDatakatalogPackage.PackageID
	kommentarPackage.Update
	
	
	Repository.WriteOutput "Script", "NVDB til SOSI ferdig med å kjøre...", 0
	
end function

NVDBTilSOSI