option explicit

!INC Local Scripts.EAConstants-VBScript
									   
!INC NVDB._felles
!INC NVDB._parametre
								 

' Script Name: DakatUML2SOSI_24_Klasser
' Author: Knut Jetlund
' Purpose: Oppdater SOSI-UML for objekttyper og kodelister fra oppdatert NVDB-UML
' Date: 2020-04-28

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
	'Kører gjennom alle tagged values på NVDB-klassen og overfører informasjon
	For idxT = 0 To elNVDB.TaggedValues.Count - 1
		set tagVal = elNVDB.TaggedValues.GetAt(idxT)
		Select Case tagVal.Name
			Case "SOSI_navn"
				'SOSI-navn på objekttypen. Brukes for å sette SOSI-modellnavn og SOSI-formatnavn
				Repository.WriteOutput "SOSI", Now & " Klassen " & element.Name & " (" & element.Alias & ") oppdateres til " & element.Stereotype & " " & tagVal.Value,0
				'Endrer navn på klassen til SOSI-modellnavn
				element.Name = tagVal.Value
				'Lager ny tagged value på SOSI-elementet for SOSI-formatnavn (NVDB_ & Uppercase(element.Name))
				'Unntak: De som allerede har prefix "NVDB_" skal kun ha uppercase, ikke ny prefix
				set newTV = element.TaggedValues.AddNew("SOSI_navn", "")
				If Not Mid(element.Name, 1, 5) = "NVDB_" Then
					newTV.Value = "NVDB_" & Ucase(tagVal.Value)
				Else
					newTV.Value = Ucase(tagVal.Value)
				End If
				newTV.Update()
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
				set newTV = element.TaggedValues.AddNew("NVDB_ID", tagVal.Value)
				newTV.Update()
			Case else
				'Kopier tagged value uendra
				set newTV = element.TaggedValues.AddNew(tagVal.Name, tagVal.Value)
				newTV.Update()			
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
		
		'SOSI_Datatype for kodelisten
		'Søk etter NVDB-objekttypen, attributt tilhørende kodelisten og dennes datatype
		dim elVOT as EA.Element
		set elVOT = getElementByAlias(pkOT_NVDB, pkOT_NVDB.Alias)
		If not elVOT is Nothing then
			Dim aVET as EA.Attribute
			set aVET = getAttributeByAlias(elVOT, element.Alias)
			if not aVET is Nothing then
				'Finn datatype-element
				Set elementDT = Nothing
				Set elementDT = Repository.GetElementByID(aVET.ClassifierID)
				If not elementDT is Nothing then
					'Sett SOSI-tag for SOSI_datatype
					Select Case elementDT.Alias
						Case 30
							set newTV = element.TaggedValues.AddNew("SOSI_datatype", "T")
						Case 31
							If aVET.Precision = 0 Then
								set newTV = element.TaggedValues.AddNew("SOSI_datatype", "H")
							Else
								set newTV = element.TaggedValues.AddNew("SOSI_datatype", "D")
							End If
					End Select
					newTV.Update
					Repository.WriteOutput "SOSI", Now & " Kodeliste: " & element.stereotype & " " & element.Name &  " SOSI_datatype " & newTV.Value, 0 
				end if
			end if
		end if
	End If
					
	element.TaggedValues.Refresh()
	element.Modified = Now
	element.Update
	
end sub



function updateClasses()
	'Oppdatering av klasser (vegobjekttyper og kodelister) 
	'Setter opp kobling til modeller og databasetabell
	dim connect 
	connect = connect2UMLmodels()
	If not connect then exit function			  
  
	Repository.WriteOutput "Script", Now & " Oppdatering av vegobjekttyper i SOSI-modellregister", 0 
	Repository.WriteOutput "Script", Now & " ", 0 
	
    'Lag hjelpeliste: Datakatalogpakker med NVDB-ID og GUID
	Set lstNVDBpck = CreateObject("System.Collections.SortedList")
	Repository.WriteOutput "Script", Now & " Lager hjelpeliste over alle vegobjekttyper i NVDB Datakatalogen", 0 
	For each pkOT in pkObjekttyper.Packages
		Repository.WriteOutput "Script", Now & " NVDB-pakke: " & pkOT.Name &  " (" & pkOT.Alias & ")", 0 
		lstNVDBpck.Add pkOT.Alias,pkOT.packageGUID
	Next
		
	dim keyIndex
	dim guid

	'Spoler gjennom alle NVDB Datakatalog-delpakker i SOSI-modellregister og sjekker klassene
	Set lstSOSIpck = CreateObject("System.Collections.SortedList")
	Repository.WriteOutput "Script", Now & " Spoler gjennom alle NVDB Datakatalog-delpakker i SOSI-modellregister og sjekker klassene", 0 
	For each pkOT in pkSOSINVDB.Packages
		'Finner tilsvarende pakke i NVDB
		if lstNVDBpck.Contains(pkOT.Alias) then 
			'Henter NVDB-pakke vha listeinformasjon
			keyIndex = lstNVDBpck.IndexofKey(pkOT.Alias)
			guid = lstNVDBpck.GetByIndex(keyIndex)
			set pkOT_NVDB = Repository.GetPackageByGuid(guid)
			Repository.WriteOutput "Script", Now & " SOSI-pakke: " & pkOT.Name &  " (" & pkOT.Alias & ")", 0 
			'Repository.WriteOutput "Script", Now & " NVDB-pakke: " & pkOT_NVDB.Name &  " (" & pkOT_NVDB.Alias & ")", 0 
		else
			exit function
		end if
		
		'Løkke for alle klasser i SOSI-Modellen, sjekk for om de finnes i NVDB Datakatalogen
		For idxE = 0 to pkOT.Elements.count -1 
			set element = pkOT.Elements.GetAt(idxE)
			'Søk etter NVDB-objekttypen
			set elNVDB = getElementByAlias(pkOT_NVDB, element.Alias)
			if elNVDB is nothing then
				Repository.WriteOutput "Endringer", Now & " SOSI-Klassen finnes ikke i NVDB, fjernes: " & element.stereotype & " " & pkOT.Name & "." & element.Name &  " (" & element.Alias & ")", 0 
				pkOT.Elements.DeleteAt idxE, False
			else
				'Oppdaterer properties for klassen 
				Repository.WriteOutput "Script", Now & " SOSI-Klassen finnes i NVDB, oppdateres: " & element.stereotype & " " & pkOT.Name & "." & element.Name &  " (" & element.Alias & ")", 0 
				updateClassProperties
			end if	
		Next 
		pkOT.Elements.Refresh
		
		'Løkke for alle klasser i NVDB Datakatalogen, sjekk for om de finnes i SOSI-Modellen
		For each elNVDB in pkOT_NVDB.Elements
			set element = getElementByAlias(pkOT, elNVDB.Alias)
			if element is nothing then
				'Eksisterer ikke i SOSI, legges til
				Repository.WriteOutput "Endringer", Now & " NVDB-klassen finnes ikke i SOSI-modellregister, legges til: " & elNVDB.stereotype & " " & pkOT_NVDB.Name & "." & elNVDB.Name &  " (" & elNVDB.Alias & ")", 0 
				createClass
			else
				'Eksisterer i SOSI
				Repository.WriteOutput "Script", Now & " NVDB-klasse funnet i SOSI-modellregister: " & element.stereotype & " " & pkOT_NVDB.Name & "." & elNVDB.Name &  " (" & elNVDB.Alias & ")", 0 
			end if
		Next	
		
	Next
		
	Repository.WriteOutput "Script", Now & " Ferdig, sjekk logg", 0 
	Repository.EnsureOutputVisible "Script"
end function

