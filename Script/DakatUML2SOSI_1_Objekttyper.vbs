option explicit

!INC Local Scripts.EAConstants-VBScript
!INC NVDB._felles
!INC NVDB._parametre
!INC NVDB.DakatUML2SOSI_0_Felles

' Script Name: DakatUML2SOSI_1_Objekttyper
' Author: Knut Jetlund
' Purpose: Oppdater SOSI-UML for objekttyper og pakker ut fra oppdatert NVDB-UML
' Date: 2019-02-09
'

sub createPackageAndFeatureType()
'Lager ny pakke og feature type som kopi av NVDB-pakke og vegobjekttype
	set pkOT = pkSOSINVDB.Packages.AddNew(pkOT_NVDB.Name,"Package")
	pkOT.Update
	set element = pkOT.Element
	element.Alias = pkOT_NVDB.Alias
	element.Update
	set element = pkOT.Elements.AddNew(pkOT_NVDB.Name,"Class")
	element.Alias = pkOT_NVDB.Alias
	element.Update
	pkOT.Elements.Refresh
	updatePackageAndFeatureTypeProperties
end sub

sub updatePackageAndFeatureTypeProperties()
'Oppdaterer properties for pakke og feature type
	
	'Oppdaterer properties på pakken
	pkOT.Name = pkOT_NVDB.Name
	pkOT.Notes = pkOT_NVDB.Notes
	pkOT.Version = FC_version
	pkOT.Update
	set element = pkOt.Element
	element.stereotype="applicationSchema"
	element.Update
	
	'Fjerner alle tagged values på pakken og legger til på nytt
	For idxT = 0 To element.TaggedValues.Count - 1
		element.TaggedValues.DeleteAt idxT, False
	Next
	'SOSI-tagger
	set tagVal = element.TaggedValues.AddNew("SOSI_kortnavn", "NVDB" & pkOT.Alias)
	tagVal.Update()
	set tagVal = element.TaggedValues.AddNew("SOSI_langnavn", "NVDB " & pkOT.Name)
	tagVal.Update()
	set tagVal = element.TaggedValues.AddNew("SOSI_organsasjon", "Statens vegvesen")
	tagVal.Update()
	set tagVal = element.TaggedValues.AddNew("SOSI_produktgruppe", "NVDB")
	tagVal.Update()
	set tagVal = element.TaggedValues.AddNew("SOSI_produsent", "Statens vegvesen")
	tagVal.Update()
	set tagVal = element.TaggedValues.AddNew("SOSI_spesifikasjonstype", "Applikasjonsskjema")
	tagVal.Update()
	set tagVal = element.TaggedValues.AddNew("SOSI_versjon", strSOSIVersjon)
	tagVal.Update()
	'GML-tagger 
	set tagVal = element.TaggedValues.AddNew("targetNamespace", strTargetNamespace)
	tagVal.Update()
	set tagVal = element.TaggedValues.AddNew("version", pkOT.Version)
	tagVal.Update()
	set tagVal = element.TaggedValues.AddNew("xmlns", "nvdb")
	tagVal.Update()
	set tagVal = element.TaggedValues.AddNew("xsdDocument", pkOT.Alias & ".xsd")
	tagVal.Update()
	set tagVal = element.TaggedValues.AddNew("xsdEncodingRule", "sosi")
	tagVal.Update()

	'Finn selve NVDB-objekttypen
	set elNVDB = getElementByAlias(pkOT_NVDB, pkOT.Alias)
	if elNVDB is nothing then
		Repository.WriteOutput "Error", Now & " Fant ikke vegobjekttypen i NVDB-Pakken", 0 
		exit sub
	end if	
	'Finn selve SOSI-feature typen
	set element = getElementByAlias(pkOT, pkOT.Alias)	
	if element is nothing then
		Repository.WriteOutput "Error", Now & " Fant ikke feature type i SOSI-Pakken", 0 
		exit sub
	end if

	'Oppdaterer properties på feature typen
	updateClassProperties
	
end sub

sub updatePackagesAndFeaturetypes()
	'Oppdatering av pakker og vegobjekttyper 
	'Setter opp kobling til modeller og databasetabell
	dim connect 
	connect = connect2UMLmodels()
	If not connect then exit sub
	
	Repository.WriteOutput "Script", Now & " Oppdatering av vegobjekttyper i SOSI-modellregister", 0 
	Repository.WriteOutput "Script", Now & " ", 0 
	
    'Lag liste med Datakatalogpakker med NVDB-ID og GUID
	Set lstNVDB = CreateObject("System.Collections.SortedList")
	Repository.WriteOutput "Script", Now & " Lager liste over alle vegobjekttyper i NVDB Datakatalogen", 0 
	For each pkOT in pkObjekttyper.Packages
		Repository.WriteOutput "Script", Now & " NVDB-pakke: " & pkOT.Name &  " (" & pkOT.Alias & ")", 0 
		lstNVDB.Add pkOT.Alias,pkOT.packageGUID
	Next

	Set lstSOSI = CreateObject("System.Collections.SortedList")
	Repository.WriteOutput "Script", Now & " Spoler gjennom alle NVDB Datakatalog-delpakker i SOSI-modellregister og sjekker om de finnes i NVDB Datakatalogen", 0 
	For idxP = 0 to pkSOSINVDB.Packages.Count - 1
		set pkOT = pkSOSINVDB.Packages.GetAt(idxP)
		if lstNVDB.Contains(pkOT.Alias) then 
			'Eksisterer i NVDB, legges til i liste og oppdateres
			Repository.WriteOutput "Script", Now & " SOSI-Pakke funnet i NVDB, oppdateres: " & pkOT.Name &  " (" & pkOT.Alias & ")", 0 
			lstSOSI.Add pkOT.Alias,pkOT.packageGUID
			'Henter NVDB-pakke vha listeinformasjon
			dim keyIndex
			keyIndex = lstNVDB.IndexofKey(pkOT.Alias)
			dim guid
			guid = lstNVDB.GetByIndex(keyIndex)
			set pkOT_NVDB = Repository.GetPackageByGuid(guid)
			updatePackageAndFeatureTypeProperties
		else
			'Eksisterer ikke i NVDB, slettes
			Repository.WriteOutput "Endringer", Now & " SOSI-Pakken finnes ikke i NVDB, fjernes: " & pkOT.Name &  " (" & pkOT.Alias & ")", 0 
			pkSOSINVDB.Packages.DeleteAt idxP, False
		end if 
	Next
	pkSOSINVDB.Packages.Refresh
	
	Repository.WriteOutput "Script", Now & " Spoler gjennom alle vegobjekttyper og sjekker om de finnes i SOSI-modellregister", 0 
	For each pkOT_NVDB in pkObjekttyper.Packages
		if lstSOSI.Contains(pkOT_NVDB.Alias) then 
			'Eksisterer i SOSI
			Repository.WriteOutput "Script", Now & " NVDB-Pakke funnet i SOSI-modellregister: " & pkOT_NVDB.Name &  " (" & pkOT_NVDB.Alias & ")", 0 
		else
			'Eksisterer ikke i SOSI, legges til
			Repository.WriteOutput "Endringer", Now & " NVDB-Pakken finnes ikke i SOSI-modellregiser, legges til: " & pkOT_NVDB.Name &  " (" & pkOT_NVDB.Alias & ")", 0 
			createPackageAndFeatureType
		end if 
	Next	
	
	'Sorter pakker
	Repository.WriteOutput "Script", Now & " Sorterer pakker etter navn, bygger liste...",0
	pkSOSINVDB.Packages.Refresh()
	dim lstPck
	set lstPck = CreateObject("System.Collections.Sortedlist")
	For each pkOT in pkSOSINVDB.Packages
		lstPck.Add pkOT.Name, pkOT.PackageGUID
	Next 
	
	dim i
	for i = 0 To lstPck.Count - 1
		set pkOT = Repository.GetPackageByGuid(lstPck.GetByIndex(i))
		pkOT.TreePos=i+1
		pkOT.Update			
		Repository.WriteOutput "Script", Now & " Ny posisjon " & i & " for pakke " & pkOT.Name ,0
	next	
	
	Repository.RefreshModelView (pkObjekttyper.PackageID)
	
	Repository.WriteOutput "Script", Now & " Ferdig, sjekk logg", 0 
	Repository.EnsureOutputVisible "Script"
end sub

updatePackagesAndFeaturetypes()