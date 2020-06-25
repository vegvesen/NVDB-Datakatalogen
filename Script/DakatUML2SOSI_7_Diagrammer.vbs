option explicit

!INC Local Scripts.EAConstants-VBScript
									   
!INC NVDB._felles
!INC NVDB._parametre
								 

' Script Name: DakatUML2SOSI_7_diagrammer
' Author: Knut Jetlund
' Purpose: Oppdater SOSI-UML for diagrammer
' Date: 2020-05-01

sub updateDiagramProperties
	'updateProperties
	eDiagram.ShowDetails = 0
	eDiagram.Author = "Dakat"
	eDiagram.Version = FC_version
	eDiagram.Update()
	'Skjule namespace (t_diagram.ShowForeign)
	Repository.Execute("UPDATE T_DIAGRAM SET SHOWFOREIGN=FALSE WHERE DIAGRAM_ID=" & eDiagram.DiagramID)
end sub 

sub updateDiagrams()
	'Oppdatering av diagrammer
	'Setter opp kobling til modeller og databasetabell
	dim connect 
	connect = connect2UMLmodels()
	If not connect then exit sub			  
  
	Repository.WriteOutput "Script", Now & " Oppdatering av diagrammer i SOSI-modellregister", 0 
	Repository.WriteOutput "Script", Now & " ", 0 
	
	dim associationsDiagram
	dim constraintsDiagram
	dim codeListDiagram
	dim missing
	
	dim lstAss
	
	'Spoler gjennom alle NVDB Datakatalog-delpakker i SOSI-modellregister og sjekker diagrammene
	Set lstSOSIpck = CreateObject("System.Collections.SortedList")
	Repository.WriteOutput "Script", Now & " Spoler gjennom alle NVDB Datakatalog-delpakker i SOSI-modellregister og sjekker diagrammer", 0 
	For each pkOT in pkSOSINVDB.Packages
		Repository.WriteOutput "Script", Now & " SOSI-pakke: " & pkOT.Name &  " (" & pkOT.Alias & ")", 0 
		'Sjekker hvilke diagrammer som finnes. Skal ha diagrammer som heter [pakkenavn] + "... betingelser", "... assosiasjoner" og "... tillatte verdier"
		associationsDiagram = 0
		constraintsDiagram = 0
		codeListDiagram = 0
		
		dim changed
		changed = false

		For each eDiagram in pkOT.Diagrams
			Repository.WriteOutput "SOSI", Now & " Diagram: " & eDiagram.Name,0
			Select case eDiagram.Name
				case pkOT.Name & " Assosiasjoner"
					associationsDiagram = eDiagram.DiagramGUID
					Repository.WriteOutput "Script", Now & " Assosiasjonsdiagram eksisterer: " & eDiagram.Name,0
				case pkOT.Name & " Betingelser" 
					constraintsDiagram = eDiagram.DiagramGUID
					Repository.WriteOutput "Script", Now & " Betingelsesdiagram eksisterer: " & eDiagram.Name,0
				case pkOT.Name & " Tillatte verdier" 
					codeListDiagram = eDiagram.DiagramGUID		
					Repository.WriteOutput "Script", Now & " Tillatte verdier-diagram eksisterer: " & eDiagram.Name,0
			End select
		Next
		'Sjekker om det finnes andre diagram med utdaterte navn. Endrer navn eller sletter.
		For idxP = 0 to pkOT.Diagrams.Count -1
			set eDiagram = pkOT.Diagrams.GetAt(idxP)
			If eDiagram.Name <> pkOT.Name & " Betingelser" And eDiagram.Name <> pkOT.Name & " Assosiasjoner" And eDiagram.Name <> pkOT.Name & " Tillatte verdier" Then
				If instr(eDiagram.Name,"Assosiasjoner") <> 0 and associationsDiagram = "0" then
					Repository.WriteOutput "Endringer", Now & " Endrer navn for diagrammet " & eDiagram.Name,0
					eDiagram.Name = pkOT.Name & " Assosiasjoner"
					eDiagram.Update
					associationsDiagram = eDiagram.DiagramGUID
				elseif instr(eDiagram.Name,"Betingelser") <> 0 and constraintsDiagram = "0" then
					Repository.WriteOutput "Endringer", Now & " Endrer navn for diagrammet " & eDiagram.Name,0
					eDiagram.Name = pkOT.Name & " Betingelser" 
					eDiagram.Update
					constraintsDiagram = eDiagram.DiagramGUID
				elseif instr(eDiagram.Name,"Tillatte verdier") <> 0 and codeListDiagram = "0" then
					Repository.WriteOutput "Endringer", Now & " Endrer navn for diagrammet " & eDiagram.Name,0
					eDiagram.Name = pkOT.Name & " Tillatte verdier" 
					eDiagram.Update
					codeListDiagram = eDiagram.DiagramGUID		
				else
					Repository.WriteOutput "Endringer", Now & " Sletter diagrammet " & eDiagram.Name,0
					pkOT.Diagrams.DeleteAt idxP, False
				end if	
			End If
			idxP = idxP + 1
		Next
		
		'Lag eventuelle manglende diagrammer, og sjekker innhold
		'-----------------------
		'Assosiasjonsdiagrammet
		if associationsDiagram = "0" then
			set eDiagram = pkOT.Diagrams.AddNew(pkOT.Name & " Assosiasjoner", "Logical")
			eDiagram.Update
			associationsDiagram = eDiagram.DiagramGUID
			Repository.WriteOutput "Endringer", Now & " Lager nytt diagram " & eDiagram.Name,0
		end if
		set eDiagram = Repository.GetDiagramByGuid(associationsDiagram)	
		'Skal inneholde feature typen fra aktuell pakke, samt alle assosierte klasser 
		Repository.WriteOutput "Script", Now & " Sjekker diagrammet " & eDiagram.Name,0
		Set lstAss = CreateObject("System.Collections.SortedList")

		for each element in pkOT.Elements
			if UCase(element.Stereotype) = "FEATURETYPE" then
				'Sjekk om selve klassen finnes i diagrammet, legg til dersom den mangler. 
				missing = true
				for idxD = 0 to eDiagram.DiagramObjects.Count - 1
					set diagramObject = eDiagram.DiagramObjects.GetAt(idxD)
					if diagramObject.ElementId = element.ElementId then missing = false
				next
				if missing then 
					Repository.WriteOutput "Endringer", Now & " Legger til " & element.Name & " i diagrammet " & eDiagram.Name,0
					set diagramObject = eDiagram.DiagramObjects.AddNew("", "")
					diagramObject.ElementID = element.ElementID
					diagramObject.Update()
					changed = true
				end if	
				eDiagram.DiagramObjects.Refresh
				missing = true
				'Løkke for alle assosiasjoner for den akuelle klassen
				for each con in element.Connectors
					if con.SupplierID = element.ElementID then 
						set elementB = Repository.GetElementByID(con.ClientID)
					else
						set elementB = Repository.GetElementByID(con.SupplierID)
					end if
					'Sjekk om den assosierte klassen finnes i diagrammet, legg til dersom den mangler. 
					Repository.WriteOutput "Script", Now & " ConnectorID: " & con.ConnectorID & " til " & elementB.Name,0

					lstAss.Add con.ConnectorID,elementB.ElementID
					
					missing = true
					for idxD = 0 to eDiagram.DiagramObjects.Count - 1
						set diagramObject = eDiagram.DiagramObjects.GetAt(idxD)
						if diagramObject.ElementId = elementB.ElementId then 
							missing = false
							'Skjuler egenskaper (AttPub=0) (alle egenskaper i modellen er public)
							hideAttributes(diagramObject)
							'Størrelse w=200xh=70
							setSize diagramObject, 70, 200
						end if	
					next
					if missing then 
						Repository.WriteOutput "Endringer", Now & " Legger til " & elementB.Name & " i diagrammet " & eDiagram.Name,0
						set diagramObject = eDiagram.DiagramObjects.AddNew("", "")
						diagramObject.ElementID = elementB.ElementID
						diagramObject.Update()
						'Skjuler egenskaper (AttPub=0) (alle egenskaper i modellen er public)
						hideAttributes(diagramObject)
						'Størrelse w=200xh=70
						setSize diagramObject, 70, 200				
						changed = true
					end if	
					eDiagram.DiagramObjects.Refresh					
				Next
				'Skjuler assosiasjoner som ikke går fra aktuelt element, viser de som skal vises
				Dim edCon As EA.DiagramLink
				eDiagram.DiagramLinks.Refresh()
				'for each edCon in eDiagram.DiagramLinks
				For idxD = 0 To eDiagram.DiagramLinks.Count - 1
					set edCon = eDiagram.DiagramLinks.GetAt(idxD)
					Repository.WriteOutput "Script", Now & " ConnectorID: " & edCon.ConnectorID,0
					if not lstAss.Contains(edCon.ConnectorID) then
						eDiagram.DiagramLinks.DeleteAt idxD, false
					else
						set con = Repository.GetConnectorByID(edCon.ConnectorID)
						if con.ClientID = element.ElementID or con.SupplierID = element.ElementID then
							edCon.IsHidden = False
						else
							edCon.IsHidden = True
						End If
						edCon.Update()
					end if	
				Next 
				eDiagram.DiagramLinks.Refresh
				'fix layout dersom endring
				if changed then 
					ePIF.LayoutDiagramEx eDiagram.DiagramGUID, 4, 4, 20, 20, True
					repository.CloseDiagram(eDiagram.DiagramID)
				end if	
				updateDiagramProperties
				
			end if	
		next

	
		'---------------------
		'Betingelserdiagrammet
		if constraintsDiagram = "0" then
			set eDiagram = pkOT.Diagrams.AddNew(pkOT.Name & " Betingelser", "Logical")
			eDiagram.Update
			constraintsDiagram = eDiagram.DiagramGUID
			Repository.WriteOutput "Endringer", Now & " Lager nytt diagram " & eDiagram.Name,0
		end if
		set eDiagram = Repository.GetDiagramByGuid(constraintsDiagram)	
		'Skal inneholde kun selve featuretypen, som det kun er en av i hver pakke
		Repository.WriteOutput "Script", Now & " Sjekker diagrammet " & eDiagram.Name,0
		for each element in pkOT.Elements
			if UCase(element.Stereotype) = "FEATURETYPE" then
				'Sjekk om klassen finnes i diagrammet, legg til dersom den mangler. Sletter diagramobjekter som ikke er den aktuelle klassen
				missing = true
				for idxD = 0 to eDiagram.DiagramObjects.Count - 1
					set diagramObject = eDiagram.DiagramObjects.GetAt(idxD)
					if diagramObject.ElementId = element.ElementId then
						missing = false
					else			
						set elementB = Repository.GetElementByID(diagramObject.ElementId)
						Repository.WriteOutput "Endringer", Now & " Sletter diagramobjekt " & elementB.Name & " fra diagrammet " & eDiagram.Name,0
						eDiagram.DiagramObjects.DeleteAt idxD,false
					end if		
				next
				if missing then 
					Repository.WriteOutput "Endringer", Now & " Legger til " & element.Name & " i diagrammet " & eDiagram.Name,0
					set diagramObject = eDiagram.DiagramObjects.AddNew("", "")
					diagramObject.ElementID = element.ElementID
					'Viser constraints ("Constraint=1")
					Dim strDiagramObjectStyle
					strDiagramObjectStyle = ""
					strDiagramObjectStyle = diagramObject.Style
					If InStr(strDiagramObjectStyle, "Constraint=0") > 0 Then
						diagramObject.Style = Replace(strDiagramObjectStyle, "Constraint=0", "Constraint=1")
					ElseIf InStr(strDiagramObjectStyle, "Constraint=1") = 0 Then
						diagramObject.Style = strDiagramObjectStyle & "Constraint=1;"
					End If
					diagramObject.Update()
				end if	
				eDiagram.DiagramObjects.Refresh
			end if	
		next
		updateDiagramProperties
		
		
		'------------------------------
		'Tillatte verdier-diagrammet
		if codeListDiagram = "0" then
			set eDiagram = pkOT.Diagrams.AddNew(pkOT.Name & " Tillatte verdier", "Logical")
			eDiagram.Update
			codeListDiagram = eDiagram.DiagramGUID		
			Repository.WriteOutput "Endringer", Now & " Lager nytt diagram " & eDiagram.Name,0
		end if
		
		set eDiagram = Repository.GetDiagramByGuid(codeListDiagram)	
		'Skal inneholde alle klasser i pakken
		Repository.WriteOutput "Script", Now & " Sjekker diagrammet " & eDiagram.Name,0
		'Sletter først diagramobjekter som ikke er i den aktuelle pakken
		for idxD = 0 to eDiagram.DiagramObjects.Count - 1
			set diagramObject = eDiagram.DiagramObjects.GetAt(idxD)
			set element = Repository.GetElementByID(diagramObject.ElementId)	
			if element.PackageId <> pkOT.PackageId then
				Repository.WriteOutput "Endringer", Now & " Sletter diagramobjekt " & elementB.Name & " fra diagrammet " & eDiagram.Name,0
				'eDiagram.DiagramObjects.DeleteAt idxD,false
			end if		
		next
		
		for each element in pkOT.Elements
			'Sjekk om klassen finnes i diagrammet, legg til dersom den mangler. 
			missing = true
			for idxD = 0 to eDiagram.DiagramObjects.Count - 1
				set diagramObject = eDiagram.DiagramObjects.GetAt(idxD)
				if diagramObject.ElementId = element.ElementId then
					missing = false
				end if		
			next
			if missing then 
				Repository.WriteOutput "Endringer", Now & " Legger til " & element.Name & " i diagrammet " & eDiagram.Name,0
				set diagramObject = eDiagram.DiagramObjects.AddNew("", "")
				diagramObject.ElementID = element.ElementID
				diagramObject.Update()
				changed = true
			end if	
			eDiagram.DiagramObjects.Refresh
		next
		'fix layout dersom endring
		if changed then 
			ePIF.LayoutDiagramEx eDiagram.DiagramGUID, 4, 4, 20, 20, True
			repository.CloseDiagram(eDiagram.DiagramID)
		end if
		updateDiagramProperties
		pkOT.Diagrams.Refresh()
		
	Next
		
	Repository.WriteOutput "Script", Now & " Ferdig, sjekk logg", 0 
	Repository.EnsureOutputVisible "Script"
end sub

updateDiagrams()