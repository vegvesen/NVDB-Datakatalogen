option explicit

!INC Local Scripts.EAConstants-VBScript
!INC NVDB._felles
!INC NVDB._parametre


' Denne filen inneholder funksjoner for oppdatering av diagrammer for vegobjekttyper i EA-prosjektet. 
' Alle vegobjekttyper skal ha tre diagrammer: "... betingelser", "... assosiasjoner" og "... tillatte verdier"
'
' Script Name: NVDB til UML.Diagrammer
' Author: Knut Jetlund
' Purpose: Oppdatering av diagrammer
' Date: 20220919
'
' **************************************************************

'Oppdaterer egenskaper på et enkelt diagra,
Sub updateProperties_Diagram(eD)
	eD.ShowDetails = 0
	eD.Author = "Dakat"
	eD.Version = FC_version
	eD.Update()
	'Skjule namespace (t_diagram.ShowForeign)
	Repository.Execute("UPDATE T_DIAGRAM SET SHOWFOREIGN=FALSE WHERE DIAGRAM_ID=" & eD.DiagramID)
End Sub

'Kontroll av om alle elementer i pakka finnes i et diagram
Sub updateDiagramObjects(eD)
	For idxE = 0 To pkOT_Sub.Elements.Count - 1
		set elementB = pkOT_Sub.Elements.GetAt(idxE)
		set diagramObjekt = Nothing
		'Går gjennom alle diagramobjekter og sjekker om elementet er et av dem
		For idxD = 0 To eD.DiagramObjects.Count - 1
			set diagramObjekt = eD.DiagramObjects.GetAt(idxD)
			If diagramObjekt.ElementID = elementB.ElementID Then
				idxD = eD.DiagramObjects.Count - 1 'elementet er funnet, hopper ut av løkka
			Else
				set diagramObjekt = Nothing
			End If
		Next 
		'Legger til manglende element i diagrammet
		If diagramObjekt Is Nothing Then
			Repository.WriteOutput "Endringer", Now & " Legger til vegobjekttype eller kodeliste i diagrammet " & eD.Name & ": " & elementB.Name, 0
			set diagramObjekt = eD.DiagramObjects.AddNew("", "")
			diagramObjekt.ElementID = elementB.ElementID
			diagramObjekt.Update()
		End If
	Next 
End Sub

'Oppdatering av assosierte vegobjekttyper for angitt element i angitt diagram. 
Sub updateDiagramObjectsAssociations(eD, el, mothers, strST)
	Dim strDiagramObjectStyle 
	strDiagramObjectStyle  = ""
	set diagramObjekt =  Nothing

	'Går gjennom alle assosiasjoner for objekttypen, og legger til i diagrammet dersom de mangler
	For idxC = 0 To el.Connectors.Count - 1
		set con = el.Connectors.GetAt(idxC)
		set elementB = Nothing
		'Tar med alle assosiasjoner dersom det er angitt (mothers = true), ellers kun der aktuelt element er "Supplier" (con.SupplierID = element.ElementID)
		If con.type = "Aggregation" or con.Type = "Association" or con.type = "Generalization" or con.Type = "Generalisation" Then
			'Finner assosiert element
			If con.SupplierID = el.ElementID Then
				set elementB = Repository.GetElementByID(con.ClientID)
			ElseIf con.ClientID = el.ElementID And mothers=True Then
				set elementB = Repository.GetElementByID(con.SupplierID)
			End If
			
			If Not elementB Is Nothing Then
				'Kontrollerer om den assosierte objekttypen finnes i diagrammet
				For idxD = 0 To eD.DiagramObjects.Count - 1
					set diagramObjekt = eD.DiagramObjects.GetAt(idxD)
					If diagramObjekt.ElementID = elementB.ElementID Then
						idxD = eD.DiagramObjects.Count - 1
					Else
						set diagramObjekt = Nothing
					End If
				Next 
				If diagramObjekt Is Nothing Then
					Repository.WriteOutput "Endringer", Now & " Legger til assosiert objekttype " & elementB.Name & " i diagrammet " & eD.Name,0
					set diagramObjekt = eD.DiagramObjects.AddNew("", "")
					diagramObjekt.ElementID = elementB.ElementID
					diagramObjekt.Update()
				End If
			End If
			eD.DiagramObjects.Refresh()
		End If
	Next 

	'Løkke for alle diagramobjekter i diagrammet:
	'Kontrollerer om det finnes objekttyper i diagrammet som ikke er assosiert lenger, og fjerner dem
	'Assosierte objekttyper som skal være med: Skjuler egenskaper
	For idxD = 0 To eD.DiagramObjects.Count - 1
		set diagramObjekt = eD.DiagramObjects.GetAt(idxD)
		'Finner tilhørende element til diagramobjektet
		set elementB = Repository.GetElementByID(diagramObjekt.ElementID)
		'Sjekker at elementet har angitt stereotype, og at det ikke er aktuelt element.
		If elementB.Stereotype = strST And elementB.ElementID <> el.ElementID Then
			'Løkke for assosiasjoner på hovedelementet, sjekker om elementet fra diagramobjektet er assosiert. 
			For idxC = 0 To el.Connectors.Count - 1
				set con = el.Connectors.GetAt(idxC)
				'Sjekker om aktuell assosiasjon har aktuelt element som "Supplier" og element fra aktuelt diagramobjekt som "Client", eller omvendt
				If (con.SupplierID = el.ElementID And con.ClientID = elementB.ElementID) Or (con.SupplierID = elementB.ElementID And con.ClientID = el.ElementID And mothers=True) Then
					idxC = el.Connectors.Count - 1
				Else
					set con = Nothing
				End If
			Next 

			If con Is Nothing Then
				'Ikke assosiert objekttype, fjernes fra diagrammet
				Repository.WriteOutput "Endringer", Now & " Fjerner objekttypen " & elementB.Name & " fra diagrammet " & eD.Name,0
				eD.DiagramObjects.DeleteAt idxD, False
			Else
				'Skal være med, skjuler egenskaper (AttPub=0) (alle egenskaper i modellen er public)
				hideAttributes(diagramObjekt)
				'Størrelse w=200xh=70
				setSize diagramObjekt, 70, 200
			End If
		End If
	Next 

	'Skjuler assosiasjoner som ikke går fra aktuelt element, viser de som skal vises
	Dim edCon As EA.DiagramLink
	eD.DiagramLinks.Refresh()
	For idxD = 0 To eD.DiagramLinks.Count - 1
		set edCon = eD.DiagramLinks.GetAt(idxD)
		set con = Repository.GetConnectorByID(edCon.ConnectorID)
		if con.ClientID = el.ElementID or con.SupplierID= el.ElementID then
			edCon.IsHidden = False
		else
			edCon.IsHidden = True
		End If
		edCon.Update()
	Next 
End Sub

'Oppdatering av alle diagrammer for alle vegobjekttyper. 
sub updateDiagrammer()
	'Kobler til modeller og databaser
	connect2models
    Repository.WriteOutput "Script", Now & " Oppdaterer diagrammer", 0 
	Dim nyttDiagram 
	'Kjører gjennom alle diagrammer for alle pakker i EA.
	For idxP = 0 To pkObjekttyper.Packages.Count - 1
		set pkOT_Sub = pkObjekttyper.Packages.GetAt(idxP)
		Repository.WriteOutput "Script", Now & " OPPDATERER DIAGRAMMER FOR VEGOBJEKTTYPEN " & UCase(pkOT_Sub.Name), 0
		'Finner selve objekttypen
		set element = getElementByAlias(pkOT_Sub, pkOT_Sub.Alias)
		if not element is nothing then	
			'Sjekker hvilke digrammer som finnes i pakken. Skal bare ha diagrammer som heter "... betingelser", "... assosiasjoner" og "... tillatte verdier"
			'Alle andre slettes
			i = 0
			For Each eDiagram In pkOT_Sub.Diagrams
				If eDiagram.Name <> pkOT_Sub.Name & " Betingelser" And eDiagram.Name <> pkOT_Sub.Name & " Assosiasjoner" And eDiagram.Name <> pkOT_Sub.Name & " Tillatte verdier" Then
					Repository.WriteOutput "Endringer", Now & " Sletter diagrammet " & eDiagram.Name,0
					'Ugyldig navn --> Diagrammet slettes
					pkOT_Sub.Diagrams.DeleteAt i, False
				End If
				i = i + 1
			Next
			pkOT_Sub.Diagrams.Refresh()
			
			'---------------
			'Oppdatering av diagram med pakkenavnet + " betingelser". Skal ha med bare selve vegobjekttypen med egenskaper og betingelser
			Repository.WriteOutput "Script", Now & " Oppdaterer diagrammet " & pkOT_Sub.Name & " Betingelser",0
			set eBDiagram = pkOT_Sub.Diagrams.GetByName(pkOT_Sub.Name & " Betingelser")
			if not eBDiagram is nothing then
				'Diagrammet finnes
				set diagramObjekt = eBDiagram.DiagramObjects.GetAt(0)
				nyttDiagram = False
			else
				'Diagrammet finnes ikke --> Lager nytt og legger til selve vegobjekttypen
				Repository.WriteOutput "Endringer", Now & " Lager diagrammet " & pkOT_Sub.Name & " Betingelser",0
				set eBDiagram = pkOT_Sub.Diagrams.AddNew(pkOT_Sub.Name & " Betingelser", "Logical")
				eBDiagram.Update()
				set diagramObjekt = eBDiagram.DiagramObjects.AddNew("", "")
				diagramObjekt.ElementID = element.ElementID
				diagramObjekt.Update()
				nyttDiagram = True
			End if
			'Viser constraints ("Constraint=1")
			Dim strDiagramObjectStyle
			strDiagramObjectStyle = ""
			strDiagramObjectStyle = diagramObjekt.Style
			If InStr(strDiagramObjectStyle, "Constraint=0") > 0 Then
				diagramObjekt.Style = Replace(strDiagramObjectStyle, "Constraint=0", "Constraint=1")
			ElseIf InStr(strDiagramObjectStyle, "Constraint=1") = 0 Then
				diagramObjekt.Style = strDiagramObjectStyle & "Constraint=1;"
			End If
			diagramObjekt.Update()
			updateProperties_Diagram eBDiagram
			'Kjører autolayout hvis nytt diagram
			If nyttDiagram=True Then 
				ePIF.LayoutDiagramEx eBDiagram.DiagramGUID, 4, 4, 20, 20, True
				repository.CloseDiagram(eBDiagram.DiagramID)
				pkOT_Sub.Diagrams.Refresh()
			end if
				
			'---------------
			'Kontroll og oppdatering av diagram med tillatte verdier. Skal ha med alle elementer i aktuell pakke (vegobjekttypen og kodelister), men ikke assosierte vegobjekktyper
			Repository.WriteOutput "Script", Now & " Oppdaterer diagrammet " & pkOT_Sub.Name & " Tillatte verdier",0
			set eTVDiagram = Nothing
			For Each eDiagram In pkOT_Sub.Diagrams
				If eDiagram.Name = pkOT_Sub.Name & " Tillatte verdier" Then
					'Diagrammet finnes
					set eTVDiagram = eDiagram
					nyttDiagram = False
				End If
			Next

			if eTVDiagram is nothing then
				'diagrammet finnes ikke --> Lager nytt
				set eTVDiagram = pkOT_Sub.Diagrams.AddNew(pkOT_Sub.Name & " Tillatte verdier", "Logical")
				eTVDiagram.Update()
				Repository.WriteOutput "Endringer", Now & " Lager diagrammet " & eTVDiagram.Name,0
				nyttDiagram = True
			End if
			'Legger til alle klasser fra pakka
			updateDiagramObjects(eTVDiagram)
			updateProperties_Diagram eTVDiagram
			'Autolayout hvis nytt diagram
			If nyttDiagram Then 
				ePIF.LayoutDiagramEx eTVDiagram.DiagramGUID, 4, 4, 20, 20, True
				repository.CloseDiagram(eTVDiagram.DiagramID)
				pkOT_Sub.Diagrams.Refresh()
			end if	
			
			'---------------
			'Kontroll og oppdatering av diagram med assosiasjoner. Skal ha med alle assosierte vegobjekttyper, men ikke kodelister
			Repository.WriteOutput "Script", Now & " Oppdaterer diagrammet " & pkOT_Sub.Name & " Assosiasjoner", 0
			set eASDiagram = Nothing
			For Each eDiagram In pkOT_Sub.Diagrams
				If eDiagram.Name = pkOT_Sub.Name & " Assosiasjoner" Then
					'Diagrammet finnes
					set eASDiagram = eDiagram
					nyttDiagram = False
				End If
			Next

			if eASDiagram is nothing then
				'Diagrammet finnes ikke --> Lager nytt
				set eASDiagram = pkOT_Sub.Diagrams.AddNew(pkOT_Sub.Name & " Assosiasjoner", "Logical")
				eASDiagram.Update()
				'Legger til selve objekttypen
				set diagramObjekt = eASDiagram.DiagramObjects.AddNew("", "")
				diagramObjekt.ElementID = element.ElementID
				diagramObjekt.Update()
				Repository.WriteOutput "Endringer", Now & " Lager diagrammet " & eASDiagram.Name, 0 
				nyttDiagram = True
			End if
			'Spesiell håndtering for Dokumentasjon, Kommentar, Systemobjekt og Tilstand*. Skal ikke ha med morobjekt
			If element.Name = "Dokumentasjon" Or element.Name = "Kommentar" Or element.Name = "Systemobjekt" Or Mid(element.Name, 1, 8) = "Tilstand" Then
				updateDiagramObjectsAssociations eASDiagram, element, False, "Vegobjekttype"
			Else
				'Tar med morobjekter i diagrammet for alle andre vegobjekttyper
				updateDiagramObjectsAssociations eASDiagram, element, True, "Vegobjekttype"
			End If
			updateProperties_Diagram eASDiagram
			'Autolayout hvis nytt
			If nyttDiagram Then 
				ePIF.LayoutDiagramEx eASDiagram.DiagramGUID, 4, 4, 20, 20, True
				repository.CloseDiagram(eASDiagram.DiagramID)
				pkOT_Sub.Diagrams.Refresh()
			end if	
		end if
	Next

	Repository.WriteOutput "Script", Now & " Ferdig, sjekk logg", 0 
	Repository.EnsureOutputVisible "Script"

end sub

updateDiagrammer
