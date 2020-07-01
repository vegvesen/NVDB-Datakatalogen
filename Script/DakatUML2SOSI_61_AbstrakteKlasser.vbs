option explicit

!INC Local Scripts.EAConstants-VBScript
									   
!INC NVDB._felles
!INC NVDB._parametre
								 

' Script Name: DakatUML2SOSI_X_AbstrakteKlasser
' Author: Knut Jetlund
' Purpose: Lager nivå med abstrakte klasser i SOSI-NVDB-modellen, for å lette implementering i GML
' Date: 2020-06-04

dim absCon as EA.Connector
dim absAssEl as EA.Element
dim assEl as EA.Element

sub abstractClasses()
	Repository.EnsureOutputVisible "Script"
	Repository.ClearOutput "Script"
	Repository.CreateOutputTab "Error"
	Repository.ClearOutput "Error"

	set ePIF = Repository.GetProjectInterface

	'Hent hovedpakken for NVDB Datakatalogen i SOSI-modellregister
	set pkSOSINVDB = Repository.GetPackageByGuid(guidSOSIDatakatalog)
	dim absPck as EA.Package
	set absPck = Repository.GetPackageByGuid(guidAbstrakteKlasser)
	dim absElement as EA.Element
	
	dim lstAbsCls
	Set lstAbsCls = CreateObject("System.Collections.SortedList")
	Repository.WriteOutput "Script", Now & " Lager hjelpeliste over alle eksisterende abstrakte klasser ", 0 
	For each absElement in absPck.Elements
		Repository.WriteOutput "Script", Now & " Abstrakt klasse: " & absElement.Name &  " (" & absElement.Alias & ")", 0 
		lstAbsCls.Add absElement.Alias, absElement.ElementGUID
		'Sletter alle assosiasjoner fra abstrakte klasser
		for idxC = 0 to absElement.Connectors.Count -1
			set con = absElement.Connectors.GetAt(idxC)
			if con.type = "Aggregation" or con.Type = "Association" then
				Repository.WriteOutput "Script", Now & " Sletter assosiasjon fra abstrakt klasse: " & con.Type & " " & con.ClientID &  " - " & con.SupplierID, 0 
				absElement.Connectors.DeleteAt idxC, false
			end if	
		next
		absElement.Connectors.Refresh

	Next

	dim keyIndex
	dim guid
	dim msgAnsw
	
	Repository.WriteOutput "Script", Now & " Hovedpakke: " & pkSOSINVDB.Name & " (" & pkSOSINVDB.PackageGUID & ")", 0 
	'Kjører gjennom alle pakker og lager abstrakte vegobjekttyper med arv til konkrete vegobjekttyper
	for each pkOT in pkSOSINVDB.Packages	
		if pkOT.PackageGUID <> guidAbstrakteKlasser then 
			Repository.WriteOutput "Script", Now & " ------------------------------------------------------------------------------", 0 
			Repository.WriteOutput "Script", Now & " Lager/oppdaterer abstrakt klasse for vegobjekttype i pakken " & pkOT.Name, 0 
			for each element in pkOT.Elements
				if uCase(element.Stereotype) = "FEATURETYPE" then
					Repository.WriteOutput "Script", Now & " Vegobjekttype: " & element.Name, 0 
					if not lstAbsCls.Contains(element.Alias) then 
						'Lager abstrakt klasse for elementet
						set absElement = absPck.Elements.AddNew("Abstrakt" & element.Name, "Class")
						Repository.WriteOutput "Script", Now & " Lager abstrakt klasse: " & absElement.Name, 0 
						absElement.Alias = element.Alias
						absElement.Version= element.Version
						absElement.Stereotype = "featureType"
						absElement.Abstract = True
						absElement.Update
						absPck.Elements.Refresh
						lstAbsCls.Add absElement.Alias, absElement.ElementGUID
					else
						keyIndex = lstAbsCls.IndexofKey(element.Alias)
						guid = lstAbsCls.GetByIndex(keyIndex)
						set absElement = Repository.GetElementByGuid(guid)
						Repository.WriteOutput "Script", Now & " Abstrakt klasse eksisterer: " & absElement.Name, 0					
					end if

					'Arv fra abstrakt klasse til opprinnelig klasse 
					dim lstAss
					Set lstAss = CreateObject("System.Collections.SortedList")
					dim inherits
					inherits = false					
					for each con in element.Connectors
						if con.type = "Generalization" or con.type = "Generalisation" then
							if con.SupplierID = absElement.ElementID then inherits = true
						end if	
					next
					If not inherits then 
						Repository.WriteOutput "Script", Now & " Legger til arv fra abstrakt klasse " & absElement.Name & " til vegobjekttypen " & element.Name, 0
						set con = element.Connectors.AddNew("", "Generalization")
						con.ClientID = element.ElementID
						con.SupplierID = absElement.ElementID
						con.Update()
					else
						Repository.WriteOutput "Script", Now & " Arv eksisterer fra abstrakt klasse " & absElement.Name & " til vegobjekttypen " & element.Name, 0					
					end if
				end if
			next
		end if
	next
	
	'Mulighet for å hoppe ut av løkka - fjernes når scriptet er ferdig.
	'msgAnsw = MsgBox("Sjekk modellen nå", vbOkCancel, "Abstrakte klasser")
	'if msgAnsw = 2 then
	'	Repository.WriteOutput "Script", Now & " Ferdig, sjekk resultatfilene...", 0 
	'	exit sub
	'end if	

	'Ny løkke for å legge til assosiasjoner til abstrakte vegobjekttyper
	for each pkOT in pkSOSINVDB.Packages	
		if pkOT.PackageGUID <> guidAbstrakteKlasser then 
			Repository.WriteOutput "Script", Now & " ------------------------------------------------------------------------------", 0 
			Repository.WriteOutput "Script", Now & " Assosiasjoner til abstrakte klasser for vegobjekttype i pakken " & pkOT.Name, 0 
			for each element in pkOT.Elements
				if uCase(element.Stereotype) = "FEATURETYPE" then
					Repository.WriteOutput "Script", Now & " Vegobjekttype: " & element.Name, 0 
					for each con in element.Connectors
						if (con.type = "Aggregation" or con.Type = "Association") then
							'Lag ny assosiasjon 
							set absCon = element.Connectors.AddNew("",con.Type)
							absCon.Subtype = con.Subtype
							'Finn assosiert element
							if con.ClientID = element.ElementID then 
								set assEl = Repository.GetElementByID(con.SupplierID)
							else
								set assEl = Repository.GetElementByID(con.ClientID)
							end if
							'Finn assosiert element sin abstrakte klasse				
							keyIndex = lstAbsCls.IndexofKey(assEl.Alias)
							guid = lstAbsCls.GetByIndex(keyIndex)
							set absAssEl = Repository.GetElementByGuid(guid)
							'Legg til assosiert abstrakt klasse som motsatt ende på assosiasjonen
							Repository.WriteOutput "Script", Now & " Legger til assosiasjon mellom vegobjekttypen " & element.Name & " og den abstrakte vegobjekttypen " & absAssEl.Name, 0
							Repository.WriteOutput "Script", Now & " Rollenavn og kardinaliteter", 0 
							'Angi kardinaliteter 
							absCon.ClientEnd.Visibility = con.ClientEnd.Visibility
							absCon.ClientEnd.Cardinality = con.ClientEnd.Cardinality
							absCon.SupplierEnd.Visibility = con.SupplierEnd.Visibility
							absCon.SupplierEnd.Cardinality = con.SupplierEnd.Cardinality
							if con.ClientID = element.ElementID then 
								absCon.ClientID = element.ElementID
								absCon.SupplierID = absAssEl.ElementID
								absCon.ClientEnd.Role = "" 
								absCon.ClientEnd.Navigable = "Non-Navigable"
								absCon.SupplierEnd.Role = "assosiert" & assEl.Name
								absCon.SupplierEnd.Navigable = "Navigable"
							else
								absCon.ClientID = absAssEl.ElementID
								absCon.SupplierID = element.ElementID
								absCon.SupplierEnd.Role = "" 
								absCon.SupplierEnd.Navigable = "Non-Navigable"
								absCon.ClientEnd.Role = "assosiert" & assEl.Name
								absCon.ClientEnd.Navigable = "Navigable"
							end if
							absCon.Update

							'Tagged values fra originalassosiasjon
							dim cTagNVDB as EA.ConnectorTag
							for each cTagNVDB in con.TaggedValues
								Repository.WriteOutput "Script", Now & " Legger til tagged value " & cTagNVDB.Name & ": " & cTagNVDB.Value, 0 
								set cTag = absCon.TaggedValues.AddNew(cTagNVDB.Name, cTagNVDB.Value)
								cTag.Update()
							next	
							absCon.TaggedValues.Refresh()

							'GML-tagged values på assosiasjonsendene
							Dim rTag As EA.RoleTag
							dim rTagFound
							rTagFound = false
							for each rTag in absCon.ClientEnd.TaggedValues
								if rTag.Tag = "inlineOrByReference" then
									rTag.Value = "ByReference"
									rTag.Update
									rTagFound = true
								end  if
							next
							if not rTagfound then 
								set rTag = absCon.ClientEnd.TaggedValues.AddNew("inlineOrByReference", "ByReference")
								rTag.Update()
							end if	
							absCon.ClientEnd.TaggedValues.Refresh()
							absCon.ClientEnd.Update()
							
							rTagFound = false
							for each rTag in absCon.SupplierEnd.TaggedValues
								if rTag.Tag = "inlineOrByReference" then
									rTag.Value = "ByReference"
									rTag.Update
									rTagFound = true
								end  if
							next
							if not rTagfound then 
								set rTag = absCon.SupplierEnd.TaggedValues.AddNew("inlineOrByReference", "ByReference")
								rTag.Update()
							end if	
							absCon.SupplierEnd.TaggedValues.Refresh()
							absCon.SupplierEnd.Update()

							absCon.Update
						end if	
					next
					element.Connectors.Refresh
					
					for each con in element.Connectors
						Repository.WriteOutput "Script", Now & " " & Con.Type & " connector: " & con.ConnectorID, 0 
						for each cTag in con.TaggedValues
							Repository.WriteOutput "Script", Now & " Connector tagged value " & cTag.Name & ": " & cTag.Value, 0 
						next				
					next
				end if
			next
		end if
		
		'Mulighet for å hoppe ut av løkka - fjernes når scriptet er ferdig.
		'msgAnsw = MsgBox("Sjekk modellen nå", vbOkCancel, "Abstrakte klasser")
		'if msgAnsw = 2 then
		'	Repository.WriteOutput "Script", Now & " Ferdig, sjekk resultatfilene...", 0 
		'	exit sub
		'end if	
	next

	'Ny løkke for å slette assosiasjoner mellom konkrete klasser
	for each pkOT in pkSOSINVDB.Packages	
		if pkOT.PackageGUID <> guidAbstrakteKlasser then 
			Repository.WriteOutput "Script", Now & " ------------------------------------------------------------------------------", 0 
			Repository.WriteOutput "Script", Now & " Sletter assosiasjoner til konkrete klasser for vegobjekttype i pakken " & pkOT.Name, 0 
			for each element in pkOT.Elements
				if uCase(element.Stereotype) = "FEATURETYPE" then
					Repository.WriteOutput "Script", Now & " Vegobjekttype: " & element.Name, 0 
					for idxC = 0 to element.Connectors.Count - 1
						set con = element.Connectors.GetAt(idxC)
						if (con.type = "Aggregation" or con.Type = "Association") then
							if con.ClientID = element.ElementID then 
								set assEl = Repository.GetElementByID(con.SupplierID)
							else
								set assEl = Repository.GetElementByID(con.ClientID)
							end if
							if assEl.Abstract = 0 then
								'Assosiasjon til konkret klasse, slettes
								element.Connectors.DeleteAt idxC, false
							end if	
						end if	
					next
					element.Connectors.Refresh
				end if
			next
		end if
		
		'Mulighet for å hoppe ut av løkka - fjernes når scriptet er ferdig.
		'msgAnsw = MsgBox("Sjekk modellen nå", vbOkCancel, "Abstrakte klasser")
		'if msgAnsw = 2 then
		'	Repository.WriteOutput "Script", Now & " Ferdig, sjekk resultatfilene...", 0 
		'	exit sub
		'end if	
	next

	'Løkke for assosiasjonsdiagrammer. Erstatter alle konkrete klasser med abstrakte klasser
	Repository.WriteOutput "Script", Now & "  ", 0 
	for each pkOT in pkSOSINVDB.Packages
		if pkOT.PackageGUID <> guidAbstrakteKlasser then 
			Repository.WriteOutput "Script", Now & " ------------------------------------------------------------------------------", 0 
			Repository.WriteOutput "Script", Now & " Oppdaterer assosiasjonsdiagram for pakken " & pkOT.Name, 0 
			for each eDiagram in pkOT.Diagrams
				if eDiagram.Name = pkOT.Name & " Assosiasjoner" then
					Repository.WriteOutput "Script", Now & " Diagram: " & eDiagram.Name, 0 
					dim concreteCls
					concreteCls = false
					for each diagramObject in eDiagram.DiagramObjects
						set element = Repository.GetElementByID(diagramObject.ElementID)
						if element.Alias <> pkot.Alias and lstAbsCls.Contains(element.Alias) then 
							keyIndex = lstAbsCls.IndexofKey(element.Alias)
							guid = lstAbsCls.GetByIndex(keyIndex)
							set absElement = Repository.GetElementByGuid(guid)
							if absElement.ElementID <> element.ElementID then 
								Repository.WriteOutput "Script", Now & " Erstatter konkret klasse med abstrakt klasse: " & absElement.Name, 0		
								diagramObject.ElementID = absElement.ElementID
								diagramObject.Update
							end if	
						end if
						if element.Alias = pkOT.Alias and element.Abstract = 0 then
							'Den konkrete hovedklassen finnes i diagrammet
							Repository.WriteOutput "Script", Now & " Konkret hovedklasse funnet i diagrammet: " & element.Name, 0		
							concreteCls = true
						else
							setSize diagramObject, 70, 200
						end if
					next
					if not concreteCls then
						'Den konkrete hovedklassen finnes ikke i diagrammet. Legger til. 
						Repository.WriteOutput "Script", Now & " Konkret hovedklasse mangler i diagrammet", 0		
						for each element in pkOT.Elements
							if UCase(element.Stereotype) = "FEATURETYPE" then
								Repository.WriteOutput "Script", Now & " Legger til konkret hovedklasse: " & element.Name, 0		
								set diagramObject = eDiagram.DiagramObjects.AddNew("", "")
								diagramObject.ElementId = element.ElementID
								diagramObject.Update
							end if
						next			
					end if
					ePIF.LayoutDiagramEx eDiagram.DiagramGUID, 4, 4, 20, 20, True
					repository.CloseDiagram(eDiagram.DiagramID)
				end if
			next
		end if	
		'Mulighet for å hoppe ut av løkka - fjernes når scriptet er ferdig.
		'msgAnsw = MsgBox("Sjekk modellen nå", vbOkCancel, "Abstrakte klasser")
		'if msgAnsw = 2 then
		'	Repository.WriteOutput "Script", Now & " Ferdig, sjekk resultatfilene...", 0 
		'	exit sub
		'end if	
		
	next
	Repository.WriteOutput "Script", Now & " Ferdig, sjekk logg", 0 
	Repository.EnsureOutputVisible "Script"
end sub

abstractClasses()