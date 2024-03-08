option explicit

!INC Local Scripts.EAConstants-VBScript
									   
!INC NVDB._felles
!INC NVDB._parametre
								 

' Script Name: DakatUML2SOSI_6_Assosiasjoner
' Author: Knut Jetlund
' Purpose: Oppdater assosiasjoner mellom objekttyper i SOSI-UML ut fra oppdatert NVDB-UML
' Date: 2020-04-28

Sub updateAssociationProperties()
	'Oppdaterer egenskaper på en assosiasjon i SOSI fra NVDB-modellen
	con.Type = conNVDB.Type
	con.Subtype = conNVDB.Subtype

	'Angi kardinaliteter 
	con.ClientEnd.Visibility = conNVDB.ClientEnd.Visibility
	con.ClientEnd.Cardinality = conNVDB.ClientEnd.Cardinality
	con.ClientEnd.Navigable = conNVDB.ClientEnd.Navigable
	con.SupplierEnd.Visibility = conNVDB.SupplierEnd.Visibility
	con.SupplierEnd.Cardinality = conNVDB.SupplierEnd.Cardinality
	con.SupplierEnd.Navigable = conNVDB.SupplierEnd.Navigable

	'Rollenavn og tagged values på assosiasjonen
	Dim conTV As EA.ConnectorTag
	If con.ClientID = element.ElementID Then
		con.ClientEnd.Role = "assosiert" & element.Name
		set conTV = con.TaggedValues.AddNew("NVDB_ClientID", element.Alias)
		conTV.Update()
		con.SupplierEnd.Role = "assosiert" & elementB.Name
		set conTV = con.TaggedValues.AddNew("NVDB_SupplierID", elementB.Alias)
		conTV.Update()
	Else
		con.ClientEnd.Role = "assosiert" & elementB.Name
		set	conTV = con.TaggedValues.AddNew("NVDB_ClientID", elementB.Alias)
		conTV.Update()
		con.SupplierEnd.Role = "assosiert" & element.Name
		set conTV = con.TaggedValues.AddNew("NVDB_SupplierID", element.Alias)
		conTV.Update()
	End If
	con.Update()

	'Fjerner alle tagged values og legger til på nytt
	For idxT = 0 To con.TaggedValues.Count - 1
		con.TaggedValues.DeleteAt idxT, False
	Next 
	Dim cTag As EA.ConnectorTag
	dim cTagNVDB as EA.ConnectorTag
	for each cTagNVDB in conNVDB.TaggedValues
		set cTag = con.TaggedValues.AddNew(cTagNVDB.Name, cTagNVDB.Value)
		cTag.Update()
	next	
	con.TaggedValues.Refresh()
	
	'GML-tagged values på assosiasjonsendene
	Dim rTag As EA.RoleTag
	dim rTagFound
	rTagFound = false
	for each rTag in con.ClientEnd.TaggedValues
		if rTag.Tag = "inlineOrByReference" then
			rTag.Value = "ByReference"
			rTag.Update
			rTagFound = true
		end  if
	next
	if not rTagfound then 
		set rTag = con.ClientEnd.TaggedValues.AddNew("inlineOrByReference", "ByReference")
		rTag.Update()
	end if	
	con.ClientEnd.TaggedValues.Refresh()
	con.ClientEnd.Update()
	
	rTagFound = false
	for each rTag in con.SupplierEnd.TaggedValues
		if rTag.Tag = "inlineOrByReference" then
			rTag.Value = "ByReference"
			rTag.Update
			rTagFound = true
		end  if
	next
	if not rTagfound then 
		set rTag = con.SupplierEnd.TaggedValues.AddNew("inlineOrByReference", "ByReference")
		rTag.Update()
	end if	
	con.SupplierEnd.TaggedValues.Refresh()
	con.SupplierEnd.Update()
	
End Sub


function updateAssociations()
	'Oppdatering av assosiasjoner
	'Setter opp kobling til modeller og databasetabell
	dim connect 
	connect = connect2UMLmodels()
	If not connect then exit function			  
  
	Repository.WriteOutput "Script", Now & " Oppdatering av assosiasjoner mellom vegobjekttyper i SOSI-modellregister", 0 
	Repository.WriteOutput "Script", Now & " ", 0 
		
    'Lag hjelpeliste: Datakatalogpakker med NVDB-ID og GUID
	Set lstNVDBpck = CreateObject("System.Collections.SortedList")
	Repository.WriteOutput "Script", Now & " Lager hjelpeliste over alle vegobjekttyper i NVDB Datakatalogen", 0 
	For each pkOT in pkObjekttyper.Packages
		Repository.WriteOutput "Script", Now & " NVDB-pakke: " & pkOT.Name &  " (" & pkOT.Alias & ")", 0 
		lstNVDBpck.Add pkOT.Alias,pkOT.packageGUID
	Next
	
	'Lag hjelpeliste: Sosi-klasser med Alias og GUID
	Set lstSOSI = CreateObject("System.Collections.SortedList")
	Repository.WriteOutput "Script", Now & " Lager hjelpeliste over alle feature types i SOSI-modellen", 0 
	For each pkOT in pkSOSINVDB.Packages
		Repository.WriteOutput "Script", Now & " SOSI-pakke: " & pkOT.Name &  " (" & pkOT.Alias & ")", 0 
		if pkOT.Name <> "_AbstrakteKlasser" then
			for each element in pkOT.Elements
				if UCase(element.Stereotype) = "FEATURETYPE" then
					lstSOSI.Add element.Alias, element.ElementGUID
				end if	
			Next	
		end if
	Next
	
	dim keyIndex
	dim guid
	
	'Spoler gjennom alle NVDB Datakatalog-delpakker i SOSI-modellregister og sjekker assosiasjoner mellom tilhørende objektyper
	Set lstSOSIpck = CreateObject("System.Collections.SortedList")
	Repository.WriteOutput "Script", Now & " Spoler gjennom alle NVDB Datakatalog-delpakker i SOSI-modellregister og sjekker om de finnes i NVDB Datakatalogen", 0 
	For each pkOT in pkSOSINVDB.Packages
		if pkOT.Name <> "_AbstrakteKlasser" then
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

			For each element in pkOT.Elements
				If UCase(element.Stereotype) = "FEATURETYPE" then
					'Finner tilsvarende objekttype i NVDB
					set elNVDB = getElementByAlias(pkOT_NVDB, element.Alias)
					'Lag liste over alle relaterte alias i NVDB
					Set lstAlias = CreateObject("System.Collections.SortedList")
					For each con in elNVDB.Connectors
						If con.SupplierID = elNVDB.ElementID then 
							set elementB = Repository.GetElementByID(con.ClientID)
							lstAlias.Add elementB.Alias,con.ConnectorGUID				
						end if	
					Next
					
					Repository.WriteOutput "Script", Now & " Oppdatering assosiasjoner for feature type " & element.Name &  " (" & element.Alias & ")", 0 
					'Repository.WriteOutput "Script", Now & " NVDB-vegobjekttype: " & elNVDB.Name &  " (" & elNVDB.Alias & ")", 0 
					'Spoler gjennom alle eksisterende assosiasjoner for klassen og sjekker om den finnes i NVDB
					For idxP = 0 to element.Connectors.Count - 1 
						set con= element.Connectors.GetAt(idxP)
						If con.SupplierID = element.ElementID then 
							set elementB = Repository.GetElementByID(con.ClientID)
							if lstAlias.Contains(elementB.Alias) then 
								'Finnes: Oppdaterer properties: Roller og multiplisitet fra NVDB
								Repository.WriteOutput "Script", Now & " Assosiasjon til feature type " & elementB.Name &  " (" & elementB.Alias & ") funnet i NVDB", 0 		
								'Get connector from alias list
								keyIndex = lstAlias.IndexofKey(elementB.Alias)
								guid = lstAlias.GetByIndex(keyIndex)
								set conNVDB = Repository.GetConnectorByGuid(guid)
								updateAssociationProperties
							else	
								'Finnes ikke: Sletter
								Repository.WriteOutput "Endringer", Now & " Assosiasjon fra " & element.Name &  " (" & element.Alias & ") til feature type " & elementB.Name &  " (" & elementB.Alias & ") finnes ikke i NVDB, sletter", 0 
								element.Connectors.DeleteAt idxP, False
							end if	
						end if	
					Next
					element.Connectors.Refresh
					
					'Lag liste over alle relaterte alias i SOSI
					Set lstAlias = CreateObject("System.Collections.SortedList")
					For each con in element.Connectors
						If con.SupplierID = element.ElementID then 
							set elementB = Repository.GetElementByID(con.ClientID)
							lstAlias.Add elementB.Alias,con.ConnectorGUID				
						end if	
					Next
					
					'Spoler gjennom alle assosiasjoner for tilsvarende objekttype i NVDB og sjekker om den finnes i SOSI
					For each conNVDB in elNVDB.Connectors
						If conNVDB.SupplierID = elNVDB.ElementID then 
							set elementB = Repository.GetElementByID(conNVDB.ClientID)
							if lstAlias.Contains(elementB.Alias) then 
								'Finnes: Ingen tiltak
								Repository.WriteOutput "Script", Now & " Assosiasjon fra " & element.Name &  " (" & element.Alias & ") til feature type " & elementB.Name &  " (" & elementB.Alias & ") finnes i SOSI", 0 
							else	
								'Finnes ikke: Oppretter og oppdaterer properties
								Repository.WriteOutput "Endringer", Now & " Assosiasjon fra " & element.Name &  " (" & element.Alias & ") til feature type " & elementB.Name &  " (" & elementB.Alias & ") finnes ikke i SOSI, oppretter", 0 
								if lstSOSI.Contains(elementB.Alias) then 
									'Repository.WriteOutput "Endringer", Now & " Noen hjemme?", 0 
									set con = element.Connectors.AddNew("", conNVDB.Type)
									con.SupplierID = element.ElementID
									'Finn SOSI-element som skal assosieres ut i fra alias i lstSOSI
									keyIndex = lstSOSI.IndexofKey(elementB.Alias)
									guid = lstSOSI.GetByIndex(keyIndex)
									set elementB = Repository.GetElementByGuid(guid)
									con.ClientID = elementB.ElementID
									con.Update
									updateAssociationProperties
								end if						
							end if
						end if	
					Next								
				end if
			Next
		end if
	Next
				
	Repository.WriteOutput "Script", Now & " Ferdig, sjekk logg", 0 
	Repository.EnsureOutputVisible "Script"
end function

