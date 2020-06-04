option explicit

!INC Local Scripts.EAConstants-VBScript
									   
!INC NVDB._felles
!INC NVDB._parametre
								 

' Script Name: DakatUML2SOSI_X_AbstrakteKlasser
' Author: Knut Jetlund
' Purpose: Lager nivå med abstrakte klasser i SOSI-NVDB-modellen, for å lette implementering i GML
' Date: 2020-06-04


sub abstractClasses()
	Repository.EnsureOutputVisible "Script"
	Repository.ClearOutput "Script"
	Repository.CreateOutputTab "Error"
	Repository.ClearOutput "Error"

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
	Next

	dim keyIndex
	dim guid
	dim msgAnsw

	Repository.WriteOutput "Script", Now & " Hovedpakke: " & pkSOSINVDB.Name & " (" & pkSOSINVDB.PackageGUID & ")", 0 
	
	'Kjører gjennom alle pakker 
	for each pkOT in pkSOSINVDB.Packages	
		if pkOT.PackageGUID <> guidAbstrakteKlasser then 
			Repository.WriteOutput "Script", Now & " ------------------------------------------------------------------------------", 0 
			Repository.WriteOutput "Script", Now & " Lager/oppdaterer abstrakt klasse for vegobjekttype i pakken " & pkOT.Name, 0 
			for each element in pkOT.Elements
				if uCase(element.Stereotype) = "FEATURETYPE" then
					Repository.WriteOutput "Script", Now & " Vegobjekttype: " & element.Name, 0 
					if not lstAbsCls.Contains(element.Alias) then 
						'Lager abstrakt klasse som skal være bærer av assosiasjonene
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

					'Arv fra abstrakt klasse til opprinnelig klasse + liste over assosiasjoner
					dim lstAss
					Set lstAss = CreateObject("System.Collections.SortedList")
					dim assEl as EA.Element
					dim inherits
					inherits = false					
					for each con in absElement.Connectors
						if con.type = "Generalization" then
							if con.SupplierID = absElement.ElementID then inherits = true
						else
							if con.ClientID <> absElement.ElementID then 
								set assEl = Repository.GetElementByID(con.ClientID)
							else
								set assEl = Repository.GetElementByID(con.SupplierID)								
							end if
							lstAss.Add assEl.Alias, assEl.ElementGUID
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
					
					'Flytter assosiasjoner fra opprinnelig klasse til abstrakt klasse
					dim iC 
					for iC = 0 to element.Connectors.Count - 1
						set con = element.Connectors.GetAt(iC)
						if (con.type = "Aggregation" or con.Type = "Association") then
							if con.ClientID <> element.ElementID then 
								set assEl = Repository.GetElementByID(con.ClientID)
								if not lstAss.Contains(assEl.Alias) then 
									Repository.WriteOutput "Script", Now & " Legger til assosiasjon mellom abstrakt klasse " & absElement.Name & " og  vegobjekttypen " & assEl.Name, 0
									con.SupplierID = absElement.ElementID
									con.Update
								else
									'Sletter overføldig assosiasjon
									Repository.WriteOutput "Script", Now & " Assosiasjon eksisterer mellom abstrakt klasse " & absElement.Name & " og  vegobjekttypen " & assEl.Name, 0
									element.Connectors.DeleteAt iC, false
								end if	
							else
								set assEl = Repository.GetElementByID(con.SupplierID)								
								if not lstAss.Contains(assEl.Alias) then 
									con.ClientID = absElement.ElementID
									Repository.WriteOutput "Script", Now & " Legger til assosiasjon mellom abstrakt klasse " & absElement.Name & " og  vegobjekttypen " & assEl.Name, 0
									con.Update
								else
									Repository.WriteOutput "Script", Now & " Assosiasjon eksisterer mellom abstrakt klasse " & absElement.Name & " og  vegobjekttypen " & assEl.Name, 0
									element.Connectors.DeleteAt iC, false
								end if 
							end if
						end if	
					next
					element.Connectors.Refresh
						
					'Mulighet for å hoppe ut av løkka - fjernes når scriptet er ferdig.
					'msgAnsw = MsgBox("Sjekk modellen nå", vbOkCancel, "GML-applikasjonsskjema")
					'if msgAnsw = 2 then
					'	Repository.WriteOutput "Script", Now & " Ferdig, sjekk resultatfilene...", 0 
					'	exit sub
					'end if	
		
				end if
			next
		end if
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
					for each diagramObject in eDiagram.DiagramObjects
						set element = Repository.GetElementByID(diagramObject.ElementID)
						if lstAbsCls.Contains(element.Alias) then 
							keyIndex = lstAbsCls.IndexofKey(element.Alias)
							guid = lstAbsCls.GetByIndex(keyIndex)
							set absElement = Repository.GetElementByGuid(guid)
							Repository.WriteOutput "Script", Now & " Erstatter konkret klasse med abstrakt klasse: " & absElement.Name, 0		
							diagramObject.ElementID = absElement.ElementID
							diagramObject.Update
						end if
					next
				end if
			next
		end if	
		'Mulighet for å hoppe ut av løkka - fjernes når scriptet er ferdig.
		'msgAnsw = MsgBox("Sjekk modellen nå", vbOkCancel, "GML-applikasjonsskjema")
		'if msgAnsw = 2 then
		'	Repository.WriteOutput "Script", Now & " Ferdig, sjekk resultatfilene...", 0 
		'	exit sub
		'end if	
		
	next
	Repository.WriteOutput "Script", Now & " Ferdig, sjekk logg", 0 
	Repository.EnsureOutputVisible "Script"
end sub

abstractClasses()