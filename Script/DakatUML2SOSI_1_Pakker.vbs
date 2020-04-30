option explicit

!INC Local Scripts.EAConstants-VBScript
									   
!INC NVDB._felles
!INC NVDB._parametre
								 

' Script Name: DakatUML2SOSI_1_Pakker
' Author: Knut Jetlund
' Purpose: Oppdater SOSI-UML for pakker ut fra oppdatert NVDB-UML
' Date: 2020-04-28

sub createPackage()
'Lager ny pakke som kopi av NVDB-pakke 
	set pkOT = pkSOSINVDB.Packages.AddNew(pkOT_NVDB.Name,"Package")
	pkOT.Update
	set element = pkOT.Element
	element.Alias = pkOT_NVDB.Alias
	element.Update
	updatePackage
end sub

sub updatePackage()
'Oppdaterer SOSI-pakke
	geomPunkt = False
	geomKurve = False
	lrAttr = False
		
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

end sub

sub updatePackages()
	'Oppdatering av pakker 
	'Setter opp kobling til modeller og databasetabell
	dim connect 
	connect = connect2UMLmodels()
	If not connect then exit sub			  
  
	Repository.WriteOutput "Script", Now & " Oppdatering av NVDB-vegobjekttypepakker i SOSI-modellregister", 0 
	Repository.WriteOutput "Script", Now & " ", 0 
	
    'Lag liste med Datakatalogpakker med NVDB-ID og GUID
	Set lstNVDBpck = CreateObject("System.Collections.SortedList")
	Repository.WriteOutput "Script", Now & " Lager liste over alle vegobjekttyper i NVDB Datakatalogen", 0 
	For each pkOT in pkObjekttyper.Packages
		Repository.WriteOutput "Script", Now & " NVDB-pakke: " & pkOT.Name &  " (" & pkOT.Alias & ")", 0 
		lstNVDBpck.Add pkOT.Alias,pkOT.packageGUID
	Next

	'Spoler gjennom alle NVDB Datakatalog-delpakker i SOSI-modellregister og sjekker om de finnes i NVDB Datakatalogen
	Set lstSOSIpck = CreateObject("System.Collections.SortedList")
	Repository.WriteOutput "Script", Now & " Spoler gjennom alle NVDB Datakatalog-delpakker i SOSI-modellregister og sjekker om de finnes i NVDB Datakatalogen", 0 
	For idxP = 0 to pkSOSINVDB.Packages.Count - 1
		set pkOT = pkSOSINVDB.Packages.GetAt(idxP)
		if lstNVDBpck.Contains(pkOT.Alias) then 
			'Eksisterer i NVDB, legges til i liste og oppdateres
			Repository.WriteOutput "Script", Now & " SOSI-Pakke funnet i NVDB, oppdateres: " & pkOT.Name &  " (" & pkOT.Alias & ")", 0 
			lstSOSIpck.Add pkOT.Alias,pkOT.packageGUID
			'Henter NVDB-pakke vha listeinformasjon
			dim keyIndex
			keyIndex = lstNVDBpck.IndexofKey(pkOT.Alias)
			dim guid
			guid = lstNVDBpck.GetByIndex(keyIndex)
			set pkOT_NVDB = Repository.GetPackageByGuid(guid)
			updatePackage
		else
			'Eksisterer ikke i NVDB, slettes 
			Repository.WriteOutput "Endringer", Now & " SOSI-Pakken finnes ikke i NVDB, fjernes: " & pkOT.Name &  " (" & pkOT.Alias & ")", 0 
			pkSOSINVDB.Packages.DeleteAt idxP, False
		end if 
	Next
	pkSOSINVDB.Packages.Refresh
			
	'Spoler gjennom alle vegobjekttyper og sjekker om de finnes i SOSI-modellregister
	Repository.WriteOutput "Script", Now & " Spoler gjennom alle vegobjekttyper og sjekker om de finnes i SOSI-modellregister", 0 
	For each pkOT_NVDB in pkObjekttyper.Packages
		if lstSOSIpck.Contains(pkOT_NVDB.Alias) then 
			'Eksisterer i SOSI
			Repository.WriteOutput "Script", Now & " NVDB-Pakke funnet i SOSI-modellregister: " & pkOT_NVDB.Name &  " (" & pkOT_NVDB.Alias & ")", 0 
		else
			'Eksisterer ikke i SOSI, legges til
			Repository.WriteOutput "Endringer", Now & " NVDB-Pakken finnes ikke i SOSI-modellregister, legges til: " & pkOT_NVDB.Name &  " (" & pkOT_NVDB.Alias & ")", 0 
			createPackage
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

updatePackages()