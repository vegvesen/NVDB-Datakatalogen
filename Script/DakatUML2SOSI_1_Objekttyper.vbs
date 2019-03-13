option explicit

!INC Local Scripts.EAConstants-VBScript
!INC NVDB._felles
!INC NVDB._parametre

' Script Name: DakatUML2SOSI_1_Objekttyper
' Author: Knut Jetlund
' Purpose: Oppdater SOSI-UML for objekttyper og pakker ut fra oppdatert NVDB-UML
' Date: 2019-02-09

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
'Oppdaterer pakke med tilhørende klasser
	
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

	updateClasses

end sub

sub updateClasses()
'Oppdaterer klasser (objekttyper og kodelister)

	'Løkke for alle klasser i SOSI-Modellen, sjekk for om de finnes i NVDB Datakatalogen
	For idxE = 0 to pkOT.Elements.count -1 
		set element = pkOT.Elements.GetAt(idxE)
		'Søk etter NVDB-objekttypen
		set elNVDB = getElementByAlias(pkOT_NVDB, element.Alias)
		if elNVDB is nothing then
			Repository.WriteOutput "Endringer", Now & " SOSI-Klassen finnes ikke i NVDB, fjernes: " & element.stereotype & " " & element.Name &  " (" & element.Alias & ")", 0 
			pkOT.Elements.DeleteAt idxE, False
		else
			'Oppdaterer properties på feature typen
			updateClassProperties
		end if	
	Next 
	pkOT.Elements.Refresh
	
	'Løkke for alle klasser i NVDB Datakatalogen, sjekk for om de finnes i SOSI-Modellen
	For each elNVDB in pkOT_NVDB.Elements
		set element = getElementByAlias(pkOT, elNVDB.Alias)
		if element is nothing then
			'Eksisterer ikke i SOSI, legges til
			Repository.WriteOutput "Endringer", Now & " NVDB-klassen finnes ikke i SOSI-modellregister, legges til: " & elNVDB.Name &  " (" & elNVDB.Alias & ")", 0 
			createClass
		else
			'Eksisterer i SOSI
			Repository.WriteOutput "Script", Now & " NVDB-klasse funnet i SOSI-modellregister: " & elNVDB.Name &  " (" & elNVDB.Alias & ")", 0 
		end if
	Next	
	
end sub

sub createClass()
'Lager ny klasse som kopi av NVDB-klasse 
	set element = pkOT.Elements.AddNew(elNVDB.Name,"Class")
	element.Alias = elNVDB.Alias
	element.Update
	pkOT.Elements.Refresh
	updateClassProperties
end sub

sub updateClassProperties()
'Oppdaterer properties for klasser (objekttyper og kodelister)
	if elNVDB.stereotype = "Vegobjekttype" then 
		element.stereotype = "featureType"
	ElseIf elNVDB.stereotype = "Tillatte verdier" then 
		element.stereotype = "CodeList" 
	End if 
	element.Notes = elNVDB.Notes
	element.Version = FC_version
	element.TreePos = elNVDB.TreePos
	element.Update	
	'Fjerner alle tagged values på feature typen og legger til på nytt
	For idxT = 0 To element.TaggedValues.Count - 1
		element.TaggedValues.DeleteAt idxT, False
	Next	
	
	'Defaultverdier
	strAlias = "Ikke angitt"
	strStedfesting = "punkt"
	retning = False
	kjorefelt = 0
	
	dim newTV as EA.TaggedValue
	'Kører gjennom alle tagged values på NVDB-pakken og overører informasjon
	For idxT = 0 To elNVDB.TaggedValues.Count - 1
		set tagVal = elNVDB.TaggedValues.GetAt(idxT)
		Select Case tagVal.Name
			Case "SOSI_navn"
				'SOSI-navn på objekttypen. Brukes for å sette SOSI-modellnavn og SOSI-formatnavn
				Repository.WriteOutput "SOSI", Now & " Klassen " & element.Name & " (" & element.Alias & ") oppdateres til " & element.Stereotype & " " & tagVal.Value,0
				'Endrer navn på klassen til SOSI-modellnavn
				element.Name = tagVal.Value
				'Lager ny tagged value pÃ¥ SOSI-elementet for SOSI-formatnavn (NVDB_ & Uppercase(element.Name))
				'Unntak: De som allerede har prefix "NVDB_" skal kun ha uppercase, ikke ny prefix
				set newTV = element.TaggedValues.AddNew("SOSI_navn", "")
				If Not Mid(element.Name, 1, 5) = "NVDB_" Then
					newTV.Value = "NVDB_" & Ucase(tagVal.Value)
				Else
					newTV.Value = Ucase(tagVal.Value)
				End If
				newTV.Update()
			Case "Stedfesting"
				'Stedfesting (strekning eller punkt). Henter informasjonen til senere bruk (kun vegobjekttyper)
				strStedfesting = tagVal.Value
				Repository.WriteOutput "SOSI", Now & " Stedfesting: " & tagVal.Value,0
			Case "RetningsRelevant"
				'Retning relevant. Henter informasjonen til senere bruk (kun vegobjekttyper)
				Repository.WriteOutput "SOSI", Now & " Skal ha retning: " & tagVal.Value,0
				If tagVal.Value = "true" Then retning = True
			Case "KjorefeltRelevant"
				'Retning relevant. Henter informasjonen til senere bruk (kun vegobjekttyper)
				Repository.WriteOutput "SOSI", Now & " Skal/kan ha kjorefelt: " & tagVal.Value,0
				kjorefelt = tagVal.Value
			Case "SOSI_datatype"
				'NVDB-datatype - konverteres til SOSI-datatype (kun kodelister)
				' ****** Her gjenstår det noe, må løses for kodelister ******
			Case "TOTAL_FELTLENGDE"
				'Feltlengde - tas vare på for SOSI-realisering (kun kodelister)
				set newTV = element.TaggedValues.AddNew("SOSI_lengde", tagVal.Value)
				newTV.Update()
			Case "NAVN_VOBJ_TYPE", "NAVN_EGENSKAPSTYPE"
				'NVDB-navn
				set newTV = element.TaggedValues.AddNew("NVDB_navn", tagVal.Value)
				newTV.Update()
			Case "ID_VOBJ_TYPE", "ID_EGENSKAPSTYPE"
				'ID - gi nytt navn til tagged value
				tagVal.Name = "NVDB_ID"
				tagVal.Update()
		End Select
	Next	

	'Lager tagged values direkte fra navn og alias
	set newTV = element.TaggedValues.AddNew("catalogue-entry", "NVDB Datakatalogen")
	newTV.Update()
	set newTV = element.TaggedValues.AddNew("NVDB_ID", element.Alias)
	newTV.Update()

	'GML-tagger for kodelister
	If element.Stereotype = "codeList" Then
		set newTV = element.TaggedValues.AddNew("asDictionary", "false")
		newTV.Update()
		set newTV = element.TaggedValues.AddNew("codeList", strTargetNamespace & element.Name)
		newTV.Update()
	End If
					
	element.TaggedValues.Refresh()
	element.Modified = Now
	element.Update
	
	'Løkke for attributter i SOSI-modellen, sjekker om de finnes i NVDB Datakatalogen
	For idxA = 0 to element.Attributes.Count - 1
		Set eAttributt = element.Attributes.GetAt(idxA)
		'Repository.WriteOutput "Script", Now & " Egenskapstype: " & element.Name &  "." & eAttributt.Name, 0 
		if not eAttributt.Alias = "" then
			set eAttrNVDB = getAttributeByAlias(elNVDB, eAttributt.Alias)
			If eAttrNVDB is nothing then 
				Repository.WriteOutput "Endringer", Now & " SOSI-Egenskapstype/kodelisteverdi finnes ikke i NVDB, fjernes: " & pkOT.name & "." & element.Name &  "." & eAttributt.Name & " (" & eAttributt.Alias & ")", 0 
				element.Attributes.DeleteAt idxA, False
			else
				Repository.WriteOutput "Script", Now & " SOSI-Egenskapstype/kodelisteverdi finnes i NVDB, oppdateres: " & element.Name &  "." & eAttributt.Name & " (" & eAttributt.Alias & ")", 0 
				updateAttributeProperties
			end if 
		else
			'egen håndtering av SOSI-attributter uten alias (lineærPosisjon mm)
		end if	
	Next
	element.Attributes.Refresh
	
	'Løkke for alle attributter i NVDB Datakatalogen, sjekk for om de finnes i SOSI-Modellen
	For each eAttrNVDB in elNVDB.Attributes
		set eAttributt = getAttributeByAlias(element, eAttrNVDB.Alias)
		if eAttributt is nothing then
			'Eksisterer ikke i SOSI, legges til
			Repository.WriteOutput "Endringer", Now & " NVDB-egenskapstype/kodelisteverdi finnes ikke i SOSI-modellregister, legges til: " & pkOT.name & "." & element.name & "." & eAttrNVDB.Name &  " (" & eAttrNVDB.Alias & ")", 0 
			createAttribute
		else
			'Eksisterer i SOSI
			Repository.WriteOutput "Script", Now & " NVDB-egenskapstype/kodelisteverdi funnet i SOSI-modellregister: " & eAttrNVDB.Name &  " (" & eAttrNVDB.Alias & ")", 0 
		end if
	Next	
	
end sub

sub createAttribute()
'Lager ny attributt/egenskapstype
	set eAttributt = element.Attributes.AddNew(eAttrNVDB.Name, "")
	eAttributt.Alias = eAttrNVDB.Alias
	eAttributt.Update
	element.Attributes.Refresh
	updateAttributeProperties
end sub

sub updateAttributeProperties()
'Oppdaterer properties på egenskapstyper

	eAttributt.Notes = eAttrNVDB.Notes
	eAttributt.LowerBound = eAttrNVDB.LowerBound
	eAttributt.UpperBound = eAttrNVDB.UpperBound
	eAttributt.Pos = eAttrNVDB.Pos
	eAttributt.Update
	
	'Fjerner alle tagged values på attributten og legger til på nytt
	For idxT = 0 To eAttributt.TaggedValues.Count - 1
		eAttributt.TaggedValues.DeleteAt idxT, False
	Next	
	
	dim newATag as EA.AttributeTag
	for each aTag in eAttrNVDB.TaggedValues
		select case aTag.Name
			Case "SOSI_navn"
				'SOSI-navn på egenskapstypen. Brukes for å sette SOSI-modellnavn og SOSI-formatnavn
				Repository.WriteOutput "SOSI", Now & " Egenskapen/kodelisteverdien " & element.Name & "." & eAttributt.Name & " (" & eAttributt.Alias & ") oppdateres til " & aTag.Value,0
				'Endrer navn på klassen til SOSI-modellnavn
				eAttributt.Name = aTag.Value
				if ucase(element.stereotype) = "FEATURETYPE" then
					'Lager ny tagged value på SOSI-elementet for SOSI-formatnavn (NVDB_ & Uppercase(element.Name))
					'Unntak: De som allerede har prefix "NVDB_" skal kun ha uppercase, ikke ny prefix
					set newATag = eAttributt.TaggedValues.AddNew("SOSI_navn", "")
					If Not Mid(eAttributt.Name, 1, 5) = "NVDB_" Then
						newATag.Value = "NVDB_" & Ucase(aTag.Value)
					Else
						newATag.Value = Ucase(aTag.Value)
					End If
					newATag.Update() 
				end if	
			Case "NAVN_EGENSKAPSTYPE", "NAVN_TILLATT_VERDI"
				'NVDB-navn
				set newATag = eAttributt.TaggedValues.AddNew("NVDB_navn", aTag.Value)
				newATag.Update()
			Case "ID_EGENSKAPSTYPE", "ID_TILLATT_VERDI"
				'ID - gi nytt navn til tagged value
				set newATag = eAttributt.TaggedValues.AddNew("NVDB_ID", aTag.Value)
				newATag.Update()	
			Case "TOTAL_FELTLENGDE"
				'Feltlengde - tas vare på for SOSI-realisering
				set newATag = eAttributt.TaggedValues.AddNew("SOSI_lengde", aTag.Value)
				newATag.Update()

			'SOSI_datatype
			
		end select
	next
	eAttributt.TaggedValues.Refresh
	eAttributt.Update
	
end sub

sub updatePackagesAndClasses()
	'Oppdatering av pakker og klasser (vegobjekttyper og kodelister) 
	'Setter opp kobling til modeller og databasetabell
	dim connect 
	connect = connect2UMLmodels()
	If not connect then exit sub
	
	Repository.WriteOutput "Script", Now & " Oppdatering av vegobjekttyper i SOSI-modellregister", 0 
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

updatePackagesAndClasses()